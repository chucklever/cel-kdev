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
- **Tighten to the surviving why.** It buries one fact the code
  cannot carry in narration. Cut the narration; keep the fact; then
  refill the block to the file's width ([kernel.md](kernel.md) gives
  the kernel's command and procedure). Cutting words from a wrapped
  block leaves short lines that read as a second edit waiting to
  happen; a block shortened but not refilled is half a tighten.
- **Delete as noise.** It survives the deletion test below without
  loss -- it restates the line, captions the call, or decodes nothing
  a reader could not read directly.
- **The code should change instead.** The comment is propping up
  inscrutable code -- a magic number, an unnamed block, an unstated
  precondition. Recommend the name, constant, helper, or assertion that
  removes the need, not a better comment.
- **Reword.** A smaller verdict for a comment that earns its place
  but, in a file that implements a specification, borrows "must",
  "should", or "may" for a local obligation (SKILL.md, "Voice"). Keep
  the fact; restate the obligation as a condition or a consequence,
  or cite the spec section it actually comes from. Do not delete it.

For API documentation blocks, judge by completeness (SKILL.md's
API-documentation exception), not the deletion test -- unless the
patch changed whether the function is part of the API at all. A block
on a function the patch made private is re-decided rather than
re-checked: completeness is not the question when there is no longer
a caller to serve. A fifth verdict applies there, **demote or drop**:
keep only what the code cannot show and no other block already
carries, as a plain comment through the gate, and drop the block if
nothing survives. In a kernel tree [kernel.md](kernel.md) decides it.

## The deletion test

The generation-time gate asks whether a reader could write the comment
from the adjacent code. At review time ask the complement: **what
breaks if I delete it?** If nothing -- if no future reader loses a
constraint, a rationale, or a warning -- it was noise. If something
does, that surviving fact is the comment, and only it.

Keep a comment for the fact that would be *lost*, not for the narration
that would merely be *absent*.

A history comment already in the file ("we used to", "previously",
"this fixes") is judged by this test, not by SKILL.md's history rule.
That rule routes narrative in a comment the patch *adds* to the
patch's commit message; a comment that predates the patch has no
commit message to move to, its origin may be unrecoverable from
`git log`, and the rejected alternative it records is what would be
lost.

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
