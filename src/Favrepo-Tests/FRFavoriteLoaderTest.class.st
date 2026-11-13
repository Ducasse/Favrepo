"
I test the network-free steps of FRFavoriteLoader on fake clones in a memory file system.
"
Class {
	#name : 'FRFavoriteLoaderTest',
	#superclass : 'TestCase',
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
FRFavoriteLoaderTest >> loader [

	^ FRFavoriteLoader new
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

{ #category : 'tests - errors' }
FRFavoriteLoaderTest >> testChooserCancelRaisesError [

	| clone loader |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfA' 'BaselineOfB' ).
	loader := self loader.
	loader baselineChooser: [ :names | nil ].
	self should: [ loader baselineToLoadIn: clone ] raise: FRError
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testDefaultBranchMeansNoCommitish [

	self assert: (self loader commitishFor: (FRFavorite url: 'git@github.com:noha/mustache.git')) isNil
]

{ #category : 'tests' }
FRFavoriteLoaderTest >> testMetacelloRepositoryIsGitlocalOnTheSourceDirectory [

	| clone |
	clone := self cloneWithSource: 'src' baselines: #( 'BaselineOfMyProject' ).
	self assert: (self loader metacelloRepositoryFor: clone) equals: 'gitlocal://' , (clone / 'src') fullName
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
