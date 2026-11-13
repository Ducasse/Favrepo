"
I am the main window of the favorites tool: one row per favorite, sorted by name, and a + button to add one.

## Responsibility:

- I rebuild my rows from the favorites file and a fresh catalog of the image on every change.
- I load a favorite, change its branch, remove it (after confirmation) and open the add and edit dialogs.
- I offer Edit and Remove from favorites (Delete key) in the row context menu.

## Collaborators:

- `FRFavoriteRowPresenter` shows one favorite and calls me back for Load and branch changes.
- `FRAddFavoritePresenter` adds or edits a favorite.
- `FRApplication` gives me the store, the catalog and the loader.
- `SpEasyComponentListPresenter` holds the rows.

## Public API and Key Messages

- `refresh`, `rows`, `rowNamed:`, `selectedFavorite`, `selectFavoriteNamed:`
- `loadFavorite:`, `changeBranch:of:`, `removeFavorite:`, `openAddDialog`, `openEditDialogOn:`

See `FRFavoritesPresenter class >> #exampleInMemory` and run `FRFavoritesPresenter class >> #scriptOpenInMemory`.
"
Class {
	#name : 'FRFavoritesPresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'titleLabel',
		'addButton',
		'list'
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
FRFavoritesPresenter >> changeBranch: aString of: aFavorite [

	self application store replace: aFavorite with: (aFavorite withBranch: aString).
	self refresh
]

{ #category : 'actions' }
FRFavoritesPresenter >> confirmAndRemove: aFavorite [

	(self application
		 confirm: ('Remove {1} from your favorites? Its clone and loaded code stay in the image.' format: { aFavorite name })
		 titled: 'Remove favorite') ifTrue: [ self removeFavorite: aFavorite ]
]

{ #category : 'layout' }
FRFavoritesPresenter >> defaultLayout [

	^ SpBoxLayout newTopToBottom
		  spacing: 4;
		  add: (SpBoxLayout newLeftToRight
				   vAlignCenter;
				   add: titleLabel;
				   add: addButton expand: false;
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

{ #category : 'initialization' }
FRFavoritesPresenter >> initializePresenters [

	titleLabel := self newLabel
		              label: 'Favorite repositories';
		              addStyle: 'frName';
		              yourself.
	addButton := self newButton
		             icon: (self iconNamed: #add);
		             help: 'Add a favorite repository';
		             action: [ self openAddDialog ];
		             yourself.
	list := self instantiate: SpEasyComponentListPresenter.
	list
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
					action: [ self confirmAndRemove: self selectedFavorite ] ].
	self refresh
]

{ #category : 'initialization' }
FRFavoritesPresenter >> initializeWindow: aWindowPresenter [

	super initializeWindow: aWindowPresenter.
	aWindowPresenter
		title: 'Favorite repositories';
		initialExtent: 520 @ 380
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

{ #category : 'actions' }
FRFavoritesPresenter >> refresh [
	"Read the favorites file again and rebuild the rows against a fresh view of the image."

	| catalog selected |
	catalog := self application catalog.
	selected := self selectedFavorite.
	list presenters: (self application store favorites collect: [ :each |
				 (self instantiate: FRFavoriteRowPresenter)
					 setFavorite: each catalog: catalog;
					 yourself ]).
	selected ifNotNil: [ self selectFavoriteNamed: selected name ]
]

{ #category : 'actions' }
FRFavoritesPresenter >> removeFavorite: aFavorite [

	self application store remove: aFavorite.
	self refresh
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
