# Folding one patch into another

Entered from "Combining patches: avoid stg squash" in
SKILL.md. `stg squash` discards its inputs' change history;
this by-hand fold leaves the fold visible as ordinary
refresh and edit entries in the surviving patch's history.

To fold patch B into the patch A beneath it. First confirm
from `stg series` that no patch sits between A and B; if one
does, read "When B is not directly above A" below and choose
a workaround before running step 1, since the sink form has
to happen before the export:

```bash
orig_top=$(stg top)          # topmost applied patch, to restore at the end
stg export -d <dir> B        # writes <dir>/B: B's message + diff
stg goto A                   # pops B and everything above A, making
                             # A top (stg fold applies to the top
                             # patch); assumes B sat directly above A
                             # -- see "When B is not directly above A"
                             # below
stg fold <dir>/B             # apply B's diff to the worktree
stg refresh                  # fold the change into A
stg edit --file <msg-file> A # combined message, if needed
stg delete B
[ "$orig_top" = B ] && orig_top=A  # if B itself was the top patch, the
                                   # fold deleted it; goto A instead
stg goto "$orig_top"         # restore the prior applied set; never
                             # 'stg push -a' here (see the "stg push -a
                             # overshoots" pitfall in SKILL.md).
```

Caveats:

- `<dir>/B` is a full patch file (message plus diff), not a
  commit message. When A's message needs text from B's, write
  the combined message to a temp file and pass that file as
  `<msg-file>` -- do not pass `<dir>/B`.
- When A carries a `Signed-off-by`, re-include that line in
  the combined message to preserve it; `stg edit --file` does
  not autosign, so an omitted trailer drops the one A had. A
  patch created while `stgit.autosign` was unset carries
  none; do not add one.
- After a conflict-free fold the worktree holds only B's
  diff, so a bare `stg refresh` is correct; scope it with a
  pathspec only when the worktree was already dirty before
  the fold. A conflicted fold finishes with `stg refresh
  --index` instead (see below).
- A content change may invalidate existing Reviewed-by tags
  on A.

## When B is not directly above A

`stg export` takes B's diff against B's parent. When other
patches sit between A and B, that diff need not apply at A.
Either -- prefer the first, which touches no other patch:

- Keep B where it is and tell fold what the diff was made
  against: in place of step 3's `stg fold <dir>/B`, run
  `stg fold --base $(stg id B^) <dir>/B`. B is unapplied
  at that point, but `stg id` still resolves it; `B^` is
  B's original parent, the intervening patch, not A.
- Move B down first so the recipe above applies as written:
  `stg sink -T A B` (`-T`/`--above` places B directly above
  A; `-t`/`--below`, alias `--to`, places it *below* the
  target), then export. The sink rebases every patch between
  A and B, and the closing `stg goto "$orig_top"` rebases
  them again, so take it only when B should end up next to A
  anyway. A conflicted sink is not finished after the
  resolution: the conflict can land on an intervening patch
  rather than B, and the sink must be re-run with identical
  arguments, never `stg push -a` -- see "A conflicted `stg
  float`/`stg sink`" in SKILL.md.

Either branch can conflict. Resolve it the way SKILL.md's
"Merge conflict resolution" section prescribes -- `stg
resolved <file>` per file, never `git add` -- and finish
with `stg refresh --index` in place of the recipe's bare
`stg refresh`, which refuses with "the index is dirty" once
`stg resolved` has staged paths.

Plain `stg fold` and `stg fold --threeway` both fail with
"patch does not apply" in this case; that error means the
gap, not a broken export.
