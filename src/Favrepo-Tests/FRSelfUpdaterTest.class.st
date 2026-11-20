"
Tests FRSelfUpdater on local Git repositories that it must refuse to update; fetching and pulling a real remote is left to trying the button.
"
Class {
	#name : 'FRSelfUpdaterTest',
	#superclass : 'TestCase',
	#instVars : [
		'gitRepository'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRSelfUpdaterTest >> gitRepository [
	"A git repository on disk, not registered in Iceberg, with one commit on master and no remote; deleted by tearDown."

	gitRepository := IceRepositoryCreator new
		                 location: (FileLocator temp / ('favrepo-test-' , UUID new asString36)) asFileReference;
		                 subdirectory: 'src';
		                 createNewRepositoryNamed: 'FRFixture'.
	gitRepository commitWithMessage: 'Initial commit'.
	^ gitRepository
]

{ #category : 'running' }
FRSelfUpdaterTest >> tearDown [

	gitRepository ifNotNil: [ gitRepository location ensureDeleteAll ].
	super tearDown
]

{ #category : 'tests' }
FRSelfUpdaterTest >> testBranchWithoutUpstreamIsNotUpdated [

	| updater text |
	updater := FRSelfUpdater new repository: self gitRepository; yourself.
	text := updater update.
	self deny: updater updated.
	self assert: (text includesSubstring: 'tracks no remote branch')
]

{ #category : 'tests' }
FRSelfUpdaterTest >> testDetachedCloneIsNotUpdated [

	| updater text |
	self gitRepository.
	gitRepository headCommit checkout: (IceCheckoutAllPackages new committish: gitRepository headCommit; yourself).
	updater := FRSelfUpdater new repository: gitRepository; yourself.
	text := updater update.
	self deny: updater updated.
	self assert: (text includesSubstring: 'not on a branch')
]

{ #category : 'tests' }
FRSelfUpdaterTest >> testFindsTheRepositoryFavrepoWasLoadedFrom [

	| repository |
	repository := FRSelfUpdater new repository.
	repository ifNil: [ ^ self skip: 'Favrepo was not loaded from a Git clone in this image' ].
	self assert: (repository workingCopy packages anySatisfy: [ :each | each name = 'Favrepo' ])
]
