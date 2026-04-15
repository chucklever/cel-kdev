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

```bash
# After editing each conflicted file:
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
