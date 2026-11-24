"
I validate a branch of a Pharo external project (NewTools, Spec, Roassal…) in the full Pharo build: I create the branch in the clone of the project and, in the Pharo fork, a branch whose `BaselineOfPharo` loads it from the project's fork. A pull request of that Pharo branch makes the Pharo CI build the whole system with it. Key messages are `isExternalProject`, `createBranch:` and `hasPharoIntegrationBranch`.

## Examples

```
FRPharoIntegration instanceNewTools
```

## Design Rationale

- A favorite is an external project when its GitHub project name is the `project:` of a `BaselineOfPharo` class method marked `<externalProject>`.
- Everything is checked before the two branches are created: valid new name, not a bottom branch, Pharo clone from a fork, nothing else changed in `BaselineOfPharo`. The user confirms when a clone is not on a bottom branch (`<ISO date>-Bottom`).
- The Pharo clone must be on the commit the image was built from, or on one made on top of it. Otherwise the differences of `BaselineOfPharo` are not changes of the user, and discarding them would downgrade the image.
- In Pharo I rewrite only the `owner:` and `version:` of the project's method and commit that alone, then put Pharo back on its base branch with the original method: the Pharo branch is only the vehicle of the pull request. The project's branch stays checked out and local: the developer commits and pushes there.

## Usage

1. `FRApplication>>newPharoIntegrationFor:` creates me for a favorite, with a `confirmer:` block.
2. `createBranch:` answers the report to show, or nil when the user cancelled.
3. `FRApplication>>openPullRequestFor:` opens the pull request dialog (`FRPharoPullRequestPresenter`) on my `checkedPharoRepository` and `integrationPharoBranch`.
4. `FRCatalog` gives the clone of the favorite and `FRPharoClone` class side `registered` the one of Pharo, which I keep once found: create another instance after the registered clones changed.

## Implementation Notes

- The rewrite replaces the two argument literals by their source intervals, so the rest of the method keeps its layout and the commit is a one-line change.
- An error between the creation of the branches and the push undoes nothing: the branches stay.
"
Class {
	#name : 'FRPharoIntegration',
	#superclass : 'Object',
	#instVars : [
		'favorite',
		'catalog',
		'confirmer',
		'pharoRepository'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'external projects' }
FRPharoIntegration class >> externalProjectMethods [
	"The methods of BaselineOfPharo declaring the projects the Pharo build loads from other repositories."

	^ Smalltalk globals
		  at: #BaselineOfPharo
		  ifPresent: [ :baseline | (Pragma allNamed: #externalProject in: baseline class) collect: [ :each | each method ] ]
		  ifAbsent: [ #(  ) ]
]

{ #category : 'instance creation' }
FRPharoIntegration class >> favorite: aFavorite catalog: aCatalog [

	^ self new
		  setFavorite: aFavorite catalog: aCatalog;
		  yourself
]

{ #category : 'instances' }
FRPharoIntegration class >> instanceNewTools [
	"The integration of a fork of NewTools; it creates nothing until sent #createBranch:."

	<sampleInstance>
	^ self favorite: (FRFavorite url: 'git@github.com:Ducasse/NewTools.git') catalog: FRCatalog current
]

{ #category : 'testing' }
FRPharoIntegration class >> isBottomBranchName: aString [
	"Whether aString is a bottom branch, <ISO date>-Bottom: a clean base for integration branches."

	^ aString matchesRegex: '\d\d\d\d-\d\d-\d\d-Bottom'
]

{ #category : 'testing' }
FRPharoIntegration class >> isGitBranchName: aString [
	"The rules of git check-ref-format that a typed name can break."

	(aString anySatisfy: [ :each | each isSeparator or: [ '~^:?*[\' includes: each ] ]) ifTrue: [ ^ false ].
	((aString includesSubstring: '..') or: [ aString includesSubstring: '@{' ]) ifTrue: [ ^ false ].
	('/.-' includes: aString first) ifTrue: [ ^ false ].
	^ ('/.' includes: aString last) not and: [ (aString endsWith: '.lock') not ]
]

{ #category : 'testing' }
FRPharoIntegration class >> isUpstreamPharo: aUrl [
	"Whether aUrl is pharo-project/pharo itself rather than a fork of it."

	| remote |
	remote := IceGitRemote url: aUrl.
	^ (remote organizer sameAs: 'pharo-project') and: [ remote projectName sameAs: 'pharo' ]
]

{ #category : 'rewriting' }
FRPharoIntegration class >> rewrite: aMethodSource owner: anOwner version: aVersion [
	"aMethodSource with only the owner: and version: arguments of its PharoExternalProject creation replaced."

	| creation replacements |
	creation := (RBParser parseMethod: aMethodSource) allChildren detect: [ :each |
		            each isMessage and: [ each selector beginsWith: 'newName:' ] ].
	replacements := OrderedCollection new.
	creation keywords withIndexDo: [ :keyword :index |
			keyword = 'owner:' ifTrue: [ replacements add: (creation arguments at: index) -> anOwner ].
			keyword = 'version:' ifTrue: [ replacements add: (creation arguments at: index) -> aVersion ] ].
	^ String streamContents: [ :stream |
			  | next |
			  next := 1.
			  (replacements sorted: [ :a :b | a key start < b key start ]) do: [ :each |
					  stream
						  nextPutAll: (aMethodSource copyFrom: next to: each key start - 1);
						  print: each value.
					  next := each key stop + 1 ].
			  stream nextPutAll: (aMethodSource copyFrom: next to: aMethodSource size) ]
]

{ #category : 'checking' }
FRPharoIntegration class >> validateBranchName: aString [
	"Raise an FRError when aString cannot be the name of an integration branch: empty, not a git branch name, or a bottom branch."

	aString isEmptyOrNil ifTrue: [ FRError signal: 'The branch name is empty' ].
	(self isGitBranchName: aString) ifFalse: [ FRError signal: ('{1} is not a valid git branch name' format: { aString }) ].
	(self isBottomBranchName: aString) ifTrue: [
		FRError signal: ('{1} is a bottom branch, not an integration branch' format: { aString }) ]
]

{ #category : 'creating' }
FRPharoIntegration >> announceChangeOf: someRepositories [

	someRepositories do: [ :each | Iceberg announcer announce: (IceRepositoryModified for: each) ]
]

{ #category : 'creating' }
FRPharoIntegration >> baselineOfPharoDiffIn: aPharoRepository [
	"The changes of the image to BaselineOfPharo, against the commit the Pharo clone is on."

	| workingCopy |
	workingCopy := aPharoRepository workingCopy.
	^ IceDiff new
		  sourceVersion: workingCopy;
		  targetVersion: workingCopy referenceCommit;
		  buildForPackages: { (workingCopy packageNamed: 'BaselineOfPharo') };
		  yourself
]

{ #category : 'checking' }
FRPharoIntegration >> check: aName canBeCreatedIn: anExternalRepository and: aPharoRepository [
	"Everything is checked before anything is created: both branches or none."

	self class validateBranchName: aName.
	self check: aName isNewIn: anExternalRepository.
	self check: aName isNewIn: aPharoRepository.
	self checkIsBasedOnImageCommit: (FRPharoClone newOn: aPharoRepository).
	self checkBaselineOfPharoIsUnchangedIn: aPharoRepository
]

{ #category : 'checking' }
FRPharoIntegration >> check: aName isNewIn: anIceRepository [

	(anIceRepository hasLocalBranchNamed: aName) ifTrue: [
			FRError signal: ('{1} already has a branch {2}' format: {
						 anIceRepository name.
						 aName }) ]
]

{ #category : 'checking' }
FRPharoIntegration >> checkBaselineOfPharoIsUnchangedIn: aPharoRepository [
	"The integration commit must hold the one-line change only."

	(self baselineOfPharoDiffIn: aPharoRepository) isEmpty ifFalse: [
		FRError signal: 'BaselineOfPharo has uncommitted changes: commit or discard them first' ]
]

{ #category : 'checking' }
FRPharoIntegration >> checkIsBasedOnImageCommit: aPharoClone [
	"Otherwise the differences of BaselineOfPharo are not changes of the user, and they must not be told to discard them."

	aPharoClone isBasedOnImageCommit ifFalse: [ FRError signal: aPharoClone notBasedOnImageCommitReport ]
]

{ #category : 'checking' }
FRPharoIntegration >> checkedExternalRepository [

	self isExternalProject ifFalse: [ FRError signal: ('{1} is not a Pharo external project' format: { favorite name }) ].
	^ self externalRepository ifNil: [ FRError signal: ('{1} has no clone: clone it first' format: { favorite name }) ]
]

{ #category : 'checking' }
FRPharoIntegration >> checkedPharoRepository [

	| pharo |
	pharo := self pharoRepository.
	pharo ifNil: [ FRError signal: 'Clone your Pharo fork first' ].
	(self class isUpstreamPharo: pharo origin url) ifTrue: [
		FRError signal: 'Your Pharo clone must come from your fork, not from pharo-project/pharo' ].
	^ pharo
]

{ #category : 'creating' }
FRPharoIntegration >> commitBaselineOfPharoIn: aPharoRepository message: aString [
	"Commit the change to BaselineOfPharo alone, whatever else the image changed in the Pharo repository."

	aPharoRepository workingCopy commitChanges: (self baselineOfPharoDiffIn: aPharoRepository) withMessage: aString force: false
]

{ #category : 'creating' }
FRPharoIntegration >> commitMessageForOwner: anOwner branch: aBranchName [

	^ 'Load {1} from {2}/{3}:{4} to validate it in the full build' format: {
			  (self externalProjectDeclaredBy: self externalProjectMethod) name.
			  anOwner.
			  (self externalProjectDeclaredBy: self externalProjectMethod) project.
			  aBranchName }
]

{ #category : 'creating' }
FRPharoIntegration >> compile: aSource like: aMethod [
	"Install aSource in the class and protocol of aMethod: the image follows the branch the Pharo clone is on."

	aMethod methodClass compile: aSource classified: aMethod protocolName
]

{ #category : 'checking' }
FRPharoIntegration >> confirmBottomOf: anIceRepository [
	"Whether anIceRepository is on a bottom branch, or the user accepts to build on its current branch."

	| current |
	current := anIceRepository branch name.
	(self class isBottomBranchName: current) ifTrue: [ ^ true ].
	^ confirmer value: ('{1} is on {2}, not a Bottom branch. Create the integration branch on top of it anyway?' format: {
				   anIceRepository name.
				   current })
]

{ #category : 'accessing' }
FRPharoIntegration >> confirmer: aBlock [
	"aBlock receives a question about working on a branch that is not a bottom branch, and answers whether to go on."

	confirmer := aBlock
]

{ #category : 'creating' }
FRPharoIntegration >> create: aName in: anExternalRepository and: aPharoRepository [

	| method owner base original |
	method := self externalProjectMethod.
	original := method sourceCode.
	owner := (IceGitRemote url: anExternalRepository origin url) organizer.
	base := aPharoRepository branch.
	anExternalRepository createBranch: aName.
	aPharoRepository createBranch: aName.
	self compile: (self class rewrite: original owner: owner version: aName) like: method.
	self commitBaselineOfPharoIn: aPharoRepository message: (self commitMessageForOwner: owner branch: aName).
	[ aPharoRepository branch pushTo: aPharoRepository origin ]
		on: Error
		do: [ :error | ^ self pushFailureReportFor: aName error: error ].
	base switch.
	self compile: original like: method.
	self announceChangeOf: {
			anExternalRepository.
			aPharoRepository }.
	^ self reportForBranch: aName base: base name
]

{ #category : 'creating' }
FRPharoIntegration >> createBranch: aName [
	"Create aName in my favorite's clone, and in the Pharo clone a commit loading my favorite's aName from its fork, pushed to the Pharo fork; then put Pharo back on its base branch. Answer the report, or nil when the user cancelled."

	| external pharo |
	external := self checkedExternalRepository.
	pharo := self checkedPharoRepository.
	self check: aName canBeCreatedIn: external and: pharo.
	((self confirmBottomOf: external) and: [ self confirmBottomOf: pharo ]) ifFalse: [ ^ nil ].
	^ self create: aName in: external and: pharo
]

{ #category : 'external projects' }
FRPharoIntegration >> externalProjectDeclaredBy: aMethod [
	"The PharoExternalProject that aMethod answers."

	^ aMethod valueWithReceiver: aMethod methodClass instanceSide arguments: #(  )
]

{ #category : 'external projects' }
FRPharoIntegration >> externalProjectMethod [
	"The method of BaselineOfPharo declaring the project my favorite is a fork of (same project name, ignoring case), or nil."

	| projectName |
	(FRFavorite isValidUrl: favorite url) ifFalse: [ ^ nil ].
	projectName := (IceGitRemote url: favorite url) projectName.
	^ self class externalProjectMethods
		  detect: [ :each | (self externalProjectDeclaredBy: each) project sameAs: projectName ]
		  ifNone: [ nil ]
]

{ #category : 'accessing' }
FRPharoIntegration >> externalRepository [
	"The Iceberg repository of my favorite's clone, or nil when it has none."

	| info |
	info := catalog infoFor: favorite.
	(info isNil or: [ info isCloned not ]) ifTrue: [ ^ nil ].
	^ info iceRepository
]

{ #category : 'accessing' }
FRPharoIntegration >> favorite [

	^ favorite
]

{ #category : 'pull request' }
FRPharoIntegration >> hasPharoIntegrationBranch [
	"Whether the Pharo clone has a branch named like the branch my favorite's clone is on."

	| pharo name |
	self isExternalProject ifFalse: [ ^ false ].
	name := self integrationBranchName ifNil: [ ^ false ].
	pharo := self pharoRepository ifNil: [ ^ false ].
	^ pharo hasLocalBranchNamed: name
]

{ #category : 'pull request' }
FRPharoIntegration >> integrationBranchName [
	"The branch my favorite's clone is on: the name the Pharo integration branch shares with it."

	^ self externalRepository ifNotNil: [ :repository | repository branch name ]
]

{ #category : 'pull request' }
FRPharoIntegration >> integrationPharoBranch [
	"The Pharo branch to open the integration pull request from."

	^ self checkedPharoRepository branchNamed: self integrationBranchName
]

{ #category : 'testing' }
FRPharoIntegration >> isExternalProject [

	^ self externalProjectMethod isNotNil
]

{ #category : 'pull request' }
FRPharoIntegration >> isIntegrationBranchPushed [
	"Whether the branch of my favorite's clone is on its fork with all its commits: the Pharo build loads it from there."

	| repository name |
	repository := self checkedExternalRepository.
	name := self integrationBranchName.
	repository fetchFrom: repository origin.
	^ repository origin
		  remoteBranchNamed: name
		  ifPresent: [ :remoteBranch | remoteBranch commit = repository branch commit ]
		  ifAbsent: [ false ]
]

{ #category : 'accessing' }
FRPharoIntegration >> pharoRepository [
	"The Iceberg repository of the Pharo clone, the one the integration branch is created in, or nil."

	^ pharoRepository ifNil: [ FRPharoClone registered ifNotNil: [ :clone | pharoRepository := clone iceRepository ] ]
]

{ #category : 'accessing' }
FRPharoIntegration >> pharoRepository: anIceRepository [

	pharoRepository := anIceRepository
]

{ #category : 'reporting' }
FRPharoIntegration >> pushFailureReportFor: aName error: anError [

	^ 'Push of {1} to your Pharo fork failed ({2}): push it from Iceberg, then switch Pharo back to its Bottom branch.

{3}: branch {1} is created and checked out.' format: {
			  aName.
			  anError messageText.
			  favorite name }
]

{ #category : 'reporting' }
FRPharoIntegration >> reportForBranch: aName base: aBaseName [

	^ '{1}: branch {2} created and checked out; commit and push your work there.

Pharo: branch {2} loads it from your fork; it is pushed to your Pharo fork, and Pharo is back on {3}.

Push {2} of {1} before opening the Pharo integration PR, or the build cannot load it.' format: {
			  favorite name.
			  aName.
			  aBaseName }
]

{ #category : 'initialization' }
FRPharoIntegration >> setFavorite: aFavorite catalog: aCatalog [

	favorite := aFavorite.
	catalog := aCatalog.
	confirmer := [ :question | false ]
]
