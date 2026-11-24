"
I test the network-free steps of FRFavoriteLoader on fake clones in a memory file system.
"
Class {
	#name : 'FRFavoriteLoaderTest',
	#superclass : 'TestCase',
	#instVars : [
		'fileSystem',
		'gitRepository',
		'upstreamRepository'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRFavoriteLoaderTest >> cloneWithSource: aSourceFolder baselines: someNames [
	"A fake clone in memory: a .project file naming aSourceFolder, and one Tonel package folder per name."

	| clone source |
	clone := fileSystem root / 'clone'.
	clone ensureCreateDirectory.
	clone / '.project' writeStreamDo: [ :stream |
		stream nextPutAll: (STON toString: (Dictionary with: 'srcDirectory' -> aSourceFolder)) ].
	source := aSourceFolder isEmpty
		          ifTrue: [ clone ]
		          ifFalse: [ clone / aSourceFolder ].
	someNames do: [ :each | (source / each) ensureCreateDirectory ].
	(source / 'MyProject-Core') ensureCreateDirectory.
	^ clone
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> clonesLoader [

	^ self loader
		  clonesLocation: fileSystem root / 'iceberg';
		  yourself
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> forkRepository [
	"A git repository whose origin is a GitHub fork (never contacted)."

	^ (self gitRepositoryWithBranch: 'dev')
		  addRemote: (IceGitRemote name: 'origin' url: 'git@github.com:Ducasse/Pharo.git');
		  yourself
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> gitRepositoryWithBranch: aBranchName [
	"A git repository on disk, not registered in Iceberg, with one commit on master and a branch aBranchName at that commit; it is checked out on master and deleted by tearDown."

	gitRepository := IceRepositoryCreator new
		                 location: (FileLocator temp / ('favrepo-test-' , UUID new asString36)) asFileReference;
		                 subdirectory: 'src';
		                 createNewRepositoryNamed: 'FRFixture'.
	gitRepository commitWithMessage: 'Initial commit'.
	gitRepository createBranch: aBranchName.
	gitRepository switchToCommitishNamed: 'master'.
	^ gitRepository
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> loader [

	^ FRFavoriteLoader new
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> loaderWithParentAt: aUrl [
	"A loader that GitHub (not asked) tells that the fork comes from aUrl, owned by pharo-project."

	^ self loader
		  upstreamFinder: (FRUpstreamFinder gitHubRepositories: [ :owner :project |
				   Dictionary new
					   at: 'fork' put: true;
					   at: 'parent' put: (Dictionary new
							    at: 'owner' put: (Dictionary with: 'login' -> 'pharo-project');
							    at: 'ssh_url' put: aUrl;
							    at: 'clone_url' put: aUrl;
							    yourself);
					   yourself ]);
		  yourself
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> loaderWithParentAtUpstream [

	^ self loaderWithParentAt: self upstreamRepository location fullName
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> mustache [

	^ FRFavorite url: 'git@github.com:noha/mustache.git' name: 'Mustache' branch: 'v1.3'
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> newGitRepositoryNamed: aName [
	"A git repository on disk, not registered in Iceberg, with one commit of its own on master."

	| repository |
	repository := IceRepositoryCreator new
		              location: (FileLocator temp / ('favrepo-test-' , UUID new asString36)) asFileReference;
		              subdirectory: 'src';
		              createNewRepositoryNamed: aName.
	repository commitWithMessage: 'Initial commit of ' , aName.
	^ repository
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> repositoryNamed: aName atCommit: anId [
	"An Iceberg repository missing on disk and not registered, listing no package and whose code comes from the commit anId, like the image's pharo repository."

	| repository |
	repository := IceLibgitRepository new
		              name: aName;
		              yourself.
	repository workingCopy referenceCommit: ((IceUnknownCommit inRepository: repository)
		 id: anId;
		 yourself).
	^ repository
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> repositoryNamed: aName packages: someNames [
	"An Iceberg repository missing on disk and not registered, holding packages named someNames (loaded when the image has them)."

	| repository |
	repository := IceLibgitRepository new
		              name: aName;
		              yourself.
	someNames do: [ :each | repository workingCopy addPackage: (IcePackage named: each repository: repository) ].
	^ repository
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> repositoryOnDiskAtUnknownCommit: anId [
	"A repository on the clone of gitRepository, on master, whose image code comes from anId, a commit the clone does not have: what attaching a fork that is behind gives."

	| clone |
	clone := self gitRepositoryWithBranch: 'dev'.
	^ (self repositoryNamed: 'pharo' atCommit: anId)
		  location: clone location;
		  yourself
]

{ #category : 'running' }
FRFavoriteLoaderTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory
]

{ #category : 'running' }
FRFavoriteLoaderTest >> tearDown [

	{
		gitRepository.
		upstreamRepository } do: [ :each |
		each ifNotNil: [
				| location |
				location := each location.
				each free.
				location ensureDeleteAll ] ].
	super tearDown
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testAttachFetchesTheImageCommitFromTheParentOfTheFork [
	"The fork is behind: the commit of the image is only in the project it was forked from."

	| fork commit pharo |
	fork := self forkRepository.
	commit := self upstreamRepository headCommit.
	pharo := self repositoryNamed: 'pharo' atCommit: commit id.
	self assert: (fork lookupCommit: commit id) isUnknownCommit.
	self loaderWithParentAtUpstream attach: fork to: pharo.
	self assert: pharo head name equals: 'image-' , commit shortId.
	self assert: pharo workingCopy referenceCommit id equals: commit id.
	self deny: pharo workingCopy referenceCommit isUnknownCommit
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testAttachKeepsTheImageCommitWhenItIsNowhere [
	"Adopting the commit of the clone would turn everything between the two commits into changes of the user."

	| fork pharo missing |
	fork := self forkRepository.
	missing := '0123456789abcdef0123456789abcdef01234567'.
	pharo := self repositoryNamed: 'pharo' atCommit: missing.
	self loaderWithParentAtUpstream attach: fork to: pharo.
	self assert: pharo workingCopy referenceCommit id equals: missing.
	self assert: pharo workingCopy referenceCommit isUnknownCommit
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testAttachNamesTheParentRemoteAfterItsOwnerLikeIceberg [

	| fork pharo |
	fork := self forkRepository.
	pharo := self repositoryNamed: 'pharo' atCommit: self upstreamRepository headCommit id.
	self loaderWithParentAtUpstream attach: fork to: pharo.
	self assert: (pharo remotes collect: [ :each | each name ] as: Set) equals: #( 'origin' 'pharo-project' ) asSet
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testAttachReportNamesTheImageBranchAndTheUpstream [

	| report |
	report := self loader
		          attachReportFor: (self repositoryNamed: 'Spec2' packages: #(  ))
		          branch: 'image-ebc98f0'
		          upstream: 'https://github.com/pharo-spec/Spec.git'.
	self assert: (report includesSubstring: 'Spec2').
	self assert: (report includesSubstring: 'image-ebc98f0').
	self assert: (report includesSubstring: 'https://github.com/pharo-spec/Spec.git')
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testAttachReportWithoutImageCommitSaysTheImageChangesShow [

	| report |
	report := self loader attachReportFor: (self repositoryNamed: 'Spec2' packages: #(  )) branch: nil upstream: nil.
	self assert: (report includesSubstring: 'not found').
	self assert: (report includesSubstring: 'No upstream')
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testAttachTellsWhyTheParentCouldNotBeFetched [

	| fork pharo told |
	fork := self forkRepository.
	pharo := self repositoryNamed: 'pharo' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	told := OrderedCollection new.
	(self loaderWithParentAt: (FileLocator temp / 'favrepo-no-such-repository') fullName)
		informer: [ :text | told add: text ];
		attach: fork to: pharo.
	self assert: (told anySatisfy: [ :each |
			 (each includesSubstring: 'could not be fetched') and: [ each includesSubstring: 'favrepo-no-such-repository' ] ])
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testBaselineNamesFindsFileTreePackages [

	| clone |
	clone := self cloneWithSource: 'repository' baselines: #( 'BaselineOfMustache.package' ).
	self assert: (self loader baselineNamesIn: clone) equals: #( 'Mustache' )
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testBaselineNamesFindsTonelPackages [

	| clone |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfMyProject' ).
	self assert: (self loader baselineNamesIn: clone) equals: #( 'MyProject' )
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testBaselineOfPharoIsNotLoaded [
	"The baseline of Pharo does not load like the others; the user is told instead of being asked which baseline to load."

	| repository told |
	repository := (self repositoryNamed: 'pharo' packages: #(  ))
		              location: (self cloneWithSource: 'src' baselines: #( 'BaselineOfIDE' 'BaselineOfPharo' ));
		              yourself.
	told := OrderedCollection new.
	self loader
		informer: [ :text | told add: text ];
		baselineChooser: [ :names | self fail: 'should not ask' ];
		loadBaselineOf: repository.
	self assert: told size equals: 1.
	self assert: (told first includesSubstring: 'not loaded')
]

{ #category : 'tests - bottom branch' }
FRFavoriteLoaderTest >> testBottomBranchNameIsTheIsoDateThenBottom [

	self assert: (self loader bottomBranchNameOn: (Date year: 2026 month: 11 day: 5)) equals: '2026-11-05-Bottom'
]

{ #category : 'tests - errors' }
FRFavoriteLoaderTest >> testChooserCancelRaisesError [

	| clone loader |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfA' 'BaselineOfB' ).
	loader := self loader.
	loader baselineChooser: [ :names | nil ].
	self should: [ loader baselineToLoadIn: clone ] raise: FRError
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testCloneAttachesToNothingWhenItHoldsNoLoadedPackage [
	"Sharing only packages that are not in the image does not count."

	| clone unloaded |
	clone := self repositoryNamed: 'new-project' packages: #( 'NotLoaded-FRFixture' 'Favrepo' ).
	unloaded := self repositoryNamed: 'Unloaded' packages: #( 'NotLoaded-FRFixture' ).
	self assert: (self loader repositoryLoadedFrom: clone among: { unloaded }) isNil
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testCloneAttachesToNothingWhenItLacksTheCommitOfARepositoryWithoutPackages [
	"A repository listing no package is taken over only by a clone that has its commit."

	| clone pharo |
	clone := self gitRepositoryWithBranch: 'dev'.
	pharo := self repositoryNamed: 'pharo' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	self assert: (self loader repositoryLoadedFrom: clone among: { pharo }) isNil
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testCloneAttachesToTheRepositoryItCoversBest [
	"The image's pharo repository lists the Spec2 packages too; a Spec fork must take over Spec2, whose loaded packages it holds all, not pharo."

	| clone spec pharo |
	clone := self repositoryNamed: 'spec' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	spec := self repositoryNamed: 'Spec2' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	pharo := self repositoryNamed: 'pharo' packages: #( 'Favrepo' 'Favrepo-Spec' 'Favrepo-Tests' 'Kernel' ).
	self
		assert: (self loader repositoryLoadedFrom: clone among: {
					 pharo.
					 spec })
		identicalTo: spec
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testCloneAttachesToTheRepositoryWhoseLoadedPackagesItHolds [
	"The fork of a project that came with the image takes over its loaded packages."

	| clone loaded other |
	clone := self repositoryNamed: 'favrepo-fork' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	loaded := self repositoryNamed: 'Favrepo' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	other := self repositoryNamed: 'Other' packages: #( 'Favrepo-Tests' ).
	self
		assert: (self loader repositoryLoadedFrom: clone among: {
					 other.
					 loaded })
		identicalTo: loaded
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testCloneAttachesToTheRepositoryWithoutPackagesWhoseCommitItHas [
	"The image's pharo repository lists no package: a Pharo fork takes it over because the clone has the commit the image was built from."

	| clone pharo other |
	clone := self gitRepositoryWithBranch: 'dev'.
	other := self repositoryNamed: 'other' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	pharo := self repositoryNamed: 'pharo' atCommit: clone headCommit id.
	self
		assert: (self loader repositoryLoadedFrom: clone among: {
			 other.
			 pharo })
		identicalTo: pharo
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testCloneDirectoryIsOwnerAndProjectInTheClonesLocation [

	self
		assert: (self clonesLoader cloneDirectoryFor: self mustache)
		equals: fileSystem root / 'iceberg' / 'noha' / 'mustache'
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testCloneWithAnotherBaselineIsNoPharoClone [

	self deny: (self loader isPharoClone: (self cloneWithSource: 'src' baselines: #( 'BaselineOfPharoExtras' )))
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testCloneWithBaselineOfPharoIsAPharoClone [

	self assert: (self loader isPharoClone: (self cloneWithSource: 'src' baselines: #( 'BaselineOfIDE' 'BaselineOfPharo' )))
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testCloneWithoutBaselineOfPharoDoesNotAttachToTheRepositoryOfTheImage [

	| clone pharo |
	clone := self gitRepositoryWithBranch: 'dev'.
	pharo := self repositoryNamed: 'pharo' atCommit: SystemVersion current commitHash.
	self assert: (self loader repositoryLoadedFrom: clone among: { pharo }) isNil
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testDefaultBranchMeansNoCommitish [

	self assert: (self loader commitishFor: (FRFavorite url: 'git@github.com:noha/mustache.git')) isNil
]

{ #category : 'tests - errors' }
FRFavoriteLoaderTest >> testDefineBottomBranchAtUnknownImageCommitRaisesError [
	"The bottom branch would be at the commit of a fork that is behind the image."

	| repository info |
	repository := self repositoryOnDiskAtUnknownCommit: '0123456789abcdef0123456789abcdef01234567'.
	info := (FRRepositoryInfo name: 'Mustache' url: nil)
		        beCloned;
		        iceRepository: repository;
		        yourself.
	self
		should: [
				self loader
					catalog: (FRCatalog withAll: { info });
					defineBottomBranchFor: self mustache ]
		raise: FRError
]

{ #category : 'tests - errors' }
FRFavoriteLoaderTest >> testDefineBottomBranchWithoutCloneRaisesError [

	self
		should: [
				self loader
					catalog: (FRCatalog withAll: #(  ));
					defineBottomBranchFor: self mustache ]
		raise: FRError
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testFallbackCommitishesAreTriedInOrder [

	self assert: self loader fallbackCommitishes asArray equals: #( 'master' 'main' 'dev' )
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testFolderWithoutGitIsNoExistingClone [

	(fileSystem root / 'iceberg' / 'noha' / 'mustache') ensureCreateDirectory.
	self assert: (self clonesLoader existingCloneFor: self mustache) isNil
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testGitFolderLeftOnDiskIsAnExistingClone [

	| folder |
	folder := fileSystem root / 'iceberg' / 'noha' / 'mustache'.
	(folder / '.git') ensureCreateDirectory.
	(folder / '.git' / 'config') writeStreamDo: [ :stream | stream nextPutAll: '[core]' ].
	self assert: (self clonesLoader existingCloneFor: self mustache) equals: folder
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testHasCommitishNamedDoesNotFindAMissingBranch [

	self deny: (self loader hasCommitishNamed: 'missing' in: (self gitRepositoryWithBranch: 'dev'))
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testHasCommitishNamedFindsAnExistingBranch [

	self assert: (self loader hasCommitishNamed: 'dev' in: (self gitRepositoryWithBranch: 'dev'))
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testMetacelloRepositoryIsGitlocalOnTheSourceDirectory [

	| clone |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfMyProject' ).
	self assert: (self loader metacelloRepositoryFor: clone) equals: 'gitlocal://' , (clone / 'src') fullName
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testMissingFolderIsNoExistingClone [

	self assert: (self clonesLoader existingCloneFor: self mustache) isNil
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testNamedBranchIsTheCommitish [

	self
		assert: (self loader commitishFor: (FRFavorite url: 'git@github.com:noha/mustache.git' name: 'Mustache' branch: 'v1.3'))
		equals: 'v1.3'
]

{ #category : 'tests - errors' }
FRFavoriteLoaderTest >> testNoBaselineRaisesError [

	| clone |
	clone := self cloneWithSource: 'src' baselines: #(  ).
	self should: [ self loader baselineToLoadIn: clone ] raise: FRError
]

{ #category : 'tests - attaching' }
FRFavoriteLoaderTest >> testPharoForkBehindTheImageAttachesToTheRepositoryOfTheImage [
	"A fork that does not have the commit the image was built from is still a clone of Pharo: it must not be registered apart."

	| clone pharo other |
	clone := self repositoryNamed: 'Pharo' packages: #( 'BaselineOfPharo' ).
	other := self repositoryNamed: 'other' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	pharo := self repositoryNamed: 'pharo' atCommit: SystemVersion current commitHash.
	self
		assert: (self loader repositoryLoadedFrom: clone among: {
				 other.
				 pharo })
		identicalTo: pharo
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testSeveralBaselinesAskTheChooser [

	| clone loader offered |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfMyProject' 'BaselineOfMyProjectExtras' ).
	offered := #(  ).
	loader := self loader.
	loader baselineChooser: [ :names |
			offered := names.
			names last ].
	self assert: (loader baselineToLoadIn: clone) equals: 'MyProjectExtras'.
	self assert: offered equals: #( 'MyProject' 'MyProjectExtras' )
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testSingleBaselineIsChosenWithoutAsking [

	| clone loader |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfMyProject' ).
	loader := self loader.
	loader baselineChooser: [ :names | self fail: 'should not ask' ].
	self assert: (loader baselineToLoadIn: clone) equals: 'MyProject'
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testSourceDirectoryComesFromProjectFile [

	| clone |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfMyProject' ).
	self assert: (self loader sourceDirectoryOf: clone) equals: clone / 'src'
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testSourceDirectoryIsTheCloneWithoutProjectFile [

	| clone |
	clone := fileSystem root / 'bare'.
	clone ensureCreateDirectory.
	self assert: (self loader sourceDirectoryOf: clone) equals: clone
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchKeepsTheImageCommitTheCloneDoesNotKnow [
	"Switching would adopt a commit unrelated to the image code."

	| repository missing told |
	missing := '0123456789abcdef0123456789abcdef01234567'.
	repository := self repositoryOnDiskAtUnknownCommit: missing.
	told := OrderedCollection new.
	self loader
		informer: [ :text | told add: text ];
		switch: repository to: (self mustache withBranch: 'dev').
	self assert: repository workingCopy referenceCommit id equals: missing.
	self assert: repository head name equals: 'master'.
	self assert: (told anySatisfy: [ :each | each includesSubstring: 'Fetch' ])
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchToExistingBranchChecksItOut [

	| repository |
	repository := self gitRepositoryWithBranch: 'dev'.
	self loader switch: repository to: (self mustache withBranch: 'dev').
	self assert: repository head name equals: 'dev'
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchToMissingBranchFallsBackOnMaster [
	"A favorite whose branch does not exist (any more) puts the clone on master, the first fallback branch, instead of failing."

	| repository |
	repository := self gitRepositoryWithBranch: 'dev'.
	repository switchToCommitishNamed: 'dev'.
	self loader switch: repository to: (self mustache withBranch: 'missing').
	self assert: repository head name equals: 'master'
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchToMissingBranchTellsTheUser [

	| repository told |
	repository := self gitRepositoryWithBranch: 'dev'.
	told := OrderedCollection new.
	self loader
		informer: [ :text | told add: text ];
		switch: repository to: (self mustache withBranch: 'missing').
	self assert: told size equals: 1.
	self assert: (told first includesSubstring: 'missing').
	self assert: (told first includesSubstring: 'master')
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> upstreamRepository [
	"The project a fork comes from, holding a commit the fork does not have; deleted by tearDown."

	^ upstreamRepository ifNil: [ upstreamRepository := self newGitRepositoryNamed: 'FRUpstreamFixture' ]
]
