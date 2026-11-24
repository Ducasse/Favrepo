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

{ #category : 'tests - matching' }
FRCloneTest >> testCloneBelongsToNothingWhenItHoldsNoLoadedPackage [
	"Sharing only packages that are not in the image does not count."

	| clone unloaded |
	clone := self cloneNamed: 'new-project' packages: #( 'NotLoaded-FRFixture' 'Favrepo' ).
	unloaded := self repositoryNamed: 'Unloaded' packages: #( 'NotLoaded-FRFixture' ).
	self assert: (clone imageRepositoryAmong: { unloaded }) isNil
]

{ #category : 'tests - matching' }
FRCloneTest >> testCloneBelongsToTheRepositoryItCoversBest [
	"The image's pharo repository lists the Spec2 packages too; a Spec fork must take over Spec2, whose loaded packages it holds all, not pharo."

	| clone spec pharo |
	clone := self cloneNamed: 'spec' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	spec := self repositoryNamed: 'Spec2' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	pharo := self repositoryNamed: 'pharo' packages: #( 'Favrepo' 'Favrepo-Spec' 'Favrepo-Tests' 'Kernel' ).
	self
		assert: (clone imageRepositoryAmong: {
				 pharo.
				 spec })
		identicalTo: spec
]

{ #category : 'tests - matching' }
FRCloneTest >> testCloneBelongsToTheRepositoryWhoseLoadedPackagesItHolds [
	"The fork of a project that came with the image takes over its loaded packages."

	| clone loaded other |
	clone := self cloneNamed: 'favrepo-fork' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	loaded := self repositoryNamed: 'Favrepo' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	other := self repositoryNamed: 'Other' packages: #( 'Favrepo-Tests' ).
	self
		assert: (clone imageRepositoryAmong: {
				 other.
				 loaded })
		identicalTo: loaded
]

{ #category : 'tests - matching' }
FRCloneTest >> testCloneWithoutBaselineOfPharoDoesNotBelongToTheRepositoryOfTheImage [

	self assert: ((self cloneWithBranch: 'dev') imageRepositoryAmong: { (self repositoryNamed: 'pharo' atCommit: FRPharoClone imageCommitId) }) isNil
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
