"
I am one row of the favorites window: initial, name, owner/project, Clone button, branch, Load button and check mark. The same controls are there in every state; a button that cannot be used is dimmed.

## Responsibility:

- I show a favorite that is not loaded in grey (style `frNotLoaded`). Not cloned: only Clone is enabled. Cloned: only Load and the branch are enabled.
- I show a loaded favorite normally with a check mark, Clone and Load dimmed; its branch is the one checked out and cannot be changed here.
- Once cloned, I offer the clone's branches (local, then remote as of the last fetch) and tags, and Other… to type a name.

## Collaborators:

- `FRFavoritesPresenter` (given with `favoritesPresenter:`) loads the favorite and saves its branch for me.
- `FRCatalog` and `FRRepositoryInfo` give the state and the versions I show.
- `FRApplication` asks for a typed branch name.

## Public API and Key Messages

- `favoritesPresenter:` then `setFavorite: aFavorite catalog: aCatalog`
- `favorite`, `state`, `isGrey`, `isCloneEnabled`, `isLoadEnabled`, `showsCheck`, `isBranchEditable`, `branchChoices`, `selectedBranch`, `stateDescription`
- `beCloning` and `beLoading` while a clone or a load runs.

See `FRFavoriteRowPresenter class >> #exampleNotCloned` and `#exampleLoaded`.

### Implementation Points

`isUpdating` keeps the drop list from reporting its own updates as user choices. I do not call my `owner`: `SpEasyComponentListPresenter` re-parents its rows to an inner presenter when it is built.
"
Class {
	#name : 'FRFavoriteRowPresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'favorite',
		'state',
		'info',
		'isLoading',
		'isUpdating',
		'initialLabel',
		'nameLabel',
		'pathLabel',
		'branchDropDown',
		'loadButton',
		'loadedLabel',
		'favoritesPresenter',
		'cloneButton'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'examples' }
FRFavoriteRowPresenter class >> exampleLoaded [
	"A row with a check mark: Microdown is loaded, on the tag v2.9.3."

	<sampleInstance>
	^ (FRApplication exampleInMemory instantiate: self)
		  setFavorite: (FRFavorite url: 'git@github.com:pillar-markup/Microdown.git') catalog: FRCatalog exampleSmallImage;
		  yourself
]

{ #category : 'examples' }
FRFavoriteRowPresenter class >> exampleNotCloned [
	"A grey row with a Load button: Seaside is not in the small example image."

	<sampleInstance>
	^ (FRApplication exampleInMemory instantiate: self)
		  setFavorite: FRFavorite exampleOnDefaultBranch catalog: FRCatalog exampleSmallImage;
		  yourself
]

{ #category : 'private' }
FRFavoriteRowPresenter >> askForBranch [

	| answer |
	answer := self application request: 'Branch or tag name' initialAnswer: favorite branch titled: favorite name.
	answer isEmptyOrNil
		ifTrue: [ self updatePresenters ]
		ifFalse: [ favoritesPresenter changeBranch: answer of: favorite ]
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> beCloning [
	"A clone of my favorite is running: disable the Clone button until it ends."

	cloneButton
		help: 'Cloning…';
		disable
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> beLoading [
	"A load of my favorite is running: disable the Load button until it ends."

	isLoading := true.
	loadButton
		label: 'Loading';
		disable
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> branchChoices [
	"The clone's branches (local, then remote) and tags, plus Other… to type one; only the shown branch before cloning or once loaded."

	| choices |
	self isBranchEditable ifFalse: [ ^ { self selectedBranch } ].
	choices := OrderedCollection withAll: info versions.
	(choices includes: self selectedBranch) ifFalse: [ choices addFirst: self selectedBranch ].
	choices add: self otherChoice.
	^ choices asArray
]

{ #category : 'private' }
FRFavoriteRowPresenter >> branchChosen: aChoice [

	aChoice ifNil: [ ^ self ].
	aChoice = self otherChoice ifTrue: [ ^ self askForBranch ].
	aChoice = favorite branch ifFalse: [ favoritesPresenter changeBranch: aChoice of: favorite ]
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> branchHelp [

	state = #cloned ifTrue: [ ^ 'Branch or tag to load' ].
	state = #loaded ifTrue: [ ^ 'Checked out in this image; switch it with Iceberg' ].
	^ 'Branch or tag to clone; clone it to choose among its branches'
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> checkHelp [

	^ self showsCheck
		  ifTrue: [ 'Loaded in this image' ]
		  ifFalse: [ '' ]
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> checkText [

	^ self showsCheck
		  ifTrue: [ String with: (Character value: 16r2713) ]
		  ifFalse: [ '' ]
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> cloneHelp [

	^ self isCloneEnabled
		  ifTrue: [ 'Clone it with Iceberg' ]
		  ifFalse: [ 'Already cloned' ]
]

{ #category : 'initialization' }
FRFavoriteRowPresenter >> connectPresenters [

	branchDropDown whenSelectedItemChangedDo: [ :choice | isUpdating ifFalse: [ self branchChosen: choice ] ]
]

{ #category : 'layout' }
FRFavoriteRowPresenter >> defaultLayout [
	"The same controls in every state, so nothing moves: Clone and Load are dimmed when they cannot be used."

	^ SpBoxLayout newLeftToRight
		  spacing: 8;
		  vAlignCenter;
		  add: initialLabel width: 24;
		  add: (SpBoxLayout newTopToBottom
				   add: nameLabel expand: false;
				   add: pathLabel expand: false;
				   yourself);
		  add: cloneButton withConstraints: [ :constraints |
			  constraints
				  width: 30;
				  height: 26 ];
		  add: branchDropDown withConstraints: [ :constraints |
			  constraints
				  width: 130;
				  height: 26 ];
		  add: loadButton withConstraints: [ :constraints |
			  constraints
				  width: 60;
				  height: 26 ];
		  add: loadedLabel width: 16;
		  yourself
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> favorite [

	^ favorite
]

{ #category : 'initialization' }
FRFavoriteRowPresenter >> favoritesPresenter: aFavoritesPresenter [
	"The main window that loads and saves for me. Not my owner: the component list re-parents its rows when it is built."

	favoritesPresenter := aFavoritesPresenter
]

{ #category : 'accessing - display' }
FRFavoriteRowPresenter >> initialText [

	^ initialLabel label
]

{ #category : 'initialization' }
FRFavoriteRowPresenter >> initialize [

	super initialize.
	isLoading := false.
	isUpdating := false.
	state := #notCloned
]

{ #category : 'initialization' }
FRFavoriteRowPresenter >> initializePresenters [

	"Bold through the text, not a Font style: SpFontStyle makes shared fonts bold."
	initialLabel := self newLabel
		                addStyle: 'frInitial';
		                displayBold: [ :text | true ];
		                yourself.
	nameLabel := self newLabel
		             displayBold: [ :text | true ];
		             yourself.
	pathLabel := self newLabel.
	cloneButton := self newButton
		               icon: (self iconNamed: #down);
		               action: [ favoritesPresenter cloneFavorite: favorite ];
		               yourself.
	branchDropDown := self newDropList.
	loadButton := self newButton
		              label: 'Load';
		              action: [ favoritesPresenter loadFavorite: favorite ];
		              yourself.
	loadedLabel := self newLabel
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isBranchEditable [

	^ state = #cloned
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isCloneEnabled [

	^ state = #notCloned
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isGrey [

	^ self isLoaded not
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isLoadEnabled [

	^ state = #cloned
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isLoaded [

	^ state = #loaded
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> isLoading [

	^ isLoading
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> loadHelp [

	state = #notCloned ifTrue: [ ^ 'Clone it first' ].
	state = #loaded ifTrue: [ ^ 'Already loaded' ].
	^ 'Load the baseline of this branch'
]

{ #category : 'accessing - display' }
FRFavoriteRowPresenter >> nameText [

	^ nameLabel label
]

{ #category : 'private' }
FRFavoriteRowPresenter >> otherChoice [

	^ 'Other' , (String with: (Character value: 16r2026))
]

{ #category : 'accessing - display' }
FRFavoriteRowPresenter >> pathText [

	^ pathLabel label
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> selectedBranch [
	"The checked-out branch when loaded, or when the favorite asks for the default branch of a clone; the favorite's own branch otherwise."

	(info isNil or: [ info currentVersion isNil ]) ifTrue: [ ^ favorite branch ].
	(self isLoaded or: [ favorite isDefaultBranch ]) ifTrue: [ ^ info currentVersion ].
	^ favorite branch
]

{ #category : 'initialization' }
FRFavoriteRowPresenter >> setFavorite: aFavorite catalog: aCatalog [
	"Show aFavorite as it is in the image described by aCatalog."

	favorite := aFavorite.
	info := aCatalog infoFor: aFavorite.
	state := aCatalog stateOf: aFavorite.
	self updatePresenters
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> showsCheck [

	^ self isLoaded
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> state [

	^ state
]

{ #category : 'accessing - display' }
FRFavoriteRowPresenter >> stateDescription [

	state = #loaded ifTrue: [ ^ 'Loaded' ].
	state = #cloned ifTrue: [ ^ 'Cloned, not loaded' ].
	^ 'Not cloned'
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> updateBranchDropDown [

	isUpdating := true.
	[
		branchDropDown items: self branchChoices.
		branchDropDown selectItem: self selectedBranch.
		branchDropDown enabled: self isBranchEditable ] ensure: [ isUpdating := false ].
	branchDropDown help: self branchHelp
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> updateButtons [

	cloneButton
		enabled: self isCloneEnabled;
		help: self cloneHelp.
	loadButton
		enabled: self isLoadEnabled;
		help: self loadHelp
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> updateLabels [

	initialLabel label: favorite initial.
	nameLabel label: favorite name.
	pathLabel label: favorite projectPath.
	{
		initialLabel.
		nameLabel.
		pathLabel } do: [ :each |
			self isGrey
				ifTrue: [ each addStyle: 'frNotLoaded' ]
				ifFalse: [ each removeStyle: 'frNotLoaded' ].
			each help: self stateDescription ].
	loadedLabel
		label: self checkText;
		help: self checkHelp
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> updatePresenters [

	self
		updateLabels;
		updateBranchDropDown;
		updateButtons
]
