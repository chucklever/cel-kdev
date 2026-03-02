---
name: stg
description: Load anytime the working directory is a git repository. When stg is active on a branch, use stg commands instead of raw git for creating commits, managing patch series, or performing version control operations.
invocation_policy: automatic
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
- `git commit --amend` (use `stg refresh` or `stg edit`)
- `git rebase` (use `stg rebase` or `stg sink`/`stg float`)
- `git reset` (use `stg pop`/`stg undo`)
- `git cherry-pick` (pop to the target position, `stg import`)

This applies to all agents and subagents. A raw `git commit
--amend` to fix a commit message MUST use `stg edit` instead.

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

Always provide `-m` flag to `stg new` to avoid interactive editor.

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
| Move patch down (toward bottom of series) | `stg sink <patch-name>` |
| Move patch up (toward top of series) | `stg float <patch-name>` |
| Move patch to specific position | `stg sink --to <target> <patch>` |

`stg sink` moves a patch earlier in the series (lower in the stack).
`stg float` moves a patch later in the series (higher in the stack).

## Git-to-Stg Command Mapping

| Instead of | Use |
| ---------- | --- |
| `git commit` | `stg new <name> -m "message"` then `stg refresh` |
| `git commit --amend` | `stg refresh` or `stg edit` |
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
