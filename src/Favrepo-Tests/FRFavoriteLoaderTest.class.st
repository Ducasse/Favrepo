"
I test the steps of `FRFavoriteLoader` that need no network.
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

{ #category : 'running' }
FRFavoriteLoaderTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testBaselineOfPharoIsNotLoaded [
	"The baseline of Pharo does not load like the others; the user is told instead of being asked which baseline to load."

	| told loader |
	told := OrderedCollection new.
	loader := self loader.
	loader
		informer: [ :text | told add: text ];
		baselineChooser: [ :names | self fail: 'should not ask' ].
	(self cloneNamed: 'pharo' packages: #( 'BaselineOfIDE' 'BaselineOfPharo' )) loadBaselineFor: loader.
	self assert: told size equals: 1.
	self assert: (told first includesSubstring: 'not loaded')
]

{ #category : 'tests - errors' }
FRFavoriteLoaderTest >> testChooserCancelRaisesError [

	| clone loader |
	clone := self cloneNamed: 'MyProject' packages: #( 'BaselineOfA' 'BaselineOfB' ).
	loader := self loader.
	loader baselineChooser: [ :names | nil ].
	self should: [ loader baselineToLoadOf: clone ] raise: FRError
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testCloneDirectoryIsOwnerAndProjectInTheClonesLocation [

	self
		assert: (self clonesLoader cloneDirectoryFor: self mustache)
		equals: fileSystem root / 'iceberg' / 'noha' / 'mustache'
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testDefaultBranchMeansNoCommitish [

	self assert: (self loader commitishFor: (FRFavorite url: 'git@github.com:noha/mustache.git')) isNil
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

	self should: [ self loader baselineToLoadOf: (self cloneNamed: 'MyProject' packages: #( 'MyProject-Core' )) ] raise: FRError
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testSeveralBaselinesAskTheChooser [

	| clone loader offered |
	clone := self cloneNamed: 'MyProject' packages: #( 'BaselineOfMyProject' 'BaselineOfMyProjectExtras' ).
	offered := #(  ).
	loader := self loader.
	loader baselineChooser: [ :names |
			offered := names.
			names last ].
	self assert: (loader baselineToLoadOf: clone) equals: 'MyProjectExtras'.
	self assert: offered equals: #( 'MyProject' 'MyProjectExtras' )
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testSingleBaselineIsChosenWithoutAsking [

	| loader |
	loader := self loader.
	loader baselineChooser: [ :names | self fail: 'should not ask' ].
	self assert: (loader baselineToLoadOf: (self cloneNamed: 'MyProject' packages: #( 'BaselineOfMyProject' ))) equals: 'MyProject'
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchKeepsTheImageCommitTheCloneDoesNotKnow [
	"Switching would adopt a commit unrelated to the image code."

	| clone told |
	clone := self cloneOnDiskAtUnknownCommit: self unknownCommitId.
	told := OrderedCollection new.
	self loader
		informer: [ :text | told add: text ];
		switch: clone to: (self mustache withBranch: 'dev').
	self assert: clone referenceCommitId equals: self unknownCommitId.
	self assert: clone headName equals: 'master'.
	self assert: (told anySatisfy: [ :each | each includesSubstring: 'Fetch' ])
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchToExistingBranchChecksItOut [

	| clone |
	clone := self cloneWithBranch: 'dev'.
	self loader switch: clone to: (self mustache withBranch: 'dev').
	self assert: clone headName equals: 'dev'
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchToMissingBranchFallsBackOnMaster [
	"A favorite whose branch does not exist (any more) puts the clone on master, the first fallback branch, instead of failing."

	| clone |
	clone := self cloneWithBranch: 'dev'.
	clone switchTo: 'dev'.
	self loader switch: clone to: (self mustache withBranch: 'missing').
	self assert: clone headName equals: 'master'
]

{ #category : 'tests - switching' }
FRFavoriteLoaderTest >> testSwitchToMissingBranchTellsTheUser [

	| told |
	told := OrderedCollection new.
	self loader
		informer: [ :text | told add: text ];
		switch: (self cloneWithBranch: 'dev') to: (self mustache withBranch: 'missing').
	self assert: told size equals: 1.
	self assert: (told first includesSubstring: 'missing').
	self assert: (told first includesSubstring: 'master')
]
