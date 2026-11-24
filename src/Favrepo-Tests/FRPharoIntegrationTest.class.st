"
I test `FRPharoIntegration`: matching favorites to the external projects of `BaselineOfPharo`, the rewrite of the method, branch names, and the checks done before creating anything. Only throwaway repositories are touched.
"
Class {
	#name : 'FRPharoIntegrationTest',
	#superclass : 'FRGitRepositoryTestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRPharoIntegrationTest >> integrationFor: aUrl [

	^ FRPharoIntegration favorite: (FRFavorite url: aUrl) catalog: (FRCatalog withAll: #(  ))
]

{ #category : 'helpers' }
FRPharoIntegrationTest >> newToolsSource [

	^ 'newTools
	<externalProject>

	^ PharoExternalProject 
		newName: ''NewTools'' 
		owner: ''pharo-spec'' 
		project: ''NewTools'' 
		version: ''v0.11.0'''
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testBottomBranchNameAsIntegrationBranchRaisesError [

	self should: [ FRPharoIntegration validateBranchName: '2026-11-15-Bottom' ] raise: FRError
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testBottomBranchNames [

	self assert: (FRPharoIntegration isBottomBranchName: '2026-11-15-Bottom').
	self deny: (FRPharoIntegration isBottomBranchName: 'Pharo14').
	self deny: (FRPharoIntegration isBottomBranchName: '2026-11-15-Bottom-fix')
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testBranchNameWithDoubleDotRaisesError [

	self should: [ FRPharoIntegration validateBranchName: 'a..b' ] raise: FRError
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testBranchNameWithSpaceRaisesError [

	self should: [ FRPharoIntegration validateBranchName: 'new packages' ] raise: FRError
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testCommitMessageNamesTheForkAndTheBranch [

	self
		assert: ((self integrationFor: 'git@github.com:Ducasse/NewTools.git') commitMessageForOwner: 'Ducasse' branch: 'fix-x')
		equals: 'Load NewTools from Ducasse/NewTools:fix-x to validate it in the full build'
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testCreateForANonExternalProjectRaisesError [

	self should: [ (self integrationFor: 'git@github.com:Ducasse/Favrepo.git') createBranch: 'fix-x' ] raise: FRError
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testCreateInACloneWithoutTheImageCommitTellsToFetch [
	"The clone is behind the image: BaselineOfPharo differs although the user changed nothing. Telling them to discard would downgrade the image."

	| pharo |
	pharo := self gitRepositoryWithBranch: 'dev'.
	pharo workingCopy addPackage: (IcePackage named: 'BaselineOfPharo' repository: pharo).
	self
		should: [ (self integrationFor: 'git@github.com:Ducasse/NewTools.git') check: 'fix-x' canBeCreatedIn: pharo and: pharo ]
		raise: FRError
		withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'Fetch') ]
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testCreateWithoutCloneRaisesError [
	"NewTools is an external project, but the catalog knows no clone of it."

	self should: [ (self integrationFor: 'git@github.com:Ducasse/NewTools.git') createBranch: 'fix-x' ] raise: FRError
]

{ #category : 'tests - errors' }
FRPharoIntegrationTest >> testEmptyBranchNameRaisesError [

	self should: [ FRPharoIntegration validateBranchName: '' ] raise: FRError
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testFavrepoIsNoExternalProject [

	self deny: (self integrationFor: 'git@github.com:Ducasse/Favrepo.git') isExternalProject
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testForkOfNewToolsIsAnExternalProject [

	self assert: (self integrationFor: 'git@github.com:Ducasse/NewTools.git') externalProjectMethod selector equals: #newTools
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testForkOfSpecIsAnExternalProjectIgnoringCase [
	"The Spec project is declared as 'Spec', the fork is named 'spec'."

	self assert: (self integrationFor: 'git@github.com:Ducasse/spec.git') externalProjectMethod selector equals: #spec
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testNonExternalProjectHasNoIntegrationBranch [
	"Favrepo is cloned in this image but is no Pharo external project."

	self deny: (FRPharoIntegration favorite: (FRFavorite url: 'git@github.com:Ducasse/Favrepo.git') catalog: FRCatalog current)
			hasPharoIntegrationBranch
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testRewriteChangesOnlyOwnerAndVersion [

	| expected |
	expected := (self newToolsSource copyReplaceAll: '''pharo-spec''' with: '''Ducasse''')
		            copyReplaceAll: '''v0.11.0'''
		            with: '''2026-11-15-new-packages'''.
	self
		assert: (FRPharoIntegration rewrite: self newToolsSource owner: 'Ducasse' version: '2026-11-15-new-packages')
		equals: expected
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testUpstreamPharoIsNotAFork [

	self assert: (FRPharoIntegration isUpstreamPharo: 'git@github.com:pharo-project/pharo.git').
	self assert: (FRPharoIntegration isUpstreamPharo: 'https://github.com/pharo-project/pharo.git').
	self deny: (FRPharoIntegration isUpstreamPharo: 'git@github.com:Ducasse/pharo.git')
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testValidBranchName [

	FRPharoIntegration validateBranchName: '2026-11-15-new-packages'
]

{ #category : 'tests' }
FRPharoIntegrationTest >> testWithoutCloneThereIsNoIntegrationBranch [

	self deny: (self integrationFor: 'git@github.com:Ducasse/NewTools.git') hasPharoIntegrationBranch
]
