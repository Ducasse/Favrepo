"
I am the Spec application of the favorites tool: I open its window and give its presenters what they share.

## Responsibility:

- I open one favorites window at a time: running me again brings the open window to the front (`run` calls my `start`).
- I give the presenters the store, a fresh catalog of the image and a loader configured to ask its questions through my dialogs.
- I run clones and loads with a progress bar, show failures, and show what the loader reports.

## Collaborators:

- `FRFavoritesPresenter` is my main window; `FRAddFavoritePresenter` my dialog.
- `FRFavoriteStore`, `FRCatalog` and `FRFavoriteLoader` are the model I hand out.
- The World menu: Versioning > Favorite repositories.

## Public API and Key Messages

- `FRApplication new run` (Spec's entry point; it calls `start`, which I override)
- `store:`, `catalog:`, `loader:` replace the defaults (tests, examples); `FRTestApplication` records my dialogs in tests.
- `openIceberg` opens Iceberg on all the repositories and `browseRepository:` on one (`icebergOpener:` and `repositoryBrowser:` replace them in tests).
- `run:titled:`, `newPharoIntegrationFor:`, `openPullRequestFor:`, `showHelp:`, `reportFailure:titled:`, `report:titled:`, `tell:`, `request:initialAnswer:titled:`.

```
FRApplication new run
```

See `FRApplication class >> #exampleInMemory` and run `FRApplication class >> #scriptOpenOnThisImage`.

## Internal Representation

- `store`: nil means `FRFavoriteStore default`.
- `catalogProvider`: nil means a new `FRCatalog current` on each request.
- `loader`: nil means a new `FRFavoriteLoader`.
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
		'repositoryBrowser',
		'icebergOpener'
	],
	#category : 'Favrepo-Spec',
	#package : 'Favrepo-Spec'
}

{ #category : 'examples' }
FRApplication class >> exampleInMemory [
	"An application on example favorites and the small example image; nothing is opened."

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

	^ self newSelect
		  title: 'Several baselines';
		  label: 'Which baseline should be loaded?';
		  items: someNames;
		  openModal
]

{ #category : 'dialogs' }
FRApplication >> confirmNotBottom: aQuestion [

	^ self newConfirm
		  title: 'Not a Bottom branch';
		  label: aQuestion;
		  acceptLabel: 'Create anyway';
		  cancelLabel: 'Cancel';
		  openModal
]

{ #category : 'dialogs' }
FRApplication >> confirmSwitchOf: anIceRepository [

	^ self newConfirm
		  title: 'Uncommitted changes';
		  label: ('{1} has uncommitted changes. Switch its branch anyway?' format: { anIceRepository name });
		  openModal
]

{ #category : 'dialogs' }
FRApplication >> confirmUnpushed: aQuestion [

	^ self newConfirm
		  title: 'Branch not pushed';
		  label: aQuestion;
		  acceptLabel: 'Open the PR anyway';
		  cancelLabel: 'Cancel';
		  openModal
]

{ #category : 'dialogs' }
FRApplication >> createPullRequest: aPullRequest [
	"Create aPullRequest on GitHub and tell where it is."

	| url |
	url := [ aPullRequest send at: 'html_url' ]
		       on: IceGitHubError
		       do: [ :error | ^ self reportFailure: error messageText titled: 'The pull request was not created' ].
	self newInform
		title: 'Pull request created. Click to view on GitHub.';
		label: url;
		onAccept: [ WebBrowser openOn: url ];
		openModal
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

{ #category : 'initialization' }
FRApplication >> initialize [

	super initialize.
	self addStyleSheetFromString: '.application [
		.label [
			.frInitial [ Font { #size: 14 } ],
			.frNotLoaded [ Draw { #color: EnvironmentColor(#disabledText) } ] ] ]'
]

{ #category : 'accessing' }
FRApplication >> loader: aFavoriteLoader [

	loader := aFavoriteLoader
]

{ #category : 'accessing' }
FRApplication >> newLoader [
	"The loader for one Load, asking its questions and telling what it did through my dialogs."

	^ (loader ifNil: [ FRFavoriteLoader new ])
		  catalog: self catalog;
		  baselineChooser: [ :names | self chooseBaselineAmong: names ];
		  switchConfirmer: [ :repository | self confirmSwitchOf: repository ];
		  informer: [ :text | self report: text titled: 'Favorite repositories' ];
		  yourself
]

{ #category : 'accessing' }
FRApplication >> newPharoIntegrationFor: aFavorite [
	"The Pharo integration of aFavorite, asking through my dialogs before building on a branch that is not a bottom branch."

	^ (FRPharoIntegration favorite: aFavorite catalog: self catalog)
		  confirmer: [ :question | self confirmNotBottom: question ];
		  yourself
]

{ #category : 'dialogs' }
FRApplication >> openIceberg [
	"Open Iceberg's browser on all the repositories, or bring it to the front."

	(icebergOpener ifNil: [ [ IceTipRepositoriesBrowser ensureIsOpen ] ]) value
]

{ #category : 'dialogs' }
FRApplication >> openPullRequestFor: aPharoIntegration [
	"Open Iceberg's GitHub pull request dialog from the integration branch of the Pharo fork."

	(FRPharoPullRequestPresenter
		 newApplication: self
		 repository: aPharoIntegration checkedPharoRepository
		 branch: aPharoIntegration integrationPharoBranch)
		onAccept: [ :pullRequest | self createPullRequest: pullRequest ];
		openModal
]

{ #category : 'dialogs' }
FRApplication >> report: aString titled: aTitle [
	"Show what a step did."

	self newInform
		title: aTitle;
		message: aString;
		openModal
]

{ #category : 'dialogs' }
FRApplication >> reportFailure: aString titled: aTitle [
	"Show a failure to the user."

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
	"Run aBlock with a progress bar."

	[ :job |
		job title: aString.
		aBlock value ] asJob run
]

{ #category : 'dialogs' }
FRApplication >> showHelp: aMicrodownString [
	"Open a window showing aMicrodownString rendered."

	(self instantiate: MicrodownPresenter)
		documentFromString: aMicrodownString;
		open;
		withWindowDo: [ :window |
				window
					title: 'Favorite repositories help';
					resize: 620 @ 640 ]
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
	"Show a short notification."

	self inform: aString
]
