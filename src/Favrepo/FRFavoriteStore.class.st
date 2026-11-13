"
I keep the favorites in a STON file shared by every image of the user, so the list follows you from image to image.

## Responsibility:

- I read the file again on every request, so two open images never overwrite each other with an old list.
- I write the file on every change (add, remove, replace) as a plain list of dictionaries that can be edited by hand.
- I refuse a second favorite with the same name by raising `FRDuplicateFavoriteError`.

## Collaborators:

- `FRFavorite` converts itself to and from the dictionaries of the file.
- `STON` reads and writes the file.
- The Pharo settings browser edits my custom location (Tools > Favorite repositories file).

## Public API and Key Messages

- `FRFavoriteStore default` is the store of the tool: the custom location when set, `FileLocator preferences / 'pharo' / 'iceberg-favorites.ston'` otherwise.
- `FRFavoriteStore on: aFileReference` for another file (tests use a memory file system).
- `favorites`, `add:`, `remove:`, `replace:with:`, `includes:`, `favoriteNamed:ifNone:`.

```
FRFavoriteStore default favorites
```

See `FRFavoriteStore class >> #exampleInMemory`.

## Internal Representation

- `file`: the FileReference of the STON file.
- `CustomLocation`: a class variable with the path chosen in the settings, empty or nil for the default file.
"
Class {
	#name : 'FRFavoriteStore',
	#superclass : 'Object',
	#instVars : [
		'file'
	],
	#classVars : [
		'CustomLocation'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'settings' }
FRFavoriteStore class >> customLocation [

	^ CustomLocation
]

{ #category : 'settings' }
FRFavoriteStore class >> customLocation: aStringOrNil [

	CustomLocation := aStringOrNil
]

{ #category : 'instance creation' }
FRFavoriteStore class >> default [
	"The store used by the tool: the custom location when set, the Pharo preferences file otherwise."

	^ self on: (self customLocation isEmptyOrNil
			   ifTrue: [ self defaultFile ]
			   ifFalse: [ self customLocation asFileReference ])
]

{ #category : 'settings' }
FRFavoriteStore class >> defaultFile [
	"Shared by every image of this user on this machine."

	^ (FileLocator preferences / 'pharo' / 'iceberg-favorites.ston') asFileReference
]

{ #category : 'examples' }
FRFavoriteStore class >> exampleInMemory [
	"A store in a memory file system, so your real favorites file is never touched."

	<sampleInstance>
	^ (self on: FileSystem memory root / 'iceberg-favorites.ston')
		  add: FRFavorite exampleMustache;
		  add: FRFavorite exampleOnDefaultBranch;
		  add: (FRFavorite url: 'git@github.com:pharo-graphics/Roassal.git');
		  add: (FRFavorite url: 'git@github.com:Ducasse/Favrepo.git');
		  yourself
]

{ #category : 'instance creation' }
FRFavoriteStore class >> on: aFileReference [

	^ self new
		  setFile: aFileReference asFileReference;
		  yourself
]

{ #category : 'settings' }
FRFavoriteStore class >> settingsOn: aBuilder [

	<systemsettings>
	(aBuilder setting: #customLocation)
		target: self;
		parent: #tools;
		label: 'Favorite repositories file';
		default: '';
		description:
			('File holding your favorite Iceberg repositories. Leave empty to use {1}. Point it to a synced folder to share favorites across machines.'
				 format: { self defaultFile fullName })
]

{ #category : 'updating' }
FRFavoriteStore >> add: aFavorite [
	"Add aFavorite and write the file; raise FRDuplicateFavoriteError when its name is taken."

	| favorites |
	favorites := self readFavorites.
	self ensureNoneIn: favorites isSameAs: aFavorite.
	self writeFavorites: (favorites copyWith: aFavorite).
	^ aFavorite
]

{ #category : 'private' }
FRFavoriteStore >> ensureNoneIn: someFavorites isSameAs: aFavorite [

	someFavorites detect: [ :each | each isSameAs: aFavorite ] ifFound: [ :existing | FRDuplicateFavoriteError signalFor: existing ]
]

{ #category : 'accessing' }
FRFavoriteStore >> favoriteNamed: aString ifNone: aBlock [

	^ self readFavorites detect: [ :each | each hasName: aString ] ifNone: aBlock
]

{ #category : 'accessing' }
FRFavoriteStore >> favorites [
	"Read the file again and answer its favorites sorted by name, ignoring case."

	^ self readFavorites sort: [ :a :b | a name asLowercase <= b name asLowercase ]
]

{ #category : 'accessing' }
FRFavoriteStore >> file [

	^ file
]

{ #category : 'testing' }
FRFavoriteStore >> includes: aFavorite [

	^ self readFavorites anySatisfy: [ :each | each isSameAs: aFavorite ]
]

{ #category : 'private' }
FRFavoriteStore >> readFavorites [

	file exists ifFalse: [ ^ OrderedCollection new ].
	^ (STON fromString: file contents) asOrderedCollection collect: [ :each | FRFavorite fromDictionary: each ]
]

{ #category : 'updating' }
FRFavoriteStore >> remove: aFavorite [
	"Remove the favorite with the same name as aFavorite, and write the file."

	self writeFavorites: (self readFavorites reject: [ :each | each isSameAs: aFavorite ])
]

{ #category : 'updating' }
FRFavoriteStore >> replace: oldFavorite with: newFavorite [
	"Replace oldFavorite by newFavorite and write the file; the new name must not belong to another favorite."

	| others |
	others := self readFavorites reject: [ :each | each isSameAs: oldFavorite ].
	self ensureNoneIn: others isSameAs: newFavorite.
	self writeFavorites: (others copyWith: newFavorite).
	^ newFavorite
]

{ #category : 'initialization' }
FRFavoriteStore >> setFile: aFileReference [

	file := aFileReference
]

{ #category : 'private' }
FRFavoriteStore >> writeFavorites: someFavorites [

	file parent ensureCreateDirectory.
	file ensureDelete.
	file writeStreamDo: [ :stream |
		STON put: (someFavorites collect: [ :each | each asDictionary ] as: Array) onStreamPretty: stream ]
]
