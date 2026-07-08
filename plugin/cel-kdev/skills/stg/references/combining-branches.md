# Constructing a base merge commit for stg rebase

For the model and the split on intent (linearize vs. true
merge), see "Combining branches: there is no stg merge" in
SKILL.md. This reference covers the **true merge** case: building
a merge commit to sit *below* the stack base, then replaying the
stack onto it with `stg rebase`.

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
