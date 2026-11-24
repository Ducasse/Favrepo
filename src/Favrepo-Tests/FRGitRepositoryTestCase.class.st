"
I am the common fixture of the tests that need Iceberg repositories: git repositories on disk, deleted by `tearDown`, and repositories missing on disk like the ones that came with the image. None is registered in Iceberg.
"
Class {
	#name : 'FRGitRepositoryTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'gitRepository'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'testing' }
FRGitRepositoryTestCase class >> isAbstract [

	^ self == FRGitRepositoryTestCase
]

{ #category : 'helpers' }
FRGitRepositoryTestCase >> deleteGitRepository: aRepositoryOrNil [

	| location |
	aRepositoryOrNil ifNil: [ ^ self ].
	location := aRepositoryOrNil location.
	aRepositoryOrNil free.
	location ensureDeleteAll
]

{ #category : 'helpers' }
FRGitRepositoryTestCase >> gitRepositoryWithBranch: aBranchName [
	"A git repository on disk, not registered in Iceberg, with one commit on master and a branch aBranchName at that commit; it is checked out on master and deleted by tearDown."

	gitRepository := self newGitRepositoryNamed: 'FRFixture'.
	gitRepository createBranch: aBranchName.
	gitRepository switchToCommitishNamed: 'master'.
	^ gitRepository
]

{ #category : 'helpers' }
FRGitRepositoryTestCase >> newGitRepositoryNamed: aName [
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
FRGitRepositoryTestCase >> repositoryNamed: aName atCommit: anId [
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
FRGitRepositoryTestCase >> repositoryNamed: aName packages: someNames [
	"An Iceberg repository missing on disk and not registered, holding packages named someNames (loaded when the image has them)."

	| repository |
	repository := IceLibgitRepository new
		              name: aName;
		              yourself.
	someNames do: [ :each | repository workingCopy addPackage: (IcePackage named: each repository: repository) ].
	^ repository
]

{ #category : 'running' }
FRGitRepositoryTestCase >> tearDown [

	self deleteGitRepository: gitRepository.
	super tearDown
]
