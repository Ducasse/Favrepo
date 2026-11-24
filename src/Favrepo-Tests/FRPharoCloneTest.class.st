"
I test that a clone of Pharo is recognized whatever its commit, belongs to the repository of the image and never loads its baseline.
"
Class {
	#name : 'FRPharoCloneTest',
	#superclass : 'FRGitRepositoryTestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'tests' }
FRPharoCloneTest >> testBaselineIsNotLoaded [
	"The baseline of Pharo does not load like the others; the user is told instead of being asked which baseline to load."

	| told loader |
	told := OrderedCollection new.
	loader := FRFavoriteLoader new.
	loader
		informer: [ :text | told add: text ];
		baselineChooser: [ :names | self fail: 'should not ask' ].
	(self cloneNamed: 'pharo' packages: #( 'BaselineOfIDE' 'BaselineOfPharo' )) loadBaselineFor: loader.
	self assert: told size equals: 1.
	self assert: (told first includesSubstring: 'not loaded')
]

{ #category : 'tests' }
FRPharoCloneTest >> testCloneHoldingBaselineOfPharoIsAPharoClone [

	self assert: (self cloneNamed: 'my-pharo' packages: #( 'BaselineOfPharo' )) class equals: FRPharoClone
]

{ #category : 'tests' }
FRPharoCloneTest >> testCloneWithAnotherBaselineIsNoPharoClone [

	self assert: (self cloneNamed: 'pharo' packages: #( 'BaselineOfPharoExtras' )) class equals: FRClone
]

{ #category : 'tests' }
FRPharoCloneTest >> testForkBehindTheImageBelongsToTheRepositoryOfTheImage [
	"A fork that does not have the commit the image was built from is still a clone of Pharo: it must not be registered apart."

	| pharo other |
	other := self repositoryNamed: 'other' atCommit: self unknownCommitId.
	pharo := self repositoryNamed: 'pharo' atCommit: FRPharoClone imageCommitId.
	self
		assert: ((self cloneNamed: 'Pharo' packages: #( 'BaselineOfPharo' )) imageRepositoryAmong: {
				 other.
				 pharo })
		identicalTo: pharo
]

{ #category : 'tests' }
FRPharoCloneTest >> testPackagelessCloneAtAnotherCommitIsNoPharoClone [

	self assert: (FRClone on: (self repositoryNamed: 'other' atCommit: self unknownCommitId)) class equals: FRClone
]

{ #category : 'tests' }
FRPharoCloneTest >> testPackagelessCloneAtTheImageCommitIsAPharoClone [
	"The clone lacks the commit of the image, so Iceberg lists no package."

	self assert: (FRClone on: (self repositoryNamed: 'pharo' atCommit: FRPharoClone imageCommitId)) class equals: FRPharoClone
]

{ #category : 'tests - registered' }
FRPharoCloneTest >> testRegisteredIsACloneOfPharoOnDisk [

	| pharo |
	pharo := self cloneOnDiskAtUnknownCommit: FRPharoClone imageCommitId.
	self
		assert: (FRPharoClone registeredAmong: {
				 (self repositoryNamed: 'Other' packages: #( 'Favrepo' )).
				 pharo iceRepository }) iceRepository
		identicalTo: pharo iceRepository
]

{ #category : 'tests - registered' }
FRPharoCloneTest >> testRegisteredIsNilWhenPharoIsMissingOnDisk [

	self assert: (FRPharoClone registeredAmong: { (self repositoryNamed: 'pharo' atCommit: FRPharoClone imageCommitId) }) isNil
]

{ #category : 'tests - registered' }
FRPharoCloneTest >> testRegisteredIsNilWithoutCloneOfPharo [

	self assert: (FRPharoClone registeredAmong: { (self gitRepositoryWithBranch: 'dev') }) isNil
]

{ #category : 'tests' }
FRPharoCloneTest >> testRepositoryWithNothingLoadedIsNotTheOneOfTheImage [
	"It has no reference commit."

	| pharo |
	pharo := self repositoryNamed: 'pharo' atCommit: FRPharoClone imageCommitId.
	self
		assert: ((self cloneNamed: 'Pharo' packages: #( 'BaselineOfPharo' )) imageRepositoryAmong: {
				 (self repositoryNamed: 'empty' packages: #(  )).
				 pharo })
		identicalTo: pharo
]

{ #category : 'tests' }
FRPharoCloneTest >> testWithoutTheRepositoryOfTheImageTheCloneBelongsToNothing [

	self assert: ((self cloneNamed: 'Pharo' packages: #( 'BaselineOfPharo' )) imageRepositoryAmong: { (self repositoryNamed: 'other' atCommit: self unknownCommitId) }) isNil
]
