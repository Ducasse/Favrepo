"
I find the project a GitHub fork comes from, its upstream. A fork often lags behind the project, so the commit an image was built from may be only there. `FRCloneAttacher` asks me for `upstreamRemoteFor:`.

## Examples

```
FRUpstreamFinder instanceSpec
```

## Design Rationale

- I ask GitHub for the parent of the fork and name its remote after its owner, as Iceberg does in its Clone from github.com dialog (`IceTipGitHubRepositoryPanel>>newRepository`). That code cannot be reused because it belongs to the dialog.
- When GitHub does not answer (no network, private repository, rate limit), I fall back on the projects the image was built or loaded from: those of `BaselineOfPharo`, those `Metacello` loaded, and Pharo itself.
- When GitHub says that a repository is no fork, I do not guess from its name.

## Usage

1. `FRCloneAttacher>>upstreamFinder` creates me.
2. `FRCloneAttacher>>addUpstreamTo:` sends me `upstreamRemoteFor:` and adds the remote I answer to the clone, then fetches it.

## Implementation Notes

- `gitHubRepositories` is the block that asks GitHub, so that it can be replaced.
- The fallback matches the project name only: without GitHub, a renamed fork has no upstream for me.
- The answered URL uses the protocol of the fork (ssh or https).
"
Class {
	#name : 'FRUpstreamFinder',
	#superclass : 'Object',
	#instVars : [
		'knownUrls',
		'gitHubRepositories'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'instance creation' }
FRUpstreamFinder class >> gitHubRepositories: aBlock [
	"A finder that asks aBlock, with an owner and a project name, for what GitHub knows about that repository."

	^ self new
		  gitHubRepositories: aBlock;
		  yourself
]

{ #category : 'accessing' }
FRUpstreamFinder class >> imageUrls [
	"The repositories this image was built or loaded from: the projects of BaselineOfPharo (its ...Repository methods, which vary between Pharo versions), the projects Metacello loaded, and Pharo itself."

	| fromPharo fromMetacello |
	fromPharo := Smalltalk globals
		             at: #BaselineOfPharo
		             ifPresent: [ :baseline |
			             (baseline class selectors select: [ :each | each endsWith: 'Repository' ]) sorted collect: [ :each |
				             baseline perform: each ] ]
		             ifAbsent: [ #(  ) ].
	fromMetacello := MetacelloProjectRegistration registry projects flatCollect: [ :each | each repositoryDescriptions ].
	^ (fromPharo , fromMetacello asArray , #( 'https://github.com/pharo-project/pharo.git' )) asArray
]

{ #category : 'instances' }
FRUpstreamFinder class >> instanceSpec [
	"A finder that knows where Spec comes from: for any fork of Spec, its fallback is https://github.com/pharo-spec/Spec.git."

	<sampleInstance>
	^ self knownUrls: #( 'github://pharo-spec/Spec:v2.0.6/src' )
]

{ #category : 'instance creation' }
FRUpstreamFinder class >> knownUrls: someUrls [
	"A finder that looks for upstreams among someUrls, Metacello github:// or git URLs."

	^ self new
		  knownUrls: someUrls;
		  yourself
]

{ #category : 'accessing' }
FRUpstreamFinder >> gitHubRepositories [
	"By default GitHub is asked without credentials, as Iceberg does when it clones a fork."

	^ gitHubRepositories ifNil: [
		  gitHubRepositories := [ :owner :project | IceGitHubAPI new beAnonymous; getRepository: owner project: project ] ]
]

{ #category : 'accessing' }
FRUpstreamFinder >> gitHubRepositories: aBlock [
	"aBlock receives an owner and a project name, and answers the JSON of GitHub for that repository, or nil."

	gitHubRepositories := aBlock
]

{ #category : 'private' }
FRUpstreamFinder >> gitHubRepositoryFor: aUrl [
	"What GitHub knows about the repository of aUrl, or nil when it is not on GitHub or GitHub does not answer."

	| ownerAndProject |
	ownerAndProject := (self ownerAndProjectOf: aUrl) ifNil: [ ^ nil ].
	^ [ self gitHubRepositories value: ownerAndProject first value: ownerAndProject second ]
		  on: Error
		  do: [ nil ]
]

{ #category : 'private' }
FRUpstreamFinder >> isSshUrl: aUrl [
	"Whether aUrl is fetched with ssh (git@github.com:... or ssh://...)."

	^ [ (IceGitRemote url: aUrl) class = IceGitScpRemote ]
		  on: Error
		  do: [ false ]
]

{ #category : 'accessing' }
FRUpstreamFinder >> knownUrls [

	^ knownUrls ifNil: [ knownUrls := self class imageUrls ]
]

{ #category : 'accessing' }
FRUpstreamFinder >> knownUrls: someUrls [

	knownUrls := someUrls
]

{ #category : 'private' }
FRUpstreamFinder >> ownerAndProjectOf: aUrl [
	"The owner and project of a GitHub URL, either Metacello's github://owner/project[:version][/folder] or a git URL; nil for other URLs."

	| path remote |
	(aUrl beginsWith: 'github://') ifTrue: [
			path := aUrl allButFirst: 'github://' size.
			^ {
				  (path copyUpTo: $/).
				  (((path copyAfter: $/) copyUpTo: $/) copyUpTo: $:) } ].
	remote := [ IceGitRemote url: aUrl ]
		          on: Error
		          do: [ ^ nil ].
	remote host = 'github.com' ifFalse: [ ^ nil ].
	^ {
		  remote organizer.
		  remote projectName }
]

{ #category : 'private' }
FRUpstreamFinder >> parentRemoteIn: aGitHubRepository like: aForkUrl [
	"The remote of the parent of aGitHubRepository, with the protocol of aForkUrl, or nil when it is no fork."

	| parent |
	(aGitHubRepository at: 'fork' ifAbsent: [ false ]) ifFalse: [ ^ nil ].
	parent := aGitHubRepository at: 'parent'.
	^ IceGitRemote
		  name: ((parent at: 'owner') at: 'login')
		  url: (parent at: ((self isSshUrl: aForkUrl)
					    ifTrue: [ 'ssh_url' ]
					    ifFalse: [ 'clone_url' ]))
]

{ #category : 'finding' }
FRUpstreamFinder >> upstreamRemoteFor: aForkUrl [
	"The remote of the project aForkUrl was forked from, named after its owner as Iceberg does, or nil when there is none. GitHub tells; when it does not answer (no network, private repository, rate limit), the projects the image knows do."

	| repository url |
	repository := self gitHubRepositoryFor: aForkUrl.
	repository ifNotNil: [ ^ self parentRemoteIn: repository like: aForkUrl ].
	url := self upstreamUrlFor: aForkUrl.
	url ifNil: [ ^ nil ].
	^ IceGitRemote name: (IceGitRemote url: url) organizer url: url
]

{ #category : 'finding' }
FRUpstreamFinder >> upstreamUrlFor: aForkUrl [
	"The URL of the GitHub project aForkUrl was forked from: a known project with the same name and another owner, with the protocol of aForkUrl (ssh for an ssh fork, https otherwise). Nil when there is none."

	| fork |
	fork := (self ownerAndProjectOf: aForkUrl) ifNil: [ ^ nil ].
	self knownUrls do: [ :each |
		(self ownerAndProjectOf: each) ifNotNil: [ :known |
			((known second sameAs: fork second) and: [ (known first sameAs: fork first) not ]) ifTrue: [
				^ (self urlFormatLike: aForkUrl) format: known ] ] ].
	^ nil
]

{ #category : 'private' }
FRUpstreamFinder >> urlFormatLike: aForkUrl [
	"The format of a GitHub URL {1}/{2} (owner and project) that uses the protocol of aForkUrl."

	^ (self isSshUrl: aForkUrl)
		  ifTrue: [ 'git@github.com:{1}/{2}.git' ]
		  ifFalse: [ 'https://github.com/{1}/{2}.git' ]
]
