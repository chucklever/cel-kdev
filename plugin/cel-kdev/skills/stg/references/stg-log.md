# Tracing patch evolution with stg log

Background and the core caveat -- the `<meta-sha>` is an stg
metadata commit, not the patch's code commit -- are in the
"Tracing patch evolution with stg log" section of SKILL.md. This
reference covers aligning `stg log` with the branch reflog,
walking file snapshots, reconstructing a patch's diff at a
historical point, and bisecting when a change entered a patch.

## Branch reflog vs stg log

`git reflog <branch>` (an alias for
`git log -g --abbrev-commit --pretty=oneline <branch>`)
and `stg log` show overlapping but different histories:

| View                   | What entries record                              | SHA points at      | Best for                                                  |
| ---------------------- | ------------------------------------------------ | ------------------ | --------------------------------------------------------- |
| `git reflog <branch>`  | stg ops that moved HEAD on the active branch     | The code commit    | "What did the top patch look like N refreshes ago?"       |
| `stg log [<patch>]`    | Every stack-state change, incl. unapplied moves  | An stg meta commit | "When did patch X enter the stack? Was it ever popped?"   |

Reflog and `stg log` entries for the same op carry the same
message string, so the two views can be aligned by matching on
that description.

The branch reflog records only HEAD movements on the active
branch. Metadata-only operations (those that do not move HEAD)
and edits to a patch made while it is unapplied appear only in
`stg log`. HEAD-moving ops performed while some patch is
unapplied (e.g., `stg pop`, `stg push <patch>`, `stg goto`)
still appear in the reflog.

### Walking HEAD snapshots of a file

To walk HEAD snapshots and inspect a file at each one:

```bash
git reflog <branch>
git show <sha>:<path>
git diff <old-sha> <new-sha> -- <path>
```

Do not pair `-- <path>` with a reflog walk (`git reflog` or
`git log -g`): pathspec filtering treats reflog entries as
linear ancestors, which they are not in a shuffled stg history.
The filter silently elides relevant entries -- often every entry
-- because each step's commit is diffed against its git-parent
rather than the prior reflog step.

## Extracting a patch diff at a historical point

Each metadata commit stores per-patch content as tree OIDs in
`patches/<name>`:

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

## Finding when a specific change entered a patch

To trace when a line or hunk was added to a patch:

```bash
# For each stg log entry, extract the tree OIDs and
# check whether the change is present
for meta in $(stg log <patch> | awk '{print $1}'); do
  top=$(git show "$meta":patches/<patch> 2>/dev/null \
        | awk '/^Top:/{print $2}')
  bottom=$(git show "$meta":patches/<patch> 2>/dev/null \
           | awk '/^Bottom:/{print $2}')
  [ -z "$top" ] && continue
  count=$(git diff "$bottom" "$top" -- <file> \
          | grep -c '<pattern>')
  echo "$meta: $count matches"
done
```

If all entries show 0 matches, the change may have been
introduced by a `stg squash` or `stg edit` that combined
patches -- check `stg log` (without a patch argument) for
stack-wide operations around the time the change appeared.

## Using stack.json head field

Each metadata commit also contains `stack.json` with a
`head` field pointing to the actual HEAD commit (the
topmost applied patch). This is useful when the change
might span multiple patches:

```bash
head_sha=$(git show <meta-sha>:stack.json | jq -r '.head')
git show "$head_sha" -- <file>
```

Note: `head` is the cumulative result of all applied
patches, not a single patch in isolation. To see one
patch's contribution, use the Top/Bottom tree approach in
"Extracting a patch diff at a historical point" above.
