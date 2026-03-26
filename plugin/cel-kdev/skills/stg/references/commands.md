# stg command reference

## Creating and updating patches

| Task | Command |
| ---- | ------- |
| Create new patch | `stg new <name> -m "message"` |
| Create with Signed-off-by | `stg new <name> -s -m "message"` |
| Update current patch (working tree) | `stg refresh` |
| Update current patch (staged only) | `stg refresh --index` |
| Update current patch (specific files) | `stg refresh -- <file1> <file2>` |
| Update a non-current patch | `stg refresh -p <patch-name>` |
| Edit current patch message | `stg edit --file <path>` |
| Edit message and diff | `stg edit --diff --file <path>` |
| Track a new file | `stg add <file>` |

`stg refresh` picks up all changes to already-tracked files
automatically. `stg add` is needed only to place a new file
under version control for the first time.

## Squashing

| Task | Command |
| ---- | ------- |
| Squash with message file | `stg squash -n <name> -f <path> <patch1> <patch2>` |
| Squash with inline message | `stg squash -n <name> -m "message" <patch1> <patch2>` |

## Navigation

| Task | Command |
| ---- | ------- |
| Go to specific patch | `stg goto <patch-name>` |
| Pop top patch | `stg pop` |
| Push next patch | `stg push` |
| Pop all patches | `stg pop -a` |
| Push all patches | `stg push -a` |
| View series | `stg series` |
| View series with descriptions | `stg series -d` |

Prefer `stg goto` over manual pop/push sequences.

## Viewing patches

| Task | Command |
| ---- | ------- |
| Show message + diff | `stg show <patch-name>` |
| Show message only | `stg show -O --no-patch <patch-name>` |
| Show diff only | `stg diff -r <patch-name>~..<patch-name>` |
| Combined diff across patches | `git diff $(stg id <first>~1) $(stg id <last>)` |

## Inspecting metadata

| Task | Command |
| ---- | ------- |
| Commit log for a patch | `stg log <patch-name>` |
| Files changed by a patch | `stg files <patch-name>` |
| Patches that modify a file | `stg patches <file-path>` |

## Reordering

| Task | Command |
| ---- | ------- |
| Move toward base (earlier) | `stg sink <patch-name>` |
| Move toward top (later) | `stg float <patch-name>` |
| Move to specific position | `stg sink --to <target> <patch>` |

## Deleting and renaming

| Task | Command |
| ---- | ------- |
| Delete a patch | `stg delete <patch-name>` |
| Delete multiple patches | `stg delete <patch1> <patch2>` |
| Rename a patch | `stg rename <old-name> <new-name>` |

## Initializing and finalizing

| Task | Command |
| ---- | ------- |
| Initialize stg on branch | `stg init` |
| Convert bottom N patches to commits | `stg commit -n <N>` |
| Convert all applied patches | `stg commit -a` |
| Turn N git commits into patches | `stg uncommit -n <N>` |

## Undo and redo

| Task | Command |
| ---- | ------- |
| Undo last operation | `stg undo` |
| Redo last undone operation | `stg redo` |
| Undo N operations | `stg undo -n <N>` |

## Repairing

```bash
stg repair
```

Reconciles stack metadata with git state after an
accidental raw git operation.

## Rebasing

```bash
stg rebase <new-base>
stg rebase --merged <new-base>   # when upstream has your patches
```

Use `--merged` after a maintainer merges part of the
series. Follow with `stg clean` to remove empty patches.

## Importing

| Task | Command |
| ---- | ------- |
| Import from mbox | `stg import -m <file.mbx>` |
| Import single patch | `stg import <file.patch>` |
| Import from stdin | `stg import -m` |

## Picking and folding

| Task | Command |
| ---- | ------- |
| Pick from another branch | `stg pick -B <branch> <patch>` |
| Pick a commit by SHA | `stg pick <committish>` |
| Fold diff into current patch | `stg fold <file.diff>` |

Run `stg refresh` after `stg fold`.

## Exporting

| Task | Command |
| ---- | ------- |
| Export to directory | `stg export -d <dir>` |
| Export to stdout | `stg export -s` |

## Email

**Formatting:**

| Task | Command |
| ---- | ------- |
| Format all applied patches | `stg email format -a -o <dir>` |
| Format with cover letter | `stg email format --cover-letter -o <dir>` |
| Format version 2 | `stg email format -v2 -o <dir>` |
| Custom subject prefix | `stg email format --subject-prefix="PATCH net-next" -o <dir>` |
| Mark as RFC | `stg email format --rfc -o <dir>` |

**Sending:**

| Task | Command |
| ---- | ------- |
| Send patches | `stg email send --to <addr> <dir>/` |
| Dry run | `stg email send --dry-run <dir>/` |
| Reply to prior message | `stg email send --in-reply-to <msg-id> <dir>/` |

## Splitting a patch

1. `stg goto <patch-name>`
2. `stg spill`
3. Stage the first portion of changes.
4. `stg refresh --index`
5. `stg new <next-name> -m "message"` then `stg refresh`
6. Repeat 3-5 for additional splits.
7. `stg push -a`

## Inserting a patch mid-series

1. `stg goto <predecessor>`
2. `stg new <name> -m "message"`
3. Make changes and `stg refresh`
4. `stg push -a`

## Cleaning up

```bash
stg clean      # remove empty patches
stg spill      # reset current patch to empty, keep changes in worktree
```
