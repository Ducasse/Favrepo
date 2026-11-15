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
FRCatalogTest >> testFavoriteIsFoundByTheCloneItWasAttachedTo [
	"A fork attached to the image's Spec2 keeps the name Spec2 in Iceberg; the favorite spec finds it by its clone folder."

	| clones spec catalog |
	clones := FileSystem memory root / 'iceberg'.
	spec := (FRRepositoryInfo name: 'Spec2' url: 'git@github.com:Ducasse/spec.git')
		        beCloned;
		        beLoaded;
		        iceRepository: (IceLibgitRepository new
				         name: 'Spec2';
				         location: clones / 'Ducasse' / 'spec';
				         yourself);
		        yourself.
	catalog := (FRCatalog withAll: { spec })
		           clonesLocation: clones;
		           yourself.
	self assert: (catalog stateOf: (FRFavorite url: 'git@github.com:Ducasse/spec.git')) equals: #loaded
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

	| catalog |
	catalog := FRCatalog withAll: { ((FRRepositoryInfo name: 'Microdown' url: 'git@github.com:pillar-markup/Microdown.git')
			            beCloned;
			            beLoaded;
			            yourself) }.
	self assert: (catalog stateOf: (FRFavorite url: 'git@github.com:pillar-markup/Microdown.git')) equals: #loaded
]

{ #category : 'tests' }
FRCatalogTest >> testLoadedRepositoryWithoutCloneGivesLoadedWithoutCloneState [
	"Roassal came with the image: its code is loaded but there is no clone to work on."

	self assert: (self catalog stateOf: (self favoriteNamed: 'Roassal')) equals: #loadedWithoutClone
]

{ #category : 'tests' }
FRCatalogTest >> testMatchingIgnoresCase [

	self assert: (self catalog stateOf: (self favoriteNamed: 'roassal')) equals: #loadedWithoutClone
]

{ #category : 'tests' }
FRCatalogTest >> testNoCloneOnDiskIsNotCloned [

	self
		assert: ((self catalogOnClonesIn: FileSystem memory) stateOf: (FRFavorite url: 'git@github.com:noha/mustache.git'))
		equals: #notCloned
]

{ #category : 'tests' }
FRCatalogTest >> testSameNameTwiceIsLoadedWhenOneIsLoaded [

	self assert: (self catalog stateOf: (self favoriteNamed: 'tonel')) equals: #loadedWithoutClone
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
