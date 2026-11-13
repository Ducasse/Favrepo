"
I load Favrepo, the tool that manages your favorite Iceberg repositories.

```
Metacello new
	baseline: 'Favrepo';
	repository: 'github://Ducasse/Favrepo:master/src';
	load
```

Groups: `Core` (model and Spec tool), `Tests`, and `default` (both).
"
Class {
	#name : 'BaselineOfFavrepo',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfFavrepo',
	#package : 'BaselineOfFavrepo'
}

{ #category : 'baselines' }
BaselineOfFavrepo >> baseline: spec [

	<baseline>
	spec for: #common do: [
			spec
				package: 'Favrepo';
				package: 'Favrepo-Spec' with: [ spec requires: #( 'Favrepo' ) ];
				package: 'Favrepo-Tests' with: [ spec requires: #( 'Favrepo-Spec' ) ].
			spec
				group: 'Core' with: #( 'Favrepo' 'Favrepo-Spec' );
				group: 'Tests' with: #( 'Favrepo-Tests' );
				group: 'default' with: #( 'Core' 'Tests' ) ]
]
