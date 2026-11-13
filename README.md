A simple tool to manage favorite repositories. Please use it and give feedback.

To load it automatically to your lovely Pharo images, just places this expression in your preference folder.

```
StartupPreferencesLoader default executeAtomicItems: {
	StartupAction
		name: 'Load Favrepo'
		code: [
		"The favorite repositories tool: World menu > Versioning > Favorite repositories,
		 or FRApplication new run. Only the Core group, without the tests."
		Metacello new
			baseline: 'Favrepo';
			repository: 'github://Ducasse/Favrepo/src';
			onConflictUseLoaded;
			load: 'Core'
		] runOnce: true}
```

or run the following script in your playground. 

```
| folder file |
  folder := StartupPreferencesLoader preferencesVersionFolder.
  folder ensureCreateDirectory.
  file := folder / 'FavrepoSettings.st'.
  file ensureDelete; writeStreamDo: [ :stream |
          stream nextPutAll: 'StartupPreferencesLoader default executeAtomicItems: {
          StartupAction
                  name: ''Load Favrepo''
                  code: [
                          Metacello new
                                  baseline: ''Favrepo'';
                                  repository: ''github://Ducasse/Favrepo/src'';
                                  onConflictUseLoaded;
                                  load: ''Core'' ]
                  runOnce: true }' ].
  file
```

![screen.png](screen.png)
