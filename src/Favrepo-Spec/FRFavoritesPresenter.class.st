"
I am the main window of the favorites tool, four rows high and scrolling beyond: one row per favorite, sorted by name, an Iceberg button that opens Iceberg on all the repositories, a refresh button that takes the branches from Iceberg, a + button to add a favorite, and a ? button showing the help (`FRFavoritesPresenter class >> #helpText`).

## Responsibility:

- I rebuild my rows from the favorites file and a fresh catalog of the image on every change.
- I clone a favorite, load it, change its branch, remove it (no confirmation: only the bookmark goes, and + adds it back) and open the add and edit dialogs.
- I offer Edit, Remove from favorites (Delete key) Define bottom branch (creates and checks out `<ISO date>-Bottom` in the clone), and for Pharo external projects Create Pharo integration branch… and Open Pharo integration PR (see `FRPharoIntegration`) in the row context menu; a double-click opens the Iceberg repository browser of a favorite Iceberg has.

## Collaborators:

- `FRFavoriteRowPresenter` shows one favorite and calls me back for Load and branch changes.
- `FRAddFavoritePresenter` adds or edits a favorite.
- `FRApplication` gives me the store, the catalog and the loader.
- `SpEasyComponentListPresenter` holds the rows.

## Public API and Key Messages

- `takeBranchesFromIceberg` (the refresh button), `refresh`, `rows`, `rowNamed:`, `selectedFavorite`, `selectFavoriteNamed:`
- `cloneFavorite:`, `loadFavorite:`, `changeBranch:of:`, `removeFavorite:`, `removeSelectedFavorite`, `defineBottomBranchOf:`, `createPharoIntegrationBranchOf:`, `openPharoIntegrationPullRequestOf:`, `browseFavorite:`, `openAddDialog`, `openEditDialogOn:`

See `FRFavoritesPresenter class >> #exampleInMemory` and run `FRFavoritesPresenter class >> #scriptOpenInMemory`.
"
Class {
	#name : 'FRFavoritesPresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'addButton',
		'list',
		'refreshButton',
		'icebergButton',
		'helpButton',
		'updateButton'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'examples' }
FRFavoritesPresenter class >> exampleInMemory [
	"The favorites presenter of the example application, not opened."

	^ FRApplication exampleInMemory instantiate: self
]

{ #category : 'help' }
FRFavoritesPresenter class >> helpText [
	"What the help button shows, in Microdown."

	^ '# Favorite repositories

Keep the Git repositories you work on at hand, and clone and load them with Iceberg in one click. Your favorites are shared by all your images: they are kept in the Pharo preferences folder (`pharo/iceberg-favorites.ston`).

## The toolbar

- **Iceberg** opens Iceberg on all the repositories of the image.
- **Update** (the rightmost button) updates Favrepo itself in this image: it fetches the clone Favrepo was loaded from, pulls the new commits of its branch and loads them, then opens the window again. Nothing is pulled into a clone with uncommitted changes.
- **Refresh** takes the branches from Iceberg and checks again what is loaded.
- **+** adds a favorite: type its URL, or pick a repository Iceberg already knows.
- **?** shows this help.

## A row

- The name and the `owner/project` of the favorite. A check mark tells that its code is loaded; a grey row that nothing is loaded.
- **Clone** (the down arrow) clones the repository with Iceberg without loading it. A clone left on disk by Iceberg''s Forget is registered again.
- **Clone of code the image already has**: projects that came with the image, such as NewTools or Spec2, are loaded but have no clone. Clone is offered for them: your clone (for example your fork) is attached to the loaded code instead of being registered apart. The clone is put, without loading anything, on a branch `image-<commit>` at the commit the image was built from, so the image and the clone are in sync. The project it was forked from is added as the `upstream` remote and fetched. Commits go to your fork (`origin`).
- **The branch list** chooses the branch or tag to load.
- **Load** clones if needed, switches to the branch, and loads the baseline (its default group) with Metacello, keeping the projects already loaded.
- **Double-click** opens the Iceberg browser of the repository.

## The row menu

- **Edit…** changes the URL, name or branch of the favorite.
- **Remove from favorites** (Delete key) removes the bookmark only: the clone and the loaded code stay, and + adds it back.
- **Define bottom branch** creates and checks out the branch `<ISO date>-Bottom` (for example `2026-11-15-Bottom`) at the current commit of the clone, without loading anything. Bottom branches are the clean bases your work and integration branches start from.
- **Create Pharo integration branch…** is for Pharo external projects, the projects `BaselineOfPharo` loads from other repositories (`<externalProject>` methods: NewTools, Spec, Roassal, Microdown, Iceberg, Toplo…). It asks for a branch name and creates that branch in the clone of the project, where you then commit and push. In your Pharo fork, it creates the same branch whose `BaselineOfPharo` loads the project from your fork at that branch, commits that one-line change, pushes it, and puts Pharo back on its Bottom branch. It warns you when a clone is not on a Bottom branch, so integration branches never pile up. You need a clone of your Pharo fork.
- **Open Pharo integration PR** opens the GitHub pull request of the Pharo branch named like the branch of the clone. It first checks that this branch is pushed to your fork: the Pharo build loads it from there and validates your change (new packages, dependency order) in the whole system.
'
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

{ #category : 'testing' }
FRFavoritesPresenter >> canCreatePharoIntegrationOfSelection [
	"Whether the selected favorite is a Pharo external project with a clone."

	^ self selectedFavorite ifNil: [ false ] ifNotNil: [ :favorite |
		  (self rowNamed: favorite name) isBottomBranchEnabled and: [
			  (self application newPharoIntegrationFor: favorite) isExternalProject ] ]
]

{ #category : 'testing' }
FRFavoritesPresenter >> canDefineBottomBranchOfSelection [
	"Whether the selected favorite has a clone to create a bottom branch in."

	^ self selectedFavorite ifNil: [ false ] ifNotNil: [ :favorite | (self rowNamed: favorite name) isBottomBranchEnabled ]
]

{ #category : 'testing' }
FRFavoritesPresenter >> canOpenPharoIntegrationPullRequestOfSelection [
	"Whether the Pharo clone has the integration branch of the selected favorite."

	^ self canCreatePharoIntegrationOfSelection and: [
		  (self application newPharoIntegrationFor: self selectedFavorite) hasPharoIntegrationBranch ]
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
					do: [ :error | self application reportFailure: error messageText titled: ('Cloning {1} failed' format: { aFavorite name }) ].
				self refresh ]
		titled: ('Cloning {1}' format: { aFavorite name })
]

{ #category : 'initialization' }
FRFavoritesPresenter >> connectPresenters [

	list whenActivatedDo: [ :selection | selection selectedItem ifNotNil: [ :row | self browseFavorite: row favorite ] ].
	"Workaround for Spec before pharo-spec/Spec#1982: the list view gives every row the default height, cutting our two-line rows. Remove once the Pharo 14 build has it."
	list contentView whenBuiltDo: [ list contentView adapter widget beRowNotHomogeneous ]
]

{ #category : 'actions' }
FRFavoritesPresenter >> createPharoIntegrationBranchOf: aFavorite [
	"Ask the name of the integration branch, create it in the clone of aFavorite and in Pharo, then tell what was done."

	| name |
	name := self application
		        request: ('Name of the branch to create in {1} and in Pharo' format: { aFavorite name })
		        initialAnswer: ''
		        titled: 'Pharo integration branch'.
	name ifNil: [ ^ self ].
	[
		self application
			run: [
					((self application newPharoIntegrationFor: aFavorite) createBranch: name trimBoth) ifNotNil: [ :report |
						self application report: report titled: 'Pharo integration branch' ] ]
			titled: ('Creating the Pharo integration branch {1}' format: { name }) ]
		on: Error
		do: [ :error | self application reportFailure: error messageText titled: 'Pharo integration branch not created' ].
	self refresh
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
				   addLast: helpButton expand: false;
				   addLast: updateButton expand: false;
				   yourself)
		  expand: false;
		  add: list;
		  yourself
]

{ #category : 'actions' }
FRFavoritesPresenter >> defineBottomBranchOf: aFavorite [
	"Create today's bottom branch in the clone of aFavorite, then show its new state."

	[
		| name |
		name := self application newLoader defineBottomBranchFor: aFavorite.
		self application tell: ('{1}: branch {2} created and checked out' format: {
					 aFavorite name.
					 name }) ]
		on: Error
		do: [ :error |
		self application reportFailure: error messageText titled: ('Bottom branch of {1} failed' format: { aFavorite name }) ].
	self refresh
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
FRFavoritesPresenter >> initializePharoIntegrationMenu [
	"The items to validate a branch of a Pharo external project in the full Pharo build."

	list
		addActionWith: [ :action |
				action
					name: 'Create Pharo integration branch…';
					description:
						'Create a branch in this clone and, in your Pharo fork, the same branch loading it from your fork (Pharo external projects only)';
					actionEnabled: [ self canCreatePharoIntegrationOfSelection ];
					action: [ self createPharoIntegrationBranchOf: self selectedFavorite ] ];
		addActionWith: [ :action |
				action
					name: 'Open Pharo integration PR';
					description: 'Open the pull request of the Pharo branch named like the branch of this clone (Pharo external projects only)';
					actionEnabled: [ self canOpenPharoIntegrationPullRequestOfSelection ];
					action: [ self openPharoIntegrationPullRequestOf: self selectedFavorite ] ]
]

{ #category : 'initialization' }
FRFavoritesPresenter >> initializePresenters [

	icebergButton := self newButton
		                 label: 'Iceberg';
		                 icon: self application icebergIcon;
		                 help: 'Open Iceberg on all the repositories of the image';
		                 action: [ self application openIceberg ];
		                 yourself.
	updateButton := self newButton
		                icon: (self iconNamed: #smallUpdate);
		                help: 'Fetch Favrepo and load its new commits into this image';
		                action: [ self updateFavrepo ];
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
	helpButton := self newButton
		              icon: (self iconNamed: #help);
		              help: 'What Favorite repositories can do';
		              action: [ self application showHelp: self class helpText ];
		              yourself.
	list := self instantiate: SpEasyComponentListPresenter.
	list activateOnDoubleClick.
	self initializeRowMenu.
	self refresh
]

{ #category : 'initialization' }
FRFavoritesPresenter >> initializeRowMenu [
	"The context menu of a row: Edit, Remove from favorites, Define bottom branch, and for Pharo external projects the integration branch and its pull request."

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
					action: [ self removeSelectedFavorite ] ];
		addActionWith: [ :action |
				action
					name: 'Define bottom branch';
					description: 'Create and check out the branch <ISO date>-Bottom at the current commit of the clone';
					actionEnabled: [ self canDefineBottomBranchOfSelection ];
					action: [ self defineBottomBranchOf: self selectedFavorite ] ].
	self initializePharoIntegrationMenu
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
					do: [ :error | self application reportFailure: error messageText titled: ('Loading {1} failed' format: { aFavorite name }) ].
				self refresh ]
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
FRFavoritesPresenter >> openPharoIntegrationPullRequestOf: aFavorite [
	"Open the pull request of the Pharo integration branch of aFavorite, after checking that its branch is on its fork."

	| integration |
	integration := self application newPharoIntegrationFor: aFavorite.
	[
		(integration isIntegrationBranchPushed or: [
				 self application confirmUnpushed:
					 ('{1} of {2} is not on your fork with all its commits: the Pharo build cannot load it. Open the pull request anyway?'
						  format: {
								  integration integrationBranchName.
								  aFavorite name }) ]) ifTrue: [ self application openPullRequestFor: integration ] ]
		on: Error
		do: [ :error | self application reportFailure: error messageText titled: 'Pharo integration PR' ]
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

{ #category : 'actions' }
FRFavoritesPresenter >> reopen [
	"Close this window and open a new one, built by the code now in the image."

	| app |
	app := self application.
	self window close.
	app start
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

{ #category : 'actions' }
FRFavoritesPresenter >> updateButton [

	^ updateButton
]

{ #category : 'actions' }
FRFavoritesPresenter >> updateFavrepo [
	"Update Favrepo itself in this image. When new code was loaded, open the window again so that it is built by the new code."

	| updater text |
	updater := self application selfUpdater.
	text := [ updater update ]
		        on: Error
		        do: [ :error |
		        ^ self application reportFailure: 'Favrepo could not be updated: ' , error messageText titled: 'Update Favrepo' ].
	self application report: text titled: 'Update Favrepo'.
	updater updated ifTrue: [ self reopen ]
]
