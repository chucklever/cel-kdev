---
name: stg
description: >-
  Load when committing, amending, rebasing, or managing patches
  in any repository that uses StGit (stg). Required whenever
  the user asks to commit changes, update a commit, create or
  edit a patch, reorder patches, or resolve merge conflicts
  on a branch with an active stg stack.
---

# stg: patch stack management

When stg is active on a branch, use stg commands instead of
raw git for all commit operations. Check activation in two
steps so each command stays simple and avoids unnecessary
permission prompts:

1. `git branch --show-current` — get the branch name
2. `git show-ref --verify refs/stacks/<branch>` — check
   for the stg stack ref

A zero exit status on step 2 means stg is active; non-zero
means it is not. Do not combine these into a single shell
command: pipes, `$()`, and `xargs` are harder for hooks and
approval rules to inspect and can trigger prompts.

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
| `git checkout <branch>` / `git switch <branch>` | `stg branch <branch>` |
| `git checkout`/`git restore` (pathspec, any form) | prohibited; leave worktree dirty + scope `stg refresh <pathspec>` (see prose) |
| `git merge` | No stg merge; build a base merge commit and `stg rebase` onto it (see "Combining branches: there is no stg merge") |

This applies to all agents and subagents.

`stg branch <name>` both creates and switches branches; it
is the canonical stg interface for branch operations. The
runtime hook's `git branch -> stg branch` line refers to
this.

`git checkout` is not used on an stg branch in any form,
period. This covers every surface: the branch forms
`git checkout <branch>`, `git checkout -b`, and
`git switch`; and the pathspec forms `git checkout <file>`,
`git checkout .`, `git checkout <commit> -- <file>`, and
`git restore [--staged] <file>`. The branch-switching form
bypasses stg's metadata bookkeeping. The pathspec form does
not move HEAD, but it is equally prohibited: it conflates
"discard this from the worktree" with "keep this out of the
patch." Reverting a file in the worktree does not remove an
already-refreshed change from the patch commit -- the stale
diff stays baked in, and a later `stg refresh` cannot undo
it, so the patch must be deleted and recreated. When only
some worktree changes belong in the next patch, scope the
refresh with `stg refresh <pathspec>` and leave the rest of
the worktree modified (see Pitfalls).

**`git worktree`** creates a new checkout that shares refs
with the main working tree. Stg tracks its stack state in
refs (`refs/stacks/<branch>`); a worktree that checks out
the same branch or manipulates shared refs corrupts the
stack metadata just like a raw `git commit` would.

This rule overrides the `superpowers:using-git-worktrees`
skill on stg branches.  Do not create a worktree for an
stg branch even when that skill recommends one for plan
isolation; on an stg branch, the stg prohibition wins.

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

## Finding the stack base

The stack base is the commit each applied patch sits above.
It is recorded per branch in stg metadata; do not assume
`origin/master` -- a branch may be rooted on any ref.

```bash
# Commit hash of the base (canonical lookup)
stg id {base}

# Upstream ref name (the form b4 expects as a fork-point)
remote=$(git config branch.<name>.remote)
parent=$(git config branch.<name>.stgit.parentbranch)
echo "${remote}/${parent#refs/heads/}"
```

`stgit.parentbranch` may be stored as a bare branch name
(`master`) or as a `refs/heads/` ref; stripping the prefix
handles both.  Not every stg branch has `parentbranch`
configured, so `stg id {base}` is the more reliable lookup
when only the commit hash is needed.  When the base is a
tag or an explicit remote ref, read `parentbranch` directly
without composing.

## Combining branches: there is no stg merge

StGit has no `stg merge`. The stack is a linear sequence of
patches above a single base commit, so it cannot hold a
multi-parent merge commit -- this is why `stg repair` refuses
merge commits. The base *below* the stack can still be any
commit, including a merge. To integrate several branches under
the stack, build the merge as ordinary history at the base, then
replay the stack onto it with `stg rebase`.

Split on intent:

- **Linearize onto a new base** (the stg-shaped task): replay or
  absorb commits, no merge commit involved.
  - `stg rebase <new-base>` -- replay the stack on a new base
    (e.g. a release tag).
  - `stg pick -B <branch> <commit>` / `stg pick <sha>` -- absorb
    individual commits from another branch as new patches.
  - `stg import -m <mbox>` -- pull a series in as patches.
- **True merge** (combine branch histories, keep a merge commit
  as the base): construct the merge commit, then rebase onto it.

### Constructing a base merge commit locally

Build the merge commit with plumbing so HEAD never leaves the stg
branch and no stack metadata is touched. Do not switch to a
scratch branch, and do not run raw `git merge` on the stg branch:
merging into the stack's HEAD corrupts the stack (see the "Merge
commits and repair" pitfall). The branches to combine may be
local or fetched first -- `git fetch <remote>` brings refs only
and does not move HEAD.

```bash
base=$(stg id {base})              # current stack base
c=$base
for b in <ref1> <ref2> <ref3>; do  # branches/tags to combine
    t=$(git merge-tree --write-tree "$c" "$b") || {
        echo "conflict merging $b; build it on an integration"
        echo "branch instead (see below) -- merge-tree leaves"
        echo "no worktree to resolve in"; c=; break; }
    c=$(git commit-tree "$t" -p "$c" -p "$(git rev-parse "$b")" \
            -m "merge $b into base")
done
[ -n "$c" ] && stg rebase "$c"     # replay only a complete merge
```

`git merge-tree --write-tree` (git >= 2.38) performs a 3-way
merge writing only tree and blob objects; `git commit-tree`
records the merge commit. Neither moves HEAD or updates a ref, so
the stg guard hook permits both. Do not confuse this constructed
commit with `git merge-base`, which only reports a common ancestor
and writes nothing.

The loop builds a chain of two-parent merge commits, normally what
you want. To record a single octopus commit instead -- one commit
with every branch as a parent -- reuse the combined tree the loop
leaves in `$t` and pass all parents to one
`git commit-tree "$t" -p "$base" -p <sha1> -p <sha2> ...`. Feeding
three refs to a single `git merge-tree` does not work; each call
merges exactly two commits.

Until `stg rebase` records it as the new base, the merge commit is
referenced only by the `$c` shell variable -- no ref, no reflog
entry -- so it is eligible for garbage collection. Do not run
`git gc` or start a fresh shell between building the commit and the
rebase.

An integration branch in another repository is the fallback for
two cases: a `merge-tree` conflict, which needs a real worktree to
resolve, and a merge that must be published rather than kept local.
Build the merge there, fetch it, and `stg rebase <fetched-ref>` --
the same final step with a different origin for the base commit.

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

**`stg push <name>` and `stg pop <name>` reorder the series.**
The named forms reposition that one patch -- they do not step
the stack in series order. Using them to walk a stack lifts
patches ahead of their prerequisites, and later pushes hit
context-shift conflicts whose root cause is the silent
reordering, not the patches. To navigate without reordering
use `stg goto <name>`, or `stg push -n N` / `stg push -a` for
forward steps. See [references/commands.md](references/commands.md).

**Merge commits and repair**: Raw `git merge` on an stg branch
commits the merge to the stack's HEAD, leaving the patches below
the merge commit; `stg repair` then reports them "hidden below
the merge commit" and marks them unapplied. `stg repair` cannot
convert a merge commit into a patch. Use `stg undo` to remove an
accidental merge before running `stg repair`. To combine branches
deliberately, build the merge below the stack base instead of on
its HEAD -- see "Combining branches: there is no stg merge".

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

**Unintended files in `stg refresh`**: bare `stg refresh`
captures *all* modified tracked files, not just the ones
edited for the current patch. If the worktree has unrelated
dirty files (generated artifacts, uncommitted work from a
prior step), they silently enter the patch. When only
specific files belong in the patch, pass them as pathspec
arguments:

```bash
stg refresh path/to/file1 path/to/file2
```

Do not run bare `stg refresh` after `stg new` when the
worktree contains other modifications. Check `git status`
first if uncertain.

**Never `git checkout`/`git restore` to drop worktree
noise**: when some worktree modifications belong in the
patch and others do not, scope the refresh -- `stg refresh
<pathspec>` folds in only the named paths and leaves the
rest dirty. Do not reach for `git checkout -- <file>` or
`git restore <file>` to discard the unwanted changes first.
On an stg branch this is prohibited outright: if the
unwanted change was already folded into the patch, restoring
the worktree leaves the stale diff in the patch commit, and
`stg refresh` cannot remove it. Leave unwanted modifications
dirty in the worktree and deal with them after the patch is
complete: `git stash` (and later `git stash pop`) only
touches the worktree and the stash ref, never HEAD or stack
metadata, so it is safe on an stg branch; or fold them into
a later patch.

To actually back out a change that is *already folded into*
the patch, edit the file in the worktree to the content you
want and `stg refresh` to fold the correction in -- or, if
the refresh was the last operation, `stg undo` to reverse
it. When the patch is beyond repair, `stg delete <patch>`
and recreate it. Never use `git checkout`/`git restore` to
undo a refreshed change.

**`stgit.autosign` trailer**: When `stgit.autosign` is set
in git config (e.g., to `Signed-off-by`), `stg new` and
`stg import` append that trailer automatically, including
the non-interactive `-m`/`--file` paths; do not also write
it into those messages by hand. The `-m` flag on
`stg import` selects mail/mbox input format and has no
effect on trailer behavior.

`stg edit` is the exception: it autosigns only when it
opens the interactive editor. The `stg edit -m` and
`stg edit --file` forms this skill mandates do NOT
autosign, so a `Signed-off-by` line omitted from the
message leaves the patch with none. Default: include the
`Signed-off-by` line in the `stg edit` message text. These
paths do not autosign, so exactly one trailer results
regardless of stg version. Alternatively, omit it from the
message and stamp it with the `-s`/`--signoff` flag (see
Trailer flags below).

**File-edit cache stale after stack ops**: Any stg command that
moves HEAD or rewrites a patch's tree (`push`, `pop`, `goto`,
`refresh`, `squash`, `fold`, `sink`, `float`, `pick`, `import`,
`rebase`, `undo`, `redo`, `edit --set-tree`) rewrites tracked
files on disk. Per-file freshness snapshots held by editing
tools can go stale; the next edit may fail with "File has
been modified since read." Re-read the file before the next
edit.

## Token efficiency

**Do not verify after refresh.** After `stg refresh`, do not
call `stg show`, `stg series`, or `stg diff` to confirm the
operation succeeded.  Check the exit code instead.  Only
read patch content when the next step actually requires it
(e.g., editing the commit message or reviewing the diff at
the user's request).

Exception for pathspec-scoped refresh: `stg refresh
<pathspec>` exits 0 even when the pathspec matches no
modified file, folding in nothing.  Exit code alone cannot
tell "captured the change" from "matched nothing."  Confirm
the path is correct relative to the current working
directory, or pass a repo-absolute path, and check with
`git status --short` that the path is no longer dirty.  This
one cheap check is warranted for pathspec-scoped refreshes,
even though verification is otherwise discouraged.

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

1. `git status` — identify every conflicted file.
2. Classify each conflict (take-ours, take-theirs,
   concatenate, or semantic).  Resolve trivial cases
   directly.
3. For semantic conflicts, recover the three-way view
   (`git show :1:`, `:2:`, `:3:` for base/ours/theirs)
   and read both sides' commit messages before editing.
4. `stg resolved <file>` (not `git add`) after each file.
5. `stg refresh` to finalize.

If intent cannot be determined, leave conflict markers in
place and report what is ambiguous rather than guessing.

To abort: `stg undo` reverts the failed operation.

See [references/conflict-resolution.md](references/conflict-resolution.md)
for the full context-gathering strategy, classification
table, and prior-resolution retrieval.

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
