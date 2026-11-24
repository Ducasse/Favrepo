"
I test `FRClone` on git repositories created on disk and on repositories missing on disk.
"
Class {
	#name : 'FRCloneTest',
	#superclass : 'FRGitRepositoryTestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'tests - baselines' }
FRCloneTest >> testBaselineNamesAreSortedWithoutPrefix [

	self
		assert: (self cloneNamed: 'MyProject' packages: #( 'MyProject-Core' 'BaselineOfMyProjectExtras' 'BaselineOfMyProject' )) baselineNames
		equals: #( 'MyProject' 'MyProjectExtras' )
]

{ #category : 'tests - errors' }
FRCloneTest >> testBottomBranchAtUnknownImageCommitRaisesError [
	"The bottom branch would be at the commit of a fork that is behind the image."

	| clone |
	clone := self cloneOnDiskAtUnknownCommit: self unknownCommitId.
	self should: [ clone createBottomBranch ] raise: FRError
]

{ #category : 'tests - branches' }
FRCloneTest >> testBottomBranchIsCheckedOut [

	| clone |
	clone := self cloneWithBranch: 'dev'.
	clone createBottomBranch.
	self assert: clone headName equals: (FRClone bottomBranchNameOn: Date today)
]

{ #category : 'tests - branches' }
FRCloneTest >> testBottomBranchNameIsTheIsoDateThenBottom [

	self assert: (FRClone bottomBranchNameOn: (Date year: 2026 month: 11 day: 5)) equals: '2026-11-05-Bottom'
]

{ #category : 'tests - branches' }
FRCloneTest >> testFallbackCommitishIsTheFirstThatExists [

	self assert: (self cloneWithBranch: 'dev') fallbackCommitish equals: 'master'
]

{ #category : 'tests - branches' }
FRCloneTest >> testFallbackCommitishesAreTriedInOrder [

	self assert: FRClone instanceMissingOnDisk fallbackCommitishes asArray equals: #( 'master' 'main' 'dev' )
]

{ #category : 'tests - branches' }
FRCloneTest >> testHasCommitishNamedDoesNotFindAMissingBranch [

	self deny: ((self cloneWithBranch: 'dev') hasCommitishNamed: 'missing')
]

{ #category : 'tests - branches' }
FRCloneTest >> testHasCommitishNamedFindsAnExistingBranch [

	self assert: ((self cloneWithBranch: 'dev') hasCommitishNamed: 'dev')
]

{ #category : 'tests' }
FRCloneTest >> testImageCommitIsKnownByTheCloneItWasLoadedFrom [

	self deny: (self cloneWithBranch: 'dev') isImageCommitUnknown
]

{ #category : 'tests' }
FRCloneTest >> testImageCommitTheCloneLacksIsUnknown [

	self assert: (self cloneOnDiskAtUnknownCommit: self unknownCommitId) isImageCommitUnknown
]

{ #category : 'tests - baselines' }
FRCloneTest >> testMetacelloRepositoryIsGitlocalOnTheSourceDirectory [
	"The source directory is the one Iceberg reads in the .project file."

	| clone |
	clone := self cloneWithBranch: 'dev'.
	self assert: clone metacelloRepository equals: 'gitlocal://' , (gitRepository location / 'src') fullName
]

{ #category : 'tests' }
FRCloneTest >> testReferenceCommitIdIsTheCommitOfTheImageCode [

	self assert: (self cloneOnDiskAtUnknownCommit: self unknownCommitId) referenceCommitId equals: self unknownCommitId
]

{ #category : 'tests' }
FRCloneTest >> testRepositoryWithNothingLoadedHasNoReferenceCommitId [
	"IceNoCommit does not understand #id."

	self assert: FRClone instanceMissingOnDisk referenceCommitId isNil
]

{ #category : 'tests - errors' }
FRCloneTest >> testSecondBottomBranchOfTheDayRaisesError [

	| clone |
	clone := self cloneWithBranch: 'dev'.
	clone createBottomBranch.
	self should: [ clone createBottomBranch ] raise: FRError
]

{ #category : 'tests - branches' }
FRCloneTest >> testSwitchToChecksOutTheBranch [

	| clone |
	clone := self cloneWithBranch: 'dev'.
	clone switchTo: 'dev'.
	self assert: clone headName equals: 'dev'
]
