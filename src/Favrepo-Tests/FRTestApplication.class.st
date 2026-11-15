"
I am the favorites application for tests: I record failures, reports and notifications (`lastFailure`, `lastReport`, `lastMessage`) instead of opening dialogs.

See `FRSpecTestCase >> #setUp`.
"
Class {
	#name : 'FRTestApplication',
	#superclass : 'FRApplication',
	#instVars : [
		'lastFailure',
		'lastReport',
		'lastMessage'
	],
	#category : 'Favrepo-Tests',
	#package : 'Favrepo-Tests'
}

{ #category : 'accessing' }
FRTestApplication >> lastFailure [

	^ lastFailure
]

{ #category : 'accessing' }
FRTestApplication >> lastMessage [

	^ lastMessage
]

{ #category : 'accessing' }
FRTestApplication >> lastReport [

	^ lastReport
]

{ #category : 'dialogs' }
FRTestApplication >> report: aString titled: aTitle [
	"Record the report instead of showing it."

	lastReport := aString
]

{ #category : 'dialogs' }
FRTestApplication >> reportFailure: aString titled: aTitle [
	"Record the failure instead of showing it."

	lastFailure := aString
]

{ #category : 'dialogs' }
FRTestApplication >> tell: aString [
	"Record the notification instead of showing it."

	lastMessage := aString
]
