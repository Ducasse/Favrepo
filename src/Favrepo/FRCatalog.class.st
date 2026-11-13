"
I am the view of the current image used by the favorites tool: the repositories Iceberg knows, as `FRRepositoryInfo`s.

## Responsibility:

- I match a favorite with a repository of the image by name, ignoring case; a loaded repository wins when a name is registered twice.
- I answer the state of a favorite: `#loaded`, `#cloned` (in the image, nothing loaded) or `#notCloned`.
- I list the repositories that are not favorites yet, for the add dialog.

## Collaborators:

- `IceRepository registry` is read by `FRCatalog current`.
- `FRFavorite` is what I am asked about.
- `FRFavoriteLoader` asks me for the existing clone of a favorite.

## Public API and Key Messages

- `FRCatalog current` takes a snapshot of the image now.
- `FRCatalog withAll: someInfos` builds a catalog by hand (tests, examples).
- `stateOf:`, `isLoaded:`, `infoFor:`, `infoNamed:`, `availableFor:`.

```
FRCatalog current stateOf: (FRFavorite url: 'git@github.com:pharo-graphics/Roassal.git')
```

See `FRCatalog class >> #exampleSmallImage`.
"
Class {
	#name : 'FRCatalog',
	#superclass : 'Object',
	#instVars : [
		'infos'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'instance creation' }
FRCatalog class >> current [
	"A snapshot of the repositories registered in Iceberg right now."

	^ self withAll: (IceRepository registry collect: [ :each | FRRepositoryInfo fromIceRepository: each ])
]

{ #category : 'examples' }
FRCatalog class >> exampleSmallImage [
	"An image with a loaded Microdown, a Roassal missing on disk and a cloned but unloaded Favrepo."

	<sampleInstance>
	^ self withAll: {
			  FRRepositoryInfo exampleLoadedOnATag.
			  FRRepositoryInfo exampleMissingOnDisk.
			  ((FRRepositoryInfo name: 'Favrepo' url: 'git@github.com:Ducasse/Favrepo.git')
				   beCloned;
				   currentVersion: 'master';
				   versions: #( 'master' );
				   yourself) }
]

{ #category : 'instance creation' }
FRCatalog class >> withAll: someRepositoryInfos [

	^ self new
		  setInfos: someRepositoryInfos asArray;
		  yourself
]

{ #category : 'accessing' }
FRCatalog >> availableFor: someFavorites [
	"The repositories that are not favorites yet, one per name, sorted by name."

	| names |
	names := (infos collect: [ :each | each name asLowercase ] as: Set) reject: [ :each |
		         someFavorites anySatisfy: [ :favorite | favorite hasName: each ] ].
	^ (names collect: [ :each | self infoNamed: each ] as: Array) sort: [ :a :b | a name asLowercase <= b name asLowercase ]
]

{ #category : 'accessing' }
FRCatalog >> infoFor: aFavorite [

	^ self infoNamed: aFavorite name
]

{ #category : 'accessing' }
FRCatalog >> infoNamed: aString [
	"The repository named aString (ignoring case); a loaded one wins when the name is registered twice."

	| matching |
	matching := infos select: [ :each | each hasName: aString ].
	^ matching detect: [ :each | each isLoaded ] ifNone: [ matching ifEmpty: [ nil ] ifNotEmpty: [ matching first ] ]
]

{ #category : 'accessing' }
FRCatalog >> infos [

	^ infos
]

{ #category : 'testing' }
FRCatalog >> isLoaded: aFavorite [

	^ (self stateOf: aFavorite) = #loaded
]

{ #category : 'initialization' }
FRCatalog >> setInfos: anArray [

	infos := anArray
]

{ #category : 'accessing' }
FRCatalog >> stateOf: aFavorite [
	"#loaded, #cloned (in the image, nothing loaded) or #notCloned."

	| info |
	info := self infoFor: aFavorite.
	info ifNil: [ ^ #notCloned ].
	info isLoaded ifTrue: [ ^ #loaded ].
	^ info isCloned
		  ifTrue: [ #cloned ]
		  ifFalse: [ #notCloned ]
]
