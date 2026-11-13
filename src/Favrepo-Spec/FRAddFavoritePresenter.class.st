"
I am the dialog to add a favorite, or to edit one.

## Responsibility:

- When adding, I list the repositories of the image that are not favorites yet, with a filter; picking one fills the URL, the name and its current branch or tag.
- I propose the project name of a valid URL unless the user typed another name, and only accept a valid URL with a name.
- On accept I add or replace the favorite in the store; for a duplicate name I tell the user and answer the existing favorite.

## Collaborators:

- `FRCatalog` gives the repositories to list; `FRRepositoryInfo` fills the fields.
- `FRFavoriteStore` saves the favorite.
- `FRFavoritesPresenter` opens me and selects the favorite I answer.

## Public API and Key Messages

- `beEditing: aFavorite` turns me into the edit dialog (no list).
- `whenAcceptedDo: aBlock`, `accept`, `canAccept`.
- `filterText:`, `pickRepositoryNamed:`, `urlText:`, `nameText:`, `urlText`, `nameText`, `branchText`, `branchChoices`, `repositoryNames`.

See `FRAddFavoritePresenter class >> #exampleInMemory` and `#exampleEditing`, and run `FRAddFavoritePresenter class >> #scriptOpenAddDialog`.
"
Class {
	#name : 'FRAddFavoritePresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'editedFavorite',
		'autoName',
		'acceptBlock',
		'filterInput',
		'repositoryList',
		'urlInput',
		'nameInput',
		'branchInput',
		'branchDropDown',
		'repositories'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'examples' }
FRAddFavoritePresenter class >> exampleEditing [
	"The edit dialog presenter on Mustache: no repository list."

	<sampleInstance>
	^ (FRApplication exampleInMemory instantiate: self)
		  beEditing: FRFavorite exampleMustache;
		  yourself
]

{ #category : 'examples' }
FRAddFavoritePresenter class >> exampleInMemory [
	"The add dialog presenter, listing the small example image's repositories that are not favorites yet."

	<sampleInstance>
	^ FRApplication exampleInMemory instantiate: self
]

{ #category : 'script' }
FRAddFavoritePresenter class >> scriptOpenAddDialog [
	"Open the add dialog on the repositories of this image; adding writes only to an in-memory store."

	<example>
	^ (FRApplication new
		   store: FRFavoriteStore exampleInMemory;
		   instantiate: self) openDialog
]

{ #category : 'actions' }
FRAddFavoritePresenter >> accept [
	"Save the favorite described by the fields; answer it, or the existing favorite with the same name."

	| favorite |
	favorite := FRFavorite url: self urlText name: self nameText branch: self branchText.
	favorite := [
		            editedFavorite
			            ifNil: [ self application store add: favorite ]
			            ifNotNil: [ self application store replace: editedFavorite with: favorite ] ]
		            on: FRDuplicateFavoriteError
		            do: [ :error |
				            self application tell: error messageText.
				            error favorite ].
	acceptBlock value: favorite.
	^ favorite
]

{ #category : 'private' }
FRAddFavoritePresenter >> acceptLabel [

	^ editedFavorite ifNil: [ 'Add' ] ifNotNil: [ 'Save' ]
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> beEditing: aFavorite [
	"Edit aFavorite instead of adding a new one; the repository list is not shown."

	editedFavorite := aFavorite.
	autoName := aFavorite name.
	urlInput text: aFavorite url.
	nameInput text: aFavorite name.
	branchInput text: aFavorite branch.
	self updateBranchChoicesFrom: (self application catalog infoFor: aFavorite)
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> branchChoices [

	^ branchDropDown items asArray
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> branchText [

	^ branchInput text asString
]

{ #category : 'testing' }
FRAddFavoritePresenter >> canAccept [

	^ (FRFavorite isValidUrl: self urlText) and: [ self nameText trimBoth isNotEmpty ]
]

{ #category : 'initialization' }
FRAddFavoritePresenter >> connectPresenters [

	filterInput whenTextChangedDo: [ self updateRepositoryList ].
	repositoryList whenSelectionChangedDo: [ :selection | selection selectedItem ifNotNil: [ :info | self pick: info ] ].
	urlInput whenTextChangedDo: [ :text | self urlChanged: text ].
	branchDropDown whenSelectedItemChangedDo: [ :choice | choice ifNotNil: [ branchInput text: choice ] ]
]

{ #category : 'layout' }
FRAddFavoritePresenter >> defaultLayout [

	| fields |
	fields := SpBoxLayout newTopToBottom
		          spacing: 4;
		          add: (self fieldNamed: 'URL:' with: urlInput) expand: false;
		          add: (self fieldNamed: 'Name:' with: nameInput) expand: false;
		          add: (self fieldNamed: 'Branch:' with: (SpBoxLayout newLeftToRight
						            spacing: 4;
						            add: branchInput;
						            add: branchDropDown width: 140;
						            yourself))
		          expand: false;
		          yourself.
	^ self hasRepositoryList
		  ifTrue: [
				  SpBoxLayout newTopToBottom
					  spacing: 4;
					  add: filterInput expand: false;
					  add: repositoryList;
					  add: fields expand: false;
					  yourself ]
		  ifFalse: [
				  SpBoxLayout newTopToBottom
					  add: fields expand: false;
					  yourself ]
]

{ #category : 'layout' }
FRAddFavoritePresenter >> fieldNamed: aLabel with: aPresenterOrLayout [

	^ SpBoxLayout newLeftToRight
		  spacing: 4;
		  add: aLabel width: 60;
		  add: aPresenterOrLayout;
		  yourself
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> filterText: aString [

	filterInput text: aString
]

{ #category : 'testing' }
FRAddFavoritePresenter >> hasRepositoryList [

	^ editedFavorite isNil
]

{ #category : 'initialization' }
FRAddFavoritePresenter >> initialize [

	super initialize.
	autoName := ''.
	acceptBlock := [ :favorite |  ]
]

{ #category : 'initialization' }
FRAddFavoritePresenter >> initializeDialogWindow: aDialogWindowPresenter [

	| okButton |
	aDialogWindowPresenter addButton: 'Cancel' do: [ :dialog |
			dialog
				triggerCancelAction;
				close ].
	okButton := aDialogWindowPresenter addDefaultButton: self acceptLabel do: [ :dialog |
			            self accept.
			            dialog close ].
	okButton enabled: self canAccept.
	urlInput whenTextChangedDo: [ okButton enabled: self canAccept ].
	nameInput whenTextChangedDo: [ okButton enabled: self canAccept ]
]

{ #category : 'initialization' }
FRAddFavoritePresenter >> initializePresenters [

	repositories := self application catalog availableFor: self application store favorites.
	filterInput := self newTextInput
		               placeholder: 'Filter the repositories of this image';
		               yourself.
	repositoryList := self newEasyColumnView
		                  addColumn: (SpStringTableColumn title: 'Name' evaluated: [ :info | info name ]);
		                  addColumn: (SpStringTableColumn title: 'Project' evaluated: [ :info | self projectTextOf: info ]);
		                  yourself.
	urlInput := self newTextInput
		            placeholder: 'git@github.com:owner/project.git';
		            yourself.
	nameInput := self newTextInput.
	branchInput := self newTextInput
		               text: FRFavorite defaultBranch;
		               yourself.
	branchDropDown := self newDropList
		                  help: 'Branches and tags of the picked repository';
		                  yourself.
	self updateRepositoryList.
	self updateBranchChoicesFrom: nil
]

{ #category : 'initialization' }
FRAddFavoritePresenter >> initializeWindow: aWindowPresenter [

	super initializeWindow: aWindowPresenter.
	aWindowPresenter
		title: (editedFavorite ifNil: [ 'Add favorite' ] ifNotNil: [ 'Edit favorite' ]);
		initialExtent: (self hasRepositoryList
				 ifTrue: [ 520 @ 460 ]
				 ifFalse: [ 520 @ 200 ])
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> nameText [

	^ nameInput text asString
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> nameText: aString [

	nameInput text: aString
]

{ #category : 'actions' }
FRAddFavoritePresenter >> pick: aRepositoryInfo [
	"Fill the fields from a repository of the image."

	| proposed |
	proposed := aRepositoryInfo asFavorite.
	autoName := proposed name.
	urlInput text: proposed url.
	nameInput text: proposed name.
	branchInput text: proposed branch.
	self updateBranchChoicesFrom: aRepositoryInfo
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> pickRepositoryNamed: aString [

	repositoryList selectItem: (repositoryList items detect: [ :each | each hasName: aString ])
]

{ #category : 'private' }
FRAddFavoritePresenter >> projectTextOf: aRepositoryInfo [

	^ aRepositoryInfo hasUrl
		  ifTrue: [ aRepositoryInfo asFavorite projectPath ]
		  ifFalse: [ '(no URL: enter it below)' ]
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> repositoryNames [

	^ repositoryList items collect: [ :each | each name ] as: Array
]

{ #category : 'private' }
FRAddFavoritePresenter >> updateBranchChoicesFrom: aRepositoryInfoOrNil [

	| choices |
	choices := OrderedCollection with: FRFavorite defaultBranch.
	aRepositoryInfoOrNil ifNotNil: [ choices addAll: aRepositoryInfoOrNil versions ].
	branchDropDown items: choices removeDuplicates asArray
]

{ #category : 'private' }
FRAddFavoritePresenter >> updateRepositoryList [

	| filter |
	filter := filterInput text asString trimBoth.
	repositoryList items: (filter
			 ifEmpty: [ repositories ]
			 ifNotEmpty: [ repositories select: [ :each | each name includesSubstring: filter caseSensitive: false ] ])
]

{ #category : 'actions' }
FRAddFavoritePresenter >> urlChanged: aText [
	"Propose the project name of a valid URL, unless the user typed another name."

	| project |
	(FRFavorite isValidUrl: aText asString) ifFalse: [ ^ self ].
	(self nameText isEmpty or: [ self nameText = autoName ]) ifFalse: [ ^ self ].
	project := (FRFavorite url: aText asString) name.
	autoName := project.
	nameInput text: project
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> urlText [

	^ urlInput text asString
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> urlText: aString [

	urlInput text: aString
]

{ #category : 'accessing' }
FRAddFavoritePresenter >> whenAcceptedDo: aBlock [
	"aBlock receives the favorite to select after accepting: the new one, or the existing one with the same name."

	acceptBlock := aBlock
]
