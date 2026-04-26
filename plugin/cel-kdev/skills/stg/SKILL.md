---
name: stg
description: >-
  Load when committing, amending, rebasing, or managing patches
  in any repository that uses StGit (stg). Required whenever
  the user asks to commit changes, update a commit, create or
  edit a patch, reorder patches, or resolve merge conflicts
  on a branch with an active stg stack.
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

**`Edit` cache stale after stack ops**: Any stg command that
moves HEAD or rewrites a patch's tree (`push`, `pop`, `goto`,
`refresh`, `squash`, `fold`, `sink`, `float`, `pick`, `import`,
`rebase`, `undo`, `redo`, `edit --set-tree`) rewrites tracked
files on disk. The `Edit` tool's per-file freshness snapshot
goes stale; the next `Edit` fails with "File has been modified
since read." `Read` the file again before the next `Edit`.

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

### Trailer flags

`stg new`, `stg edit`, and `stg refresh` accept three
non-interactive trailer flags (no editor launched):

- `-s` / `--signoff[=<value>]` -- Signed-off-by
- `--ack[=<value>]` -- Acked-by
- `--review[=<value>]` -- Reviewed-by

With no `=<value>`, each uses the configured git user
identity; with `=<value>`, the given string is inserted
verbatim. The `=` is mandatory when supplying a value --
`--review="Name <email>"` works, but `--review "Name
<email>"` fails because stg consumes the next token as a
patch name. Each flag may be repeated to add multiple
trailers of the same type in one invocation.

Compose with a `stg series --noprefix` loop to stamp a
trailer across the whole stack:

```bash
for p in $(stg series --noprefix); do
    stg edit --review="Name <email>" "$p"
done
```

Each `stg edit` rewrites that patch's commit; expect every
patch at or above the edited one to get a new SHA.

Use `stg refresh --signoff` / `--ack` / `--review` to stamp
the top patch in place without a `stg goto`.

There is no generic `--trailer` / `-t` flag on `stg edit`;
`-t` is `--set-tree`. Do not extrapolate from
`git commit --trailer`.

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

`stg log` accepts no `--format` or `--oneline`; output is
limited to its default, `--full` (full git-log format), or
`--diff` (stack-state diffs).

### Branch reflog vs stg log

`git reflog <branch>` (an alias for
`git log -g --abbrev-commit --pretty=oneline <branch>`)
and `stg log` show overlapping but different histories:

| View                   | What entries record                              | SHA points at      | Best for                                                  |
| ---------------------- | ------------------------------------------------ | ------------------ | --------------------------------------------------------- |
| `git reflog <branch>`  | stg ops that moved HEAD on the active branch     | The code commit    | "What did the top patch look like N refreshes ago?"       |
| `stg log [<patch>]`    | Every stack-state change, incl. unapplied moves  | An stg meta commit | "When did patch X enter the stack? Was it ever popped?"   |

Reflog and `stg log` entries for the same op carry the
same message string, so the two views can be aligned by
matching on that description.

Recipe for the reflog case -- walk HEAD snapshots and
inspect the file at each one. Do not pair `-- <path>`
with a reflog walk (`git reflog` or `git log -g`):
pathspec filtering treats reflog entries as linear
ancestors, which they are not in a shuffled stg history.
The filter silently elides relevant entries -- often
every entry -- because each step's commit is diffed
against its git-parent rather than the prior reflog step.

```bash
git reflog <branch>
git show <sha>:<path>
git diff <old-sha> <new-sha> -- <path>
```

The branch reflog records only HEAD movements on the
active branch. Metadata-only operations (those that do
not move HEAD) and edits to a patch made while it is
unapplied appear only in `stg log`. HEAD-moving ops
performed while some patch is unapplied (e.g., `stg pop`,
`stg push <patch>`, `stg goto`) still appear in the
reflog.

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
