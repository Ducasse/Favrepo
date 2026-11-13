"
I test how FRCatalog matches favorites with the repositories of an image.
"
Class {
	#name : 'FRCatalogTest',
	#superclass : 'TestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRCatalogTest >> catalog [

	^ FRCatalog withAll: {
			  ((FRRepositoryInfo name: 'Roassal' url: nil)
				   beLoaded;
				   yourself).
			  ((FRRepositoryInfo name: 'Favrepo' url: 'git@github.com:Ducasse/Favrepo.git')
				   beCloned;
				   yourself).
			  (FRRepositoryInfo name: 'tonel' url: nil).
			  ((FRRepositoryInfo name: 'tonel' url: nil)
				   beLoaded;
				   yourself) }
]

{ #category : 'helpers' }
FRCatalogTest >> catalogOnClonesIn: aFileSystem [

	^ (FRCatalog withAll: #(  ))
		  clonesLocation: aFileSystem root / 'iceberg';
		  yourself
]

{ #category : 'helpers' }
FRCatalogTest >> favoriteNamed: aString [

	^ FRFavorite url: ('git@github.com:someone/{1}.git' format: { aString })
]

{ #category : 'tests' }
FRCatalogTest >> testAvailableForExcludesFavorites [

	| names |
	names := (self catalog availableFor: { (self favoriteNamed: 'Roassal') }) collect: [ :each | each name ].
	self assert: names asSet equals: #( 'Favrepo' 'tonel' ) asSet
]

{ #category : 'tests' }
FRCatalogTest >> testCatalogWithoutClonesLocationDoesNotLookOnDisk [

	self assert: (FRCatalog withAll: #(  )) clonesLocation isNil
]

{ #category : 'tests' }
FRCatalogTest >> testCloneLeftOnDiskIsCloned [

	| fileSystem gitFolder |
	fileSystem := FileSystem memory.
	gitFolder := fileSystem root / 'iceberg' / 'noha' / 'mustache' / '.git'.
	gitFolder ensureCreateDirectory.
	(gitFolder / 'config') writeStreamDo: [ :stream | stream nextPutAll: '[core]' ].
	self
		assert: ((self catalogOnClonesIn: fileSystem) stateOf: (FRFavorite url: 'git@github.com:noha/mustache.git'))
		equals: #cloned
]

{ #category : 'tests' }
FRCatalogTest >> testClonedRepositoryWithNothingLoadedGivesClonedState [

	self assert: (self catalog stateOf: (self favoriteNamed: 'Favrepo')) equals: #cloned
]

{ #category : 'tests' }
FRCatalogTest >> testInfoNamedAnswersNilWhenAbsent [

	self assert: (self catalog infoNamed: 'Seaside') isNil
]

{ #category : 'tests' }
FRCatalogTest >> testInfoNamedAnswersTheLoadedOne [

	self assert: (self catalog infoNamed: 'tonel') isLoaded
]

{ #category : 'tests' }
FRCatalogTest >> testIsLoaded [

	self assert: (self catalog isLoaded: (self favoriteNamed: 'Roassal')).
	self deny: (self catalog isLoaded: (self favoriteNamed: 'Favrepo'))
]

{ #category : 'tests' }
FRCatalogTest >> testLoadedRepositoryGivesLoadedState [

	self assert: (self catalog stateOf: (self favoriteNamed: 'Roassal')) equals: #loaded
]

{ #category : 'tests' }
FRCatalogTest >> testMatchingIgnoresCase [

	self assert: (self catalog stateOf: (self favoriteNamed: 'roassal')) equals: #loaded
]

{ #category : 'tests' }
FRCatalogTest >> testNoCloneOnDiskIsNotCloned [

	self
		assert: ((self catalogOnClonesIn: FileSystem memory) stateOf: (FRFavorite url: 'git@github.com:noha/mustache.git'))
		equals: #notCloned
]

{ #category : 'tests' }
FRCatalogTest >> testSameNameTwiceIsLoadedWhenOneIsLoaded [

	self assert: (self catalog stateOf: (self favoriteNamed: 'tonel')) equals: #loaded
]

{ #category : 'tests' }
FRCatalogTest >> testUnknownRepositoryGivesNotClonedState [

	self assert: (self catalog stateOf: (self favoriteNamed: 'Seaside')) equals: #notCloned
]

{ #category : 'tests' }
FRCatalogTest >> testVersionsAreLocalThenRemoteBranchesThenTags [

	self
		assert: (FRRepositoryInfo
				 versionNamesFromLocal: #( 'master' )
				 remote: #( 'HEAD' 'master' 'dev' )
				 tags: #( 'v1.0' ))
		equals: #( 'master' 'dev' 'v1.0' )
]
