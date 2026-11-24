"
I load a favorite into the image in one go: clone it, find its baseline, load it with `Metacello`. I also put its clone in order: switch it to the branch of the favorite, or define its bottom branch. Key messages are `clone:`, `load:` and `defineBottomBranchFor:`.

## Examples

```
FRFavoriteLoader instanceOnSmallImage
```

## Design Rationale

- A clone of code that came with the image is attached to that code by `FRCloneAttacher` instead of being registered apart.
- When the clone does not have the commit of the image code, I refuse to switch it or to define a bottom branch: the commit adopted would be unrelated to the image.
- A missing branch never fails a load: I fall back on master, main or dev, and tell the user.

## Usage

1. `FRApplication>>newLoader` creates or configures me with a catalog, and with blocks that ask the user (`baselineChooser:`, `switchConfirmer:`) or tell them what I did (`informer:`).
2. `FRFavoritesPresenter` sends me `clone:`, `load:` or `defineBottomBranchFor:` for a row.
3. `FRCatalog` tells me whether the favorite is already cloned.

## Implementation Notes

- I switch branches with Iceberg without loading code. `load:` then loads the default group of the baseline from the clone, keeping the projects already loaded (`onConflictUseLoaded`). The baseline of Pharo is never loaded: Pharo is the running system and its baseline does not load like the others.
- `isImageCommitUnknownIn:` must be checked before anything that adopts a commit: a switch or a checkout does.
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
FRFavoriteLoader >> baselineNamesIn: aCloneDirectory [
	"The names of the BaselineOf packages of the clone, without the BaselineOf prefix, sorted."

	| prefix |
	prefix := 'BaselineOf'.
	^ ((self sourceDirectoryOf: aCloneDirectory) directories
		   select: [ :each | each basename beginsWith: prefix ]
		   thenCollect: [ :each | (each basename withoutSuffix: '.package') allButFirst: prefix size ]) asArray sort
]

{ #category : 'baselines' }
FRFavoriteLoader >> baselineToLoadIn: aCloneDirectory [
	"The single baseline of the clone, or the one picked by the baseline chooser when there are several."

	| names chosen |
	names := self baselineNamesIn: aCloneDirectory.
	names ifEmpty: [ FRError signal: ('No baseline in {1}' format: { (self sourceDirectoryOf: aCloneDirectory) fullName }) ].
	names size = 1 ifTrue: [ ^ names first ].
	chosen := baselineChooser value: names.
	chosen ifNil: [ FRError signal: 'No baseline chosen' ].
	^ chosen
]

{ #category : 'bottom branch' }
FRFavoriteLoader >> bottomBranchNameOn: aDate [
	"The bottom branch of aDate: its ISO date followed by -Bottom."

	^ aDate yyyymmdd , '-Bottom'
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
	"Create today's bottom branch at the current commit of aFavorite's clone and check it out; nothing is loaded, the image code stays. Answer the branch name."

	| info repository name |
	info := self catalog infoFor: aFavorite.
	(info isNil or: [ info isCloned not ]) ifTrue: [ FRError signal: ('{1} has no clone: clone it first' format: { aFavorite name }) ].
	repository := info iceRepository.
	(self isImageCommitUnknownIn: repository) ifTrue: [ FRError signal: (self unknownImageCommitReportFor: repository) ].
	name := self bottomBranchNameOn: Date today.
	(repository hasLocalBranchNamed: name) ifTrue: [
			FRError signal: ('{1} already has a branch {2}' format: {
						 aFavorite name.
						 name }) ].
	repository createBranch: name.
	Iceberg announcer announce: (IceRepositoryModified for: repository).
	^ name
]

{ #category : 'steps' }
FRFavoriteLoader >> existingCloneFor: aFavorite [
	"The clone of aFavorite left on disk without being registered in Iceberg (for example after Forget), or nil."

	| directory |
	directory := self cloneDirectoryFor: aFavorite.
	(IceRepositoryCreator isGitRoot: directory) ifFalse: [ ^ nil ].
	^ directory
]

{ #category : 'loading' }
FRFavoriteLoader >> fallbackCommitishIn: anIceRepository [
	"The first of the fallback branches that anIceRepository knows, or nil."

	^ self fallbackCommitishes detect: [ :each | self hasCommitishNamed: each in: anIceRepository ] ifNone: [ nil ]
]

{ #category : 'loading' }
FRFavoriteLoader >> fallbackCommitishes [
	"The branches tried, in order, when the branch of a favorite does not exist."

	^ #( 'master' 'main' 'dev' )
]

{ #category : 'loading' }
FRFavoriteLoader >> hasCommitishNamed: aString in: anIceRepository [
	"Whether aString names a branch, a remote branch, a tag or a commit that anIceRepository knows."

	^ [
		  anIceRepository commitishNamed: aString.
		  true ]
		  on: NotFound
		  do: [ false ]
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

{ #category : 'attaching' }
FRFavoriteLoader >> isImageCommitUnknownIn: aRepository [
	"Whether the clone of aRepository does not have the commit the image code comes from (Iceberg's Fetch required)."

	^ aRepository workingCopy workingCopyState isUnknownCommitState
]

{ #category : 'baselines' }
FRFavoriteLoader >> isPharoClone: aCloneDirectory [
	"Whether aCloneDirectory is a clone of Pharo. It is read on disk: a repository whose image commit is unknown lists no package."

	^ (self baselineNamesIn: aCloneDirectory) includes: 'Pharo'
]

{ #category : 'loading' }
FRFavoriteLoader >> load: aFavorite [
	"Clone aFavorite (or reuse its clone on the right branch), then load its baseline with Metacello."

	| repository |
	repository := self repositoryFor: aFavorite.
	self loadBaselineOf: repository.
	^ repository
]

{ #category : 'loading' }
FRFavoriteLoader >> loadBaselineOf: aRepository [
	"Load the baseline of the clone of aRepository with Metacello, except the one of Pharo: it is the running system and its baseline does not load like the others."

	| clone baseline |
	clone := aRepository location.
	(self isPharoClone: clone) ifTrue: [
		^ self report: ('The baseline of {1} was not loaded: Pharo is the running system.' format: { aRepository name }) ].
	baseline := self baselineToLoadIn: clone.
	Metacello new
		baseline: baseline;
		repository: (self metacelloRepositoryFor: clone);
		onConflictUseLoaded;
		onWarningLog;
		load
]

{ #category : 'baselines' }
FRFavoriteLoader >> metacelloRepositoryFor: aCloneDirectory [

	^ 'gitlocal://' , (self sourceDirectoryOf: aCloneDirectory) fullName
]

{ #category : 'loading' }
FRFavoriteLoader >> missingBranchReportFor: aFavorite in: anIceRepository [
	"The text telling the user that the branch of aFavorite does not exist, so its clone stays on its current branch."

	^ '{1} has no branch or tag {2}: the clone stays on {3}. Edit the favorite to choose another branch.' format: {
			  aFavorite name.
			  aFavorite branch.
			  anIceRepository head name }
]

{ #category : 'loading' }
FRFavoriteLoader >> missingBranchReportFor: aFavorite in: anIceRepository fallback: aCommitishOrNil [
	"The text telling the user that the branch of aFavorite does not exist, and which branch the clone is on instead."

	^ aCommitishOrNil ifNil: [ self missingBranchReportFor: aFavorite in: anIceRepository ] ifNotNil: [
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
FRFavoriteLoader >> registerOrAttach: aClone for: aFavorite [
	"Register aClone in Iceberg and put it on aFavorite's branch, unless it holds code that the image loaded from a repository without clone: that repository then takes aClone over."

	(self attacher repositoryLoadedFrom: aClone) ifNotNil: [ :loaded | ^ self attacher attach: aClone to: loaded ].
	aClone register.
	^ self switch: aClone to: aFavorite
]

{ #category : 'accessing' }
FRFavoriteLoader >> report: aString [
	"Tell the user what happened, through the informer."

	informer value: aString
]

{ #category : 'steps' }
FRFavoriteLoader >> repositoryFor: aFavorite [
	"The Iceberg repository of aFavorite: cloned when it is not in the image yet, registered when only its clone was left on disk."

	| info |
	info := self catalog infoFor: aFavorite.
	(info isNil or: [ info isCloned not ]) ifTrue: [ ^ self clone: aFavorite ].
	(info iceRepository isNotNil and: [ (IceRepository registry includes: info iceRepository) not ]) ifTrue: [
		^ self register: info iceRepository location for: aFavorite ].
	^ self switch: info iceRepository to: aFavorite
]

{ #category : 'baselines' }
FRFavoriteLoader >> sourceDirectoryOf: aCloneDirectory [
	"The source folder named by the clone's .project file, or the clone itself."

	| projectFile source |
	projectFile := aCloneDirectory / '.project'.
	projectFile exists ifFalse: [ ^ aCloneDirectory ].
	source := (STON fromString: projectFile contents) at: 'srcDirectory' ifAbsent: [ '' ].
	^ source isEmptyOrNil
		  ifTrue: [ aCloneDirectory ]
		  ifFalse: [ aCloneDirectory resolve: source ]
]

{ #category : 'loading' }
FRFavoriteLoader >> switch: anIceRepository to: aFavorite [
	"Put an existing clone on the favorite's branch; ask before switching a clone with uncommitted changes and, when the user declines, keep the clone where it is and tell the user. A clone that does not have the commit of the image code stays where it is too. When the branch or tag does not exist, fall back on the first of #fallbackCommitishes that exists and tell the user; when none exists, keep the clone on its branch."

	| commitish |
	commitish := self commitishFor: aFavorite.
	commitish ifNil: [ ^ anIceRepository ].
	(self isImageCommitUnknownIn: anIceRepository) ifTrue: [
			self report: (self unknownImageCommitReportFor: anIceRepository).
			^ anIceRepository ].
	(self hasCommitishNamed: commitish in: anIceRepository) ifFalse: [
			commitish := self fallbackCommitishIn: anIceRepository.
			self report: (self missingBranchReportFor: aFavorite in: anIceRepository fallback: commitish).
			commitish ifNil: [ ^ anIceRepository ] ].
	anIceRepository head name = commitish ifTrue: [ ^ anIceRepository ].
	(anIceRepository isModified and: [ (switchConfirmer value: anIceRepository) not ]) ifTrue: [
			self report: ('{1} has uncommitted changes: the clone stays on {2} instead of switching to {3}.' format: {
						 anIceRepository name.
						 anIceRepository head name.
						 commitish }).
			^ anIceRepository ].
	anIceRepository switchToCommitishNamed: commitish.
	^ anIceRepository
]

{ #category : 'accessing' }
FRFavoriteLoader >> switchConfirmer: aBlock [
	"aBlock receives a clone with uncommitted changes and answers whether to switch its branch anyway."

	switchConfirmer := aBlock
]

{ #category : 'attaching' }
FRFavoriteLoader >> unknownImageCommitReportFor: aRepository [

	^ 'The clone of {1} does not have the commit the image was built from ({2}): Fetch it in Iceberg first (Repair repository).' format: {
		  aRepository name.
		  aRepository workingCopy referenceCommit shortId }
]
