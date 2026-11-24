"
I am a loader for tests: I record the favorites I am asked to load instead of cloning them, and can be told to fail (`failWith:`).

See `FRFavoritesPresenterTest`.
"
Class {
	#name : 'FRRecordingLoader',
	#superclass : 'FRFavoriteLoader',
	#instVars : [
		'loaded',
		'failure',
		'cloned',
		'bottomBranched'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'accessing' }
FRRecordingLoader >> bottomBranched [

	^ bottomBranched ifNil: [ bottomBranched := OrderedCollection new ]
]

{ #category : 'steps' }
FRRecordingLoader >> clone: aFavorite [
	"Record aFavorite instead of cloning it."

	failure ifNotNil: [ FRError signal: failure ].
	self cloned add: aFavorite.
	^ nil
]

{ #category : 'accessing' }
FRRecordingLoader >> cloned [

	^ cloned ifNil: [ cloned := OrderedCollection new ]
]

{ #category : 'bottom branch' }
FRRecordingLoader >> defineBottomBranchFor: aFavorite [
	"Record aFavorite instead of creating a branch in its clone."

	failure ifNotNil: [ FRError signal: failure ].
	self bottomBranched add: aFavorite.
	^ FRClone bottomBranchNameOn: Date today
]

{ #category : 'accessing' }
FRRecordingLoader >> failWith: aString [
	"Make the next loads fail with aString."

	failure := aString
]

{ #category : 'loading' }
FRRecordingLoader >> load: aFavorite [
	"Record aFavorite instead of cloning and loading it."

	failure ifNotNil: [ FRError signal: failure ].
	self loaded add: aFavorite.
	^ nil
]

{ #category : 'accessing' }
FRRecordingLoader >> loaded [

	^ loaded ifNil: [ loaded := OrderedCollection new ]
]
