"
I am a snapshot of one repository registered in Iceberg, holding just what the favorites tool needs to know about it.

## Responsibility:

- I know the name and origin URL of the repository (nil when it is missing on disk, as for the repositories that came with the image).
- I know whether it is cloned, whether any of its packages is loaded, the branch or tag checked out, and the local branches and tags.
- I propose the favorite to add when I am picked in the add dialog (`asFavorite`).

## Collaborators:

- `IceRepository` is what I am built from (`fromIceRepository:`); I keep it for the loader.
- `FRCatalog` holds one of me per registered repository.

## Public API and Key Messages

- `FRRepositoryInfo fromIceRepository: anIceRepository`
- `FRRepositoryInfo name:url:` then `beCloned`, `beLoaded`, `currentVersion:`, `versions:` (used by tests and examples).
- `isCloned`, `isLoaded`, `hasUrl`, `hasName:`, `asFavorite`.

See `FRRepositoryInfo class >> #exampleLoadedOnATag` and `#exampleMissingOnDisk`.

### Implementation Points

Reading branches, tags and the origin can fail on a broken clone; I answer nil or an empty collection instead of raising.
"
Class {
	#name : 'FRRepositoryInfo',
	#superclass : 'Object',
	#instVars : [
		'name',
		'url',
		'isCloned',
		'isLoaded',
		'currentVersion',
		'versions',
		'iceRepository'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'private' }
FRRepositoryInfo class >> currentVersionOf: anIceRepository [
	"The checked-out branch name, or the name of a tag on the checked-out commit."

	^ [
		  | head |
		  head := anIceRepository head.
		  head isBranch
			  ifTrue: [ head name ]
			  ifFalse: [ head tags ifEmpty: [ nil ] ifNotEmpty: [ :tags | tags first name ] ] ]
		  on: Error
		  do: [ nil ]
]

{ #category : 'examples' }
FRRepositoryInfo class >> exampleLoadedOnATag [

	<sampleInstance>
	^ (self name: 'Microdown' url: 'git@github.com:pillar-markup/Microdown.git')
		  beCloned;
		  beLoaded;
		  currentVersion: 'v2.9.3';
		  versions: #( 'dev' 'v2.9.3' );
		  yourself
]

{ #category : 'examples' }
FRRepositoryInfo class >> exampleMissingOnDisk [

	<sampleInstance>
	^ (self name: 'Roassal' url: nil)
		  beLoaded;
		  yourself
]

{ #category : 'instance creation' }
FRRepositoryInfo class >> fromIceRepository: anIceRepository [
	"Snapshot what the tool needs to know about anIceRepository."

	| info |
	info := self name: anIceRepository name url: (self urlOf: anIceRepository).
	info iceRepository: anIceRepository.
	anIceRepository isMissing ifFalse: [ info beCloned ].
	(anIceRepository workingCopy packages anySatisfy: [ :each | each isLoaded ]) ifTrue: [ info beLoaded ].
	info isCloned ifTrue: [
			info
				currentVersion: (self currentVersionOf: anIceRepository);
				versions: (self versionsOf: anIceRepository) ].
	^ info
]

{ #category : 'instance creation' }
FRRepositoryInfo class >> name: aName url: aUrlOrNil [
	"A repository that is neither cloned nor loaded until told otherwise."

	^ self new
		  setName: aName url: aUrlOrNil;
		  yourself
]

{ #category : 'private' }
FRRepositoryInfo class >> urlOf: anIceRepository [
	"The origin URL, or nil for a repository missing on disk or without remote."

	anIceRepository isMissing ifTrue: [ ^ nil ].
	^ [ anIceRepository origin url ]
		  on: Error
		  do: [ nil ]
]

{ #category : 'private' }
FRRepositoryInfo class >> versionsOf: anIceRepository [
	"Local branch and tag names, read from the clone without any network access."

	^ [
		  (anIceRepository localBranches collect: [ :each | each name ] as: Array)
		  , (anIceRepository tags collect: [ :each | each name ] as: Array) ]
		  on: Error
		  do: [ #(  ) ]
]

{ #category : 'converting' }
FRRepositoryInfo >> asFavorite [
	"The favorite proposed when this repository is picked in the add dialog."

	^ FRFavorite url: (url ifNil: [ '' ]) name: name branch: currentVersion
]

{ #category : 'updating' }
FRRepositoryInfo >> beCloned [

	isCloned := true
]

{ #category : 'updating' }
FRRepositoryInfo >> beLoaded [
	"Loaded code implies a clone or a repository that came with the image; either way it is in the image."

	isLoaded := true
]

{ #category : 'accessing' }
FRRepositoryInfo >> currentVersion [

	^ currentVersion
]

{ #category : 'accessing' }
FRRepositoryInfo >> currentVersion: aStringOrNil [

	currentVersion := aStringOrNil
]

{ #category : 'testing' }
FRRepositoryInfo >> hasName: aString [

	^ name sameAs: aString
]

{ #category : 'testing' }
FRRepositoryInfo >> hasUrl [

	^ url isNotNil
]

{ #category : 'accessing' }
FRRepositoryInfo >> iceRepository [

	^ iceRepository
]

{ #category : 'accessing' }
FRRepositoryInfo >> iceRepository: anIceRepository [

	iceRepository := anIceRepository
]

{ #category : 'testing' }
FRRepositoryInfo >> isCloned [

	^ isCloned
]

{ #category : 'testing' }
FRRepositoryInfo >> isLoaded [

	^ isLoaded
]

{ #category : 'accessing' }
FRRepositoryInfo >> name [

	^ name
]

{ #category : 'printing' }
FRRepositoryInfo >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPutAll: ' (';
		nextPutAll: name;
		nextPut: $)
]

{ #category : 'initialization' }
FRRepositoryInfo >> setName: aName url: aUrlOrNil [

	name := aName.
	url := aUrlOrNil.
	isCloned := false.
	isLoaded := false.
	versions := #(  )
]

{ #category : 'accessing' }
FRRepositoryInfo >> url [

	^ url
]

{ #category : 'accessing' }
FRRepositoryInfo >> versions [

	^ versions
]

{ #category : 'accessing' }
FRRepositoryInfo >> versions: aCollection [

	versions := aCollection
]
