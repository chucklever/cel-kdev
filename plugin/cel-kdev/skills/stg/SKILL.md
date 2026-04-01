---
name: stg
description: >-
  StGit (stg) patch stack management. When stg is active on a
  branch, replaces git commit, amend, rebase, and reset with stg
  equivalents to prevent stack corruption. Covers patch creation,
  reordering, squashing, conflict resolution, and series management.
invocation_policy: automatic
---

# stg: patch stack management

When stg is active on a branch, use stg commands instead of
raw git for all commit operations. Check activation in two
steps so each command matches an allowed-tool prefix and
avoids a permission prompt:

1. `git branch --show-current` — get the branch name
2. `git show-ref --verify refs/stacks/<branch>` — check
   for the stg stack ref

A zero exit status on step 2 means stg is active; non-zero
means it is not. Do not combine these into a single shell
command (pipes, `$()`, and `xargs` defeat prefix matching
and trigger a permission prompt).

## CRITICAL: Prohibited git commands

**NEVER use these git commands when stg is active. They move
HEAD behind stg's back, corrupting the stack metadata.**

| Prohibited | Replacement |
| ---------- | ----------- |
| `git commit` | `stg new <name> -m "msg"` + `stg refresh` |
| `git commit --amend` | `stg refresh` or `stg edit --file <path>` |
| `git rebase` | `stg rebase`, `stg sink`, `stg float` |
| `git reset` | `stg pop`, `stg undo` |
| `git cherry-pick` | `stg pick` or `stg import` |
| `git rebase -i` (reorder) | `stg sink`, `stg float` |
| `git rebase -i` (squash) | `stg squash` |
| `git worktree add` | (not supported with stg) |

This applies to all agents and subagents.

**`git worktree`** creates a new checkout that shares refs
with the main working tree. Stg tracks its stack state in
refs (`refs/stacks/<branch>`); a worktree that checks out
the same branch or manipulates shared refs corrupts the
stack metadata just like a raw `git commit` would.

## CRITICAL: No parallel stg operations

The stg stack is a single shared resource. Every mutating
command (`new`, `refresh`, `goto`, `push`, `pop`, `float`,
`sink`) changes HEAD and on-disk metadata. Concurrent stg
operations from parallel agents corrupt the stack.

**Do NOT delegate patch creation or editing to parallel
subagents.** All stg operations on a given branch must run
in a single sequential session. Parallelism is safe only
for read-only work (research, building, testing).

## Stack model

```
+ patch-a          <- applied, ancestor of HEAD
+ patch-b          <- applied, ancestor of HEAD
> patch-c          <- current top patch = HEAD
- patch-d          <- unapplied, not ancestor of HEAD
- patch-e          <- unapplied, not ancestor of HEAD
```

Applied patches (`+` and `>`) form a contiguous commit
sequence above the stack base. HEAD points at the topmost
applied patch (`>`).

Unapplied patches (`-`) are commit objects in stg metadata
but not ancestors of HEAD. They do not appear in `git log`.
Use `stg show` with patch names from `stg series --unapplied`
to examine them -- not `HEAD~N`.

## Pitfalls

**`stg diff` without `-r`**: `stg diff <patch-name>` treats
the argument as a file path, producing silent wrong output.
Use `stg diff -r <patch-name>~..<patch-name>` for a patch diff.

**`stg fold` positioning**: `stg fold` applies to the current
top patch only. Use `stg goto` first to position the stack.

**Options vs patch names**: Commands accepting `[patch]...`
arguments (`squash`, `float`, `sink`, `push`, `pop`) consume
everything after the first patch name as patch names. Place
all options before patch names.

**Merge commits and repair**: `stg repair` cannot convert
merge commits into patches. Use `stg undo` to remove an
accidental merge before running `stg repair`.

**`git add` before `stg refresh`**: `stg refresh` picks up
all changes to tracked files automatically. Do not run
`git add <file> && stg refresh` or `stg add <file> &&
stg refresh` -- the staging step is unnecessary. `stg add`
is needed only when introducing a new file to the repository
(adding it to the tracked list for the first time).
`stg resolved` is needed only to indicate that merge
conflicts have been cleared, not for routine refreshes.

**Dirty index guard on `stg refresh`**: When changes exist
in both the index and the worktree (e.g., after `stg add`,
`stg mv`, or `stg rm` staged some paths), plain `stg refresh`
refuses with "the index is dirty." Two flags override this:

- `--index` (`-i`): refresh only from what is staged in the
  index, ignoring worktree changes. Use after `stg add`,
  `stg mv`, or `stg rm` when only the staged changes belong
  in the patch. Mutually exclusive with pathspecs, `--update`,
  and `--force`.
- `--force` (`-F`): fold in all changes from both the index
  and the worktree, bypassing the dirty-index check.

**`stgit.autosign` trailer**: When `stgit.autosign` is set
in git config (e.g., to `Signed-off-by`), `stg new`,
`stg import`, and `stg edit` automatically append that
trailer. The `-m` flag on `stg import` selects mail/mbox
input format and has no effect on trailer behavior.

## Token efficiency

**Do not verify after refresh.** After `stg refresh`, do not
call `stg show`, `stg series`, or `stg diff` to confirm the
operation succeeded.  Check the exit code instead.  Only
read patch content when the next step actually requires it
(e.g., editing the commit message or reviewing the diff at
the user's request).

**Use `git status` for working tree state.** `git status`
is the cheapest way to check whether there are modified
tracked files, untracked files, or merge conflicts.  Use
it instead of `stg diff` when the goal is to determine
whether anything needs refreshing, not what the changes are.

**Do not diff before refresh.** `stg refresh` captures all
modifications to tracked files automatically.  Do not run
`stg diff` before `stg refresh` to preview what will be
folded in — unless the user explicitly asks to review
pending changes first.

**Batch patch inspection.** When reviewing multiple patches,
avoid walking the stack one `stg show` at a time.  Prefer:

- `stg series -d` — names and descriptions in one call.
- `stg diff -r <first>~..<last>` — combined diff across a
  range of patches.
- `stg show -O --stat <patch>` — summary only, when the
  full diff is not needed.

**Limit stg series calls.** Run `stg series` (or
`stg series -d`) once for orientation at the start of a
session.  After `stg push`, `stg pop`, `stg goto`, or
`stg new`, the new stack position is known from the command
output — do not re-run `stg series` to confirm it.  Prefer
`stg series -d` over a plain `stg series` followed by
individual `stg show` calls when both names and descriptions
are needed.

## Avoiding interactive editors

Always provide `-m` to `stg new` and `--file <path>` to
`stg edit`. Write multi-line messages to a temp file and
pass `-f /tmp/msg.txt` to `stg squash`.

Use `-s` / `--sign` to auto-generate Signed-off-by from
git config.

## Merge conflict resolution

When `stg push` or `stg rebase` produces conflicts:

1. Run `git status` to identify conflicted files.
2. Run `git reflog` to examine the pre-merge patch state.
3. Edit conflicted files to resolve each conflict.
4. Mark resolved files with `stg resolved <file>` (not
   `git add`).
5. Run `stg refresh` to finalize the resolution.

To abort: `stg undo` reverts the failed operation.

## Tracing patch evolution with stg log

`stg log [<patch>]` prints the history of stack operations
for a patch (or the whole stack). Each line has the form:

```
<meta-sha>   <date>   <description>
```

**The `<meta-sha>` is an stg metadata commit, not the
patch's code commit.** It records a snapshot of the stack
state (which patches are applied, their order, and their
content). Do not pass it to `git show` or `git diff`
expecting code -- it contains stg internal files
(`stack.json`, `patches/<name>`, etc.).

`stg log` accepts no formatting flags (no `--format`,
`--oneline`, etc.). Its output format is fixed.

### Extracting a patch diff at a historical point

Each metadata commit stores per-patch content as tree
OIDs in `patches/<name>`:

```
Bottom: <tree-oid-before>
Top:    <tree-oid-after>
```

To reconstruct the patch diff at a given `stg log` entry:

```bash
# Read the Top and Bottom tree OIDs
git show <meta-sha>:patches/<patch-name>

# Diff the two trees to see the patch content
git diff <bottom-tree> <top-tree> -- <file>
```

For bisecting when a change entered a patch or inspecting
the cumulative HEAD across patches, see
[references/stg-log.md](references/stg-log.md).

## Command reference

See [references/commands.md](references/commands.md) for
the full command table covering creation, navigation,
reordering, splitting, importing, exporting, and email.
