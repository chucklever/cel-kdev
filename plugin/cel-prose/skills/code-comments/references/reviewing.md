# Reviewing comments that already exist

Read alongside SKILL.md when the comment is already written -- a patch
under review, an incoming series, a block you are editing rather than
creating. SKILL.md governs generation: it starts from zero comments and
asks what earns a place. This file governs judgment: the comment is on
the page and the question is what to do with it.

## The four verdicts

Run SKILL.md's gate backward over each comment and land on exactly one:

- **Keep as-is.** It records a surviving fact (an invariant, a barrier
  pairing, a caller obligation, a rationale) that the code cannot
  carry. Leave it alone.
- **Tighten to the surviving why.** It buries one load-bearing fact in
  narration. Cut the narration; keep the fact.
- **Delete as noise.** It survives the deletion test below without
  loss -- it restates the line, captions the call, or decodes nothing
  a reader could not read directly.
- **The code should change instead.** The comment is propping up
  inscrutable code -- a magic number, an unnamed block, an unstated
  precondition. Recommend the name, constant, helper, or assertion that
  removes the need, not a better comment.

For API documentation blocks, judge by completeness (SKILL.md's
API-documentation exception), not the deletion test.

## The deletion test

The generation-time gate asks whether a reader could write the comment
from the adjacent code. At review time ask the complement: **what
breaks if I delete it?** If nothing -- if no future reader loses a
constraint, a rationale, or a warning -- it was noise. If something
does, that surviving fact is the comment, and only it.

Keep a comment for the fact that would be *lost*, not for the narration
that would merely be *absent*.

## Look outside the diff

A comment can restate something a reader already has without any line
of the diff showing it -- the places SKILL.md's gate widens to. The
patch is your frame, not the reader's: grep the file, the header, and
the callee before ruling a comment necessary. When the fact is
recorded elsewhere and the reader might not find it, the fix is a
pointer to that place, not a copy of what it says.

The same failure appears within one patch: one rationale written at
every site it governs. Each instance passes the deletion test alone, so
no per-comment check catches it. Read the patch's comments as a list
before judging them one at a time.

## Review output

Per comment, emit the location, the quoted line, one of the four
verdicts, and -- for tighten or refactor -- the replacement. Nothing
else:

> `fs/nfsd/nfs4state.c:812` -- `/* increment the sequence id */`
> **Delete as noise.** Restates `seqid++` on the next line;
> survives the deletion test without loss.
>
> `fs/nfsd/nfs4state.c:1040` -- `/* set the start time */`
> **Tighten to the surviving why.** Cut the narration, keep what
> the timestamp is for:
> `/* Snapshot before the RPC so a stall shows as elapsed time. */`
>
> `net/sunrpc/svc.c:critical block` -- unnamed 30-line dispatch
> **The code should change instead.** Extract `svc_process_common()`
> body into a named helper; the banner comment goes away with it.

## Stale comments

A wrong comment is worse than none: it actively misleads, and this is
empirically confirmed to seed bugs (Tan et al., SOSP 2007, found 60
comment/code inconsistencies in Linux, Mozilla, Wine, and Apache, 33 of
them confirmed by developers as bugs or bad comments). Every comment
near changed code must still be true. Update it or drop it -- never
leave it.
