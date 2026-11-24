"
I load a favorite into the image in one go: clone it, put it on its branch, load its baseline. I hold the steps and the dialogs; what a clone can do is in `FRClone`. Key messages are `clone:`, `load:` and `defineBottomBranchFor:`.

## Examples

```
FRFavoriteLoader instanceOnSmallImage
```

## Design Rationale

- A clone of code that came with the image is attached to that code by `FRCloneAttacher` instead of being registered apart.
- When the clone does not have the commit of the image code, I do not switch it: the commit adopted would be unrelated to the image.
- A missing branch never fails a load: I fall back on master, main or dev, and tell the user.

## Usage

1. `FRApplication>>newLoader` creates or configures me with a catalog, and with blocks that ask the user (`baselineChooser:`, `switchConfirmer:`) or tell them what I did (`informer:`).
2. `FRFavoritesPresenter` sends me `clone:`, `load:` or `defineBottomBranchFor:` for a row.
3. `FRCatalog` tells me whether the favorite is already cloned; I answer an `FRClone`.
"
Class {
	#name : 'FRFavoriteLoader',
	#superclass : 'Object',
	#instVars : [
		'catalog',
		'baselineChooser',
		'switchConfirmer',
		'clonesLocation',
		'informer',
		'attacher'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'instances' }
FRFavoriteLoader class >> instanceOnSmallImage [
	"A loader that sees the small example image; it loads nothing until sent #load:."

	<sampleInstance>
	^ self new
		  catalog: FRCatalog exampleSmallImage;
		  baselineChooser: [ :names | names first ];
		  yourself
]

{ #category : 'accessing' }
FRFavoriteLoader >> attacher [
	"What attaches a clone to the code of the image; it tells the user through my informer."

	^ attacher ifNil: [
		  attacher := FRCloneAttacher new
			              informer: [ :text | self report: text ];
			              yourself ]
]

{ #category : 'accessing' }
FRFavoriteLoader >> baselineChooser: aBlock [
	"aBlock receives the baseline names when a clone has several, and answers the one to load or nil to cancel."

	baselineChooser := aBlock
]

{ #category : 'baselines' }
FRFavoriteLoader >> baselineToLoadOf: aClone [
	"The single baseline of aClone, or the one picked by the baseline chooser when there are several."

	| names chosen |
	names := aClone baselineNames.
	names ifEmpty: [ FRError signal: ('No baseline in {1}' format: { aClone name }) ].
	names size = 1 ifTrue: [ ^ names first ].
	chosen := baselineChooser value: names.
	chosen ifNil: [ FRError signal: 'No baseline chosen' ].
	^ chosen
]

{ #category : 'accessing' }
FRFavoriteLoader >> catalog [

	^ catalog ifNil: [ catalog := FRCatalog current ]
]

{ #category : 'accessing' }
FRFavoriteLoader >> catalog: aCatalog [

	catalog := aCatalog
]

{ #category : 'steps' }
FRFavoriteLoader >> clone: aFavorite [
	"Register the clone left on disk if there is one, otherwise clone aFavorite and put it on its branch or tag. A clone of code the image already has (a fork of a project that came with the image) takes over that code instead of being registered apart.
	The clone is made on the remote's default branch and switched by #switch:to:, which keeps it there when the favorite's branch does not exist; Iceberg's own switch would fail and leave an unregistered clone on disk."

	| repository |
	(self existingCloneFor: aFavorite) ifNotNil: [ :directory | ^ self register: directory for: aFavorite ].
	repository := IceRepositoryCreator new
		              remote: (IceGitRemote url: aFavorite url);
		              location: (self cloneDirectoryFor: aFavorite);
		              createRepository.
	^ self registerOrAttach: repository for: aFavorite
]

{ #category : 'steps' }
FRFavoriteLoader >> cloneDirectoryFor: aFavorite [
	"Where Iceberg puts the clone of aFavorite: <clones location>/<owner>/<project>."

	^ aFavorite cloneDirectoryIn: self clonesLocation
]

{ #category : 'steps' }
FRFavoriteLoader >> cloneFor: aFavorite [
	"The clone of aFavorite on its branch: cloned when it is not in the image yet, registered when only its clone was left on disk."

	| info |
	info := self catalog infoFor: aFavorite.
	(info isNil or: [ info isCloned not ]) ifTrue: [ ^ self clone: aFavorite ].
	(info iceRepository isNotNil and: [ (IceRepository registry includes: info iceRepository) not ]) ifTrue: [
		^ self register: info iceRepository location for: aFavorite ].
	^ self switch: (FRClone on: info iceRepository) to: aFavorite
]

{ #category : 'accessing' }
FRFavoriteLoader >> clonesLocation [

	^ clonesLocation ifNil: [ IceLibgitRepository repositoriesLocation ]
]

{ #category : 'accessing' }
FRFavoriteLoader >> clonesLocation: aFileReference [

	clonesLocation := aFileReference
]

{ #category : 'baselines' }
FRFavoriteLoader >> commitishFor: aFavorite [
	"The branch or tag to check out, or nil for the remote's default branch."

	^ aFavorite isDefaultBranch
		  ifTrue: [ nil ]
		  ifFalse: [ aFavorite branch ]
]

{ #category : 'bottom branch' }
FRFavoriteLoader >> defineBottomBranchFor: aFavorite [
	"Create today's bottom branch in the clone of aFavorite and check it out. Answer the branch name."

	| info |
	info := self catalog infoFor: aFavorite.
	(info isNil or: [ info isCloned not ]) ifTrue: [ FRError signal: ('{1} has no clone: clone it first' format: { aFavorite name }) ].
	^ (FRClone on: info iceRepository) createBottomBranch
]

{ #category : 'steps' }
FRFavoriteLoader >> existingCloneFor: aFavorite [
	"The clone of aFavorite left on disk without being registered in Iceberg (for example after Forget), or nil."

	| directory |
	directory := self cloneDirectoryFor: aFavorite.
	(IceRepositoryCreator isGitRoot: directory) ifFalse: [ ^ nil ].
	^ directory
]

{ #category : 'accessing' }
FRFavoriteLoader >> informer: aBlock [
	"aBlock receives a text telling what happened when a clone was attached to the code of the image."

	informer := aBlock
]

{ #category : 'initialization' }
FRFavoriteLoader >> initialize [

	super initialize.
	baselineChooser := [ :names | nil ].
	switchConfirmer := [ :repository | false ].
	informer := [ :text |  ]
]

{ #category : 'loading' }
FRFavoriteLoader >> load: aFavorite [
	"Clone aFavorite (or reuse its clone on the right branch), then load its baseline. Answer the clone."

	| clone |
	clone := self cloneFor: aFavorite.
	clone loadBaselineFor: self.
	^ clone
]

{ #category : 'loading' }
FRFavoriteLoader >> missingBranchReportFor: aFavorite in: aClone [
	"The text telling the user that the branch of aFavorite does not exist, so its clone stays on its current branch."

	^ '{1} has no branch or tag {2}: the clone stays on {3}. Edit the favorite to choose another branch.' format: {
			  aFavorite name.
			  aFavorite branch.
			  aClone headName }
]

{ #category : 'loading' }
FRFavoriteLoader >> missingBranchReportFor: aFavorite in: aClone fallback: aCommitishOrNil [
	"The text telling the user that the branch of aFavorite does not exist, and which branch the clone is on instead."

	^ aCommitishOrNil ifNil: [ self missingBranchReportFor: aFavorite in: aClone ] ifNotNil: [
			  '{1} has no branch or tag {2}: the clone is on {3} instead. Edit the favorite to choose another branch.' format: {
					  aFavorite name.
					  aFavorite branch.
					  aCommitishOrNil } ]
]

{ #category : 'steps' }
FRFavoriteLoader >> register: aCloneDirectory for: aFavorite [
	"Add the clone in aCloneDirectory to Iceberg, then put it on the favorite's branch; when it holds code the image already has, attach it to that code instead."

	^ self
		  registerOrAttach: (IceRepositoryCreator new
				   location: aCloneDirectory;
				   createRepository)
		  for: aFavorite
]

{ #category : 'steps' }
FRFavoriteLoader >> registerOrAttach: anIceRepository for: aFavorite [
	"Register the clone of anIceRepository in Iceberg and put it on aFavorite's branch, unless it holds code that the image loaded from a repository without clone: that repository then takes the clone over."

	(self attacher repositoryLoadedFrom: anIceRepository) ifNotNil: [ :loaded |
		^ FRClone on: (self attacher attach: anIceRepository to: loaded) ].
	anIceRepository register.
	^ self switch: (FRClone on: anIceRepository) to: aFavorite
]

{ #category : 'accessing' }
FRFavoriteLoader >> report: aString [
	"Tell the user what happened, through the informer."

	informer value: aString
]

{ #category : 'loading' }
FRFavoriteLoader >> switch: aClone to: aFavorite [
	"Put aClone on the favorite's branch; ask before switching a clone with uncommitted changes and, when the user declines, keep the clone where it is and tell the user. A clone that does not have the commit of the image code stays where it is too. When the branch or tag does not exist, fall back on the first fallback branch that exists and tell the user; when none exists, keep the clone on its branch."

	| commitish |
	commitish := self commitishFor: aFavorite.
	commitish ifNil: [ ^ aClone ].
	aClone isImageCommitUnknown ifTrue: [
			self report: aClone unknownImageCommitReport.
			^ aClone ].
	(aClone hasCommitishNamed: commitish) ifFalse: [
			commitish := aClone fallbackCommitish.
			self report: (self missingBranchReportFor: aFavorite in: aClone fallback: commitish).
			commitish ifNil: [ ^ aClone ] ].
	aClone headName = commitish ifTrue: [ ^ aClone ].
	(aClone isModified and: [ (switchConfirmer value: aClone iceRepository) not ]) ifTrue: [
			self report: ('{1} has uncommitted changes: the clone stays on {2} instead of switching to {3}.' format: {
						 aClone name.
						 aClone headName.
						 commitish }).
			^ aClone ].
	aClone switchTo: commitish.
	^ aClone
]

{ #category : 'accessing' }
FRFavoriteLoader >> switchConfirmer: aBlock [
	"aBlock receives a clone with uncommitted changes and answers whether to switch its branch anyway."

	switchConfirmer := aBlock
]
