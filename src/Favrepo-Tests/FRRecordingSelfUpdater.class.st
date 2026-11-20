"
I stand for FRSelfUpdater in tests: #update answers a given text, or signals a given error, and counts the calls; nothing is fetched or loaded.
"
Class {
	#name : 'FRRecordingSelfUpdater',
	#superclass : 'FRSelfUpdater',
	#instVars : [
		'answer',
		'error',
		'updates'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'accessing' }
FRRecordingSelfUpdater >> answer: aString updated: aBoolean [
	answer := aString.
	updated := aBoolean
]

{ #category : 'accessing' }
FRRecordingSelfUpdater >> failWith: anError [
	error := anError
]

{ #category : 'accessing' }
FRRecordingSelfUpdater >> update [
	"Record the call; answer the given text or signal the given error."
	updates := self updates + 1.
	error ifNotNil: [ error signal ].
	^ answer
]

{ #category : 'accessing' }
FRRecordingSelfUpdater >> updates [
	^ updates ifNil: [ 0 ]
]
