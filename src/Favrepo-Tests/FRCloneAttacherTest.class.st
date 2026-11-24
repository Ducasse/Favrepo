"
I test that `FRCloneAttacher` finds the repository of the image a clone belongs to, and that attaching a fork brings the commit of the image from its parent. GitHub is never contacted: the parent is a repository on disk.
"
Class {
	#name : 'FRCloneAttacherTest',
	#superclass : 'FRGitRepositoryTestCase',
	#instVars : [
		'upstreamRepository'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRCloneAttacherTest >> attacher [

	^ FRCloneAttacher new
]

{ #category : 'helpers' }
FRCloneAttacherTest >> attacherWithParentAt: aUrl [
	"An attacher that GitHub (not asked) tells that the fork comes from aUrl, owned by pharo-project."

	^ self attacher
		  upstreamFinder: (FRUpstreamFinder gitHubRepositories: [ :owner :project |
				   Dictionary new
					   at: 'fork' put: true;
					   at: 'parent' put: (Dictionary new
							    at: 'owner' put: (Dictionary with: 'login' -> 'pharo-project');
							    at: 'ssh_url' put: aUrl;
							    at: 'clone_url' put: aUrl;
							    yourself);
					   yourself ]);
		  yourself
]

{ #category : 'helpers' }
FRCloneAttacherTest >> attacherWithParentAtUpstream [

	^ self attacherWithParentAt: self upstreamRepository location fullName
]

{ #category : 'helpers' }
FRCloneAttacherTest >> forkRepository [
	"A git repository whose origin is a GitHub fork (never contacted)."

	^ (self gitRepositoryWithBranch: 'dev')
		  addRemote: (IceGitRemote name: 'origin' url: 'git@github.com:Ducasse/Pharo.git');
		  yourself
]

{ #category : 'running' }
FRCloneAttacherTest >> tearDown [

	self deleteGitRepository: upstreamRepository.
	super tearDown
]

{ #category : 'tests - attaching' }
FRCloneAttacherTest >> testAttachFetchesTheImageCommitFromTheParentOfTheFork [
	"The fork is behind: the commit of the image is only in the project it was forked from."

	| fork commit pharo |
	fork := self forkRepository.
	commit := self upstreamRepository headCommit.
	pharo := self repositoryNamed: 'pharo' atCommit: commit id.
	self assert: (fork lookupCommit: commit id) isUnknownCommit.
	self attacherWithParentAtUpstream attach: fork to: pharo.
	self assert: pharo head name equals: 'image-' , commit shortId.
	self assert: pharo workingCopy referenceCommit id equals: commit id.
	self deny: pharo workingCopy referenceCommit isUnknownCommit
]

{ #category : 'tests - attaching' }
FRCloneAttacherTest >> testAttachKeepsTheImageCommitWhenItIsNowhere [
	"Adopting the commit of the clone would turn everything between the two commits into changes of the user."

	| fork pharo missing |
	fork := self forkRepository.
	missing := '0123456789abcdef0123456789abcdef01234567'.
	pharo := self repositoryNamed: 'pharo' atCommit: missing.
	self attacherWithParentAtUpstream attach: fork to: pharo.
	self assert: pharo workingCopy referenceCommit id equals: missing.
	self assert: pharo workingCopy referenceCommit isUnknownCommit
]

{ #category : 'tests - attaching' }
FRCloneAttacherTest >> testAttachNamesTheParentRemoteAfterItsOwnerLikeIceberg [

	| fork pharo |
	fork := self forkRepository.
	pharo := self repositoryNamed: 'pharo' atCommit: self upstreamRepository headCommit id.
	self attacherWithParentAtUpstream attach: fork to: pharo.
	self assert: (pharo remotes collect: [ :each | each name ] as: Set) equals: #( 'origin' 'pharo-project' ) asSet
]

{ #category : 'tests - attaching' }
FRCloneAttacherTest >> testAttachTellsWhyTheParentCouldNotBeFetched [

	| fork pharo told |
	fork := self forkRepository.
	pharo := self repositoryNamed: 'pharo' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	told := OrderedCollection new.
	(self attacherWithParentAt: (FileLocator temp / 'favrepo-no-such-repository') fullName)
		informer: [ :text | told add: text ];
		attach: fork to: pharo.
	self assert: (told anySatisfy: [ :each |
			 (each includesSubstring: 'could not be fetched') and: [ each includesSubstring: 'favrepo-no-such-repository' ] ])
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testCloneAttachesToNothingWhenItHoldsNoLoadedPackage [
	"Sharing only packages that are not in the image does not count."

	| clone unloaded |
	clone := self repositoryNamed: 'new-project' packages: #( 'NotLoaded-FRFixture' 'Favrepo' ).
	unloaded := self repositoryNamed: 'Unloaded' packages: #( 'NotLoaded-FRFixture' ).
	self assert: (self attacher repositoryLoadedFrom: clone among: { unloaded }) isNil
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testCloneAttachesToNothingWhenItLacksTheCommitOfARepositoryWithoutPackages [
	"A repository listing no package is taken over only by a clone that has its commit."

	| clone pharo |
	clone := self gitRepositoryWithBranch: 'dev'.
	pharo := self repositoryNamed: 'pharo' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	self assert: (self attacher repositoryLoadedFrom: clone among: { pharo }) isNil
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testCloneAttachesToTheRepositoryItCoversBest [
	"The image's pharo repository lists the Spec2 packages too; a Spec fork must take over Spec2, whose loaded packages it holds all, not pharo."

	| clone spec pharo |
	clone := self repositoryNamed: 'spec' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	spec := self repositoryNamed: 'Spec2' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	pharo := self repositoryNamed: 'pharo' packages: #( 'Favrepo' 'Favrepo-Spec' 'Favrepo-Tests' 'Kernel' ).
	self
		assert: (self attacher repositoryLoadedFrom: clone among: {
				 pharo.
				 spec })
		identicalTo: spec
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testCloneAttachesToTheRepositoryWhoseLoadedPackagesItHolds [
	"The fork of a project that came with the image takes over its loaded packages."

	| clone loaded other |
	clone := self repositoryNamed: 'favrepo-fork' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	loaded := self repositoryNamed: 'Favrepo' packages: #( 'Favrepo' 'Favrepo-Spec' ).
	other := self repositoryNamed: 'Other' packages: #( 'Favrepo-Tests' ).
	self
		assert: (self attacher repositoryLoadedFrom: clone among: {
				 other.
				 loaded })
		identicalTo: loaded
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testCloneAttachesToTheRepositoryWithoutPackagesWhoseCommitItHas [

	| clone pharo other |
	clone := self gitRepositoryWithBranch: 'dev'.
	other := self repositoryNamed: 'other' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	pharo := self repositoryNamed: 'pharo' atCommit: clone headCommit id.
	self
		assert: (self attacher repositoryLoadedFrom: clone among: {
				 other.
				 pharo })
		identicalTo: pharo
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testCloneWithoutBaselineOfPharoDoesNotAttachToTheRepositoryOfTheImage [

	| clone pharo |
	clone := self gitRepositoryWithBranch: 'dev'.
	pharo := self repositoryNamed: 'pharo' atCommit: SystemVersion current commitHash.
	self assert: (self attacher repositoryLoadedFrom: clone among: { pharo }) isNil
]

{ #category : 'tests - matching' }
FRCloneAttacherTest >> testPharoForkBehindTheImageAttachesToTheRepositoryOfTheImage [
	"A fork that does not have the commit the image was built from is still a clone of Pharo: it must not be registered apart."

	| clone pharo other |
	clone := self repositoryNamed: 'Pharo' packages: #( 'BaselineOfPharo' ).
	other := self repositoryNamed: 'other' atCommit: '0123456789abcdef0123456789abcdef01234567'.
	pharo := self repositoryNamed: 'pharo' atCommit: SystemVersion current commitHash.
	self
		assert: (self attacher repositoryLoadedFrom: clone among: {
				 other.
				 pharo })
		identicalTo: pharo
]

{ #category : 'tests - attaching' }
FRCloneAttacherTest >> testReportNamesTheImageBranchAndTheUpstream [

	| report |
	report := self attacher
		          reportFor: (self repositoryNamed: 'Spec2' packages: #(  ))
		          branch: 'image-ebc98f0'
		          upstream: 'https://github.com/pharo-spec/Spec.git'.
	self assert: (report includesSubstring: 'Spec2').
	self assert: (report includesSubstring: 'image-ebc98f0').
	self assert: (report includesSubstring: 'https://github.com/pharo-spec/Spec.git')
]

{ #category : 'tests - attaching' }
FRCloneAttacherTest >> testReportWithoutImageCommitSaysItWasNotFound [

	| report |
	report := self attacher reportFor: (self repositoryNamed: 'Spec2' packages: #(  )) branch: nil upstream: nil.
	self assert: (report includesSubstring: 'not found').
	self assert: (report includesSubstring: 'No upstream')
]

{ #category : 'helpers' }
FRCloneAttacherTest >> upstreamRepository [
	"The project a fork comes from, holding a commit the fork does not have; deleted by tearDown."

	^ upstreamRepository ifNil: [ upstreamRepository := self newGitRepositoryNamed: 'FRUpstreamFixture' ]
]
