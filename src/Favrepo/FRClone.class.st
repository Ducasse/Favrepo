"
I represent a clone of a project: its Iceberg repository, seen by the favorites tool. I know its baselines and branches, and how to load it. Key messages are `loadBaselineFor:`, `switchTo:` and `createBottomBranch`.

## Examples

```
FRClone instanceMissingOnDisk
```

## Design Rationale

- What Iceberg knows is asked to Iceberg and never read again on disk: the source directory (`IceLibgitRepository>>codeDirectory`, from the .project file) and the baselines (`IcePackage>>isMetacelloBaseline`).
- I ask nothing to the user: the loader given to `loadBaselineFor:` does.
- When the commit of the image code is unknown to me I refuse a bottom branch: it would be at a commit unrelated to the image.

## Usage

1. `FRFavoriteLoader` creates me with `on:` around the Iceberg repository it cloned, registered, attached or found in the catalog.
2. It sends me `switchTo:`, `loadBaselineFor:` or `createBottomBranch`, and forgets me.

I hold no state but the repository, so two clones on the same repository are interchangeable.

## Implementation Notes

- `switchTo:` loads no code but adopts the commit checked out. Check `isImageCommitUnknown` before it: the image would be compared with an unrelated commit.
- `referenceCommitId` is nil when there is no reference commit, because `IceNoCommit` does not understand `id`.
"
Class {
	#name : 'FRClone',
	#superclass : 'Object',
	#instVars : [
		'iceRepository'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'bottom branch' }
FRClone class >> bottomBranchNameOn: aDate [
	"The bottom branch of aDate: its ISO date followed by -Bottom."

	^ aDate yyyymmdd , '-Bottom'
]

{ #category : 'instances' }
FRClone class >> instanceMissingOnDisk [
	"The clone of a repository that is not on disk: enough to look at, nothing can be loaded from it."

	<sampleInstance>
	^ self newOn: (IceLibgitRepository new
			   name: 'Mustache';
			   yourself)
]

{ #category : 'instance creation' }
FRClone class >> newOn: anIceRepository [

	^ self new
		  setIceRepository: anIceRepository;
		  yourself
]

{ #category : 'instance creation' }
FRClone class >> on: anIceRepository [

	^ self newOn: anIceRepository
]

{ #category : 'baselines' }
FRClone >> baselineNames [
	"The names of my baselines, without the BaselineOf prefix, sorted."

	^ (iceRepository workingCopy packages
		   select: [ :each | each isMetacelloBaseline ]
		   thenCollect: [ :each | each metacelloBaselineName ]) asArray sort
]

{ #category : 'branches' }
FRClone >> createBottomBranch [
	"Create today's bottom branch at my current commit and check it out; nothing is loaded, the image code stays. Answer its name."

	| branchName |
	self isImageCommitUnknown ifTrue: [ FRError signal: self unknownImageCommitReport ].
	branchName := self class bottomBranchNameOn: Date today.
	(iceRepository hasLocalBranchNamed: branchName) ifTrue: [
			FRError signal: ('{1} already has a branch {2}' format: {
						 self name.
						 branchName }) ].
	iceRepository createBranch: branchName.
	Iceberg announcer announce: (IceRepositoryModified for: iceRepository).
	^ branchName
]

{ #category : 'branches' }
FRClone >> fallbackCommitish [
	"The first of the fallback branches that I have, or nil."

	^ self fallbackCommitishes detect: [ :each | self hasCommitishNamed: each ] ifNone: [ nil ]
]

{ #category : 'branches' }
FRClone >> fallbackCommitishes [
	"The branches tried, in order, when the branch of a favorite does not exist."

	^ #( 'master' 'main' 'dev' )
]

{ #category : 'branches' }
FRClone >> hasCommitishNamed: aString [
	"Whether aString names a branch, a remote branch, a tag or a commit that I have."

	^ [
		  iceRepository commitishNamed: aString.
		  true ]
		  on: NotFound
		  do: [ false ]
]

{ #category : 'accessing' }
FRClone >> headName [
	"The branch or commit checked out."

	^ iceRepository head name
]

{ #category : 'accessing' }
FRClone >> iceRepository [

	^ iceRepository
]

{ #category : 'testing' }
FRClone >> isImageCommitUnknown [
	"Whether I do not have the commit the image code comes from (Iceberg's Fetch required)."

	^ iceRepository workingCopy workingCopyState isUnknownCommitState
]

{ #category : 'testing' }
FRClone >> isModified [

	^ iceRepository isModified
]

{ #category : 'testing' }
FRClone >> isPharo [
	"Whether I am a clone of Pharo: I hold its baseline or, when my commit is unknown and I list no package, the image was built from that commit."

	(iceRepository workingCopy packageNames includes: 'BaselineOfPharo') ifTrue: [ ^ true ].
	^ iceRepository workingCopy packages isEmpty and: [ self referenceCommitId = SystemVersion current commitHash ]
]

{ #category : 'baselines' }
FRClone >> loadBaselineFor: aLoader [
	"Load the baseline that aLoader chooses with Metacello, except the one of Pharo: it is the running system and its baseline does not load like the others."

	self isPharo ifTrue: [
		^ aLoader report: ('The baseline of {1} was not loaded: Pharo is the running system.' format: { self name }) ].
	self loadBaselineNamed: (aLoader baselineToLoadOf: self)
]

{ #category : 'baselines' }
FRClone >> loadBaselineNamed: aName [

	Metacello new
		baseline: aName;
		repository: self metacelloRepository;
		onConflictUseLoaded;
		onWarningLog;
		load
]

{ #category : 'baselines' }
FRClone >> metacelloRepository [

	^ 'gitlocal://' , iceRepository codeDirectory fullName
]

{ #category : 'accessing' }
FRClone >> name [

	^ iceRepository name
]

{ #category : 'accessing' }
FRClone >> referenceCommitId [
	"The id of the commit the image code comes from, or nil when there is none (nothing loaded yet) or several (a merge)."

	| commit |
	commit := iceRepository workingCopy referenceCommit.
	^ (commit isCollection or: [ commit isNoCommit ])
		  ifTrue: [ nil ]
		  ifFalse: [ commit id ]
]

{ #category : 'initialization' }
FRClone >> setIceRepository: anIceRepository [

	iceRepository := anIceRepository
]

{ #category : 'branches' }
FRClone >> switchTo: aCommitishName [
	"Check out aCommitishName without loading its code."

	iceRepository switchToCommitishNamed: aCommitishName
]

{ #category : 'reporting' }
FRClone >> unknownImageCommitReport [

	^ 'The clone of {1} does not have the commit the image was built from ({2}): Fetch it in Iceberg first (Repair repository).' format: {
		  self name.
		  iceRepository workingCopy referenceCommit shortId }
]
