# Retiring patches upstream has taken

Entered from "Retiring patches upstream has taken" in
SKILL.md: a remote has taken a patch -- a maintainer merging
part of a series, or a plain `git push` to a repo you own --
and it must be cleared from the stack by re-deriving from
upstream rather than folding it in locally:

```bash
git fetch <remote>
stg rebase -m <upstream-ref>   # patches already upstream go empty
stg clean                      # drop the emptied patches
```

## Choosing `<upstream-ref>`

`<upstream-ref>` is the ref that now carries the patches, not
an assumed `origin/master`. Usually that is the base's
upstream, composed per [stack-base.md](stack-base.md) (see
"Finding the stack base" in SKILL.md); when the push remote
differs from the remote the base tracks -- the case that
file's script warns about -- it is the ref you actually
pushed to.

## Why not `stg commit`

Prefer this over `stg commit <patch>`. Both end with the
patch folded into the base, but `stg commit` never consults
the remote: a push that failed, or landed as something other
than what you sent, leaves the stack asserting work the
remote never received. The rebase checks -- a patch upstream
did not take comes back non-empty and survives the
`stg clean`. Read a survivor before concluding the push
failed, though: a patch the remote took in modified form also
comes back non-empty, because the check compares content, not
intent, and keeping that one re-sends work upstream already
has.

## Unapplied patches are never re-derived

`-m` tests only the applied patches. `stg rebase` pops the
applied set and pushes back that same set, so an unapplied
patch is never re-derived: one upstream took stays non-empty,
`stg clean` leaves it in the stack, and it conflicts or
duplicates on its next push. Check `stg series -d` for `-`
lines first. To bring a pushed one into reach use `stg goto
<patch>`, which applies the intervening patches in series
order -- not `stg push <patch>`, which reorders the series
(see that pitfall in SKILL.md).

The `stg commit -a` in the raw-reset recovery
([recovery.md](recovery.md)) is a separate case: what it
absorbs is upstream history that `stg repair` turned into
patches, not a patch of yours a remote took.
