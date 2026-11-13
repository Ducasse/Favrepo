"
I am the Spec application of the favorites tool: I open its window and give its presenters what they share.

## Responsibility:

- I open one favorites window at a time: running me again brings the open window to the front (`run` calls my `start`).
- I give the presenters the store, a fresh catalog of the image and a loader configured to ask its questions through my dialogs.
- I run loads in the background with a progress bar, and show failures; when synchronous (tests, scripts) I run in place and record failures in `lastFailure`.

## Collaborators:

- `FRFavoritesPresenter` is my main window; `FRAddFavoritePresenter` my dialog.
- `FRFavoriteStore`, `FRCatalog` and `FRFavoriteLoader` are the model I hand out.
- The World menu: Versioning > Favorite repositories.

## Public API and Key Messages

- `FRApplication new run` (Spec's entry point; it calls `start`, which I override)
- `store:`, `catalog:`, `loader:`, `beSynchronous` replace the defaults (tests, examples).
- `openIceberg` opens Iceberg on all the repositories and `browseRepository:` on one (`icebergOpener:` and `repositoryBrowser:` replace them in tests).
- `run:titled:`, `inUIProcess:`, `reportFailure:titled:`, `tell:`, `confirm:titled:`, `request:initialAnswer:titled:`.

```
FRApplication new run
```

See `FRApplication class >> #exampleInMemory` and run `FRApplication class >> #scriptOpenOnThisImage`.

## Internal Representation

- `store`: nil means `FRFavoriteStore default`.
- `catalogProvider`: nil means a new `FRCatalog current` on each request.
- `loader`: nil means a new `FRFavoriteLoader`.
- `isSynchronous`: a Boolean.
- `repositoryBrowser`: nil means open an `IceTipRepositoryBrowser`.
- `icebergOpener`: nil means `IceTipRepositoriesBrowser ensureIsOpen`.

### Implementation Points

The stylesheet adds the `frInitial` (14 pt) and `frNotLoaded` (grey) label styles. Bold is set with `displayBold:` on the labels, never with `Font { #bold: true }`: `SpFontStyle` would make the image's shared regular font bold.
"
Class {
	#name : 'FRApplication',
	#superclass : 'SpApplication',
	#instVars : [
		'store',
		'catalogProvider',
		'loader',
		'isSynchronous',
		'repositoryBrowser',
		'icebergOpener'
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
		action: [ self new run ]
]

{ #category : 'script' }
FRApplication class >> scriptOpenOnThisImage [
	"The favorites window on example favorites, showing their state in this image. Your favorites file is not used."

	<example>
	^ self new
		  store: FRFavoriteStore exampleInMemory;
		  run
]

{ #category : 'running' }
FRApplication >> beSynchronous [
	"Run loads in the calling process and record failures instead of showing them; used by tests and scripts."

	isSynchronous := true
]

{ #category : 'dialogs' }
FRApplication >> browseRepository: anIceRepository [
	"Open the Iceberg repository browser on anIceRepository."

	(repositoryBrowser ifNil: [ [ :repository | (IceTipRepositoryBrowser onRepository: repository) open ] ])
		value: anIceRepository
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
		  message: aString;
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

{ #category : 'accessing' }
FRApplication >> icebergIcon [

	^ IceTipRepositoriesBrowser iconForWorldMenu
]

{ #category : 'accessing' }
FRApplication >> icebergOpener: aBlock [
	"aBlock opens Iceberg's repositories browser (tests record it instead)."

	icebergOpener := aBlock
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
			.frInitial [ Font { #size: 14 } ],
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
FRApplication >> openIceberg [
	"Open Iceberg's browser on all the repositories, or bring it to the front."

	(icebergOpener ifNil: [ [ IceTipRepositoriesBrowser ensureIsOpen ] ]) value
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

{ #category : 'accessing' }
FRApplication >> repositoryBrowser: aBlock [
	"aBlock opens a browser on the Iceberg repository it is given (tests record it instead)."

	repositoryBrowser := aBlock
]

{ #category : 'dialogs' }
FRApplication >> request: aString initialAnswer: anAnswer titled: aTitle [
	"Ask for a text; nil when cancelled."

	^ self newRequest
		  title: aTitle;
		  message: aString;
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
