"
I load a favorite into the image in one go: clone, find the baseline, load it with Metacello.

## Responsibility:

- I clone the favorite with Iceberg at its branch or tag, register a clone left on disk (after Iceberg's Forget), or reuse its registered clone and switch it to that branch (asking first when the clone has uncommitted changes).
- I find the source folder from the `.project` file and the `BaselineOf` packages in it; I ask which one to load when there are several.
- I load the `default` group with `Metacello`, keeping the projects already loaded (`onConflictUseLoaded`).

## Collaborators:

- `FRCatalog` tells me whether the favorite is already cloned.
- `IceRepositoryCreator` clones; `IceRepository` switches branches.
- `Metacello` loads the baseline from the clone through a `gitlocal://` repository.
- The baseline chooser and switch confirmer blocks, set by `FRApplication`, ask the user.

## Public API and Key Messages

- `clone: aFavorite` only clones (or registers a clone left on disk) and answers the Iceberg repository.
- `load: aFavorite` answers the Iceberg repository; raises `FRError` when there is no baseline or the user cancels.
- `catalog:`, `baselineChooser:`, `switchConfirmer:`, `clonesLocation:` (Iceberg's clone folder by default) configure me.
- `baselineNamesIn:`, `sourceDirectoryOf:`, `metacelloRepositoryFor:`, `commitishFor:`, `cloneDirectoryFor:`, `existingCloneFor:` are the steps, testable without network.

```
FRFavoriteLoader new load: (FRFavorite url: 'git@github.com:noha/mustache.git')
```

See `FRFavoriteLoader class >> #exampleOnSmallImage`.
"
Class {
	#name : 'FRFavoriteLoader',
	#superclass : 'Object',
	#instVars : [
		'catalog',
		'baselineChooser',
		'switchConfirmer',
		'clonesLocation'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'examples' }
FRFavoriteLoader class >> exampleOnSmallImage [
	"A loader that sees the small example image; it loads nothing until sent #load:."

	<sampleInstance>
	^ self new
		  catalog: FRCatalog exampleSmallImage;
		  baselineChooser: [ :names | names first ];
		  yourself
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
	"Register the clone left on disk if there is one, otherwise clone aFavorite at its branch or tag."

	| creator repository |
	(self existingCloneFor: aFavorite) ifNotNil: [ :directory |
		^ self register: directory for: aFavorite ].
	creator := IceRepositoryCreator new
		           remote: (IceGitRemote url: aFavorite url);
		           location: (self cloneDirectoryFor: aFavorite);
		           yourself.
	(self commitishFor: aFavorite) ifNotNil: [ :commitish | creator commitishName: commitish ].
	repository := creator createRepository.
	repository register.
	^ repository
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

{ #category : 'steps' }
FRFavoriteLoader >> existingCloneFor: aFavorite [
	"The clone of aFavorite left on disk without being registered in Iceberg (for example after Forget), or nil."

	| directory |
	directory := self cloneDirectoryFor: aFavorite.
	(IceRepositoryCreator isGitRoot: directory) ifFalse: [ ^ nil ].
	^ directory
]

{ #category : 'initialization' }
FRFavoriteLoader >> initialize [

	super initialize.
	baselineChooser := [ :names | nil ].
	switchConfirmer := [ :repository | false ]
]

{ #category : 'loading' }
FRFavoriteLoader >> load: aFavorite [
	"Clone aFavorite (or reuse its clone on the right branch), then load its baseline with Metacello."

	| repository clone baseline |
	repository := self repositoryFor: aFavorite.
	clone := repository location.
	baseline := self baselineToLoadIn: clone.
	Metacello new
		baseline: baseline;
		repository: (self metacelloRepositoryFor: clone);
		onConflictUseLoaded;
		onWarningLog;
		load.
	^ repository
]

{ #category : 'baselines' }
FRFavoriteLoader >> metacelloRepositoryFor: aCloneDirectory [

	^ 'gitlocal://' , (self sourceDirectoryOf: aCloneDirectory) fullName
]

{ #category : 'steps' }
FRFavoriteLoader >> register: aCloneDirectory for: aFavorite [
	"Add the clone in aCloneDirectory to Iceberg, then put it on the favorite's branch."

	| repository |
	repository := IceRepositoryCreator new
		              location: aCloneDirectory;
		              createRepository.
	repository register.
	^ self switch: repository to: aFavorite
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
	"Put an existing clone on the favorite's branch; ask before switching a clone with uncommitted changes."

	| commitish |
	commitish := self commitishFor: aFavorite.
	(commitish isNil or: [ anIceRepository head name = commitish ]) ifTrue: [ ^ anIceRepository ].
	(anIceRepository isModified and: [ (switchConfirmer value: anIceRepository) not ]) ifTrue: [
			FRError signal: ('{1} has uncommitted changes; it was not switched to {2}' format: {
						 anIceRepository name.
						 commitish }) ].
	anIceRepository switchToCommitishNamed: commitish.
	^ anIceRepository
]

{ #category : 'accessing' }
FRFavoriteLoader >> switchConfirmer: aBlock [
	"aBlock receives a clone with uncommitted changes and answers whether to switch its branch anyway."

	switchConfirmer := aBlock
]
