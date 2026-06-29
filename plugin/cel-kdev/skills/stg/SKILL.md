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

The `block-raw-git.sh` guard hook checks stg-activity against
the repo the command targets: a leading `git -C <dir>` retargets
the check at `<dir>` when `<dir>` resolves to a directory,
otherwise it falls back to the hook's cwd -- the session's
primary branch -- keeping the guard fail-closed. The hook cannot see a `cd <repo> &&`
prefix; the harness resets cwd between calls. So when an stg
session also touches a second, non-stg repo, drive that repo
with `git -C <repo> <subcommand>` rather than a `cd`. The guard
then resolves `<repo>`, and once it confirms `<repo>` carries no
stg stack it permits raw git there. This is not a license to
bypass the guard on an actual stg branch.

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
| `git rebase -i` (squash) | fold workflow (see "Combining patches: avoid stg squash") |
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
  - `stg import -M <mbox>` -- pull a series in as patches
    (`-M`/`--mbox` reads an mbox series; `-m`/`--mail` reads a
    single mail file).
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
# seed when adding branches on top of the current base:
c=$(stg id {base})
# seed for a release rebase (new upstream tag; see below):
# c=$(git rev-parse "<next-rc>^{commit}")
for b in <ref1> <ref2> <ref3>; do  # branches/tags to combine
    t=$(git merge-tree --write-tree "$c" "$b") || {
        echo "conflict merging $b; build it on an integration"
        echo "branch instead (see below) -- merge-tree leaves"
        echo "no worktree to resolve in"; c=; break; }
    c=$(git commit-tree "$t" -p "$c" \
            -p "$(git rev-parse "$b^{commit}")" \
            -m "merge $b into base")
done
[ -n "$c" ] && echo "$c"           # anchor only a complete merge
```

`git merge-tree --write-tree` (git >= 2.38) performs a 3-way
merge writing only tree and blob objects; `git commit-tree`
records the merge commit. Neither moves HEAD or updates a ref, so
the stg guard hook permits both. Do not confuse this constructed
commit with `git merge-base`, which only reports a common ancestor
and writes nothing.

The `stg id {base}` seed is correct only when adding branches on
top of the current base. For a release rebase -- the new base is a
fresh merge of the next upstream tag plus the same topic branches --
the current base is the *old* merge, and seeding from it stacks
each cycle's merge on top of stale history. Seed from the new
upstream ref instead (`c=$(git rev-parse "<next-rc>^{commit}")`) and
merge the topic branches onto it.

Release tags are annotated, so a bare `git rev-parse <tag>` yields
the tag object, and a merge commit built with that as a parent
points at the tag object, not the commit. Dereference with
`^{commit}` wherever a ref may name a tag -- the seed and each
`-p` parent, as the recipe above does.

The loop builds a chain of two-parent merge commits, normally what
you want. To record a single octopus commit instead -- one commit
with every branch as a parent -- reuse the combined tree the loop
leaves in `$t` and pass the seed plus all branch tips to one
`git commit-tree "$t" -p <seed> -p <sha1> -p <sha2> ...`, where
`<seed>` is whichever seed the recipe above used. `$t` survives
only within the tool call that ran the loop, so this commit-tree
must run in the same call, or the tree OID must be captured and
passed explicitly. Feeding three refs to a single
`git merge-tree` does not work; each call merges exactly two
commits.

Until `stg rebase` records it as the new base, the merge commit is
referenced only by the `$c` shell variable -- no ref, no reflog
entry -- so it is eligible for garbage collection, and the variable
itself does not survive into a later shell. The loop and the
rebase normally run as separate tool calls, so `$c` does not
survive to the rebase. Anchor the commit with a plain ref before
rebasing:

```bash
git update-ref refs/tmp/<name> <sha>
stg rebase refs/tmp/<name>
git update-ref -d refs/tmp/<name>
```

Delete the temp ref after `stg rebase` returns, whether it
succeeded or left conflicts to resolve.

Use `git update-ref`, not `git tag`: with `tag.gpgsign` or
`tag.forceSignAnnotated` set (common in kernel trees),
`git tag <name> <sha>` fails with "fatal: no tag message?".
`update-ref` writes the ref directly, touches no stg metadata,
and bypasses signing. Placing it under `refs/tmp/` keeps it out
of `git tag -l`, `git describe`, and fetch refspecs.

When only the base moved (topic tips unchanged),
`git diff --stat <old-base> <new-merge>` matches
`git diff --stat <old-tag>..<new-tag>` exactly. A match before
`stg rebase` confirms the rebuilt merge introduces nothing beyond
the upstream delta. This check is a warranted exception to the
token-efficiency guidance: a silent mismatch here means the
rebuilt base carries unintended history.

An integration branch in another repository is the fallback for
two cases: a `merge-tree` conflict, which needs a real worktree to
resolve, and a merge that must be published rather than kept local.
Build the merge there, fetch it, and `stg rebase <fetched-ref>` --
the same final step with a different origin for the base commit.

## Combining patches: avoid stg squash

`stg squash` deletes all of its input patches and creates a
new patch whose `stg log` history begins at the squash; the
change history of every input patch is discarded. Do not use
it to fold a fix patch into the patch it corrects. Fold the
patch by hand instead -- the fold appears as ordinary refresh
and edit entries in the surviving patch's history.

To fold patch B into the patch A beneath it:

```bash
orig_top=$(stg top)          # topmost applied patch, to restore at the end
stg export -d <dir> B        # writes <dir>/B: B's message + diff
stg pop B
stg goto A                   # make A top (stg fold applies to the
                             # top patch); no-op only when B was the
                             # top patch directly above A
stg fold <dir>/B             # apply B's diff to the worktree
stg refresh                  # fold the change into A
stg edit --file <msg-file> A # combined message, if needed
stg delete B
[ "$orig_top" = B ] && orig_top=A  # if B itself was the top patch, the
                                   # fold deleted it; goto A instead
stg goto "$orig_top"         # restore the prior applied set; never
                             # 'stg push -a' here (see Pitfalls).
```

`<dir>/B` is a full patch file (message plus diff), not a
commit message. When A's message needs text from B's, write
the combined message to a temp file and pass that file as
`<msg-file>` -- do not pass `<dir>/B`. When A carries a
`Signed-off-by`, re-include that line in the combined message
to preserve it; `stg edit --file` does not autosign, so an
omitted trailer drops the one A had. A patch created while
`stgit.autosign` was unset carries none; do not add one.
After the fold the worktree holds only B's diff,
so a bare `stg refresh` is correct; scope it with a pathspec
only when the worktree was already dirty before the fold.
A content change may invalidate existing Reviewed-by tags
on A.

## Pitfalls

**`stg diff` without `-r`**: `stg diff <patch-name>` treats
the argument as a file path, producing silent wrong output.
Use `stg diff -r <patch-name>~..<patch-name>` for a patch diff.

**`stg fold` positioning**: `stg fold` applies to the current
top patch only. Use `stg goto` first to position the stack.

**Options vs patch names**: Commands accepting `[patch]...`
arguments (`float`, `sink`, `push`, `pop`) consume
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

**`stg push -a` overshoots the prior state**: after a
goto-based edit (fold, message edit, reorder), reapply by
returning to the patch that was top before the goto --
`stg goto <original-top>` -- not `stg push -a`. Patches left
unapplied before the edit are usually unapplied on purpose
(not recently rebased, likely to conflict); `push -a` applies
them too, overshooting the prior applied set and often hitting
stale-context conflicts in a patch unrelated to the edit.
Record the original top with `stg top` before the goto. Use
`push -a` only when the intent is genuinely to apply the whole
stack.

**Merge commits and repair**: Raw `git merge` on an stg branch
commits the merge to the stack's HEAD, leaving the patches below
the merge commit; `stg repair` then reports them "hidden below
the merge commit" and marks them unapplied. `stg repair` cannot
convert a merge commit into a patch. Use `stg undo` to remove an
accidental merge before running `stg repair`. To combine branches
deliberately, build the merge below the stack base instead of on
its HEAD -- see "Combining branches: there is no stg merge".

**Conflicting `stg import` creates no patch**: when `stg import`
cannot apply a patch it aborts patch creation -- no new patch
lands on the stack. A plain `stg import` leaves the worktree
clean: `git apply` is atomic, so a failed apply rolls back with
nothing to refresh; re-run with `-3` (see below) to get
resolvable markers. Only `stg import --3way` leaves the diff,
conflict markers and all, loose in the worktree, because the
3-way apply writes them before failing. Once those markers are
marked resolved, a bare `stg refresh` folds the imported change
into whatever patch is currently top, not into a patch of its
own. To abandon the import outright, `stg undo` reverses it. To
keep it, resolve the markers, mark them resolved with `stg
resolved <file>` -- otherwise `stg new` and `stg refresh` both
abort with "resolve outstanding conflicts first" -- then
recreate the patch explicitly: `stg new <name> --file <msg>`,
recovering the commit log from the mbox into `<msg>` (a
multi-line changelog needs `--file`, not `-m`) and the author
from the mbox header via `--authname`/`--authemail`/`--authdate`.
Then `stg refresh`. When `stgit.autosign` is set, `stg new`
appends the committer's `Signed-off-by`; drop that line from
`<msg>` if the recovered log already carries it (you authored
the patch) to avoid a duplicate trailer.

To tell whether a stray `stg refresh` already folded the change
in, `stg show` the top patch and look for the imported diff you
did not author. If it is there, `stg undo` splits it back out
into stg's internal `refresh-temp` patch, which can be renamed
(`stg rename`) and re-messaged (`stg edit --file`; that form
does not autosign, so re-include the `Signed-off-by` line the
mbox carried, or restore it with `-s`, to preserve the trailer
rather than add one).

When an import without 3-way merge fails outright because
context diverged by an unrelated change (e.g. an upstream rename
landed in the stack base), escalate to `stg import --3way`
(`-3`): it runs a 3-way merge and converts the apply failure
into resolvable conflict markers rather than refusing the patch.

**`stg import --3way` fails with "repository lacks the necessary
blob"**: the plain apply failed on context drift, and the 3-way
fallback needs the pre-image blobs named in the patch's `index`
lines -- which are absent when the patch was exported from a tree
state since rewritten or pruned (`git cat-file -e <blob>`
confirms). Two recoveries:

- Fetch the objects from the repository the patch was exported
  from (`git fetch <remote>` brings objects without touching HEAD
  or stack metadata), then retry the import.
- Hand-rebase the patch: create it with `stg new --file <msg>`
  plus `--authname`/`--authemail`/`--authdate` from the patch
  header, then apply with `git apply --reject` (safe on an stg
  branch; never moves HEAD). Resolve the `.rej` hunks against
  current code; when the patch moves a code block between files,
  diff the moved block against its current in-tree state and
  port any drift into the destination here, or the patch
  silently reverts later changes. Delete the `.rej` files and
  confirm none remain with `git status` before refreshing.
  `stg add` any new files, then `stg refresh` -- or
  `stg refresh --force` when `stg add` left the index dirty.

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
it. `stg undo` un-folds the change into an applied
`refresh-temp` patch rather than back to the worktree (see
"Conflicting `stg import` creates no patch"); `stg delete
refresh-temp` then discards it. When the patch is beyond
repair, `stg delete <patch>` and recreate it. Never use
`git checkout`/`git restore` to undo a refreshed change.

**`stgit.autosign` trailer**: When `stgit.autosign` is set
in git config (e.g., to `Signed-off-by`), `stg new` and
`stg import` append that trailer automatically, including
the non-interactive message paths (`stg new -m`/`--file`);
do not also write it into those messages by hand. On
`stg import`,
`-m`/`--mail` selects single-mail input and `-M`/`--mbox`
selects mbox-series input; neither flag affects trailer
behavior.

Autosign takes the sign-off address from git's effective
`user.email`, which falls back to global config when the repo
has no local identity set. On a project whose sign-off
identity differs from your global default, this silently bakes
the wrong address into the trailer. Whenever `stgit.autosign`
is set and you have not already confirmed this repo's sign-off
identity, check before the first `stg new` or `stg import`:

```bash
git config --get user.email   # the address autosign will stamp
```

Confirm it matches the address you sign off as *on this
project*. If you do not know which address that is, ask the
user -- do not infer it from history. Recent sign-offs can be
listed as a rough hint, but in a shared repo the most common
one is often another contributor's address, not yours, so
never copy it into your own identity:

```bash
git log -20 --format='%(trailers:key=Signed-off-by,valueonly)' \
    | grep . | sort | uniq -c | sort -rn
```

If `user.email` is wrong for this project, set a repo-local
identity: `git config --local user.email <your-addr>`. Once a
patch is stamped with the wrong address a plain `stg refresh`
does not correct it; the message must be re-edited (`stg edit
--file`; note that form does not autosign, so include the
corrected trailer in the message text -- see the `stg edit`
exception below).

When `stgit.autosign` is unset, the absence is the signal that
no sign-off is wanted: on a newly created patch, do not add a
`Signed-off-by` at all -- neither in the message text nor via
`-s`/`--signoff` -- unless the user explicitly asks for one.
Preserving a sign-off the patch already carries through an
edit or fold is not adding one; see the `stg edit` exception
below. Treat unset autosign as "no sign-off by default"; it
is not a cue to supply the trailer by hand. Read the setting
with `git config --get stgit.autosign`; a non-zero exit means
unset.

`stg edit` is the exception: it autosigns only when it
opens the interactive editor. The `stg edit -m` and
`stg edit --file` forms this skill mandates do NOT
autosign, so a `Signed-off-by` line omitted from the
message drops one the patch already carried. When the
patch carries a sign-off, re-include that line in the
`stg edit` message text to preserve it; these paths do not
autosign, so exactly one trailer results regardless of stg
version. Alternatively, preserve it by omitting it from the
message and restoring it with the `-s`/`--signoff` flag (see
Trailer flags below). A patch created while `stgit.autosign`
was unset carries none; do not add one here.

**File-edit cache stale after stack ops**: Any stg command that
moves HEAD or rewrites a patch's tree (`push`, `pop`, `goto`,
`refresh`, `fold`, `sink`, `float`, `pick`, `import`,
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
`stg edit`. For multi-line messages, write the text to a
temp file and pass it with `--file`; both commands accept
it.

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

Reach for `-s`/`--signoff` only when a sign-off is actually
wanted -- `stgit.autosign` is set, or the user asked for one.
When autosign is unset, omit the trailer entirely (see the
`stgit.autosign` pitfall); `-s` is not a default to apply by
hand.

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

1. `git status` — identify every conflicted file.  For the
   in-flight patch's *full* file set (e.g. to drive a
   per-file mechanical loop), use `git status --short` (it
   lists the merge-staged files as well as the conflicted
   ones), not `stg files <patch>`: until the finalizing
   `stg refresh` `stg files` can return empty for the
   in-flight patch, and a loop driven off it fails open --
   no error, no files, patch silently skipped.  See the
   reference for the mechanism.
2. Classify each conflict (take-ours, take-theirs,
   concatenate, or semantic).  Resolve trivial cases
   directly.
3. For semantic conflicts, recover the three-way view
   (`git show :1:`, `:2:`, `:3:` for base/ours/theirs)
   and read both sides' commit messages before editing.
4. Before marking any file resolved, run `stg top`.  It MUST
   name the conflicting patch.  `stg refresh` folds the
   resolution into whatever patch is top, so if `stg top`
   names a different patch -- the in-flight patch is
   unapplied with the merged content loose in the worktree --
   do NOT `stg resolved` and do NOT refresh.  Recover first:
   confirm with `stg log` that the last recorded operation is
   the conflict to reverse, then `stg undo --hard`
   (`git stash` unrelated edits first; it discards the
   worktree) and `stg goto <patch>` to re-derive on the
   correct top.  See the reference for when undo is unsafe.
5. `stg resolved <file>` (not `git add`) after each file.
6. `stg refresh` to finalize.

If intent cannot be determined, leave conflict markers in
place and report what is ambiguous rather than guessing.

To abort: `stg undo` reverts the failed operation.  In the
unapplied-in-flight case (step 4), use `stg undo --hard` to
also clear the merged content left loose in the worktree.

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
