"
I load a favorite into the image in one go: clone it, find its baseline, load it with `Metacello`. I also put its clone in order: switch it to the branch of the favorite, attach it to code that came with the image, or define its bottom branch. Key messages are `clone:`, `load:` and `defineBottomBranchFor:`.

## Examples

```
FRFavoriteLoader exampleOnSmallImage
```

## Design Rationale

- When a clone holds code that the image has from a repository without clone (one that came with the image, such as Spec2 for a fork of Spec, or Pharo itself), I attach the clone to that repository instead of registering it apart: two repositories for the same code confuse Iceberg and the user.
- A clone of Pharo is recognized by its content (`BaselineOfPharo`), never by its commits: forks lag behind the image.
- Once attached, I add the parent of the fork as a remote and fetch it, as Iceberg does when it clones a fork, then check out a branch `image-<commit>` at the commit the image was built from. Nothing is loaded: the image and the clone are in sync, and commits go to the fork (origin).
- When that commit is still unknown I adopt no other one: it would turn all the commits in between into changes of the user. The repository stays in the Fetch required state of Iceberg, and I refuse to switch it or define a bottom branch.
- A missing branch never fails a load: I fall back on master, main or dev, and tell the user.

## Usage

1. `FRApplication>>newLoader` creates or configures me with a catalog, and with blocks that ask the user (`baselineChooser:`, `switchConfirmer:`) or tell them what I did (`informer:`).
2. `FRFavoritesPresenter` sends me `clone:`, `load:` or `defineBottomBranchFor:` for a row.
3. `FRCatalog` tells me whether the favorite is already cloned; `FRUpstreamFinder` finds the parent of a fork.

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

{ #category : 'attaching' }
FRFavoriteLoader >> ensureRemote: aRemote in: aRepository [
	"The remote of aRepository at the location of aRemote, whatever its name; aRemote is added when there is none."

	^ aRepository remotes detect: [ :each | each referencesSameRemoteLocationAs: aRemote ] ifNone: [
		  aRepository addRemote: aRemote.
		  aRepository remoteNamed: aRemote name ]
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

{ #category : 'attaching' }
FRFavoriteLoader >> repositoryBestHeldBy: aClone among: someRepositories [
	"The repository among someRepositories whose loaded packages aClone holds best (the most covered, then the most packages), or nil when aClone holds none of their loaded packages."

	| cloneNames best bestScore |
	cloneNames := aClone workingCopy packageNames asSet.
	best := nil.
	bestScore := { 0. 0 }.
	someRepositories do: [ :each |
		| score |
		score := self scoreOf: each heldBy: cloneNames.
		(score second > 0 and: [ self score: score isBetterThan: bestScore ]) ifTrue: [
			best := each.
			bestScore := score ] ].
	^ best
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
	"The repository among someRepositories that aClone is a clone of: the one of the image itself for a clone of Pharo; otherwise the one whose loaded packages aClone holds best; failing that, one that lists no package whose code comes from a commit aClone has; nil otherwise."

	^ (self repositoryOfTheImageAmong: someRepositories for: aClone) ifNil: [
		  (self repositoryBestHeldBy: aClone among: someRepositories) ifNil: [
			  someRepositories detect: [ :each | self clone: aClone hasTheCommitOfPackagelessRepository: each ] ifNone: [ nil ] ] ]
]

{ #category : 'attaching' }
FRFavoriteLoader >> repositoryOfTheImageAmong: someRepositories for: aClone [
	"The repository of the Pharo image itself (its code comes from the commit the image was built from) when aClone is a clone of Pharo, nil otherwise. The fork may be behind: whether aClone has that commit does not matter."

	(aClone workingCopy packageNames includes: 'BaselineOfPharo') ifFalse: [ ^ nil ].
	^ someRepositories
		  detect: [ :each | each workingCopy referenceCommit id = SystemVersion current commitHash ]
		  ifNone: [ nil ]
]

{ #category : 'attaching' }
FRFavoriteLoader >> score: aScore isBetterThan: anotherScore [
	"Scores are {coverage. count}; compare the coverage first, then the count."

	aScore first = anotherScore first ifFalse: [ ^ aScore first > anotherScore first ].
	^ aScore second > anotherScore second
]

{ #category : 'attaching' }
FRFavoriteLoader >> scoreOf: aRepository heldBy: someNames [
	"How well someNames cover the loaded packages of aRepository: {coverage. count}."

	| loadedNames held |
	loadedNames := aRepository workingCopy packages select: [ :package | package isLoaded ] thenCollect: [ :package | package name ].
	held := loadedNames count: [ :name | someNames includes: name ].
	^ {
		  (held / (loadedNames size max: 1)).
		  held }
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
FRFavoriteLoader >> syncCloneWithImageOf: aRepository [
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

{ #category : 'attaching' }
FRFavoriteLoader >> unknownImageCommitReportFor: aRepository [

	^ 'The clone of {1} does not have the commit the image was built from ({2}): Fetch it in Iceberg first (Repair repository).' format: {
		  aRepository name.
		  aRepository workingCopy referenceCommit shortId }
]

{ #category : 'accessing' }
FRFavoriteLoader >> upstreamFinder [

	^ upstreamFinder ifNil: [ upstreamFinder := FRUpstreamFinder new ]
]

{ #category : 'accessing' }
FRFavoriteLoader >> upstreamFinder: anUpstreamFinder [

	upstreamFinder := anUpstreamFinder
]
