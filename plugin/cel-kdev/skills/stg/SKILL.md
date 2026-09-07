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
raw git for all commit operations. Check activation with two
read-only commands:

1. `git branch --show-current` — get the branch name
2. `git show-ref --verify refs/stacks/<branch>` — check
   for the stg stack ref

A zero exit status on step 2 means stg is active. When the
branch name is already in session context, write it
literally. When it is not, do not guess it from the checkout
directory or the repo name; fold step 1 into step 2 instead:

    git show-ref --verify refs/stacks/$(git branch --show-current)

The raw-git guard tests each simple command on its own, so
this form passes. Keep pipes and `xargs` out of the check;
they are harder for approval rules to inspect and can
trigger permission prompts. Either form may be chained with
`;` into one command together with other read-only calls
(the orientation `stg series` call below, `stg top`). When
chained, step 2's exit
status is not separately visible; judge by its output --
`show-ref --verify` prints the ref line when the stack
exists and `fatal: ... not a valid ref` when it does not. On
a non-stg branch the chained stg calls fail alongside step
2; that is the expected answer, not an error to chase.

Once stg is active, orient before your first mutating
command (`new`, `refresh`, `goto`, `push`, `pop`, `float`,
`sink`): run `stg series -d` once to see the applied set --
the current top (`>`) and whether any `-` unapplied patches
sit below it. Many rules below turn on this state: where
`stg new` lands, whether `stg push -a` overshoots, and which
patch a bare `stg refresh` folds into. Orient once per
session, not before every command; on a deep stack, probe
with `stg series -c` first and window the call (see "Scope
orientation on a deep stack" under Token efficiency).

The `block-raw-git.sh` guard hook checks stg-activity
against the repo a command targets. When an stg session also
touches a second, non-stg repo, drive that repo with
`git -C <repo> <subcommand>`, giving `<repo>` as an absolute
path or one starting with `~/`, `$HOME/`, or `${HOME}/` --
never a `cd <repo> &&` prefix, which the hook cannot see
(and the harness resets cwd between calls anyway). Any other
path form is unresolvable to the hook and falls back to
checking the session's primary branch, blocking the command
whenever that branch is stg even though the target repo is
not. This includes a scratch repo you create yourself for a
test or reproduction. Build it with a literal absolute path
on every command, never a variable, a `cd` prefix, or
`GIT_DIR=`. Create the directory in its own Bash call:

```bash
mkdir -p <scratchpad>/repo
```

Then drive it in later calls with that same literal path:

```bash
git -C <scratchpad>/repo init
git -C <scratchpad>/repo commit -m "msg"
```

Write the path out in full from the session's scratchpad
directory; `mktemp -d` and any other `$(...)` cannot be
resolved by the hook either. Do not fold the two into one
call. The hook resolves every
`-C` target before the shell runs the line, so a directory
created by a `mkdir` earlier on the same line does not exist
yet: the check falls back to the primary branch and blocks
the command. Once the directory exists, every command
resolves it, finds no stack, and is allowed; `git init` is
not a guarded subcommand, so the hook never checks it.
`git -C $S` is blocked even when `$S` holds an absolute
path: the hook expands only `~/`, `$HOME/`, and `${HOME}/`
itself and takes everything else literally. `GIT_DIR=` is
blocked even with a literal path, because it leaves a bare
`git`, which the hook checks against the cwd. See
[references/raw-git-guard.md](references/raw-git-guard.md)
for the fallback mechanics. This is not a license to bypass
the guard on an actual stg branch.

## CRITICAL: Prohibited git commands

**NEVER use these git commands when stg is active. They move
HEAD behind stg's back, corrupting the stack metadata.**

The table is the common denylist, not the whole rule: *any*
raw git that moves HEAD or rewrites a stacked commit corrupts
the stack the same way, including commands not listed here
(`git am`, `git revert`, `git update-ref` on HEAD,
`git filter-branch`). When you need an operation the table
does not name, route it through the stg equivalent or ask --
absence from the table is not permission to reach for raw git.

| Prohibited | Replacement |
| ---------- | ----------- |
| `git commit` | `stg new <name> -m "msg"` + `stg refresh` (on a partial stack, check applied state first -- see the `stg new` pitfall) |
| `git commit --amend` | `stg refresh` or `stg edit --file <path>` |
| `git rebase` | `stg rebase`, `stg sink`, `stg float` |
| `git reset` | `stg pop`, `stg undo` |
| `git cherry-pick` | `stg pick` or `stg import` |
| `git rebase -i` (reorder) | `stg sink`, `stg float` |
| `git rebase -i` (squash) | fold workflow (see "Combining patches: avoid stg squash") |
| `git worktree add` | (not supported with stg) |
| `git checkout <branch>` / `git switch <branch>` | `stg branch <branch>` |
| `git checkout`/`git restore` (pathspec, any form) | prohibited; leave worktree dirty + scope `stg refresh <pathspec>` (see Pitfalls) |
| `git merge` | No stg merge; build a base merge commit and `stg rebase` onto it (see "Combining branches: there is no stg merge") |

This applies to all agents and subagents.

`stg branch <name>` both creates and switches branches; it
is the canonical stg interface for branch operations. The
runtime hook's `git branch -> stg branch` line refers to
this. To read another branch's stack without switching to
it, pass `--branch <name>` to a read-only command
(`stg series`, `stg show`, `stg id`, `stg log`, `stg top`);
there is no global `stg -b`, and `stg files`/`stg diff` do
not take it.

`git checkout` is not used on an stg branch in any form,
period. The branch forms (`git checkout <branch>`,
`git checkout -b`, `git switch`) bypass stg's metadata
bookkeeping. The pathspec forms (`git checkout <file>`,
`git checkout .`, `git checkout <commit> -- <file>`,
`git restore [--staged] <file>`) do not move HEAD but are
equally prohibited -- see the "Never `git checkout`/
`git restore`" pitfall for why and what to do instead.

**`git worktree`** creates a new checkout that shares refs
with the main working tree; stg tracks its stack state in
refs (`refs/stacks/<branch>`), so a worktree that checks out
the same branch or manipulates shared refs corrupts the
stack metadata just like a raw `git commit` would. This
overrides the `superpowers:using-git-worktrees` skill on stg
branches: do not create a worktree for an stg branch even
when that skill recommends one for plan isolation.

## CRITICAL: No parallel stg operations

The stg stack is a single shared resource. Every mutating
command (`new`, `refresh`, `goto`, `push`, `pop`, `float`,
`sink`) changes HEAD and on-disk metadata. Concurrent stg
operations from parallel agents corrupt the stack.

**Do NOT delegate patch creation or editing to parallel
subagents.** All stg operations on a given branch must run
in a single sequential session. Parallelism is safe only
for read-only work (research, building, testing).

A pipe interrupts a mutating command the same way: a consumer
that stops reading early aborts it mid-run, which can strand
a partial `import`. See "Never pipe a mutating stg command"
in Pitfalls.

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

**stg patch names are not git revisions.** `git show
<patch-name>`, `git diff <patch-name>`, and `git log
<patch-name>` all fail with `fatal: ambiguous argument
'<patch-name>': unknown revision or path not in the working
tree`. To inspect any patch, applied or unapplied, use
`stg show <patch>` (optionally `stg show <patch> -- <path>`).
For a patch-range diff, prefer the native `stg diff -r
<first>~..<last>` over composing raw git. The inverse holds
too: the endpoints of that range are patch names or
`{base}`, not git revisions (see the "`stg diff -r` range
endpoints" pitfall below). Reach for `stg id` only when a
git command or an external tool genuinely needs a commit stg
cannot supply -- e.g. `git log $(stg id <patch>)`, `git show
$(stg id <patch>):<path>`, or `./scripts/checkpatch.pl
--strict -g $(stg id)`. With no argument `stg id` resolves
HEAD, which is the top patch whenever any patch is applied,
so `$(stg id)` is the patch just refreshed.

## Finding the stack base

The stack base is the commit each applied patch sits above.
It is recorded per branch in stg metadata; do not assume
`origin/master` -- a branch may be rooted on any ref. The
base *commit* comes from `stg id {base}`, the canonical
lookup (`stg id --branch <branch> {base}` for a non-current
branch). The *upstream ref name* (the b4 fork-point) is
composed from the recorded parent branch, and the
composition has enough failure modes that you must read
[references/stack-base.md](references/stack-base.md) for the
recipe and its caveats before composing it. Even when the
composed ref resolves, trust `stg id {base}` for the base
commit.

## Retiring patches upstream has taken

After a remote takes a patch -- a maintainer merging part of
a series, or a plain `git push` to a repo you own -- clear it
from the stack by re-deriving from upstream: `git fetch`,
`stg rebase -m <upstream-ref>` (patches already upstream go
empty), `stg clean` (drop the emptied ones). Never
`stg commit <patch>`, which consults no remote and can leave
the stack asserting work upstream never received. The rebase
re-derives only the *applied* set, so check `stg series -d`
for `-` lines first and bring a pushed-but-unapplied patch
into reach with `stg goto` (not `stg push <patch>`, which
reorders). Before running this, read
[references/retiring.md](references/retiring.md) for
choosing `<upstream-ref>`, reading a patch that survives the
clean, and the unapplied-patch trap.

## Combining branches: there is no stg merge

StGit has no `stg merge`: the stack is a linear sequence of
patches above a single base commit, so it cannot hold a
multi-parent merge commit (this is why `stg repair` refuses
merge commits). The base *below* the stack can still be any
commit, including a merge. Never run raw `git merge` on an stg
branch -- it commits the merge to the stack's HEAD and corrupts
the stack (see the "Merge commits and repair" pitfall).

Split on intent. **Linearize onto a new base** (the
stg-shaped task, no merge commit involved): `stg rebase
<new-base>` to replay the stack on a new base (e.g. a
release tag); `stg pick -B <branch> <commit>` /
`stg pick <sha>` to absorb individual commits as new patches
(no sign-off added; see the `stgit.autosign` pitfall);
`stg import -M <mbox>` to pull a series in. **True merge**
(keep a merge commit as the base): construct the merge with
plumbing (never moves HEAD), anchor it under `refs/tmp/`,
then `stg rebase` onto it -- see
[references/combining-branches.md](references/combining-branches.md)
for the `merge-tree`/`commit-tree` recipe, octopus merges,
release-rebase seeding, and the `diff --stat` base check.

## Combining patches: avoid stg squash

`stg squash` deletes all of its input patches and creates a
new patch whose `stg log` history begins at the squash; the
change history of every input patch is discarded. Do not use
it to fold a fix patch into the patch it corrects. Fold the
patch by hand instead -- export, pop, goto, `stg fold`,
refresh -- so the fold appears as ordinary refresh and edit
entries in the surviving patch's history. Follow the recipe
in [references/folding.md](references/folding.md); it
carries message-combining, trailer-preservation, and
restore-position caveats that are easy to get wrong from
memory.

## Pitfalls

**Scratch repo in the scratchpad**: a throwaway git repo you
create for a test or reproduction is not exempt from the
raw-git guard. `mkdir` it in one Bash call, then drive it
with `git -C <literal absolute path>` in later calls -- the
hook resolves the target before the shell runs, so a
directory created on the same command line does not exist
yet. See the guard-hook paragraph near the top of this file.

**`stg diff` without `-r`**: `stg diff <patch-name>` treats
the argument as a file path, producing silent wrong output.
Use `stg diff -r <patch-name>~..<patch-name>` for a patch diff.

**`stg diff -r` range endpoints are patch names, not git
revisions**: with `..` in the argument, each endpoint
resolves as a patch name or `{base}`, despite `stg diff
--help` saying git revisions are accepted. `stg diff -r
HEAD~..HEAD` fails with "patch `HEAD` does not exist", and so
does a range built from the base or an upstream SHA, or one
pairing a patch name with a git revision. An endpoint may
carry a `~` or `~N` suffix (`<patch>~`, `{base}~2`) and
nothing else; `^` is rejected as an invalid StGit revision.
The only SHA a range accepts is a patch's own commit id
(what `stg id <patch>` prints), which is why
`$(stg id <patch>)~..$(stg id <patch>)` happens to work; name
the patch instead. Without `..`, `-r <rev>` diffs one
revision, patch name or git revision, against the worktree,
so it prints nothing on a clean tree; it is never a patch's
diff. Given a commit id that is not a stacked patch, use
`git diff <sha>~..<sha>` or `git show <sha>`; given a patch
name, use `stg diff -r <patch>~..<patch>`.

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
reordering. To navigate without reordering use
`stg goto <name>`, or `stg push -n N` / `stg push -a` for
forward steps. See [references/commands.md](references/commands.md).

**`stg new` inserts above the current top, not at the series
end.** On a partially-applied stack (any `-` line in
`stg series`; run it now if you have not oriented this
session), a patch meant for the END of the series lands
mid-series, between the applied set and the unapplied
patches. No `-` lines means the top is already the series
end and `stg new` appends correctly. To append at the true
end of a partial stack, `stg push -a` first, then `stg new`
-- but only when applying the whole stack is genuinely
intended: `push -a` is a state change beyond adding a patch,
and patches left unapplied on purpose may raise stale-context
conflicts. If you cannot tell whether the new patch belongs
at the end, or whether the unapplied patches should be
applied at all, do NOT `push -a`: create the patch above the
current top and report its position, or ask the user.

**`stg push -a` overshoots the prior state**: after a
goto-based edit (fold, message edit, reorder), reapply by
returning to the patch that was top before the goto -- record
it with `stg top` first, then `stg goto <original-top>` --
not `stg push -a`. Patches left unapplied before the edit are
usually unapplied on purpose (not recently rebased, likely to
conflict); `push -a` applies them too, overshooting the prior
applied set. Use `push -a` only when applying the whole stack
is itself the goal (e.g. the series-end append above).

**A conflicted `stg float`/`stg sink` is resumed by
re-running the same command, never with `stg push -a`.**
float and sink pop the affected patches and push them back
in the new order; a conflict stops them mid-push with the
new order only partly applied, and the unapplied list still
carries the original order. The signal is the top `stg log`
entry: `float (CONFLICT)` or `sink (CONFLICT)`. `push -a` is
refused while the conflict stands, so the trap is right
after `stg refresh --index`, when the float looks finished
but is not. `stg push -a` there pushes the remainder in the
order the pops left it, plus every patch that was unapplied
before the float, and can lose the reorder with no error.
Resolve and finalize per "Merge conflict resolution", then
re-run the identical `stg float`/`stg sink` command with the
same arguments: it pops nothing already in place and pushes
only the remainder, in the intended order. To abandon
instead, `stg undo --hard` while that `(CONFLICT)` entry is
still the last one in `stg log`. If `push -a` has already
run, a single `stg undo` reverts it and keeps the
resolution; add `--hard` only if that push itself stopped on
a conflict. Confirm in `stg log` that the undone entry was
the push, then re-run the float/sink command.

**Editing a non-top patch cascades conflicts on re-push.**
Re-pushing the stack after a `stg goto` edit re-runs a 3-way
merge for every intervening patch. When the edited line sits
adjacent to lines those patches also add or remove (a shared
prototype list, an enum, a struct-member block), a one-line
change can fan out to N trivial "both deleted adjacent
lines" conflicts, each re-injecting the file into context.
Before such an edit, check whether the intervening patches
touch the same region: `stg diff -r <target>..<top> --
<file>` shows exactly what they change there (the range
takes no `~`: it excludes target's own diff), or `git log
-S<symbol> -- <file>` for a quick scan. If they overlap,
tell the user the re-push cost up front and confirm rather
than discovering it mid-cascade; if you cannot cheaply tell,
say so and let the user decide.

**A `stg pick` conflict means a skipped prerequisite, not a
bad patch.** Unlike the cascade above, a pick conflicts
because the destination never received the commit the picked
patch was built on. Do not resolve the markers in place:
folding the missing fix into the dependent patch loses that
fix's standalone commit along with its `Fixes:` and
`Cc: stable` trailers. The conflicted patch is left APPLIED
as top, so the generic resolution flow misreads it as an
ordinary push conflict. Back the pick out instead --
`stg undo --hard` after a plain pick, or a bare
`stg reset --hard` after `stg pick --fold`/`--update` (which
create no patch); both discard only the failed merge, since
`stg pick` refuses to start dirty. Then land the
prerequisite upstream before re-picking. See "Pick
conflicts" in
[references/conflict-resolution.md](references/conflict-resolution.md)
for the diagnosis and why `git stash` cannot substitute.

**Merge commits and repair**: `stg repair` cannot convert a
merge commit into a patch, so it alone cannot recover from a
raw `git merge` committed on the stack's HEAD. On noticing
an accidental merge, or when `stg repair` reports patches
"hidden below the merge commit", read the "accidental raw
merge" section of
[references/recovery.md](references/recovery.md) before
acting.

**Recovering a stack detached by a raw reset**: when a raw
git command moved HEAD (a `git reset` catching the branch up
to origin, say), `stg new`, `goto`, `push`, and the rest
refuse with "HEAD and stack top are not the same." On that
error, read [references/recovery.md](references/recovery.md)
before running any recovery command -- the wrong first
command destroys the state the right one needs. Prevention:
catch a stack up to upstream with `stg rebase
<upstream-ref>`, never a raw reset.

**Conflicting `stg import` creates no patch**: when `stg import`
cannot apply a patch it aborts atomically -- no patch lands, and
a plain import leaves the worktree clean, so there is nothing to
refresh. Re-run with `-3`/`--3way` to get resolvable markers;
only `--3way` leaves the diff loose in the worktree. After
resolving and `stg resolved`, a bare `stg refresh` folds the
change into whatever patch is top, not a patch of its own. For
the full recovery, read "Recovering from a failed `stg import`"
in [references/conflict-resolution.md](references/conflict-resolution.md)
before acting.

**`git add` before `stg refresh`**: `stg refresh` picks up
all changes to tracked files automatically; do not stage
first. `stg add` is needed only when introducing a new file
to the repository; `stg resolved` only to clear merge
conflicts, not for routine refreshes.

**Dirty index guard on `stg refresh`**: When changes exist
in both the index and the worktree (e.g., after `stg add`,
`stg mv`, `stg rm`, or `stg resolved` staged some paths --
the staged and unstaged changes need not touch the same
file), plain `stg refresh` refuses with "the index is
dirty." Two overrides:

- `--index` (`-i`): refresh only from what is staged,
  ignoring worktree changes. Use after `stg add`, `stg mv`,
  or `stg rm` when only the staged changes belong in the
  patch, and to finalize a conflict resolution after
  `stg resolved`. Mutually exclusive with pathspecs,
  `--update`, and `--force`.
- `--force` (`-F`): fold in all changes from both the index
  and the worktree.

**Unintended files in `stg refresh`**: bare `stg refresh`
captures *all* modified tracked files, not just the ones
edited for the current patch -- unrelated dirty files
silently enter the patch. When only specific files belong,
pass them as pathspecs: `stg refresh path/to/file1
path/to/file2`. Do not run bare `stg refresh` after
`stg new` when the worktree contains other modifications;
check `git status` first if uncertain.

**Never `git checkout`/`git restore` to drop worktree
noise**: reverting a file in the worktree does not remove an
already-refreshed change from the patch commit -- the stale
diff stays baked in, a later `stg refresh` cannot undo it,
and the patch must be deleted and recreated. When only some
worktree changes belong in the patch, scope the refresh
(`stg refresh <pathspec>`) and leave the rest dirty; deal
with them after the patch is complete -- `git stash` /
`git stash pop` is safe on an stg branch (it never touches
HEAD or stack metadata), or fold them into a later patch. To
back out a change *already folded into* the patch: edit the
file to the wanted content and refresh; or, if the refresh
was the last operation, `stg undo` -- which un-folds into an
applied `refresh-temp` patch, discarded with `stg delete
refresh-temp`, not back to the worktree; or, when the patch
is beyond repair, `stg delete <patch>` and recreate it.

**`stgit.autosign` trailer**: When set (e.g., to
`Signed-off-by`), `stg new` and `stg import` append that
trailer automatically, including the non-interactive paths
(`stg new -m`/`--file`); do not also write it in by hand.
(On `stg import`, `-m`/`--mail` and `-M`/`--mbox` only
select input format.) Autosign stamps git's effective
`user.email`, which falls back to global config -- on a
project whose sign-off identity differs from your global
default this silently bakes in the wrong address, and once
stamped it is not fixed by a plain refresh. Whenever
autosign is set and this repo's identity is unconfirmed,
check `git config --get user.email` before the first
`stg new`/`stg import`; see
[references/signoff.md](references/signoff.md) for
confirming the identity and correcting a wrong stamp.

When `stgit.autosign` is unset (`git config --get
stgit.autosign` exits non-zero), that absence is the signal
that no sign-off is wanted: add no `Signed-off-by` to a
newly created patch -- neither in the message text nor via
`-s`/`--signoff` -- unless the user explicitly asks.
Preserving a sign-off the patch already carries through an
edit or fold is not adding one.

`stg edit`, `stg refresh`, and `stg pick` do NOT autosign
(`stg edit` autosigns only when it opens the interactive
editor, which the `-m`/`--file` forms this skill mandates do
not). Two consequences:

- `stg edit -m`/`--file`: a `Signed-off-by` omitted from the
  message drops one the patch carried. Re-include the line in
  the message text (recent stg de-duplicates an identical
  trailer) or restore it with `-s`/`--signoff`. A patch
  created while autosign was unset carries none; do not add
  one here.
- `stg pick` copies the picked commit's message and trailers
  verbatim, adding no `Signed-off-by` even when autosign is
  set -- the reversible default, correct for a backport
  meant to match upstream. Add a backporter sign-off only
  when actually wanted (the user asked, or recent picks on
  this branch carry one): `stg edit -s` or `stg refresh
  --signoff` on the just-picked top appends it without an
  editor. That trailer takes `user.email`, so confirm the
  identity first; if you still cannot tell whether this
  branch wants it, ask.

**Position before editing**: `stg goto`, `stg push`,
`stg pop`, and `stg rebase` refuse to run when any tracked
file is dirty (`worktree not clean`). The error offers
`refresh` or `reset --hard` -- the latter is
`stg reset --hard`, which **discards your uncommitted
worktree changes**; it is not in the prohibited table and
the guard hook permits it, so nothing stops you. Never take
it to escape this error. `stg rebase` alone has a safe
escape: `--autostash` (`stgit.autostash` makes it the
default).

General rule: to route a change into a specific patch,
`stg goto <patch>` FIRST, then edit and refresh. A
`stg refresh` on the wrong top does not warn -- it silently
folds the change into whatever patch is top -- so confirm
`stg top` names the target before every refresh. A stray
refresh, if it was the last operation, reverses with
`stg undo` (un-folding into a `refresh-temp` patch; see the
checkout/restore pitfall).

When the worktree is already dirty and the change must be
routed (note `stg refresh` itself is exempt from the
clean-worktree check, which is why the first case needs no
move):

- Target patch is already top -> just `stg refresh`, scoped
  with a pathspec when the worktree also holds changes that
  do not belong (see "Unintended files in `stg refresh`").
- A *different* patch is the target -> move while keeping
  the dirty changes, then confirm `stg top` before
  refreshing. Either `stg goto -k <patch>` (native; aborts
  without moving if the changes will not apply at the
  destination), or `git stash` / goto / `git stash pop`
  (safe on an stg branch; the pop may conflict against the
  new position, so resolve it first).

**File-edit cache stale after stack ops**: Any stg command that
moves HEAD or rewrites a patch's tree (`push`, `pop`, `goto`,
`refresh`, `fold`, `sink`, `float`, `pick`, `import`,
`rebase`, `undo`, `redo`, `edit --set-tree`) rewrites tracked
files on disk. Per-file freshness snapshots held by editing
tools can go stale; the next edit may fail with "File has
been modified since read." Re-read the file before the next
edit.

**Never pipe a mutating stg command**: pipe only the
read-only commands -- `series`, `show`, `log`, `diff`,
`files`, `id`, `top`, `export`. Every other stg command can
change stack state and streams progress to stdout; a
consumer that stops reading early (`head -N`, `grep -q`)
makes stg's next write fail with EPIPE, aborting it
mid-operation -- an aborted `import` strands a
partially-applied mbox. Do not reason about which consumers
read to EOF; to trim noisy progress, redirect to a file
outside the repo (the session scratchpad; a log inside the
repo pollutes the `git status` checks this skill relies on)
and read the file:
`stg sink -t <patch> > <scratchpad>/stg-sink.log 2>&1; echo $?`.
The pipeline's exit status hides the failure (it carries the
consumer's status; check `${PIPESTATUS[0]}`). After a
suspected pipe abort, confirm the stack state with
`stg series -d` -- the one override of "Do not verify after
refresh" and "Limit stg series calls" -- and read "Mutating
command aborted by a broken pipe" in
[references/recovery.md](references/recovery.md) before
re-running.

## Token efficiency

**Do not verify after refresh.** After `stg refresh`, do not
call `stg show`, `stg series`, or `stg diff` to confirm the
operation succeeded.  Check the exit code instead.  Only
read patch content when the next step actually requires it
(e.g., editing the commit message or reviewing the diff at
the user's request).

Exception for pathspec-scoped refresh: `stg refresh
<pathspec>` exits 0 even when the pathspec matches no
modified file, folding in nothing.  Confirm the path is
correct relative to the current working directory, or pass a
repo-absolute path, and check with `git status --short` that
the path is no longer dirty.  This one cheap check is
warranted for pathspec-scoped refreshes.

**Use `git status` for working tree state.** `git status`
is the cheapest way to check whether there are modified
tracked files, untracked files, or merge conflicts.  Use
it instead of `stg diff` when the goal is to determine
whether anything needs refreshing, not what the changes are.

**Do not diff before refresh.** `stg refresh` captures all
modifications to tracked files automatically.  Do not run
`stg diff` first to preview what will be folded in — unless
the user explicitly asks to review pending changes.

**Batch patch inspection.** When reviewing multiple patches,
avoid walking the stack one `stg show` at a time.  Prefer:

- `stg series -d` — names and descriptions in one call.
- `stg diff -r <first>~..<last>` — combined diff across a
  range of patches.
- `stg show --stat <patch>` — summary first; see "Cap the
  full diff" for when to widen.

**Cap the full diff.** A whole-patch `stg show` is the single
largest source of stg output, and most of that volume is one
patch opened whole to find one hunk. For any patch not
already in context, read the stat first. When the stat names
more than two files or more than 200 changed lines
(insertions plus deletions), do not widen -- read the files
that matter with `stg show <patch> -- <path>`, which takes
several paths in one call. Widen to the whole diff when the
stat is under that bound, or when the task genuinely
requires every file the patch touches -- reviewing the patch
as a patch. A lookup within the patch is not such a task,
even during a review.

**Prefer stg's own flag over `-O`.** `--stat` is native to
both `stg show` and `stg diff`, and it replaces the diff, so
a range summary is `stg diff -r <first>~..<last> --stat`. Do
not reach the stat through `-O`: `-O` forwards an option to
`git diff` on top of the patch stg already asks for, so
`stg show -O --stat` prints the diffstat *and* the full
diff. `-O` is right for a git-diff option stg does not wrap,
such as `-O --no-patch`.

Trim output with `--stat`, `-O --no-prefix`, or a redirect to
a file, never by piping a *mutating* command into `head` --
that aborts the command; see "Never pipe a mutating stg
command" in Pitfalls. Read-only commands pipe safely.

**Checking a patch with checkpatch or another patch-parsing
tool.** Piping `stg show` is safe; its format is the
problem. It emits git-log format, which indents the commit
message four spaces, and a tool that parses the message
reads that indent as text -- checkpatch reports a spurious
"Do not use whitespace before Signed-off-by:" on every
patch. Point the tool at the commit instead:
`./scripts/checkpatch.pl --strict -g $(stg id)` checks the
patch just refreshed, and `-g $(stg id {base})..` the whole
applied stack. Bare `stg id` is HEAD (see "Stack model"), so
with the stack popped it names the base -- checkpatch would
check an upstream commit as if it were yours. For a tool
that wants a file, `stg export -p -d <dir>` writes one
`.patch` file per patch (`get_maintainer.pl` reads one);
without `-p` the files carry no suffix and a `*.patch` glob
matches nothing. `stg email format` writes the mbox that
`stg export` does not.

**Limit stg series calls.** Run `stg series` (or
`stg series -d`) once for orientation at the start of a
session.  After `stg push`, `stg pop`, `stg goto`, or
`stg new`, the new stack position is known from the command
output — do not re-run `stg series` to confirm it.  Prefer
`stg series -d` over a plain `stg series` followed by
individual `stg show` calls when both names and descriptions
are needed.

**Scope orientation on a deep stack.** `stg series -d`
prints a line per patch, so a deep stack spends 3-4k chars
before any work starts. Probe first: `stg series -c` prints
the patch count and nothing else. At 11 patches or fewer,
take the full `stg series -d`. Above that, when the work
sits in one region, window it: `stg series -d --short=5`
prints five patches either side of the current top (the `=`
is mandatory -- `-s 5` consumes the `5` as a patch name --
and `--short` takes no patch arguments). Two windowing
traps: the window elides with no marker, so when the count
exceeds it, never read the last `-` line as the end of the
unapplied set -- the `stg new` and `push -a` pitfalls turn
on the full set, so take the unwindowed call before acting
on either; and with nothing applied there is no `>` to
center on, so a fully popped stack needs the full call.
Prefer the window over a `<first>..<last>` range, which
hides the `-` lines outright.

## Avoiding interactive editors

Always provide `-m` to `stg new` and `--file <path>` to
`stg edit`. For multi-line messages, write the text to a
temp file and pass it with `--file`; both commands accept
it. On a partially-applied stack, check the applied state
before `stg new` -- see the `stg new` pitfall.

Keep the repo as the working directory when the temp file
lives elsewhere (the session scratchpad): write the file at
its absolute path and pass that same absolute path to
`--file`. Never `cd` toward it -- a `cd <scratchpad> && ...
stg edit` compound runs stg outside the repo and fails (or,
under some other git tree, silently targets the wrong repo),
and a standalone `cd` does not persist: the harness resets
cwd between calls.

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

A `stg pick` conflict is NOT resolved this way -- it signals
a prerequisite the destination never received; see the
pick-conflict pitfall before proceeding.

When `stg push` or `stg rebase` produces conflicts, follow
[references/conflict-resolution.md](references/conflict-resolution.md):
survey with `git status`, classify each conflict, resolve,
then `stg resolved <file>` (not `git add`) per file and
`stg refresh --index` to finalize. Non-negotiable gates,
detailed in the reference:

- To enumerate the in-flight patch's full file set (e.g. for
  a per-file mechanical loop), use `git status --short`,
  never `stg files <patch>`: mid-conflict the latter can
  return empty, and a loop driven off it fails open --
  no error, no files, patch silently skipped.
- Before any `stg resolved` or refresh, `stg top` MUST name
  the conflicting patch. If it names a different patch, the
  in-flight patch is unapplied with merged content loose in
  the worktree: do NOT `stg resolved` and do NOT refresh --
  read "Recovering an unapplied-in-flight state" in the
  reference first; its `stg undo` recovery is unsafe unless
  the conflict is the last recorded stack operation.
- Before `stg refresh --index`, check `git status --short`
  for second-column `M` entries: `--index` silently leaves
  unstaged edits out. Use `--force` only when those edits
  belong in the patch too -- it also sweeps in every other
  dirty tracked file.
- If intent cannot be determined, leave the conflict markers
  in place and report what is ambiguous rather than
  guessing.

To abort: `stg undo` reverts the failed operation. In the
unapplied-in-flight case, `stg undo --hard` also clears the
loose merged content -- but `--hard` discards the whole
worktree, so `git stash` unrelated edits first, and the
last-recorded-operation gate applies to the abort too.

## Tracing patch evolution with stg log

`stg log [<patch>]` prints the history of stack operations
for a patch (or the whole stack), one line per operation:
`<meta-sha> <date> <description>`. **The `<meta-sha>` is an
stg metadata commit, not the patch's code commit** -- it
snapshots stack state, so do not pass it to `git show` or
`git diff` expecting code. `stg log` accepts no `--format`
or `--oneline`; output is its default, `--full`, or
`--diff` (stack-state diffs). To align `stg log` with the
branch reflog, walk HEAD snapshots of a file, reconstruct a
patch's diff at a historical entry, or bisect when a change
entered a patch, see
[references/stg-log.md](references/stg-log.md).

## Command reference

See [references/commands.md](references/commands.md) for
the full command table covering creation, navigation,
reordering, splitting, importing, exporting, and email.
