"
I update Favrepo itself in this image: I fetch the Iceberg clone Favrepo was loaded from and pull the new commits of its branch, which loads them into the image. This is how an existing image gets the latest Favrepo.

I never pull into a clone with uncommitted changes, nor when its branch tracks no remote branch: I only tell why. #update answers the text to show the user; #updated tells whether new code was loaded.

	FRSelfUpdater new update
"
Class {
	#name : 'FRSelfUpdater',
	#superclass : 'Object',
	#instVars : [
		'repository',
		'updated'
	],
	#category : 'Favrepo',
	#package : 'Favrepo'
}

{ #category : 'initialization' }
FRSelfUpdater >> initialize [

	super initialize.
	updated := false
]

{ #category : 'accessing' }
FRSelfUpdater >> repository [
	"The Iceberg repository Favrepo was loaded from, or nil when it was not loaded from a Git clone."

	^ repository ifNil: [
			  repository := IceRepository registry
				                detect: [ :each | each workingCopy packages anySatisfy: [ :package | package name = 'Favrepo' ] ]
				                ifNone: [ nil ] ]
]

{ #category : 'accessing' }
FRSelfUpdater >> repository: anIceRepository [

	repository := anIceRepository
]

{ #category : 'updating' }
FRSelfUpdater >> update [
	"Fetch the clone of Favrepo and pull the new commits of its branch into the image. Answer what happened, for the user."

	| incoming |
	updated := false.
	self repository ifNil: [
		^ 'Favrepo was not loaded from a Git clone known by Iceberg, so it cannot be updated from here. Load it again with its baseline.' ].
	repository head isDetached ifTrue: [
			^ 'The clone of Favrepo is not on a branch (detached at {1}): check out a branch in Iceberg first.' format:
				  { repository headCommit shortId } ].
	repository branch hasUpstream ifFalse: [
			^ 'The branch {1} of the clone of Favrepo tracks no remote branch: set its upstream in Iceberg first.' format:
				  { repository branchName } ].
	repository isModified ifTrue: [
		^ 'The clone of Favrepo has uncommitted changes: commit or discard them in Iceberg first. Nothing was updated.' ].
	repository fetch.
	incoming := repository incomingCommits size.
	incoming = 0 ifTrue: [
			^ 'Favrepo is up to date ({1} on {2}).' format: {
					  repository branchName.
					  repository headCommit shortId } ].
	repository pull.
	updated := true.
	^ 'Favrepo was updated: {1} new commit(s) on {2} loaded (now at {3}).' format: {
			  incoming.
			  repository branchName.
			  repository headCommit shortId }
]

{ #category : 'accessing' }
FRSelfUpdater >> updated [
	"Whether the last #update loaded new code."

	^ updated
]
