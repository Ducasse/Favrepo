"
I test the favorites window without opening it, except to check that only one window opens.
"
Class {
	#name : 'FRFavoritesPresenterTest',
	#superclass : 'FRSpecTestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'running' }
FRFavoritesPresenterTest >> setUp [

	super setUp.
	presenter := application instantiate: FRFavoritesPresenter
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testBranchChoicesKeepTheFavoriteBranch [

	| row |
	row := presenter rowNamed: 'Seaside'.
	self assert: row branchChoices equals: #( 'default' 'master' 'Other…' ).
	self assert: row selectedBranch equals: 'master'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testBranchChoicesOfAClone [

	self assert: (presenter rowNamed: 'Favrepo') branchChoices equals: #( 'default' 'master' 'dev' 'Other…' )
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testChangeBranchIsSaved [

	presenter changeBranch: 'dev' of: (presenter rowNamed: 'Favrepo') favorite.
	self assert: (store favoriteNamed: 'Favrepo' ifNone: [ nil ]) branch equals: 'dev'.
	self assert: (presenter rowNamed: 'Favrepo') selectedBranch equals: 'dev'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testClonedRowIsGreyWithLoadButton [

	| row |
	row := presenter rowNamed: 'Favrepo'.
	self assert: row isGrey.
	self assert: row showsLoadButton.
	self assert: row stateDescription equals: 'Cloned, not loaded'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testLoadFailureKeepsTheRowGreyAndIsReported [

	loader failWith: 'no baseline'.
	presenter loadFavorite: (presenter rowNamed: 'Seaside') favorite.
	self assert: (presenter rowNamed: 'Seaside') isGrey.
	self assert: (presenter rowNamed: 'Seaside') showsLoadButton.
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
	self deny: row showsLoadButton.
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
FRFavoritesPresenterTest >> testNotClonedRowIsGreyWithLoadButton [

	| row |
	row := presenter rowNamed: 'Seaside'.
	self assert: row isGrey.
	self assert: row showsLoadButton.
	self deny: row showsCheck.
	self assert: row stateDescription equals: 'Not cloned'
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
FRFavoritesPresenterTest >> testSelectFavoriteNamed [

	presenter selectFavoriteNamed: 'seaside'.
	self assert: presenter selectedFavorite name equals: 'Seaside'
]

{ #category : 'tests' }
FRFavoritesPresenterTest >> testStartOpensOnlyOneWindow [

	application start.
	application start.
	self assert: application windows size equals: 1
]
