---
name: stg
description: Load anytime the working directory is a git repository. When stg is active on a branch, use stg commands instead of raw git for creating commits, managing patch series, or performing version control operations.
invocation_policy: automatic
allowed-tools: Bash(*:stg series *), Bash(*:stg show *), Bash(*:stg log *), Bash(*:stg id *), Bash(*:stg diff *), Bash(*:stg files *), Bash(*:stg patches *), Bash(*:git diff *), Bash(*:git log *), Bash(*:git reflog *)
---

# Use stg commands instead of raw git for commit operations

## Detection

Check if stg is active before using these commands:

```bash
stg series >/dev/null 2>&1
```

If this succeeds, use stg commands. If it fails, fall back to standard git.

## CRITICAL: Prohibited git commands when stg is active

**NEVER use these git commands when stg is active on a branch.
They move HEAD behind stg's back, corrupting the stack metadata
and requiring `stg repair` to recover.**

- `git commit` (use `stg new` + `stg refresh`)
- `git commit --amend` (use `stg refresh` or `stg edit --file <path>`)
- `git rebase` (use `stg rebase` or `stg sink`/`stg float`)
- `git reset` (use `stg pop`/`stg undo`)
- `git cherry-pick` (pop to the target position, `stg import`)

This applies to all agents and subagents. A raw `git commit
--amend` to fix a commit message MUST use `stg edit --file
<path>` instead.

## Core Commands

Several stg commands accept variadic `[patch]...` positional
arguments (`squash`, `float`, `sink`, `push`, `pop`, etc.).
Always place options before patch names on the command line;
options placed after the first patch name are consumed as
patch names, producing "invalid patch range" errors.

### Creating and Updating Patches

| Task | Command |
| ---- | ------- |
| Create new patch | `stg new <name> -m "message"` |
| Update current patch with working tree changes | `stg refresh` |
| Update current patch with staged changes only | `stg refresh --index` |
| Edit current patch message | `stg edit --file <path>` |
| Edit patch message and diff | `stg edit --diff --file <path>` |

Always provide `-m` flag to `stg new` and `--file <path>`
to `stg edit` to avoid interactive editors.

`stg edit --diff` includes the patch diff in the edit file,
allowing changes to both the commit message and the patch
content in one operation.

### Squashing Patches

| Task | Command |
| ---- | ------- |
| Squash with message from file | `stg squash -n <name> -f <path> <patch1> <patch2>` |
| Squash with inline message | `stg squash -n <name> -m "message" <patch1> <patch2>` |

Write multi-line commit messages to a temp file and pass
`-f /tmp/msg.txt` rather than using heredocs or `/dev/stdin`.

### Navigation

| Task | Command |
| ---- | ------- |
| Go to specific patch | `stg goto <patch-name>` |
| View patch series | `stg series` |
| View series with descriptions | `stg series -d` |

Prefer `stg goto` over manual `stg pop`/`stg push` sequences.

### Viewing a Single Patch

To see the commit message and diff for a patch (defaults to the
top patch if no name is given):

```bash
stg show <patch-name>
```

To see just the commit message (no diff):

```bash
stg show -O --no-patch <patch-name>
```

(`-O` passes the following option through to `git diff`.)

To see just the diff (no commit message):

```bash
stg diff -r <patch-name>~..<patch-name>
```

**Do NOT use `stg diff <patch-name>` without `-r`. The patch
name is interpreted as a file path, producing silent wrong
output.**

### Inspecting Patch Metadata

| Task | Command |
| ---- | ------- |
| Show commit log for a patch | `stg log <patch-name>` |
| List files changed by a patch | `stg files <patch-name>` |
| Show which patches modify a file | `stg patches <file-path>` |

### Generating a Combined Diff Across Multiple Patches

stg patch names are not git refs and cannot be used in
`git diff` ranges. To produce a single unified diff spanning
a range of patches, resolve the patch names to commit SHAs
with `stg id`, then use `git diff`:

```bash
git diff $(stg id <first-patch>~1) $(stg id <last-patch>)
```

The `~1` on the first patch gives the base commit before that
patch was applied, so the resulting diff covers all changes
from `<first-patch>` through `<last-patch>` inclusive.

### Series Management

| Task | Command |
| ---- | ------- |
| Pop top patch | `stg pop` |
| Push next patch | `stg push` |
| Pop all patches | `stg pop -a` |
| Push all patches | `stg push -a` |

### Reordering

| Task | Command |
| ---- | ------- |
| Move patch earlier in the series | `stg sink <patch-name>` |
| Move patch later in the series | `stg float <patch-name>` |
| Move patch to specific position | `stg sink --to <target> <patch>` |

Earlier means closer to the base (applied first); later means
closer to the top (applied last).

### Deleting and Renaming Patches

| Task | Command |
| ---- | ------- |
| Delete a patch | `stg delete <patch-name>` |
| Delete multiple patches | `stg delete <patch1> <patch2>` |
| Rename a patch | `stg rename <old-name> <new-name>` |

`stg delete` removes a patch from the series entirely. The
patch need not be on top; stg handles the pop/push cycle
internally.

### Refreshing a Non-Current Patch

To fold working tree changes into a patch that is not on top:

```bash
stg refresh -p <patch-name>
```

This avoids the need to `stg goto <patch>`, refresh, then
push the rest of the series back.

### Initializing and Finalizing

| Task | Command |
| ---- | ------- |
| Initialize stg on current branch | `stg init` |
| Convert bottom N patches to git commits | `stg commit -n <N>` |
| Convert all applied patches to git commits | `stg commit -a` |
| Turn N most recent git commits into stg patches | `stg uncommit -n <N>` |

`stg commit` permanently converts applied patches at the
bottom of the stack into ordinary git commits. Use this when
a series is finalized and no longer needs stg management.
`stg uncommit` does the reverse, pulling git commits back
into the stg stack for further editing.

### Undo and Redo

| Task | Command |
| ---- | ------- |
| Undo last stg operation | `stg undo` |
| Redo last undone operation | `stg redo` |
| Undo N operations | `stg undo -n <N>` |

`stg undo` reverts the last stack-mutating operation (push,
pop, refresh, new, delete, etc.). Safe to use for recovery
after an unintended operation.

### Rebasing the Stack

To rebase all patches onto a new base commit:

```bash
stg rebase <new-base>
```

This pops all patches, moves the stack base to `<new-base>`,
and re-applies patches one at a time. Conflicts may arise
at each patch; resolve them using the Merge Conflict
Resolution procedure in this document.

### Importing Patches

| Task | Command |
| ---- | ------- |
| Import from mbox file | `stg import -m <file.mbx>` |
| Import a single patch file | `stg import <file.patch>` |
| Import from stdin | `stg import -m` (reads stdin) |

When importing from an mbox, each email becomes a separate
patch. The commit message is taken from the email subject
and body.

### Cleaning Up Empty Patches

```bash
stg clean
```

Removes patches that have become empty (no diff). Useful
after conflict resolution or editing leaves a patch with
no actual changes.

### Spilling a Patch

`stg spill` resets the current patch to empty while leaving
its changes in the working tree (or index, with `--index`).
This is useful for repartitioning a patch's content.

### Splitting a Patch

To split one patch into multiple patches:

1. Navigate to the patch: `stg goto <patch-name>`
2. Spill its changes back to the working tree: `stg spill`
3. Selectively stage the first portion of changes.
4. Refresh the current (now-empty) patch: `stg refresh --index`
5. Create a new patch for the remainder:
   `stg new <next-name> -m "message"` then `stg refresh`
6. Repeat steps 3-5 if splitting into more than two patches.
7. Push the rest of the series: `stg push -a`

### Inserting a Patch in the Middle of the Series

1. Navigate to the patch that should precede the new one:
   `stg goto <predecessor>`
2. Create the new patch: `stg new <name> -m "message"`
3. Make changes and refresh: `stg refresh`
4. Push the rest of the series: `stg push -a`

### Series Output Format

`stg series` marks each patch with a prefix:

| Prefix | Meaning |
| ------ | ------- |
| `>` | Current (top applied) patch |
| `+` | Applied patch |
| `-` | Unapplied patch |

Filter with `--applied` or `--unapplied` to show only
patches in that state.

## Git-to-Stg Command Mapping

The prohibited commands section above lists the primary
mappings. These additional mappings cover git operations
that are safe but have more idiomatic stg equivalents:

| Instead of | Use |
| ---------- | --- |
| `git rebase -i` (reorder) | `stg sink`, `stg float` |
| `git rebase -i` (squash/fixup) | `stg squash` |

## Parallelism Prohibition

**CRITICAL: stg stack operations are strictly sequential.**

The stg stack is a single shared resource. Every `stg new`,
`stg refresh`, `stg goto`, `stg push`, `stg pop`, `stg float`,
and `stg sink` mutates HEAD and the on-disk stack metadata.
Two agents performing stg operations concurrently will
interleave those mutations, producing patches with wrong
contents, hunks absorbed into the wrong patch, or a corrupted
stack requiring `stg repair`.

**When stg is active on the branch, do NOT delegate patch
creation or editing to parallel subagents.** All stg operations
on a given branch must be performed by a single agent in a
single sequential session. Parallelism is safe only for work
that produces no stg operations (e.g., read-only research,
building, testing).

When a plan-execution coordinator detects that stg is active,
it MUST abandon parallel delegation for implementation tasks
and fall back to a single sequential developer agent for all
patch creation and editing.

## Merge Conflict Resolution

When `stg push` or `stg rebase` results in merge conflicts:

1. Use `git reflog` to examine the pre-merge state of the patch.
   The reflog entry before the failed push shows the original
   patch content, which guides the correct conflict resolution.
2. Edit the conflicted files to resolve each conflict.
3. Mark each resolved file with `stg resolved <filename>` (not
   `git add`). stg will not permit `stg refresh` until all
   conflicted files have been marked resolved this way.
4. Run `stg refresh` to update the patch with the resolution.
