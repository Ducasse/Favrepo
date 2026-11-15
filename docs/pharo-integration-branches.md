# Pharo integration branches for external projects

Design agreed on 2026-11-15. Not implemented yet.

## Goal

The Pharo build is made of several repositories. Each external project (NewTools, Spec, Roassal, ...) has its own tests, but only the main `pharo-project/pharo` repository builds the complete system. To validate a change of an external project (new packages, dependency order) in the full build, we open a Pharo PR that loads the branch of that project.

FavRep automates this, through Iceberg only (no command line).

## Scope

Only favorites that are Pharo external projects: the GitHub project name of the favorite equals (ignoring case) the `project:` of a `BaselineOfPharo` class method marked `<externalProject>`, e.g.

```smalltalk
BaselineOfPharo class >> newTools
	<externalProject>
	^ PharoExternalProject
		newName: 'NewTools'
		owner: 'pharo-spec'
		project: 'NewTools'
		version: 'v0.11.0'
```

`Ducasse/NewTools` matches `newTools`, `Ducasse/spec` matches `spec` (`project: 'Spec'`). The matching method is the one rewritten.

For other favorites, the two menu items below are dimmed, with the tooltip "Not a Pharo external project".

## Menu item 1: "Create Pharo integration branch…"

1. Ask for the branch name: free text, no prefill.
2. Find the **Pharo clone**: the Iceberg repository holding the `BaselineOfPharo` package. If it has no clone, stop: "Clone your Pharo fork first" (clone a `<you>/pharo` favorite with FavRep: it attaches to the loaded code).
3. **Checks, all before creating anything (both or nothing):**
   - the name is not empty, is a valid git branch name, and does not end with `-Bottom`;
   - the name does not exist in the external clone nor in the Pharo clone;
   - the Pharo clone's `origin` is not `pharo-project/pharo` (it must be your fork), otherwise stop: "Your Pharo clone must come from your fork";
   - `BaselineOfPharo` has no other uncommitted change, otherwise stop;
   - the external clone is on a Bottom branch (any `<ISO date>-Bottom`), otherwise confirm "<project> is on <branch>, not a Bottom branch. Create the integration branch on top of it anyway?" (Cancel by default);
   - the Pharo clone is on a Bottom branch, otherwise the same confirmation.
4. Create the branch in the **external clone** at its current commit and check it out. Local only: the developer commits and pushes there.
5. Create the same-named branch in the **Pharo clone** at its current commit and check it out.
6. Rewrite, in the image, the matching `BaselineOfPharo class >> <project>` method, changing only `owner:` (owner of the external clone's origin, e.g. `Ducasse`) and `version:` (the branch name).
7. Commit that change alone with Iceberg: "Load NewTools from Ducasse/NewTools:<branch> to validate it in the full build".
8. Push the Pharo branch to `origin` (your Pharo fork). This push happens only once.
9. Switch the Pharo clone back to its Bottom branch and reload the original `BaselineOfPharo` method, so the image and the clone stay in sync. The external clone stays on the new branch.
10. Report: both branch names, and a reminder to push the external branch before opening the PR.

**When the push fails** (no credentials, no network): keep the commit, leave Pharo on the integration branch, and report "Push of <branch> to <you>/pharo failed: push it from Iceberg, then switch Pharo back to its Bottom branch". The external branch stays.

## Menu item 2: "Open Pharo integration PR"

- The Pharo branch is the one named like the branch checked out in the external clone; the item is dimmed when Pharo has no such branch.
- Check that the external branch is pushed to your fork; warn if not (otherwise the Pharo build cannot load it).
- Open Iceberg's GitHub "Create pull request" dialog, prefilled for `<you>/pharo:<branch>` → `pharo-project/pharo`.

## Menu placement

Both items go after "Define bottom branch" in the row context menu.

## Decisions and why

| Decision | Why |
|---|---|
| FavRep creates the external branch from a typed name | One action; an empty branch is fine, commits come next |
| Bottom branch = any `<ISO date>-Bottom` | An older Bottom is still a clean base; no daily warnings |
| Not on a Bottom branch: confirm, Cancel by default | Prevents nested integration branches, still allows combining two projects on purpose |
| Same Bottom check on the external project | Same nesting risk on both sides |
| Pharo clone = repository holding `BaselineOfPharo` | It is the package being edited; no configuration |
| Rewrite only `owner:` and `version:`, commit it alone | One-line, reviewable, revertable PR |
| Push the Pharo branch only | It is pushed once; the external branch is the developer's |
| No PR at creation, separate menu item | At creation the external branch is empty and unpushed |
| Pharo back to Bottom after the push | Next integration starts clean, no manual switch |
| Push failure keeps the commit | Iceberg handles credentials; no redo for a transient problem |
