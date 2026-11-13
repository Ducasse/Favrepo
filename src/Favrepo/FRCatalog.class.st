"
I am the view of the current image used by the favorites tool: the repositories Iceberg knows, as `FRRepositoryInfo`s, and the clones Iceberg forgot but left on disk.

## Responsibility:

- I match a favorite with a repository of the image by name, ignoring case; a loaded repository wins when a name is registered twice.
- I answer the state of a favorite: `#loaded`, `#cloned` (in the image, nothing loaded) or `#notCloned`.
- I find the clone of a favorite left in Iceberg's folder (`<owner>/<project>`) after Forget, and read its branches without registering it.
- I list the repositories that are not favorites yet, for the add dialog.

## Collaborators:

- `IceRepository registry` is read by `FRCatalog current`.
- `FRFavorite` is what I am asked about.
- `FRFavoriteLoader` asks me for the existing clone of a favorite.

## Internal Representation

- `infos`: the `FRRepositoryInfo`s of the registered repositories.
- `clonesLocation`: the folder searched for forgotten clones, or nil to never look on disk.
- `diskInfos`: the forgotten clones already read, by folder.

## Public API and Key Messages

- `FRCatalog current` takes a snapshot of the image now, and looks on disk in Iceberg's clone folder.
- `FRCatalog withAll: someInfos` builds a catalog by hand (tests, examples); it looks on disk only after `clonesLocation:`.
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
		'infos',
		'clonesLocation',
		'diskInfos'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'instance creation' }
FRCatalog class >> current [
	"A snapshot of the repositories registered in Iceberg right now, that also finds the clones Iceberg forgot."

	^ (self withAll: (IceRepository registry collect: [ :each | FRRepositoryInfo fromIceRepository: each ]))
		  clonesLocation: IceLibgitRepository repositoriesLocation;
		  yourself
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
FRCatalog >> clonesLocation [

	^ clonesLocation
]

{ #category : 'accessing' }
FRCatalog >> clonesLocation: aFileReference [
	"Also look for clones left in aFileReference (<owner>/<project>) that Iceberg does not know any more."

	clonesLocation := aFileReference
]

{ #category : 'private' }
FRCatalog >> diskInfos [

	^ diskInfos ifNil: [ diskInfos := Dictionary new ]
]

{ #category : 'accessing' }
FRCatalog >> infoFor: aFavorite [
	"The repository of aFavorite registered in Iceberg, else its clone left on disk, else nil."

	^ (self infoNamed: aFavorite name) ifNil: [ self infoOnDiskFor: aFavorite ]
]

{ #category : 'accessing' }
FRCatalog >> infoNamed: aString [
	"The repository named aString (ignoring case); a loaded one wins when the name is registered twice."

	| matching |
	matching := infos select: [ :each | each hasName: aString ].
	^ matching detect: [ :each | each isLoaded ] ifNone: [ matching ifEmpty: [ nil ] ifNotEmpty: [ matching first ] ]
]

{ #category : 'private' }
FRCatalog >> infoOnDiskFor: aFavorite [
	"The clone of aFavorite left in the clones location without being registered in Iceberg (after Forget), or nil. Its branches are read without registering it."

	| directory |
	(clonesLocation isNil or: [ (FRFavorite isValidUrl: aFavorite url) not ]) ifTrue: [ ^ nil ].
	directory := aFavorite cloneDirectoryIn: clonesLocation.
	(IceRepositoryCreator isGitRoot: directory) ifFalse: [ ^ nil ].
	^ self diskInfos at: directory fullName ifAbsentPut: [
		  FRRepositoryInfo fromIceRepository: (IceLibgitRepository new
				   name: aFavorite name;
				   location: directory;
				   yourself) ]
]

{ #category : 'accessing' }
FRCatalog >> infos [

	^ infos
]

{ #category : 'testing' }
FRCatalog >> isLoaded: aFavorite [

	^ (self stateOf: aFavorite) = #loaded
]

{ #category : 'accessing' }
FRCatalog >> registeredRepositoryFor: aFavorite [
	"The Iceberg repository of aFavorite when Iceberg has it registered, nil otherwise."

	^ (self infoNamed: aFavorite name) ifNotNil: [ :info | info iceRepository ]
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
