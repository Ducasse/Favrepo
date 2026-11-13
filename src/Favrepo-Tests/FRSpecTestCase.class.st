"
I am the common fixture of the presenter tests: an `FRApplication` running synchronously on an in-memory `FRFavoriteStore`, a hand-made `FRCatalog`, and an `FRRecordingLoader` that never touches the network.
"
Class {
	#name : 'FRSpecTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'application',
		'store',
		'loader',
		'presenter'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'testing' }
FRSpecTestCase class >> isAbstract [

	^ self == FRSpecTestCase
]

{ #category : 'helpers' }
FRSpecTestCase >> catalog [
	"Roassal came with the image (no URL) and is loaded, Favrepo is cloned with nothing loaded, Microdown and MCP are loaded and not favorites yet."

	^ FRCatalog withAll: {
			  ((FRRepositoryInfo name: 'Roassal' url: nil)
				   beLoaded;
				   yourself).
			  ((FRRepositoryInfo name: 'Favrepo' url: 'git@github.com:Ducasse/Favrepo.git')
				   beCloned;
				   currentVersion: 'master';
				   versions: #( 'master' 'dev' );
				   yourself).
			  ((FRRepositoryInfo name: 'Microdown' url: 'git@github.com:pillar-markup/Microdown.git')
				   beCloned;
				   beLoaded;
				   currentVersion: 'v2.9.3';
				   versions: #( 'dev' 'v2.9.3' );
				   yourself).
			  ((FRRepositoryInfo name: 'MCP' url: 'git@github.com:Evref-BL/MCP.git')
				   beCloned;
				   beLoaded;
				   currentVersion: 'main';
				   yourself).
			  (FRRepositoryInfo name: 'Spec2' url: nil) }
]

{ #category : 'running' }
FRSpecTestCase >> setUp [

	super setUp.
	store := FRFavoriteStore on: FileSystem memory root / 'favorites.ston'.
	store add: (FRFavorite url: 'git@github.com:pharo-graphics/Roassal.git').
	store add: (FRFavorite url: 'git@github.com:SeasideSt/Seaside.git' name: 'Seaside' branch: 'master').
	store add: (FRFavorite url: 'git@github.com:Ducasse/Favrepo.git').
	loader := FRRecordingLoader new.
	application := FRApplication new
		               store: store;
		               catalog: self catalog;
		               loader: loader;
		               beSynchronous;
		               yourself
]

{ #category : 'helpers' }
FRSpecTestCase >> storedNames [

	^ store favorites collect: [ :each | each name ] as: Array
]

{ #category : 'running' }
FRSpecTestCase >> tearDown [

	application ifNotNil: [ application closeAllWindows ].
	super tearDown
]
