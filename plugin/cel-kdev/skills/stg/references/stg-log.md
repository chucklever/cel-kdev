# Tracing patch evolution with stg log

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
patch's contribution, use the Top/Bottom tree approach
described in the main skill document.
