"
I test that `FRUpstreamFinder` finds the upstream of a fork among known URLs, and that the image knows where Spec comes from.

```
FRUpstreamFinderTest suite run
```
"
Class {
	#name : 'FRUpstreamFinderTest',
	#superclass : 'TestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'tests' }
FRUpstreamFinderTest >> finder [

	^ FRUpstreamFinder knownUrls:
		  #( 'github://pharo-spec/Spec:v2.0.6/src' 'github://pharo-spec/NewTools:v0.11.0/src' 'github://Ducasse/Favrepo/src'
		     'https://github.com/pharo-project/pharo.git' )
]

{ #category : 'helpers' }
FRUpstreamFinderTest >> gitHubFork [
	"What GitHub answers for a fork of Pharo."

	^ Dictionary new
		  at: 'fork' put: true;
		  at: 'parent' put: (Dictionary new
				   at: 'owner' put: (Dictionary with: 'login' -> 'pharo-project');
				   at: 'ssh_url' put: 'git@github.com:pharo-project/pharo.git';
				   at: 'clone_url' put: 'https://github.com/pharo-project/pharo.git';
				   yourself);
		  yourself
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testImageKnowsTheUpstreamOfSpec [
	"The default finder reads what the image was built from."

	self
		assert: (FRUpstreamFinder new upstreamUrlFor: 'git@github.com:someone/spec.git')
		equals: 'git@github.com:pharo-spec/Spec.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testRemoteOfAForkIsItsGitHubParentNamedAfterItsOwner [
	"Like Iceberg's Clone from github.com dialog."

	| remote |
	remote := (FRUpstreamFinder gitHubRepositories: [ :owner :project | self gitHubFork ]) upstreamRemoteFor: 'git@github.com:Ducasse/my-pharo.git'.
	self assert: remote name equals: 'pharo-project'.
	self assert: remote url equals: 'git@github.com:pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testRemoteOfAnHttpsForkUsesHttps [

	| remote |
	remote := (FRUpstreamFinder gitHubRepositories: [ :owner :project | self gitHubFork ]) upstreamRemoteFor: 'https://github.com/Ducasse/my-pharo.git'.
	self assert: remote url equals: 'https://github.com/pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testRepositoryOfTheSameOwnerIsNotItsOwnUpstream [
	"Favrepo was loaded from the user's own repository: it is no fork, so there is no upstream."

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/Favrepo.git') isNil
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testRepositoryThatIsNoForkOnGitHubHasNoUpstreamRemote [
	"GitHub knows better than the names of the projects of the image."

	| finder |
	finder := FRUpstreamFinder gitHubRepositories: [ :owner :project | Dictionary with: 'fork' -> false ].
	finder knownUrls: #( 'https://github.com/pharo-project/pharo.git' ).
	self assert: (finder upstreamRemoteFor: 'git@github.com:Ducasse/pharo.git') isNil
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUnknownProjectHasNoUpstream [

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/Cozy.git') isNil
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamMatchesHttpsKnownUrls [

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/pharo.git') equals: 'git@github.com:pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamOfAForkIsTheKnownProjectWithTheSameName [

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/spec.git') equals: 'git@github.com:pharo-spec/Spec.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamOfAnHttpsForkUsesHttps [
	"A fork cloned with https gets its upstream with https too."

	self
		assert: (self finder upstreamUrlFor: 'https://github.com/Ducasse/pharo.git')
		equals: 'https://github.com/pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamOfAnSshUrlForkUsesSsh [
	"A fork cloned with an ssh:// URL gets its upstream with ssh too."

	self
		assert: (self finder upstreamUrlFor: 'ssh://git@github.com/Ducasse/pharo.git')
		equals: 'git@github.com:pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamRemoteFallsBackOnTheKnownUrlsWhenGitHubDoesNotAnswer [

	| finder remote |
	finder := FRUpstreamFinder gitHubRepositories: [ :owner :project | nil ].
	finder knownUrls: #( 'https://github.com/pharo-project/pharo.git' ).
	remote := finder upstreamRemoteFor: 'git@github.com:Ducasse/pharo.git'.
	self assert: remote name equals: 'pharo-project'.
	self assert: remote url equals: 'git@github.com:pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamRemoteFallsBackOnTheKnownUrlsWhenGitHubFails [
	"No network, rate limit…"

	| finder |
	finder := FRUpstreamFinder gitHubRepositories: [ :owner :project | Error signal: 'no network' ].
	finder knownUrls: #( 'https://github.com/pharo-project/pharo.git' ).
	self assert: (finder upstreamRemoteFor: 'git@github.com:Ducasse/pharo.git') name equals: 'pharo-project'
]
