"
I test the add and edit dialog without opening it.
"
Class {
	#name : 'FRAddFavoritePresenterTest',
	#superclass : 'FRSpecTestCase',
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'running' }
FRAddFavoritePresenterTest >> setUp [

	super setUp.
	presenter := application instantiate: FRAddFavoritePresenter
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testAcceptAddsTheFavorite [

	presenter pickRepositoryNamed: 'Microdown'.
	presenter accept.
	self assert: self storedNames equals: #( 'Favrepo' 'Microdown' 'Roassal' 'Seaside' ).
	self assert: (store favoriteNamed: 'Microdown' ifNone: [ nil ]) branch equals: 'v2.9.3'
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testAcceptRunsTheAcceptBlock [

	| accepted |
	accepted := nil.
	presenter whenAcceptedDo: [ :favorite | accepted := favorite ].
	presenter urlText: 'git@github.com:FedeLoch/Ume.git'.
	presenter accept.
	self assert: accepted name equals: 'Ume'
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testAcceptWhileEditingReplacesTheFavorite [

	presenter beEditing: (store favoriteNamed: 'Seaside' ifNone: [ nil ]).
	presenter nameText: 'Seaside3'.
	presenter accept.
	self assert: self storedNames equals: #( 'Favrepo' 'Roassal' 'Seaside3' )
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testAcceptingADuplicateAnswersTheExistingFavorite [

	| answer |
	presenter urlText: 'https://github.com/someone/seaside'.
	answer := presenter accept.
	self assert: answer branch equals: 'master'.
	self assert: self storedNames equals: #( 'Favrepo' 'Roassal' 'Seaside' )
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testAddingHasAList [

	self assert: presenter hasRepositoryList
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testCannotAcceptWithoutAValidUrl [

	presenter urlText: 'not a url'.
	self deny: presenter canAccept.
	presenter urlText: 'git@github.com:FedeLoch/Ume.git'.
	self assert: presenter canAccept
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testEditingHasNoListAndShowsTheFavorite [

	presenter beEditing: (store favoriteNamed: 'Seaside' ifNone: [ nil ]).
	self deny: presenter hasRepositoryList.
	self assert: presenter urlText equals: 'git@github.com:SeasideSt/Seaside.git'.
	self assert: presenter branchText equals: 'master'
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testFilterNarrowsTheList [

	presenter filterText: 'mic'.
	self assert: presenter repositoryNames equals: #( 'Microdown' )
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testListShowsImageRepositoriesThatAreNotFavorites [

	self assert: presenter repositoryNames equals: #( 'MCP' 'Microdown' 'Spec2' )
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testPickingARepositoryFillsTheFields [

	presenter pickRepositoryNamed: 'Microdown'.
	self assert: presenter urlText equals: 'git@github.com:pillar-markup/Microdown.git'.
	self assert: presenter nameText equals: 'Microdown'.
	self assert: presenter branchText equals: 'v2.9.3'
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testPickingARepositoryOffersItsBranchesAndTags [

	presenter pickRepositoryNamed: 'Microdown'.
	self assert: presenter branchChoices equals: #( 'default' 'dev' 'v2.9.3' )
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testPickingARepositoryWithoutUrlFillsOnlyTheName [

	presenter pickRepositoryNamed: 'Spec2'.
	self assert: presenter urlText equals: ''.
	self assert: presenter nameText equals: 'Spec2'.
	self assert: presenter branchText equals: 'default'
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testTypingAUrlFillsTheName [

	presenter urlText: 'git@github.com:FedeLoch/Ume.git'.
	self assert: presenter nameText equals: 'Ume'
]

{ #category : 'tests' }
FRAddFavoritePresenterTest >> testTypingAUrlKeepsANameTheUserTyped [

	presenter nameText: 'My Ume'.
	presenter urlText: 'git@github.com:FedeLoch/Ume.git'.
	self assert: presenter nameText equals: 'My Ume'
]
