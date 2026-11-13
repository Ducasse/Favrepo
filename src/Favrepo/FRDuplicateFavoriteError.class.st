"
I am raised when a favorite is added, or renamed, with the name of an existing favorite.

## Responsibility:

- I know the existing favorite, so the tool can select it instead of adding a duplicate.
- I tell the user which name is already taken.
- I am raised by `FRFavoriteStore` only.

## Collaborators:

- `FRFavoriteStore` raises me with `signalFor:`.
- `FRAddFavoritePresenter` catches me and selects the existing favorite.

## Public API and Key Messages

- `FRDuplicateFavoriteError signalFor: anExistingFavorite`
- `favorite`

See `FRDuplicateFavoriteError class >> #exampleMustache`.
"
Class {
	#name : 'FRDuplicateFavoriteError',
	#superclass : 'FRError',
	#instVars : [
		'favorite'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'examples' }
FRDuplicateFavoriteError class >> exampleMustache [

	<sampleInstance>
	^ self new
		  favorite: FRFavorite exampleMustache;
		  messageText: 'Mustache is already a favorite';
		  yourself
]

{ #category : 'signalling' }
FRDuplicateFavoriteError class >> signalFor: anExistingFavorite [

	^ self new
		  favorite: anExistingFavorite;
		  signal: ('{1} is already a favorite' format: { anExistingFavorite name })
]

{ #category : 'accessing' }
FRDuplicateFavoriteError >> favorite [

	^ favorite
]

{ #category : 'accessing' }
FRDuplicateFavoriteError >> favorite: aFavorite [

	favorite := aFavorite
]
