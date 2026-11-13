"
I am the main window of the favorites tool, four rows high and scrolling beyond: one row per favorite, sorted by name, an Iceberg button that opens Iceberg on all the repositories, a refresh button that takes the branches from Iceberg, and a + button to add a favorite.

## Responsibility:

- I rebuild my rows from the favorites file and a fresh catalog of the image on every change.
- I clone a favorite, load it, change its branch, remove it (no confirmation: only the bookmark goes, and + adds it back) and open the add and edit dialogs.
- I offer Edit and Remove from favorites (Delete key) in the row context menu; a double-click opens the Iceberg repository browser of a favorite Iceberg has.

## Collaborators:

- `FRFavoriteRowPresenter` shows one favorite and calls me back for Load and branch changes.
- `FRAddFavoritePresenter` adds or edits a favorite.
- `FRApplication` gives me the store, the catalog and the loader.
- `SpEasyComponentListPresenter` holds the rows.

## Public API and Key Messages

- `takeBranchesFromIceberg` (the refresh button), `refresh`, `rows`, `rowNamed:`, `selectedFavorite`, `selectFavoriteNamed:`
- `cloneFavorite:`, `loadFavorite:`, `changeBranch:of:`, `removeFavorite:`, `removeSelectedFavorite`, `browseFavorite:`, `openAddDialog`, `openEditDialogOn:`

See `FRFavoritesPresenter class >> #exampleInMemory` and run `FRFavoritesPresenter class >> #scriptOpenInMemory`.
"
Class {
	#name : 'FRFavoritesPresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'addButton',
		'list',
		'refreshButton',
		'icebergButton'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'examples' }
FRFavoritesPresenter class >> exampleInMemory [
	"The favorites presenter of the example application, not opened."

	<sampleInstance>
	^ FRApplication exampleInMemory instantiate: self
]

{ #category : 'script' }
FRFavoritesPresenter class >> scriptOpenInMemory [
	"Open the favorites window on example favorites and the small example image: Roassal is loaded (check mark), Favrepo, Mustache and Seaside are grey with a Load button."

	<example>
	^ self exampleInMemory open
]

{ #category : 'actions' }
FRFavoritesPresenter >> browseFavorite: aFavorite [
	"Open Iceberg on the repository of aFavorite; nothing happens while Iceberg does not have it."

	(self application catalog registeredRepositoryFor: aFavorite) ifNotNil: [ :repository |
		self application browseRepository: repository ]
]

{ #category : 'actions' }
FRFavoritesPresenter >> changeBranch: aString of: aFavorite [

	self application store replace: aFavorite with: (aFavorite withBranch: aString).
	self refresh
]

{ #category : 'actions' }
FRFavoritesPresenter >> cloneFavorite: aFavorite [
	"Clone aFavorite with a progress bar, without loading it, then show its new state."

	(self rowNamed: aFavorite name) ifNotNil: [ :row | row beCloning ].
	self application
		run: [
				[ self application newLoader clone: aFavorite ]
					on: Error
					do: [ :error |
							self application inUIProcess: [
								self application reportFailure: error messageText titled: ('Cloning {1} failed' format: { aFavorite name }) ] ].
				self application inUIProcess: [ self refresh ] ]
		titled: ('Cloning {1}' format: { aFavorite name })
]

{ #category : 'initialization' }
FRFavoritesPresenter >> connectPresenters [

	list whenActivatedDo: [ :selection |
		selection selectedItem ifNotNil: [ :row | self browseFavorite: row favorite ] ]
]

{ #category : 'layout' }
FRFavoritesPresenter >> defaultLayout [

	^ SpBoxLayout newTopToBottom
		  spacing: 4;
		  add: (SpBoxLayout newLeftToRight
				   vAlignCenter;
				   spacing: 4;
				   add: icebergButton expand: false;
				   addLast: refreshButton expand: false;
				   addLast: addButton expand: false;
				   yourself)
		  expand: false;
		  add: list;
		  yourself
]

{ #category : 'actions' }
FRFavoritesPresenter >> favoriteAccepted: aFavorite [

	self refresh.
	self selectFavoriteNamed: aFavorite name
]

{ #category : 'accessing' }
FRFavoritesPresenter >> favoritesList [

	^ list
]

{ #category : 'accessing' }
FRFavoritesPresenter >> icebergButton [

	^ icebergButton
]

{ #category : 'initialization' }
FRFavoritesPresenter >> initializePresenters [

	icebergButton := self newButton
		                 label: 'Iceberg';
		                 icon: self application icebergIcon;
		                 help: 'Open Iceberg on all the repositories of the image';
		                 action: [ self application openIceberg ];
		                 yourself.
	refreshButton := self newButton
		                 icon: (self iconNamed: #refresh);
		                 help: 'Take the branches from Iceberg and check again what is loaded';
		                 action: [ self takeBranchesFromIceberg ];
		                 yourself.
	addButton := self newButton
		             icon: (self iconNamed: #add);
		             help: 'Add a favorite repository';
		             action: [ self openAddDialog ];
		             yourself.
	list := self instantiate: SpEasyComponentListPresenter.
	list
		activateOnDoubleClick;
		addActionWith: [ :action |
				action
					name: 'Edit…';
					actionEnabled: [ self selectedFavorite isNotNil ];
					action: [ self openEditDialogOn: self selectedFavorite ] ];
		addActionWith: [ :action |
				action
					name: 'Remove from favorites';
					shortcutKey: KeyboardKey delete asKeyCombination;
					actionEnabled: [ self selectedFavorite isNotNil ];
					action: [ self removeSelectedFavorite ] ].
	self refresh
]

{ #category : 'initialization' }
FRFavoritesPresenter >> initializeWindow: aWindowPresenter [
	"Four rows high. The rows are set again once the window is open: built before, the list misses that it needs a scroll bar."

	super initializeWindow: aWindowPresenter.
	aWindowPresenter
		title: 'Favorite repositories';
		initialExtent: 520 @ 209;
		whenOpenedDo: [ self refresh ]
]

{ #category : 'actions' }
FRFavoritesPresenter >> loadFavorite: aFavorite [
	"Clone and load aFavorite with a progress bar, then show its new state."

	(self rowNamed: aFavorite name) ifNotNil: [ :row | row beLoading ].
	self application
		run: [
				[ self application newLoader load: aFavorite ]
					on: Error
					do: [ :error |
							self application inUIProcess: [
								self application reportFailure: error messageText titled: ('Loading {1} failed' format: { aFavorite name }) ] ].
				self application inUIProcess: [ self refresh ] ]
		titled: ('Loading {1}' format: { aFavorite name })
]

{ #category : 'actions' }
FRFavoritesPresenter >> openAddDialog [

	(self application instantiate: FRAddFavoritePresenter)
		whenAcceptedDo: [ :favorite | self favoriteAccepted: favorite ];
		openDialog
]

{ #category : 'actions' }
FRFavoritesPresenter >> openEditDialogOn: aFavorite [

	(self application instantiate: FRAddFavoritePresenter)
		beEditing: aFavorite;
		whenAcceptedDo: [ :favorite | self favoriteAccepted: favorite ];
		openDialog
]

{ #category : 'updating' }
FRFavoritesPresenter >> refresh [
	"Read the favorites file again and rebuild the rows against a fresh view of the image."

	| catalog selected |
	catalog := self application catalog.
	selected := self selectedFavorite.
	list presenters: (self application store favorites collect: [ :each |
				 (self instantiate: FRFavoriteRowPresenter)
					 favoritesPresenter: self;
					 setFavorite: each catalog: catalog;
					 yourself ]).
	selected ifNotNil: [ self selectFavoriteNamed: selected name ]
]

{ #category : 'accessing' }
FRFavoritesPresenter >> refreshButton [

	^ refreshButton
]

{ #category : 'actions' }
FRFavoritesPresenter >> removeFavorite: aFavorite [

	self application store remove: aFavorite.
	self refresh
]

{ #category : 'actions' }
FRFavoritesPresenter >> removeSelectedFavorite [
	"Remove the selected favorite from the list only: its clone and loaded code stay, and + adds it back."

	self selectedFavorite ifNotNil: [ :favorite | self removeFavorite: favorite ]
]

{ #category : 'accessing' }
FRFavoritesPresenter >> rowNamed: aString [

	^ self rows detect: [ :each | each favorite hasName: aString ] ifNone: [ nil ]
]

{ #category : 'accessing' }
FRFavoritesPresenter >> rows [

	^ list items
]

{ #category : 'actions' }
FRFavoritesPresenter >> selectFavoriteNamed: aString [

	(self rowNamed: aString) ifNotNil: [ :row | list selectItem: row ]
]

{ #category : 'accessing' }
FRFavoritesPresenter >> selectedFavorite [

	^ list selectedItem ifNotNil: [ :row | row favorite ]
]

{ #category : 'actions' }
FRFavoritesPresenter >> takeBranchesFromIceberg [
	"Make each favorite cloned in the image follow the branch or tag Iceberg has checked out, then show the image again."

	self application store takeBranchesFrom: self application catalog.
	self refresh
]
