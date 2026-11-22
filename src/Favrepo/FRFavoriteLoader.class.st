"
I load a favorite into the image in one go: clone, find the baseline, load it with Metacello.

## Responsibility:

- I clone the favorite with Iceberg and switch it to its branch or tag (keeping it on its branch, and telling the user, when that branch or tag does not exist), register a clone left on disk (after Iceberg's Forget), or reuse its registered clone and switch it to that branch (asking first when the clone has uncommitted changes).
- When the clone holds code the image already has from a repository without clone (one that came with the image, such as Spec2 for a fork of Spec), I attach the clone to that repository instead of registering it apart, and check out a branch `image-<commit>` at the commit the image was loaded from, without loading anything: the image and the clone are in sync, and commits go to the clone's remote (your fork). I add the project it was forked from as the `upstream` remote (found by `FRUpstreamFinder`) and fetch it first, so the image commit is found even when the fork is behind, then tell the user what I did through the informer block.
- I find the source folder from the `.project` file and the `BaselineOf` packages in it; I ask which one to load when there are several.
- I load the `default` group with `Metacello`, keeping the projects already loaded (`onConflictUseLoaded`).

## Collaborators:

- `FRCatalog` tells me whether the favorite is already cloned.
- `IceRepositoryCreator` clones; `IceRepository` switches branches.
- `Metacello` loads the baseline from the clone through a `gitlocal://` repository.
- The baseline chooser and switch confirmer blocks, set by `FRApplication`, ask the user.

## Public API and Key Messages

- `clone: aFavorite` only clones (or registers a clone left on disk) and answers the Iceberg repository.
- `repositoryLoadedFrom: aClone among: someRepositories` answers the repository whose loaded packages the clone holds best; `attach:to:` and `syncCloneWithImageOf:` do the attaching.
- `defineBottomBranchFor: aFavorite` creates and checks out today's bottom branch (`2026-11-15-Bottom`) at the current commit of the clone, without loading; `bottomBranchNameOn: aDate` names it.
- `load: aFavorite` answers the Iceberg repository; raises `FRError` when there is no baseline or the user cancels.
- `catalog:`, `baselineChooser:`, `switchConfirmer:`, `informer:` (what `report:` tells: a clone attached to the image code, a missing branch), `upstreamFinder:`, `clonesLocation:` (Iceberg's clone folder by default) configure me.
- `baselineNamesIn:`, `sourceDirectoryOf:`, `metacelloRepositoryFor:`, `commitishFor:`, `cloneDirectoryFor:`, `existingCloneFor:`, `hasCommitishNamed:in:` are the steps, testable without network.

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
		'clonesLocation',
		'upstreamFinder',
		'informer'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'examples' }
FRFavoriteLoader class >> exampleOnSmallImage [
	"A loader that sees the small example image; it loads nothing until sent #load:."

	^ self new
		  catalog: FRCatalog exampleSmallImage;
		  baselineChooser: [ :names | names first ];
		  yourself
]

{ #category : 'attaching' }
FRFavoriteLoader >> addUpstreamTo: aRepository [
	"Add the project aRepository was forked from as its upstream remote and fetch it, so that the commit of the image is found even when the fork is behind. Answer the upstream URL, or nil when there is none or it cannot be fetched."

	| url remote |
	url := self upstreamFinder upstreamUrlFor: aRepository origin url.
	url ifNil: [ ^ nil ].
	remote := aRepository remoteNamed: 'upstream' ifAbsent: [
			          aRepository addRemote: (IceGitRemote name: 'upstream' url: url).
			          aRepository remoteNamed: 'upstream' ].
	^ [
		  aRepository fetchFrom: remote.
		  remote url ]
		  on: Error
		  do: [ nil ]
]

{ #category : 'attaching' }
FRFavoriteLoader >> attach: aClone to: aLoadedRepository [
	"Make aLoadedRepository, whose code is in the image, work on the clone of aClone, add the project it was forked from as upstream, then put the clone on the commit the image was loaded from. Committing goes to aClone's remote (a fork, for pull requests)."

	| upstream branch |
	aLoadedRepository location: aClone location.
	aClone free.
	upstream := self addUpstreamTo: aLoadedRepository.
	branch := self syncCloneWithImageOf: aLoadedRepository.
	Iceberg announcer announce: (IceRepositoryModified for: aLoadedRepository).
	self report: (self attachReportFor: aLoadedRepository branch: branch upstream: upstream).
	^ aLoadedRepository
]

{ #category : 'attaching' }
FRFavoriteLoader >> attachReportFor: aRepository branch: aBranchNameOrNil upstream: anUpstreamUrlOrNil [
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
							  'The commit the image was built from was not found: the clone stays on its branch and the differences with the image show as changes in Iceberg.' ]
				  ifNotNil: [
						  stream nextPutAll:
							  ('Branch {1} is checked out at the commit the image was built from: the image and the clone are in sync.' format:
								   { aBranchNameOrNil }) ].
			  stream
				  cr;
				  cr.
			  anUpstreamUrlOrNil
				  ifNil: [
				  stream nextPutAll: 'No upstream remote was added: the project it was forked from is unknown or could not be fetched.' ]
				  ifNotNil: [ stream nextPutAll: ('Remote upstream: {1}' format: { anUpstreamUrlOrNil }) ] ]
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

{ #category : 'attaching' }
FRFavoriteLoader >> clone: aClone hasTheCommitOfPackagelessRepository: aRepository [
	"Whether aRepository lists no package and its code comes from a commit that aClone has."

	| id |
	aRepository workingCopy packages ifNotEmpty: [ ^ false ].
	id := aRepository workingCopy referenceCommit id.
	id ifNil: [ ^ false ].
	^ [ (aClone lookupCommit: id) isUnknownCommit not ]
		  on: Error
		  do: [ false ]
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

{ #category : 'attaching' }
FRFavoriteLoader >> imageBranchNameFor: aCommit [
	"The branch created at the commit the image code comes from."

	^ 'image-' , aCommit shortId
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

{ #category : 'attaching' }
FRFavoriteLoader >> registerOrAttach: aClone for: aFavorite [
	"Register aClone in Iceberg and put it on aFavorite's branch, unless it holds code that the image loaded from a repository without clone: that repository then takes aClone over."

	(self repositoryLoadedFrom: aClone among: self repositoriesToAttach) ifNotNil: [ :loaded | ^ self attach: aClone to: loaded ].
	aClone register.
	^ self switch: aClone to: aFavorite
]

{ #category : 'accessing' }
FRFavoriteLoader >> report: aString [
	"Tell the user what happened, through the informer."

	informer value: aString
]

{ #category : 'attaching' }
FRFavoriteLoader >> repositoriesToAttach [
	"The repositories Iceberg has registered without clone: the ones that came with the image, whose code is loaded."

	^ IceRepository registry select: [ :each | each isMissing ]
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

{ #category : 'attaching' }
FRFavoriteLoader >> repositoryLoadedFrom: aClone among: someRepositories [
	"The repository among someRepositories whose loaded packages aClone holds best (the most covered, then the most packages); failing that, one that lists no package (like the image's pharo repository) whose code comes from a commit aClone has; nil otherwise."

	| cloneNames best bestScore |
	cloneNames := aClone workingCopy packageNames asSet.
	best := nil.
	bestScore := { 0. 0 }.
	someRepositories do: [ :each |
		| loadedNames held score |
		loadedNames := each workingCopy packages select: [ :package | package isLoaded ] thenCollect: [ :package | package name ].
		held := loadedNames count: [ :name | cloneNames includes: name ].
		score := {
			         (held / (loadedNames size max: 1)).
			         held }.
		(held > 0 and: [ self score: score isBetterThan: bestScore ]) ifTrue: [
			best := each.
			bestScore := score ] ].
	^ best ifNil: [
		  someRepositories detect: [ :each | self clone: aClone hasTheCommitOfPackagelessRepository: each ] ifNone: [ nil ] ]
]

{ #category : 'attaching' }
FRFavoriteLoader >> score: aScore isBetterThan: anotherScore [
	"Scores are {coverage. count}; compare the coverage first, then the count."

	aScore first = anotherScore first ifFalse: [ ^ aScore first > anotherScore first ].
	^ aScore second > anotherScore second
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
	"Put an existing clone on the favorite's branch; ask before switching a clone with uncommitted changes and, when the user declines, keep the clone where it is and tell the user. When the branch or tag does not exist, fall back on the first of #fallbackCommitishes that exists and tell the user; when none exists, keep the clone on its branch."

	| commitish |
	commitish := self commitishFor: aFavorite.
	commitish ifNil: [ ^ anIceRepository ].
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
FRFavoriteLoader >> syncCloneWithImageOf: aRepository [
	"Without loading anything, check out a branch at the commit the image code comes from, so that the image and the clone have no difference, and answer its name. When the clone does not know that commit, keep its branch and answer nil: the image differences show as changes."

	| commit branchName |
	commit := aRepository lookupCommit: aRepository workingCopy referenceCommit id.
	commit isUnknownCommit ifTrue: [
			aRepository branch switch.
			^ nil ].
	branchName := self imageBranchNameFor: commit.
	(aRepository hasLocalBranchNamed: branchName)
		ifTrue: [ (aRepository branchNamed: branchName) switch ]
		ifFalse: [ aRepository createBranch: branchName inCommit: commit ].
	commit adopt.
	^ branchName
]

{ #category : 'accessing' }
FRFavoriteLoader >> upstreamFinder [

	^ upstreamFinder ifNil: [ upstreamFinder := FRUpstreamFinder new ]
]

{ #category : 'accessing' }
FRFavoriteLoader >> upstreamFinder: anUpstreamFinder [

	upstreamFinder := anUpstreamFinder
]
