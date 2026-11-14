"
I test the favorites window without opening it, except to check that only one window opens.
"
Class {
	#name : 'FRFavoritesPresenterTest',
	#superclass : 'FRSpecTestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'helpers' }
FRFavoritesPresenterTest >> clickCloneOf: aName [

	((presenter rowNamed: aName) presenters detect: [ :each |
		 (each isKindOf: SpButtonPresenter) and: [ each help = 'Clone it with Iceberg' ] ]) click
]

{ #category : 'helpers' }
FRFavoritesPresenterTest >> clickLoadOf: aName [

	((presenter rowNamed: aName) presenters detect: [ :each |
		 (each isKindOf: SpButtonPresenter) and: [ each label = 'Load' ] ]) click
]

{ #category : 'helpers' }
FRFavoritesPresenterTest >> doubleClick: aName [

	| browsed |
	browsed := OrderedCollection new.
	application repositoryBrowser: [ :repository | browsed add: repository ].
	presenter favoritesList contentView doActivateAtIndex: (presenter rows indexOf: (presenter rowNamed: aName)).
	^ browsed asArray
]

{ #category : 'helpers' }
FRFavoritesPresenterTest >> pick: aBranch in: aName [

	((presenter rowNamed: aName) presenters detect: [ :each | each isKindOf: SpDropListPresenter ])
		selectItem: aBranch
]

{ #category : 'running' }
FRFavoritesPresenterTest >> setUp [

	super setUp.
	presenter := application instantiate: FRFavoritesPresenter
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testBranchChoicesKeepTheFavoriteBranch [

	| row |
	row := presenter rowNamed: 'Seaside'.
	self assert: row branchChoices equals: #( 'master' ).
	self assert: row selectedBranch equals: 'master'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testBranchChoicesOfAClone [

	| row |
	row := presenter rowNamed: 'Favrepo'.
	self assert: row branchChoices equals: #( 'master' 'dev' 'Other…' ).
	self assert: row selectedBranch equals: 'master'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testBranchPickedInABuiltWindowIsSaved [

	presenter build.
	self pick: 'dev' in: 'Favrepo'.
	self assert: (store favoriteNamed: 'Favrepo' ifNone: [ nil ]) branch equals: 'dev'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testBuildingRowsLeavesTheSharedFontsRegular [

	| regular |
	regular := { 10. 14 } collect: [ :size |
		           LogicalFont
			           familyName: StandardFonts defaultFont familyName
			           pointSize: size ].
	presenter build.
	self
		assert: (regular collect: [ :each | each weightValue ])
		equals: #( 400 400 )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testChangeBranchIsSaved [

	presenter changeBranch: 'dev' of: (presenter rowNamed: 'Favrepo') favorite.
	self assert: (store favoriteNamed: 'Favrepo' ifNone: [ nil ]) branch equals: 'dev'.
	self assert: (presenter rowNamed: 'Favrepo') selectedBranch equals: 'dev'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testCloneButtonOfABuiltWindowOnlyClones [

	presenter build.
	self clickCloneOf: 'Seaside'.
	self assert: (loader cloned collect: [ :each | each name ] as: Array) equals: #( 'Seaside' ).
	self assert: loader loaded isEmpty
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testClonedRowIsGreyAndCanBeLoaded [

	| row |
	row := presenter rowNamed: 'Favrepo'.
	self assert: row isGrey.
	self deny: row isCloneEnabled.
	self assert: row isLoadEnabled.
	self assert: row isBranchEditable.
	self deny: row showsCheck.
	self assert: row stateDescription equals: 'Cloned, not loaded'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testDoubleClickOnANotClonedFavoriteOpensNothing [

	self assert: (self doubleClick: 'Seaside') isEmpty
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testDoubleClickOpensTheIcebergRepository [

	self assert: (self doubleClick: 'Favrepo') equals: #( #favrepoRepository )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testEveryRowShowsTheSameControls [

	| shapes |
	shapes := presenter rows collect: [ :row |
		          row layout children collect: [ :each | each class ] as: Array ].
	self assert: shapes asSet size equals: 1.
	self
		assert: ((presenter rowNamed: 'Roassal') layout children count: [ :each | each isKindOf: SpButtonPresenter ])
		equals: 2
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testIcebergButtonOpensIceberg [

	| opened |
	opened := false.
	application icebergOpener: [ opened := true ].
	presenter icebergButton click.
	self assert: opened
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testLoadButtonLoadsTheBranchPickedInTheDropList [

	self pick: 'dev' in: 'Favrepo'.
	self clickLoadOf: 'Favrepo'.
	self assert: (loader loaded collect: [ :each | each branch ] as: Array) equals: #( 'dev' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testLoadButtonOfABuiltWindowLoads [

	presenter build.
	self clickLoadOf: 'Favrepo'.
	self assert: (loader loaded collect: [ :each | each name ] as: Array) equals: #( 'Favrepo' )
]

{ #category : 'tests - errors' }
FRFavoritesPresenterTest >> testLoadFailureKeepsTheRowGreyAndIsReported [

	loader failWith: 'no baseline'.
	presenter loadFavorite: (presenter rowNamed: 'Favrepo') favorite.
	self assert: (presenter rowNamed: 'Favrepo') isGrey.
	self assert: (presenter rowNamed: 'Favrepo') isLoadEnabled.
	self assert: application lastFailure equals: 'no baseline'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testLoadUsesTheLoader [

	presenter loadFavorite: (presenter rowNamed: 'Seaside') favorite.
	self assert: (loader loaded collect: [ :each | each name ] as: Array) equals: #( 'Seaside' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testLoadedRowIsNotGreyAndShowsCheck [

	| row |
	row := presenter rowNamed: 'Roassal'.
	self deny: row isGrey.
	self deny: row isCloneEnabled.
	self deny: row isLoadEnabled.
	self assert: row showsCheck
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testLoadedRowShowsCheckedOutBranchAndCannotChangeIt [

	| row |
	store add: (FRFavorite url: 'git@github.com:pillar-markup/Microdown.git' name: 'Microdown' branch: 'dev').
	presenter refresh.
	row := presenter rowNamed: 'Microdown'.
	self assert: row selectedBranch equals: 'v2.9.3'.
	self deny: row isBranchEditable
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testNotClonedRowIsGreyAndCanOnlyBeCloned [

	| row |
	row := presenter rowNamed: 'Seaside'.
	self assert: row isGrey.
	self assert: row isCloneEnabled.
	self deny: row isLoadEnabled.
	self deny: row isBranchEditable.
	self deny: row showsCheck.
	self assert: row stateDescription equals: 'Not cloned'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRefreshButtonTakesBranchesFromIceberg [

	presenter refreshButton click.
	self assert: (store favoriteNamed: 'Favrepo' ifNone: [ nil ]) branch equals: 'master'.
	self assert: (presenter rowNamed: 'Favrepo') selectedBranch equals: 'master'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRefreshReadsTheStoreAgain [

	store add: (FRFavorite url: 'git@github.com:FedeLoch/Ume.git').
	presenter refresh.
	self assert: (presenter rows collect: [ :each | each favorite name ] as: Array) equals: #( 'Favrepo' 'Roassal' 'Seaside'
	   'Ume' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRemoveFavorite [

	presenter removeFavorite: (presenter rowNamed: 'Seaside') favorite.
	self assert: self storedNames equals: #( 'Favrepo' 'Roassal' ).
	self assert: (presenter rows collect: [ :each | each favorite name ] as: Array) equals: #( 'Favrepo' 'Roassal' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRemoveSelectedFavorite [

	presenter selectFavoriteNamed: 'Seaside'.
	presenter removeSelectedFavorite.
	self assert: self storedNames equals: #( 'Favrepo' 'Roassal' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRowNameIsBold [

	| row nameLabel |
	row := presenter rowNamed: 'Seaside'.
	nameLabel := row presenters detect: [ :each |
		             (each isKindOf: SpLabelPresenter) and: [
			             each label = 'Seaside' ] ].
	self assert: (nameLabel displayBold value: nameLabel label)
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRowShowsInitialNameAndProjectPath [

	| row |
	row := presenter rowNamed: 'Seaside'.
	self assert: row initialText equals: 'S'.
	self assert: row nameText equals: 'Seaside'.
	self assert: row pathText equals: 'SeasideSt/Seaside'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRowsFollowTheStoreSortedByName [

	self assert: (presenter rows collect: [ :each | each favorite name ] as: Array) equals: #( 'Favrepo' 'Roassal' 'Seaside' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRowsOfABuiltWindowGetTheirOwnHeight [
	"Rows have two lines: the table must use the height each row asks for, not its default row height."

	| table |
	presenter build.
	table := presenter favoritesList contentView adapter widget.
	self assert: presenter rows isNotEmpty.
	1 to: presenter rows size do: [ :index |
	self assert: (table container rowHeight: index default: table rowHeight) equals: (table dataSource rowHeight: index) ]
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testRunOpensOnlyOneWindow [

	application run.
	application run.
	self assert: application windows size equals: 1
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testSelectFavoriteNamed [

	presenter selectFavoriteNamed: 'seaside'.
	self assert: presenter selectedFavorite name equals: 'Seaside'
]
