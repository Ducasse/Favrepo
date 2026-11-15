"
I find the project a fork comes from, its upstream, among the repositories the image knows, without any network access.

## Responsibility:

- I know the GitHub repositories this image was built or loaded from: the projects of `BaselineOfPharo` (Spec, NewTools, Roassal…), the projects `Metacello` loaded, and Pharo itself.
- I answer the upstream of a fork: the known project with the same name and another owner, as an https URL (fetching needs no credentials).
- I read both Metacello URLs (`github://owner/project:version/src`) and git URLs.

## Collaborators:

- `FRFavoriteLoader` asks me for the upstream when it attaches a fork to the code of the image, and adds it as the `upstream` remote.
- `IceGitRemote` parses git URLs; `MetacelloProjectRegistration` and `BaselineOfPharo` tell what the image was loaded from.

## Public API and Key Messages

- `FRUpstreamFinder new` looks among the repositories of the image; `FRUpstreamFinder knownUrls: someUrls` among the given ones.
- `upstreamUrlFor: aForkUrl` answers the upstream URL or nil.

```
FRUpstreamFinder new upstreamUrlFor: 'git@github.com:Ducasse/spec.git'
	""'https://github.com/pharo-spec/Spec.git'""
```

See `FRUpstreamFinder class >> #exampleSpec`.

## Internal Representation

- `knownUrls`: the candidate URLs, read from the image the first time they are needed.

### Implementation Points

The match is on the project name only: a fork renamed on GitHub has no upstream for me.
"
Class {
	#name : 'FRUpstreamFinder',
	#superclass : 'Object',
	#instVars : [
		'knownUrls'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'examples' }
FRUpstreamFinder class >> exampleSpec [
	"A finder that knows where Spec comes from: it answers https://github.com/pharo-spec/Spec.git for any fork of Spec."

	<sampleInstance>
	^ self knownUrls: #( 'github://pharo-spec/Spec:v2.0.6/src' )
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

{ #category : 'instance creation' }
FRUpstreamFinder class >> knownUrls: someUrls [
	"A finder that looks for upstreams among someUrls, Metacello github:// or git URLs."

	^ self new
		  knownUrls: someUrls;
		  yourself
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

{ #category : 'finding' }
FRUpstreamFinder >> upstreamUrlFor: aForkUrl [
	"The https URL of the GitHub project aForkUrl was forked from: a known project with the same name and another owner. Nil when there is none."

	| fork |
	fork := (self ownerAndProjectOf: aForkUrl) ifNil: [ ^ nil ].
	self knownUrls do: [ :each |
			(self ownerAndProjectOf: each) ifNotNil: [ :known |
					((known second sameAs: fork second) and: [ (known first sameAs: fork first) not ]) ifTrue: [
						^ 'https://github.com/{1}/{2}.git' format: known ] ] ].
	^ nil
]
