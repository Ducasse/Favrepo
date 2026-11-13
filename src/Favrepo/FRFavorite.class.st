"
I am a favorite git repository: a bookmark you keep across all your images, so a fresh image is one click away from your usual projects.

## Responsibility:

- I know the URL to clone from, the name shown to the user, and the branch or tag to load (`default` means the default branch of the remote).
- I know my identity: two favorites with the same name, ignoring case, are the same favorite.
- I convert myself to and from the plain dictionary written in the favorites file.

## Collaborators:

- `IceGitRemote` parses my URL to give my project name and my owner/project path.
- `FRFavoriteStore` keeps me in the favorites file.
- `FRCatalog` tells whether I am loaded, cloned or absent in the current image.

## Public API and Key Messages

- `FRFavorite url: aString` creates a favorite named after the project of the URL, on the default branch.
- `FRFavorite url:name:branch:` creates a fully described favorite.
- `name`, `url`, `branch`, `projectPath`, `initial`, `isSameAs:`, `withBranch:`.

```
(FRFavorite url: 'git@github.com:noha/mustache.git') projectPath
	>>> 'noha/mustache'
```

See `FRFavorite class >> #exampleMustache`.

## Internal Representation

- `url`: the git URL as typed (scp or https form).
- `name`: a String, my identity.
- `branch`: a branch or tag name, or `'default'`.
"
Class {
	#name : 'FRFavorite',
	#superclass : 'Object',
	#instVars : [
		'url',
		'name',
		'branch'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'accessing' }
FRFavorite class >> defaultBranch [
	"The branch name meaning 'whatever branch the remote uses by default'."

	^ 'default'
]

{ #category : 'examples' }
FRFavorite class >> exampleMustache [

	<sampleInstance>
	^ self url: 'git@github.com:noha/mustache.git' name: 'Mustache' branch: 'v1.3'
]

{ #category : 'examples' }
FRFavorite class >> exampleOnDefaultBranch [

	<sampleInstance>
	^ self url: 'https://github.com/SeasideSt/Seaside'
]

{ #category : 'instance creation' }
FRFavorite class >> fromDictionary: aDictionary [
	"Answer the favorite stored as aDictionary by the favorites file."

	^ self new
		  setUrl: (aDictionary at: 'url')
		  name: (aDictionary at: 'name')
		  branch: (aDictionary at: 'branch' ifAbsent: [ self defaultBranch ]);
		  yourself
]

{ #category : 'testing' }
FRFavorite class >> isValidUrl: aString [
	"Answer whether aString is a git URL Iceberg can clone from."

	^ [
		  self remoteFor: aString.
		  true ]
		  on: FRError
		  do: [ false ]
]

{ #category : 'private' }
FRFavorite class >> remoteFor: aString [
	"Parse aString with Iceberg, raising FRError when it is not a git URL."

	| remote |
	remote := [ IceGitRemote url: aString trimBoth ]
		          on: Error
		          do: [ :error | FRError signal: ('Not a git URL: {1}' format: { aString }) ].
	remote projectName isEmptyOrNil ifTrue: [ FRError signal: ('Not a git URL: {1}' format: { aString }) ].
	^ remote
]

{ #category : 'instance creation' }
FRFavorite class >> url: aString [
	"A favorite named after the project of aString, on the remote's default branch."

	^ self url: aString name: (self remoteFor: aString) projectName branch: self defaultBranch
]

{ #category : 'instance creation' }
FRFavorite class >> url: aUrl name: aName branch: aBranch [

	^ self new
		  setUrl: aUrl name: aName branch: aBranch;
		  yourself
]

{ #category : 'converting' }
FRFavorite >> asDictionary [
	"The plain form written to the favorites file."

	^ Dictionary new
		  at: 'url' put: url;
		  at: 'name' put: name;
		  at: 'branch' put: branch;
		  yourself
]

{ #category : 'accessing' }
FRFavorite >> branch [

	^ branch
]

{ #category : 'accessing' }
FRFavorite >> cloneDirectoryIn: aClonesLocation [
	"Where Iceberg puts my clone inside aClonesLocation: <owner>/<project>."

	| remote |
	remote := self class remoteFor: url.
	^ aClonesLocation / remote organizer / remote projectName
]

{ #category : 'testing' }
FRFavorite >> hasName: aString [

	^ name sameAs: aString
]

{ #category : 'accessing' }
FRFavorite >> initial [
	"The letter shown as the favorite's avatar."

	^ name isEmpty
		  ifTrue: [ '?' ]
		  ifFalse: [ name first asUppercase asString ]
]

{ #category : 'testing' }
FRFavorite >> isDefaultBranch [

	^ branch = self class defaultBranch
]

{ #category : 'testing' }
FRFavorite >> isSameAs: aFavorite [
	"Two favorites are the same when their names are equal, ignoring case."

	^ self hasName: aFavorite name
]

{ #category : 'accessing' }
FRFavorite >> name [

	^ name
]

{ #category : 'printing' }
FRFavorite >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPutAll: ' (';
		nextPutAll: name;
		nextPutAll: ' @ ';
		nextPutAll: branch;
		nextPut: $)
]

{ #category : 'accessing' }
FRFavorite >> projectPath [
	"owner/project, as shown under the name; the URL itself when it cannot be parsed."

	^ [
		  | remote |
		  remote := self class remoteFor: url.
		  '{1}/{2}' format: {
				  remote owner.
				  remote projectName } ]
		  on: FRError
		  do: [ url ]
]

{ #category : 'initialization' }
FRFavorite >> setUrl: aUrl name: aName branch: aBranch [

	url := aUrl trimBoth.
	name := aName trimBoth.
	branch := aBranch isEmptyOrNil
		          ifTrue: [ self class defaultBranch ]
		          ifFalse: [ aBranch trimBoth ]
]

{ #category : 'accessing' }
FRFavorite >> url [

	^ url
]

{ #category : 'converting' }
FRFavorite >> withBranch: aString [
	"A copy of me on another branch."

	^ self class url: url name: name branch: aString
]
