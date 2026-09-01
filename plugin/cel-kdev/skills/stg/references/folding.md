# Folding one patch into another

Entered from "Combining patches: avoid stg squash" in
SKILL.md. `stg squash` discards its inputs' change history;
this by-hand fold leaves the fold visible as ordinary
refresh and edit entries in the surviving patch's history.

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
- After the fold the worktree holds only B's diff, so a bare
  `stg refresh` is correct; scope it with a pathspec only
  when the worktree was already dirty before the fold.
- A content change may invalidate existing Reviewed-by tags
  on A.
