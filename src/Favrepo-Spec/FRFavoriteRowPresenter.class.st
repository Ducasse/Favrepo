"
I am one row of the favorites window: initial, name, owner/project, branch and Load button or check mark.

## Responsibility:

- I show a favorite that is not loaded in grey (style `frNotLoaded`) with a Load button; a tooltip says whether it is cloned or not.
- I show a loaded favorite normally with a check mark; its branch is the one checked out and cannot be changed here.
- I offer `default`, the branches and tags of the local clone, the favorite branch, and Other... to type a name.

## Collaborators:

- `FRFavoritesPresenter` is my owner: I ask it to load the favorite or change its branch.
- `FRCatalog` and `FRRepositoryInfo` give the state and the versions I show.
- `FRApplication` asks for a typed branch name.

## Public API and Key Messages

- `setFavorite: aFavorite catalog: aCatalog`
- `favorite`, `state`, `isGrey`, `showsLoadButton`, `showsCheck`, `isBranchEditable`, `branchChoices`, `selectedBranch`, `stateDescription`
- `beLoading` while a load runs.

See `FRFavoriteRowPresenter class >> #exampleNotCloned` and `#exampleLoaded`.

### Implementation Points

My layout depends on the state, so it is set by `setFavorite:catalog:`. `isUpdating` keeps the drop list from reporting its own updates as user choices.
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
		'loadedLabel'
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
		ifFalse: [ self owner changeBranch: answer of: favorite ]
]

{ #category : 'updating' }
FRFavoriteRowPresenter >> beLoading [
	"A load of my favorite is running: disable the Load button until it ends."

	isLoading := true.
	loadButton
		label: 'Loading';
		disable
]

{ #category : 'accessing - display' }
FRFavoriteRowPresenter >> branchChoices [
	"default, the clone's branches and tags, the favorite's branch, and Other… to type one."

	| choices |
	self isLoaded ifTrue: [ ^ { self selectedBranch } ].
	choices := OrderedCollection with: FRFavorite defaultBranch.
	info ifNotNil: [ choices addAll: info versions ].
	choices add: favorite branch.
	choices := choices asOrderedCollection removeDuplicates.
	choices add: self otherChoice.
	^ choices asArray
]

{ #category : 'private' }
FRFavoriteRowPresenter >> branchChosen: aChoice [

	aChoice ifNil: [ ^ self ].
	aChoice = self otherChoice ifTrue: [ ^ self askForBranch ].
	aChoice = favorite branch ifFalse: [ self owner changeBranch: aChoice of: favorite ]
]

{ #category : 'initialization' }
FRFavoriteRowPresenter >> connectPresenters [

	branchDropDown whenSelectedItemChangedDo: [ :choice | isUpdating ifFalse: [ self branchChosen: choice ] ]
]

{ #category : 'layout' }
FRFavoriteRowPresenter >> defaultLayout [
	"The Load button for a favorite that is not loaded, a check mark for a loaded one."

	^ SpBoxLayout newLeftToRight
		  spacing: 8;
		  vAlignCenter;
		  add: initialLabel width: 24;
		  add: (SpBoxLayout newTopToBottom
				   add: nameLabel expand: false;
				   add: pathLabel expand: false;
				   yourself);
		  add: branchDropDown withConstraints: [ :constraints |
			  constraints
				  width: 130;
				  height: 26 ];
		  add: (self showsLoadButton
				   ifTrue: [ loadButton ]
				   ifFalse: [ loadedLabel ])
		  withConstraints: [ :constraints |
				  constraints
					  width: 70;
					  height: 26 ];
		  yourself
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> favorite [

	^ favorite
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

	initialLabel := self newLabel
		                addStyle: 'frInitial';
		                yourself.
	nameLabel := self newLabel
		             addStyle: 'frName';
		             yourself.
	pathLabel := self newLabel.
	branchDropDown := self newDropList.
	loadButton := self newButton
		              label: 'Load';
		              action: [ self owner loadFavorite: favorite ];
		              yourself.
	loadedLabel := self newLabel
		               label: (String with: (Character value: 16r2713));
		               help: 'Loaded in this image';
		               yourself
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isBranchEditable [

	^ self isLoaded not
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isGrey [

	^ self isLoaded not
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> isLoaded [

	^ state = #loaded
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> isLoading [

	^ isLoading
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

{ #category : 'accessing - display' }
FRFavoriteRowPresenter >> selectedBranch [
	"The checked-out branch for a loaded favorite, the favorite's own branch otherwise."

	^ (self isLoaded and: [ info isNotNil and: [ info currentVersion isNotNil ] ])
		  ifTrue: [ info currentVersion ]
		  ifFalse: [ favorite branch ]
]

{ #category : 'accessing' }
FRFavoriteRowPresenter >> setFavorite: aFavorite catalog: aCatalog [
	"Show aFavorite as it is in the image described by aCatalog."

	favorite := aFavorite.
	info := aCatalog infoFor: aFavorite.
	state := aCatalog stateOf: aFavorite.
	self updatePresenters.
	self layout: self defaultLayout
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> showsCheck [

	^ self isLoaded
]

{ #category : 'testing' }
FRFavoriteRowPresenter >> showsLoadButton [

	^ self isLoaded not
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

{ #category : 'private' }
FRFavoriteRowPresenter >> updatePresenters [

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
	isUpdating := true.
	[
		branchDropDown items: self branchChoices.
		branchDropDown selectItem: self selectedBranch.
		branchDropDown enabled: self isBranchEditable ] ensure: [ isUpdating := false ].
	branchDropDown help: (self isBranchEditable
			 ifTrue: [ 'Branch or tag to load' ]
			 ifFalse: [ 'Checked out in this image; switch it with Iceberg' ])
]
