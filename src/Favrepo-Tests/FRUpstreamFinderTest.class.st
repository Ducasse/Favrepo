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

{ #category : 'tests' }
FRUpstreamFinderTest >> testImageKnowsTheUpstreamOfSpec [
	"The default finder reads what the image was built from."

	self
		assert: (FRUpstreamFinder new upstreamUrlFor: 'git@github.com:someone/spec.git')
		equals: 'https://github.com/pharo-spec/Spec.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testRepositoryOfTheSameOwnerIsNotItsOwnUpstream [
	"Favrepo was loaded from the user's own repository: it is no fork, so there is no upstream."

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/Favrepo.git') isNil
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUnknownProjectHasNoUpstream [

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/Cozy.git') isNil
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamMatchesHttpsKnownUrls [

	self
		assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/pharo.git')
		equals: 'https://github.com/pharo-project/pharo.git'
]

{ #category : 'tests' }
FRUpstreamFinderTest >> testUpstreamOfAForkIsTheKnownProjectWithTheSameName [

	self assert: (self finder upstreamUrlFor: 'git@github.com:Ducasse/spec.git') equals: 'https://github.com/pharo-spec/Spec.git'
]
