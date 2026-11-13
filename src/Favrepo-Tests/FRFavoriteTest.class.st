"
I test FRFavorite: names from URLs, identity, and the dictionary form of the favorites file.
"
Class {
	#name : 'FRFavoriteTest',
	#superclass : 'TestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'tests' }
FRFavoriteTest >> testBranchIsDefaultUnlessGiven [

	self assert: (FRFavorite url: 'git@github.com:noha/mustache.git') branch equals: 'default'
]

{ #category : 'tests' }
FRFavoriteTest >> testDictionaryRoundTrip [

	| favorite copy |
	favorite := FRFavorite url: 'git@github.com:noha/mustache.git' name: 'Mustache' branch: 'v1.3'.
	copy := FRFavorite fromDictionary: favorite asDictionary.
	self assert: copy url equals: favorite url.
	self assert: copy name equals: 'Mustache'.
	self assert: copy branch equals: 'v1.3'
]

{ #category : 'tests' }
FRFavoriteTest >> testDifferentNamesAreDifferentFavorites [

	self deny: ((FRFavorite url: 'git@github.com:noha/mustache.git') isSameAs: (FRFavorite url: 'git@github.com:noha/Seaside.git'))
]

{ #category : 'tests' }
FRFavoriteTest >> testHttpsUrlGivesTheSameName [

	self assert: (FRFavorite url: 'https://github.com/pillar-markup/Microdown') name equals: 'Microdown'
]

{ #category : 'tests' }
FRFavoriteTest >> testInitialIsTheUppercaseFirstLetterOfTheName [

	self assert: (FRFavorite url: 'git@github.com:noha/mustache.git') initial equals: 'M'
]

{ #category : 'tests - errors' }
FRFavoriteTest >> testInvalidUrlRaisesError [

	self should: [ FRFavorite url: 'not a url' ] raise: FRError
]

{ #category : 'tests' }
FRFavoriteTest >> testIsDefaultBranch [

	self assert: (FRFavorite url: 'git@github.com:noha/mustache.git') isDefaultBranch.
	self deny: (FRFavorite url: 'git@github.com:noha/mustache.git' name: 'mustache' branch: 'v1.3') isDefaultBranch
]

{ #category : 'tests' }
FRFavoriteTest >> testIsValidUrl [

	self assert: (FRFavorite isValidUrl: 'git@github.com:noha/mustache.git').
	self deny: (FRFavorite isValidUrl: 'not a url').
	self deny: (FRFavorite isValidUrl: '')
]

{ #category : 'tests' }
FRFavoriteTest >> testNameIsTakenFromTheUrl [

	self assert: (FRFavorite url: 'git@github.com:pillar-markup/Microdown.git') name equals: 'Microdown'
]

{ #category : 'tests' }
FRFavoriteTest >> testProjectPathIsOwnerSlashProject [

	self assert: (FRFavorite url: 'git@github.com:pharo-graphics/Roassal.git') projectPath equals: 'pharo-graphics/Roassal'
]

{ #category : 'tests' }
FRFavoriteTest >> testSameNameIgnoringCaseIsTheSameFavorite [

	self assert:
		((FRFavorite url: 'git@github.com:noha/mustache.git') isSameAs: (FRFavorite url: 'https://github.com/someone/Mustache.git'))
]
