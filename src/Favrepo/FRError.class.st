"
I am the error raised by the favorites tool when something cannot be done: an invalid URL, a clone without baseline, a cancelled choice.

## Responsibility:

- I carry a message the tool shows to the user as is.
- I am the error tests expect from the model (`should: [ ... ] raise: FRError`).
- My subclasses carry more context.

## Collaborators:

- `FRFavorite`, `FRFavoriteLoader` and `FRFavoriteStore` raise me.
- `FRFavoritesPresenter` reports me through `FRApplication`.

## Public API and Key Messages

- `FRError signal: aString`

See `FRError class >> #exampleNoBaseline`.
"
Class {
	#name : 'FRError',
	#superclass : 'Error',
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'examples' }
FRError class >> exampleNoBaseline [

	<sampleInstance>
	^ self new
		  messageText: 'No baseline in /tmp/clone/src';
		  yourself
]
