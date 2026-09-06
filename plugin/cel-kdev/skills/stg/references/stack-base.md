# Composing the upstream ref (b4 fork-point) for the stack base

The base *commit* always comes from `stg id {base}`; this file
covers the separate task of naming the *upstream ref* the stack
is rooted on -- the form b4 expects as a fork-point -- which is
composed from the recorded parent branch.

```bash
# Upstream ref name (the form b4 expects as a fork-point).
# <name> is the branch whose stack you are asking about: the
# current branch (git branch --show-current) unless you are
# reading another branch. These config reads need no checkout.
remote=$(git config branch.<name>.remote)
parent=$(git config branch.<name>.stgit.parentbranch)
# With no parentbranch recorded there is nothing to compose:
# unguarded, the fallback below echoes an empty ref, silently.
# Do not guess a ref; ask the user which ref the stack is
# rooted on.
[ -n "$parent" ] || { echo "no stgit.parentbranch recorded" >&2; exit 1; }
# Composition maps a bare LOCAL parent (master) to its remote-tracking
# ref (cel/master). It breaks two ways: parent may already BE a
# remote-tracking ref (net-next/main), and the push remote
# (branch.<name>.remote) is often NOT the remote the base tracks -- a
# series can push to cel/ while sitting on net-next/main. Blind
# composition then yields a non-existent cel/net-next/main. Try the
# composed form, fall back to the recorded parent (prefix stripped, so
# both paths emit the same form) when it does not resolve.
#
# Detect the unreliable case up front: derive the remote the base
# tracks and warn when it differs from the push remote. Even a ref
# that resolves may then be the wrong same-named branch, so trust
# stg id {base} for the commit.
case "$parent" in
  refs/heads/*) base_remote="$remote" ;;        # local ref -> push remote
  */*)          base_remote="${parent%%/*}" ;;  # remote-tracking ref (net-next/main)
  *)            base_remote="$remote" ;;        # bare local name -> push remote
esac
[ "$base_remote" = "$remote" ] || \
  echo "WARN: push remote ($remote) != base remote ($base_remote); trust 'stg id {base}'" >&2
ref="${remote}/${parent#refs/heads/}"
git rev-parse --verify -q "$ref" >/dev/null || ref="${parent#refs/heads/}"
echo "$ref"
```

`stgit.parentbranch` may be stored as a bare branch name
(`master`) or as a `refs/heads/` ref; stripping the prefix
handles both.  Not every stg branch has `parentbranch`
configured, so `stg id {base}` -- which reads the recorded
base directly and never hits the composition above -- is the
canonical lookup when only the commit hash is needed
(`stg id --branch <name> {base}` for a non-current branch).

**When `branch.<name>.remote` differs from the parent's
tracked remote** (the WARN case above): the rev-parse guard
only rejects a ref that does not resolve, so a composed ref
that *does* resolve but points at a same-named branch on the
push remote passes silently. `stg id {base}` stays
authoritative for the base commit.
