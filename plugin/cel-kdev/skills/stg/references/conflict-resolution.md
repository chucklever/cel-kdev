# Merge conflict resolution strategy

When `stg push`, `stg rebase`, or `stg float`/`stg sink`
produce conflicts, the default approach of reading conflict
markers and guessing at the right resolution misses available
context that substantially improves accuracy.  The strategy
below gathers that context before any editing begins.

## Step 1: Survey the conflicts

```bash
git status
```

Identify every conflicted file.  Do not start editing until
the full scope is known -- conflicts in separate files may
be coupled (one side renamed a function that the other side
calls).

`git status` lists the conflicted files, but to enumerate the
in-flight patch's *full* file set -- for example to drive a
per-file mechanical step across the patch -- use `git status
--short`.  It lists every file the merge touched: the cleanly
merged files the 3-way merge auto-staged, the conflicted ones,
and any already cleared with `stg resolved`.  This equals the
patch's file set only when the worktree carries no unrelated
edits, so stash those first.  Prefer it over a bare
`git diff --name-only`, which shows only unstaged changes and
so omits the staged merge results -- exactly the files an
enumeration must not miss.  Do not read that set from
`stg files <patch>`: it reports the patch's *recorded* commit,
so between `stg resolved` and `stg refresh` it omits the
still-loose merge content and can return empty for the
in-flight top patch.  `stg files` becomes reliable again only
after the finalizing `stg refresh` (step 5).  A stack-walking
script that drives a per-patch step off `stg files`
mid-conflict fails open -- no error, no files -- and silently
skips the patch.

## Step 2: Classify each conflict

Most conflicts fall into one of a small number of categories.
Classify before resolving; the category determines the
approach:

| Category | Description | Resolution |
| -------- | ----------- | ---------- |
| take-ours | Only our side changed the region | Keep ours |
| take-theirs | Only their side changed the region | Keep theirs |
| concatenate | Both sides added independent content | Combine in logical order |
| refactor + edit | One side restructured, the other edited | Apply the edit to the restructured form |
| semantic | Both sides changed the same logic | Requires intent analysis (step 3) |

For take-ours, take-theirs, and concatenate conflicts,
resolve directly without further research.  These account
for 60-75% of conflicts in practice.

## Step 3: Gather context for complex conflicts

For conflicts classified as refactor+edit or semantic,
collect the following before attempting resolution.

### Three-way view (base, ours, theirs)

The conflict markers show ours and theirs but omit the
common ancestor.  Recover all three:

```bash
# Show the base (ancestor) version of the file
git show :1:<file>

# Show "ours" (the patch being pushed onto)
git show :2:<file>

# Show "theirs" (the patch being applied)
git show :3:<file>
```

Comparing each side against the base reveals what changed
and why.  Without the base, the model cannot distinguish
"preserved existing behavior" from "introduced new behavior."

### Commit messages explaining intent

The commit messages for each side describe what the author
intended.  For stg patches:

```bash
# Message for the patch being applied (theirs)
stg show -O --no-patch <conflicting-patch>

# Message for the patch underneath (ours), if it is
# also a stg patch
stg show -O --no-patch <underlying-patch>
```

If the base side is an upstream commit rather than a patch:

```bash
git log --oneline --no-walk <base-commit>
```

### Surrounding file context

Include 50-100 lines above and below the conflict region.
More context causes diminishing returns and can degrade
resolution quality through distraction.  Truncate
symmetrically around the conflicting hunk.

### Patch series relationships

When the conflict arises during `stg push -a` or
`stg rebase`, the patch being applied may depend on
earlier patches in the series.  Check:

```bash
stg series -d
```

If the conflicting patch's description references changes
made by an earlier patch, that earlier patch's diff may
clarify the intended state.

## Step 4: Reason about intent before editing

For semantic conflicts, articulate three things before
writing any resolution:

1. What the base version did in the conflicting region.
2. What "ours" changed and why (from its commit message
   and diff against base).
3. What "theirs" changed and why (from its commit message
   and diff against base).

A correct resolution preserves both intents.  If the two
intents are contradictory (both sides deliberately changed
the same logic in incompatible ways), flag this to the user
rather than guessing -- silent wrong merges are the most
dangerous failure mode.

## Step 5: Resolve and finalize

Before `stg resolved` or `stg refresh`, confirm the
conflicting patch is the current top:

```bash
stg top      # must name the patch whose push hit the conflict
```

`stg refresh` folds the resolution into whatever patch is
top, so the top patch must be the in-flight patch before a
refresh.

- If `stg top` names the conflicting patch: this is a real
  `stg push`/`stg rebase`/`stg float`/`stg sink` conflict,
  which leaves the in-flight patch APPLIED as top.  Proceed
  to `stg resolved` and `stg refresh` below.
- If `stg top` names a different patch: the in-flight patch
  is unapplied while its merged content sits loose in the
  worktree, from an interrupted or rolled-back operation or
  a conflict constructed by external tooling.  Do NOT
  refresh and do NOT `stg resolved` -- a refresh folds the
  resolution into the wrong (current top) patch.  Recover as
  below before re-deriving the conflict.

### Recovering an unapplied-in-flight state

`stg undo` resets the stack to the state before the last
operation recorded in stg's stack log -- it reads that log,
not the worktree -- and `--hard` additionally discards the
index and worktree.  So `stg undo --hard` recovers cleanly
only when that last recorded operation is what left this
state: a real `stg push`/`stg rebase`/`stg goto` conflict
(the recovery StGit's own push-conflict message recommends),
possibly already half-rolled-back.  Confirm with `stg log`
before undoing.

If `stg log` shows the last operation is something else --
the state came from raw git, or from tooling that dirtied
the worktree without a stack transaction -- `stg undo` would
reverse an unrelated earlier operation.  Do not undo; stop
and report the stack state rather than guessing.

When undo is appropriate:

```bash
git stash         # save unrelated edits first
stg undo --hard   # discards ALL worktree and index changes
stg goto <patch>  # re-derive the conflict on the correct top
```

Do not skip the undo and instead position the in-flight
patch as top with `stg goto` while the merged content is
still loose in the worktree: `stg goto` either refuses the
dirty worktree or re-derives the conflict on top of it.
Clear the worktree with `stg undo --hard` first; `stg goto
<patch>` then applies patches in series order, re-deriving
on the correct top without reordering the stack.

`stg resolved` clears the unmerged-index guard that
otherwise blocks a premature `stg refresh`, so run the
top-patch check above before `stg resolved`.

```bash
# Top patch confirmed; after editing each conflicted file:
stg resolved <file>

# Once all conflicts are resolved:
stg refresh
```

## Step 6: Verify cross-hunk consistency

When a conflict in one function required changing a call
signature, variable name, or data structure layout, check
all other callers and references in the file.  A resolution
that fixes the conflicting hunk but leaves a stale reference
200 lines away produces a silent build break.

```bash
# Quick check: does the resolved file compile?
# (language-dependent; adapt to the project's build system)
```

## Failure policy

If the conflict involves cross-file semantic dependencies
or the intent of both sides cannot be determined from
available context, leave the conflict markers in place and
report what is known and what is ambiguous.  A loud failure
that the user can review is safer than a plausible-looking
resolution that silently blends both sides incorrectly.

## Retrieving prior resolution precedent

Repositories with long histories often contain analogous
past conflicts.  When the conflict involves a pattern that
recurs (e.g., API changes that propagate across many
callers), search for prior resolutions:

```bash
# Find merge commits that touched the same file
git log --merges --oneline -- <file>

# Inspect how a past merge resolved changes to this area
git show <merge-commit> -- <file>
```

Past resolutions in the same repository are the strongest
signal for project-specific conventions (ordering, naming,
error handling style) that a generic resolution would miss.

## Recovering from a failed `stg import`

When `stg import` cannot apply a patch it aborts patch creation
-- no new patch lands on the stack (see the "Conflicting `stg
import` creates no patch" pitfall in SKILL.md for the trap). A
plain `stg import` rolls back atomically and leaves the worktree
clean; only `stg import --3way` (`-3`) leaves the diff and
conflict markers loose in the worktree, because the 3-way apply
writes them before failing. Escalate a plain apply failure to
`-3` when context diverged by an unrelated change (e.g. an
upstream rename landed in the stack base): it runs a 3-way merge
and converts the refusal into resolvable markers.

### Rebuilding the patch after a --3way import

Resolve the markers and mark them with `stg resolved <file>` --
otherwise `stg new` and `stg refresh` both abort with "resolve
outstanding conflicts first." A bare `stg refresh` then folds the
imported change into whatever patch is currently top, not into a
patch of its own. To abandon the import outright, `stg undo`
reverses it. To keep it as its own patch, recreate it explicitly:

```bash
stg new <name> --file <msg> \
    --authname <name> --authemail <addr> --authdate <date>
stg refresh
```

Recover the commit log from the mbox into `<msg>` (a multi-line
changelog needs `--file`, not `-m`) and the author fields from
the mbox header. When `stgit.autosign` is set, `stg new` appends
the committer's `Signed-off-by`; drop that line from `<msg>` if
the recovered log already carries it (you authored the patch) to
avoid a duplicate.

To tell whether a stray `stg refresh` already folded the change
in, `stg show` the top patch and look for the imported diff you
did not author. If it is there, `stg undo` splits it back out
into stg's internal `refresh-temp` patch, which can be renamed
(`stg rename`) and re-messaged (`stg edit --file`; that form does
not autosign, so re-include the `Signed-off-by` the mbox carried,
or restore it with `-s`, rather than adding a new one).

### --3way fails with "repository lacks the necessary blob"

The plain apply failed on context drift, and the 3-way fallback
needs the pre-image blobs named in the patch's `index` lines --
absent when the patch was exported from a tree state since
rewritten or pruned (`git cat-file -e <blob>` confirms). Two
recoveries:

- Fetch the objects from the repository the patch was exported
  from (`git fetch <remote>` brings objects without touching HEAD
  or stack metadata), then retry the import.
- Hand-rebase the patch: create it with `stg new --file <msg>`
  plus `--authname`/`--authemail`/`--authdate` from the patch
  header, then apply with `git apply --reject` (safe on an stg
  branch; never moves HEAD). Resolve the `.rej` hunks against
  current code; when the patch moves a code block between files,
  diff the moved block against its current in-tree state and port
  any drift into the destination here, or the patch silently
  reverts later changes. Delete the `.rej` files and confirm none
  remain with `git status` before refreshing. `stg add` any new
  files, then `stg refresh` -- or `stg refresh --force` when
  `stg add` left the index dirty.
