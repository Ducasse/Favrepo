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
FRFavoriteLoaderTest >> repositoryNamed: aName packages: someNames [
	"An Iceberg repository missing on disk and not registered, holding packages named someNames (loaded when the image has them)."

	| repository |
	repository := IceLibgitRepository new
		              name: aName;
		              yourself.
	someNames do: [ :each | repository workingCopy addPackage: (IcePackage named: each repository: repository) ].
	^ repository
]

{ #category : 'running' }
FRFavoriteLoaderTest >> setUp [

	super setUp.
	fileSystem := FileSystem memory
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
