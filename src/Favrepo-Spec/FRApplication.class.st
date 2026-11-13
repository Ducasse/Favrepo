"
I am the Spec application of the favorites tool: I open its window and give its presenters what they share.

## Responsibility:

- I open one favorites window at a time: starting me again brings the open window to the front.
- I give the presenters the store, a fresh catalog of the image and a loader configured to ask its questions through my dialogs.
- I run loads in the background with a progress bar, and show failures; when synchronous (tests, scripts) I run in place and record failures in `lastFailure`.

## Collaborators:

- `FRFavoritesPresenter` is my main window; `FRAddFavoritePresenter` my dialog.
- `FRFavoriteStore`, `FRCatalog` and `FRFavoriteLoader` are the model I hand out.
- The World menu: Versioning > Favorite repositories.

## Public API and Key Messages

- `FRApplication new start`
- `store:`, `catalog:`, `loader:`, `beSynchronous` replace the defaults (tests, examples).
- `run:titled:`, `inUIProcess:`, `reportFailure:titled:`, `tell:`, `confirm:titled:`, `request:initialAnswer:titled:`.

```
FRApplication new start
```

See `FRApplication class >> #exampleInMemory` and run `FRApplication class >> #scriptOpenOnThisImage`.

## Internal Representation

- `store`: nil means `FRFavoriteStore default`.
- `catalogProvider`: nil means a new `FRCatalog current` on each request.
- `loader`: nil means a new `FRFavoriteLoader`.
- `isSynchronous`: a Boolean.

### Implementation Points

The stylesheet adds the `frName`, `frInitial` and `frNotLoaded` (grey) label styles.
"
Class {
	#name : 'FRApplication',
	#superclass : 'SpApplication',
	#instVars : [
		'store',
		'catalogProvider',
		'loader',
		'isSynchronous'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'examples' }
FRApplication class >> exampleInMemory [
	"An application on example favorites and the small example image; nothing is opened."

	<sampleInstance>
	^ self new
		  store: FRFavoriteStore exampleInMemory;
		  catalog: FRCatalog exampleSmallImage;
		  yourself
]

{ #category : 'world menu' }
FRApplication class >> menuCommandOn: aBuilder [

	<worldMenu>
	(aBuilder item: #'Favorite repositories')
		parent: #Versioning;
		order: 2;
		iconName: #git;
		help: 'Your favorite Iceberg repositories, shared by all your images';
		action: [ self new start ]
]

{ #category : 'script' }
FRApplication class >> scriptOpenOnThisImage [
	"The favorites window on example favorites, showing their state in this image. Your favorites file is not used."

	<example>
	^ self new
		  store: FRFavoriteStore exampleInMemory;
		  start
]

{ #category : 'running' }
FRApplication >> beSynchronous [
	"Run loads in the calling process and record failures instead of showing them; used by tests and scripts."

	isSynchronous := true
]

{ #category : 'accessing' }
FRApplication >> catalog [
	"A fresh snapshot of the repositories in the image, unless a fixed catalog was given."

	^ catalogProvider ifNil: [ FRCatalog current ] ifNotNil: [ catalogProvider value ]
]

{ #category : 'accessing' }
FRApplication >> catalog: aCatalog [

	catalogProvider := [ aCatalog ]
]

{ #category : 'dialogs' }
FRApplication >> chooseBaselineAmong: someNames [

	^ self inUIProcess: [
			  self newSelect
				  title: 'Several baselines';
				  label: 'Which baseline should be loaded?';
				  items: someNames;
				  openModal ]
]

{ #category : 'dialogs' }
FRApplication >> confirm: aString titled: aTitle [
	"Ask a yes/no question; always yes when running synchronously."

	isSynchronous ifTrue: [ ^ true ].
	^ self newConfirm
		  title: aTitle;
		  label: aString;
		  openModal
]

{ #category : 'dialogs' }
FRApplication >> confirmSwitchOf: anIceRepository [

	^ self inUIProcess: [
			  self newConfirm
				  title: 'Uncommitted changes';
				  label: ('{1} has uncommitted changes. Switch its branch anyway?' format: { anIceRepository name });
				  openModal ]
]

{ #category : 'running' }
FRApplication >> inUIProcess: aBlock [
	"Evaluate aBlock in the UI process and answer its value, waiting for it when called from a background load."

	| result done |
	(isSynchronous or: [ Processor activeProcess == UIManager default uiProcess ]) ifTrue: [ ^ aBlock value ].
	result := nil.
	done := Semaphore new.
	self defer: [ result := [ aBlock value ] ensure: [ done signal ] ].
	done wait.
	^ result
]

{ #category : 'initialization' }
FRApplication >> initialize [

	super initialize.
	isSynchronous := false.
	self addStyleSheetFromString: '.application [
		.label [
			.frName [ Font { #bold: true } ],
			.frInitial [ Font { #bold: true, #size: 14 } ],
			.frNotLoaded [ Draw { #color: EnvironmentColor(#disabledText) } ] ] ]'
]

{ #category : 'accessing' }
FRApplication >> lastFailure [
	"The message of the last failure reported while running synchronously."

	^ self propertyAt: #lastFailure ifAbsent: [ nil ]
]

{ #category : 'accessing' }
FRApplication >> loader: aFavoriteLoader [

	loader := aFavoriteLoader
]

{ #category : 'accessing' }
FRApplication >> newLoader [
	"The loader for one Load, asking its questions through my dialogs."

	^ (loader ifNil: [ FRFavoriteLoader new ])
		  catalog: self catalog;
		  baselineChooser: [ :names | self chooseBaselineAmong: names ];
		  switchConfirmer: [ :repository | self confirmSwitchOf: repository ];
		  yourself
]

{ #category : 'dialogs' }
FRApplication >> reportFailure: aString titled: aTitle [
	"Show a failure to the user, or record it when running synchronously."

	isSynchronous ifTrue: [ ^ self propertyAt: #lastFailure put: aString ].
	self newInform
		title: aTitle;
		label: aString;
		openModal
]

{ #category : 'dialogs' }
FRApplication >> request: aString initialAnswer: anAnswer titled: aTitle [
	"Ask for a text; nil when cancelled."

	^ self newRequest
		  title: aTitle;
		  label: aString;
		  text: anAnswer;
		  openModal
]

{ #category : 'running' }
FRApplication >> run: aBlock titled: aString [
	"Run aBlock with a progress bar; in the background unless I am synchronous."

	| job |
	job := [ :aJob |
		       aJob title: aString.
		       aBlock value ] asJob.
	isSynchronous
		ifTrue: [ job run ]
		ifFalse: [ [ job run ] forkAt: Processor userBackgroundPriority named: aString ]
]

{ #category : 'running' }
FRApplication >> start [
	"Open the favorites window, or bring the one already open to the front."

	self windows
		ifEmpty: [ (self instantiate: FRFavoritesPresenter) open ]
		ifNotEmpty: [ :openWindows | openWindows anyOne activate ]
]

{ #category : 'accessing' }
FRApplication >> store [

	^ store ifNil: [ FRFavoriteStore default ]
]

{ #category : 'accessing' }
FRApplication >> store: aFavoriteStore [

	store := aFavoriteStore
]

{ #category : 'dialogs' }
FRApplication >> tell: aString [
	"Show a short notification, or record it when running synchronously."

	isSynchronous ifTrue: [ ^ self propertyAt: #lastMessage put: aString ].
	self inform: aString
]
