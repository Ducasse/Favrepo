"
I represent a clone of Pharo, the running system: its baseline is never loaded, and it belongs to the repository the image itself came from. The main definition of ""this is Pharo"" is my class side `canHandle:`.

## Examples

```
FRPharoClone instanceMissingOnDisk
```

## Design Rationale

- I am recognized by `BaselineOfPharo`, not by a commit: a fork is usually behind the image and lacks the commit the image was built from.
- A repository whose commit is unknown lists no package at all, so it is recognized by that commit being the one of the image.
- The repository of the image is found by the commit the image was built from, not by its packages: it may list none.
- The baseline is not loaded because the one of Pharo does not load like the others.
"
Class {
	#name : 'FRPharoClone',
	#superclass : 'FRClone',
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'testing' }
FRPharoClone class >> canHandle: anIceRepository [
	"Whether anIceRepository is a clone of Pharo: it holds its baseline or, when its commit is unknown and it lists no package, the image was built from that commit."

	(anIceRepository workingCopy packageNames includes: 'BaselineOfPharo') ifTrue: [ ^ true ].
	^ anIceRepository workingCopy packages isEmpty and: [ (self newOn: anIceRepository) isAtImageCommit ]
]

{ #category : 'accessing' }
FRPharoClone class >> imageCommitId [
	"The commit of Pharo the image was built from."

	^ SystemVersion current commitHash
]

{ #category : 'instances' }
FRPharoClone class >> instanceMissingOnDisk [
	"A clone of Pharo that is not on disk, like the one of a fresh image."

	<sampleInstance>
	^ self newOn: (IceLibgitRepository new
			   name: 'pharo';
			   yourself)
]

{ #category : 'matching' }
FRPharoClone >> imageRepositoryAmong: someRepositories [
	"The repository of the image itself: its code comes from the commit the image was built from. I may be a fork that is behind and lacks that commit."

	^ someRepositories
		  detect: [ :each | (self class newOn: each) isAtImageCommit ]
		  ifNone: [ super imageRepositoryAmong: someRepositories ]
]

{ #category : 'testing' }
FRPharoClone >> isAtImageCommit [
	"Whether the image code comes from the commit the image was built from, known by the clone or not."

	^ self referenceCommitId = self class imageCommitId
]

{ #category : 'baselines' }
FRPharoClone >> loadBaselineFor: aLoader [
	"Pharo is the running system and its baseline does not load like the others."

	aLoader report: ('The baseline of {1} was not loaded: Pharo is the running system.' format: { self name })
]
