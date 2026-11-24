"
I test the network-free steps of FRFavoriteLoader on fake clones in a memory file system.
"
Class {
	#name : 'FRFavoriteLoaderTest',
	#superclass : 'FRGitRepositoryTestCase',
	#instVars : [
		'fileSystem'
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
FRFavoriteLoaderTest >> loader [

	^ FRFavoriteLoader new
]

{ #category : 'helpers' }
FRFavoriteLoaderTest >> mustache [

	^ FRFavorite url: 'git@github.com:noha/mustache.git' name: 'Mustache' branch: 'v1.3'
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
