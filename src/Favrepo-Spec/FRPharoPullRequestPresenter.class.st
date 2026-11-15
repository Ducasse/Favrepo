"
I am Iceberg's GitHub pull request dialog proposing the Pharo integration branch rather than the branch the Pharo clone is on: after creating it, `FRPharoIntegration` puts the Pharo clone back on its bottom branch.

## Responsibility:

- I propose the integration branch as head, and its commit message as title.
- Everything else (base fork, base branch, sending) is Iceberg's.

## Collaborators:

- `FRApplication >> #openPullRequestFor:` opens me and sends the pull request I answer.
- `IceGitHubCreatePullRequestPresenter` is my superclass.

## Public API and Key Messages

- `FRPharoPullRequestPresenter newApplication: anApplication repository: aPharoRepository branch: anIntegrationBranch`

```
(FRPharoPullRequestPresenter newApplication: FRApplication new repository: pharoRepository branch: (pharoRepository branchNamed: 'fix-x')) openModal
```
"
Class {
	#name : 'FRPharoPullRequestPresenter',
	#superclass : 'IceGitHubCreatePullRequestPresenter',
	#instVars : [
		'integrationBranch'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'instance creation' }
FRPharoPullRequestPresenter class >> newApplication: anApplication repository: aPharoRepository branch: anIntegrationBranch [
	"A pull request from anIntegrationBranch of the Pharo fork (origin). The branch is set before the presenters are filled: they propose it, not the branch the Pharo clone is on."

	^ self basicNew
		  application: anApplication;
		  setIntegrationBranch: anIntegrationBranch;
		  initializeRepository: aPharoRepository credentials: IceGitHubAPI ensureCredentials headRemote: aPharoRepository origin;
		  yourself
]

{ #category : 'accessing' }
FRPharoPullRequestPresenter >> branch [
	"The integration branch, pushed to the Pharo fork, while the Pharo clone is back on its bottom branch."

	^ integrationBranch
]

{ #category : 'initialization' }
FRPharoPullRequestPresenter >> setIntegrationBranch: anIceBranch [

	integrationBranch := anIceBranch
]
