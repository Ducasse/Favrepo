"
I attach a clone to the code the image already has: the code of a repository that came with the image without clone, such as Spec2, NewTools or Pharo itself. I find that repository, make it work on the clone, and put the clone on the commit the image was built from. Key messages are `repositoryLoadedFrom:` and `attach:to:`.

## Examples

```
FRCloneAttacher instanceSpec
```

## Design Rationale

- A clone of code that is in the image takes over the repository that came with the image instead of being registered apart: two repositories for the same code confuse Iceberg and the user.
- Which repository a clone belongs to is the business of `FRClone`: it depends on the kind of clone.
- Once attached, the parent of the fork is added as a remote and fetched, as Iceberg does when it clones a fork, then a branch `image-<commit>` is checked out at the commit the image was built from. Nothing is loaded: the image and the clone are in sync, and commits go to the fork (origin).
- When that commit is still unknown I adopt no other one: it would turn all the commits in between into changes of the user. The repository stays in the Fetch required state of Iceberg.

## Usage

1. `FRFavoriteLoader>>attacher` creates me, with an `informer:` block that tells the user what I did.
2. `FRFavoriteLoader>>registerOrAttach:for:` asks me for `repositoryLoadedFrom:` and, when there is one, sends me `attach:to:`.
3. I ask `FRUpstreamFinder` for the parent of the fork.
"
Class {
	#name : 'FRCloneAttacher',
	#superclass : 'Object',
	#instVars : [
		'upstreamFinder',
		'informer'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'instances' }
FRCloneAttacher class >> instanceSpec [
	"An attacher that knows where the forks of Spec come from; it attaches nothing until sent #attach:to:."

	<sampleInstance>
	^ self new
		  upstreamFinder: FRUpstreamFinder instanceSpec;
		  yourself
]

{ #category : 'upstream' }
FRCloneAttacher >> addUpstreamTo: aRepository [
	"Add the project aRepository was forked from as a remote named after its owner, as Iceberg does, and fetch it, so that the commit of the image is found even when the fork is behind. Answer its URL, or nil when there is none or it cannot be fetched (the user is told why)."

	| upstream remote |
	upstream := self upstreamFinder upstreamRemoteFor: aRepository origin url.
	upstream ifNil: [ ^ nil ].
	remote := self ensureRemote: upstream in: aRepository.
	^ [
		  aRepository fetchFrom: remote.
		  remote url ]
		  on: Error
		  do: [ :error |
			  self report: ('{1} could not be fetched: {2}' format: {
						   remote url.
						   error messageText }).
			  nil ]
]

{ #category : 'attaching' }
FRCloneAttacher >> attach: aClone to: aLoadedRepository [
	"Make aLoadedRepository, whose code is in the image, work on the clone of aClone, add the project it was forked from as upstream, then put the clone on the commit the image was loaded from. Committing goes to aClone's remote (a fork, for pull requests)."

	| upstream branch |
	aLoadedRepository location: aClone location.
	aClone free.
	upstream := self addUpstreamTo: aLoadedRepository.
	branch := self syncCloneWithImageOf: aLoadedRepository.
	Iceberg announcer announce: (IceRepositoryModified for: aLoadedRepository).
	self report: (self reportFor: aLoadedRepository branch: branch upstream: upstream).
	^ aLoadedRepository
]

{ #category : 'upstream' }
FRCloneAttacher >> ensureRemote: aRemote in: aRepository [
	"The remote of aRepository at the location of aRemote, whatever its name; aRemote is added when there is none."

	^ aRepository remotes detect: [ :each | each referencesSameRemoteLocationAs: aRemote ] ifNone: [
		  aRepository addRemote: aRemote.
		  aRepository remoteNamed: aRemote name ]
]

{ #category : 'attaching' }
FRCloneAttacher >> imageBranchNameFor: aCommit [
	"The branch created at the commit the image code comes from."

	^ 'image-' , aCommit shortId
]

{ #category : 'accessing' }
FRCloneAttacher >> informer: aBlock [
	"aBlock receives a text telling what happened when a clone was attached to the code of the image."

	informer := aBlock
]

{ #category : 'initialization' }
FRCloneAttacher >> initialize [

	super initialize.
	informer := [ :text |  ]
]

{ #category : 'reporting' }
FRCloneAttacher >> report: aString [
	"Tell the user what happened, through the informer."

	informer value: aString
]

{ #category : 'reporting' }
FRCloneAttacher >> reportFor: aRepository branch: aBranchNameOrNil upstream: anUpstreamUrlOrNil [
	"The text telling the user how the clone was attached to the code of the image."

	^ String streamContents: [ :stream |
			  stream nextPutAll:
				  ('The clone now holds {1}, the code loaded in the image; commits go to your repository (origin).' format:
					   { aRepository name }).
			  stream
				  cr;
				  cr.
			  aBranchNameOrNil
				  ifNil: [
						  stream nextPutAll:
							  'The commit the image was built from was not found: nothing was checked out. Fetch it in Iceberg (Repair repository), then create a branch at the image commit.' ]
				  ifNotNil: [
						  stream nextPutAll:
							  ('Branch {1} is checked out at the commit the image was built from: the image and the clone are in sync.' format:
								   { aBranchNameOrNil }) ].
			  stream
				  cr;
				  cr.
			  anUpstreamUrlOrNil
				  ifNil: [
				  stream nextPutAll: 'No upstream was fetched: the project it was forked from is unknown or could not be fetched.' ]
				  ifNotNil: [ stream nextPutAll: ('Upstream fetched: {1}' format: { anUpstreamUrlOrNil }) ] ]
]

{ #category : 'matching' }
FRCloneAttacher >> repositoriesWithoutClone [
	"The repositories Iceberg has registered without clone: the ones that came with the image, whose code is loaded."

	^ IceRepository registry select: [ :each | each isMissing ]
]

{ #category : 'matching' }
FRCloneAttacher >> repositoryLoadedFrom: anIceRepository [
	"The repository of the image without clone that anIceRepository is a clone of, or nil."

	^ (FRClone on: anIceRepository) imageRepositoryAmong: self repositoriesWithoutClone
]

{ #category : 'attaching' }
FRCloneAttacher >> syncCloneWithImageOf: aRepository [
	"Without loading anything, check out a branch at the commit the image code comes from, so that the image and the clone have no difference, and answer its name. When the clone does not know that commit, change nothing and answer nil: Iceberg asks to fetch it. Adopting the commit of the clone instead would turn all the commits in between into changes of the user."

	| commit branchName |
	commit := aRepository lookupCommit: aRepository workingCopy referenceCommit id.
	commit isUnknownCommit ifTrue: [ ^ nil ].
	branchName := self imageBranchNameFor: commit.
	(aRepository hasLocalBranchNamed: branchName)
		ifTrue: [ (aRepository branchNamed: branchName) switch ]
		ifFalse: [ aRepository createBranch: branchName inCommit: commit ].
	commit adopt.
	^ branchName
]

{ #category : 'accessing' }
FRCloneAttacher >> upstreamFinder [

	^ upstreamFinder ifNil: [ upstreamFinder := FRUpstreamFinder new ]
]

{ #category : 'accessing' }
FRCloneAttacher >> upstreamFinder: anUpstreamFinder [

	upstreamFinder := anUpstreamFinder
]
