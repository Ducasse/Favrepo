"
I test FRFavoriteStore on a memory file system.
"
Class {
	#name : 'FRFavoriteStoreTest',
	#superclass : 'TestCase',
	#instVars : [
		'store',
		'file'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRFavoriteStoreTest >> favoriteNamed: aString [

	^ FRFavorite url: ('git@github.com:someone/{1}.git' format: { aString })
]

{ #category : 'helpers' }
FRFavoriteStoreTest >> icebergCatalog [
	"Favrepo is cloned on master, Roassal came with the image without a clone."

	^ FRCatalog withAll: {
			  ((FRRepositoryInfo name: 'Favrepo' url: 'git@github.com:Ducasse/Favrepo.git')
				   beCloned;
				   currentVersion: 'master';
				   yourself).
			  ((FRRepositoryInfo name: 'Roassal' url: nil)
				   beLoaded;
				   yourself) }
]

{ #category : 'running' }
FRFavoriteStoreTest >> setUp [

	super setUp.
	file := FileSystem memory root / 'prefs' / 'iceberg-favorites.ston'.
	store := FRFavoriteStore on: file
]

{ #category : 'helpers' }
FRFavoriteStoreTest >> storedNames [

	^ store favorites collect: [ :each | each name ] as: Array
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testAddWritesTheFile [

	store add: (self favoriteNamed: 'Seaside').
	self assert: file exists.
	self assert: self storedNames equals: #( 'Seaside' )
]

{ #category : 'tests - errors' }
FRFavoriteStoreTest >> testAddingTheSameNameTwiceRaisesError [

	store add: (self favoriteNamed: 'Seaside').
	self should: [ store add: (FRFavorite url: 'https://github.com/other/seaside') ] raise: FRDuplicateFavoriteError
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testCustomLocationOverridesTheDefaultFile [

	| previous |
	previous := FRFavoriteStore customLocation.
	[
		FRFavoriteStore customLocation: '/tmp/somewhere/favorites.ston'.
		self assert: FRFavoriteStore default file equals: '/tmp/somewhere/favorites.ston' asFileReference ] ensure: [
		FRFavoriteStore customLocation: previous ]
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testDefaultFileIsInPharoPreferences [

	self assert: FRFavoriteStore defaultFile equals: (FileLocator preferences / 'pharo' / 'iceberg-favorites.ston') asFileReference
]

{ #category : 'tests - errors' }
FRFavoriteStoreTest >> testDuplicateErrorKnowsTheExistingFavorite [

	| existing |
	store add: (FRFavorite url: 'git@github.com:SeasideSt/Seaside.git' name: 'Seaside' branch: 'master').
	existing := [
		            store add: (self favoriteNamed: 'seaside').
		            nil ]
		            on: FRDuplicateFavoriteError
		            do: [ :error | error favorite ].
	self assert: existing branch equals: 'master'
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testEmptyCustomLocationMeansDefaultFile [

	| previous |
	previous := FRFavoriteStore customLocation.
	[
		FRFavoriteStore customLocation: ''.
		self assert: FRFavoriteStore default file equals: FRFavoriteStore defaultFile ] ensure: [
		FRFavoriteStore customLocation: previous ]
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testFavoritesAreSortedByNameIgnoringCase [

	store add: (self favoriteNamed: 'Ume').
	store add: (self favoriteNamed: 'mustache').
	store add: (self favoriteNamed: 'Seaside').
	self assert: self storedNames equals: #( 'mustache' 'Seaside' 'Ume' )
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testFileHoldsPlainDictionaries [

	| contents |
	store add: (FRFavorite url: 'git@github.com:noha/mustache.git' name: 'Mustache' branch: 'v1.3').
	contents := STON fromString: file contents.
	self assert: contents size equals: 1.
	self assert: (contents first at: 'url') equals: 'git@github.com:noha/mustache.git'.
	self assert: (contents first at: 'name') equals: 'Mustache'.
	self assert: (contents first at: 'branch') equals: 'v1.3'
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testFileIsReadAgainEachTime [

	| other |
	store add: (self favoriteNamed: 'Seaside').
	other := FRFavoriteStore on: file.
	other add: (self favoriteNamed: 'Ume').
	self assert: store favorites size equals: 2
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testIncludes [

	store add: (self favoriteNamed: 'Seaside').
	self assert: (store includes: (self favoriteNamed: 'SEASIDE')).
	self deny: (store includes: (self favoriteNamed: 'Ume'))
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testNoFileMeansNoFavorites [

	self assert: store favorites isEmpty
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testRemove [

	store add: (self favoriteNamed: 'Seaside').
	store add: (self favoriteNamed: 'Ume').
	store remove: (self favoriteNamed: 'seaside').
	self assert: self storedNames equals: #( 'Ume' )
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testReplace [

	store add: (self favoriteNamed: 'Seaside').
	store
		replace: (self favoriteNamed: 'Seaside')
		with: (FRFavorite url: 'git@github.com:SeasideSt/Seaside.git' name: 'Seaside' branch: 'master').
	self assert: store favorites size equals: 1.
	self assert: store favorites first branch equals: 'master'.
	self assert: store favorites first url equals: 'git@github.com:SeasideSt/Seaside.git'
]

{ #category : 'tests - errors' }
FRFavoriteStoreTest >> testReplacingWithAnExistingNameRaisesError [

	store add: (self favoriteNamed: 'Seaside').
	store add: (self favoriteNamed: 'Ume').
	self should: [ store replace: (self favoriteNamed: 'Ume') with: (self favoriteNamed: 'Seaside') ] raise: FRDuplicateFavoriteError
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testTakeBranchesFromAnswersTheChangedFavorites [

	| changed |
	store add: (self favoriteNamed: 'Favrepo').
	store add: (self favoriteNamed: 'Seaside').
	changed := store takeBranchesFrom: self icebergCatalog.
	self assert: (changed collect: [ :each | each name ] as: Array) equals: #( 'Favrepo' )
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testTakeBranchesFromKeepsFavoritesWithoutClone [

	store add: ((self favoriteNamed: 'Roassal') withBranch: 'v1.0').
	store add: ((self favoriteNamed: 'Seaside') withBranch: 'dev').
	store takeBranchesFrom: self icebergCatalog.
	self
		assert: (store favorites collect: [ :each | each branch ] as: Array)
		equals: #( 'v1.0' 'dev' )
]

{ #category : 'tests' }
FRFavoriteStoreTest >> testTakeBranchesFromUsesTheCheckedOutVersion [

	store add: (self favoriteNamed: 'Favrepo').
	store takeBranchesFrom: self icebergCatalog.
	self assert: store favorites first branch equals: 'master'
]
