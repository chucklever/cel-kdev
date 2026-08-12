---
name: code-comments
description: Use when writing, editing, or reviewing a code comment in any codebase -- calibrating a comment's voice and verbosity, deciding whether a comment earns its place, judging whether to comment at all, or writing an API documentation block (kernel-doc, rustdoc, a docstring). Linux kernel trees take references/kernel.md on top of it; reviewing comments that already exist takes references/reviewing.md. For a commit message use the cel-prose:commit-message skill; for a doc-focused kernel patch review use kdoc.
---

# Code comments: voice and verbosity

## Core principle

The first tool for making code understandable is the code, not
the comment. Write the function so its working is obvious -- by
naming, structure, decomposition, named constants -- and most
comments become unnecessary before you type them. Kernel
coding-style is emphatic: "it's much better to write the code so
that the working is obvious." A comment is the fallback for what
the code cannot be made to carry, not the first move.

For the residue that naming and structure cannot express -- an
intent, a rationale, a load-bearing invariant, a hazard -- say the
non-obvious thing and stop. A comment that restates the code has
a cost: it adds maintenance and goes stale the first time the
code changes underneath it.

## Start at zero

The starting state is **no comments**. Not "comment as you go, then
prune" -- commenting as you go produces narration, and pruning your own
narration is the check that never happens. Work in this order:

1. **Write the code complete and bare.** No comments at all, not even
   placeholders. Name things precisely while you do it.
2. **Reread it as someone who has never seen it.** Note where you
   actually stumble: a constant with no story, an ordering that looks
   arbitrary, a branch whose reason is offstage.
3. **Fix what the code can fix.** Each stumble gets the code-first
   treatment below before it gets a comment.
4. **Add comments only for what survives** -- the always-comment floor,
   plus the facts step 2 surfaced that step 3 could not absorb.

Every comment is now an addition you chose and can name a reason for.
If you cannot say which floor item or which surviving fact a comment
covers, it does not go in.

Entering mid-stream: when the code is already drafted and already
carries comments, delete the ones you wrote and rejoin at step 2.
Comments that were in the file before you touched it are the reader's
context, not yours to defend -- judging those is review, and
[references/reviewing.md](references/reviewing.md) governs it.

## Code first: eliminate before you explain

Most first-draft comments are a signal that the code has not yet said
what it means. The moves, cheapest first:

- **A precise name.** A function or variable whose name states
  intent removes the summarizing comment. `if
  (!fh_within_export(fh, exp))` needs no comment; the extracted
  predicate says what a `/* reject handles outside the export */`
  would have.
- **A named constant or enum** removes the "what does this literal
  mean" comment: the name carries it, in every use site.
- **An extracted helper** removes the "this block does X" banner:
  the call reads as the sentence the banner would have written.
- **Structured control flow** (guard clauses, early returns)
  removes the "handle the error case" narration.
- **An assertion** documents a precondition *executably*:
  `lockdep_assert_held(&serv->sv_lock)` states and enforces what
  `/* caller must hold sv_lock */` only claims -- and unlike the
  comment it cannot silently go stale.

Elimination beats a terse comment, and a terse comment beats a
verbose one.

## The gate: could the reader have written it?

One question, applied to every comment before it goes in:

> **Could a reader who has never seen this code write this comment
> from the adjacent lines alone?**

If yes, it adds nothing. Delete it. (Ousterhout's redundancy test;
see [references/literature.md](references/literature.md).)

This is deliberately a test on the text in front of you, not on an
imagined future reader's loss -- that one is easy to answer generously
in your own favor, so it is kept for review time, where the comment
already exists and the burden runs the other way.

"The adjacent lines" is narrower than what the reader has. Two
widenings, both of which sink a comment that passes the bare gate:

- **The rest of the codebase.** The struct definition, the header
  declaration, the caller, the callee, a comment already sitting
  elsewhere in the file. Grep before adding. When a fact is recorded
  elsewhere and the reader might not find it, point at that place
  rather than copying what it says.
- **Your own diff.** One rationale governing several sites is one
  comment, at the site where a reader first meets the condition. The
  later sites go bare.

## Length budget

Adjectives like "terse" do not constrain; numbers do. Unless the
comment is an API documentation block, which is sized by its contract:

| Length | When |
|---|---|
| **One line** | The default, and the great majority. |
| **Two to four lines** | Only for a floor item that needs the room -- a barrier pairing, a caller obligation invisible at the site, a non-obvious workaround's why. The floor list governs, not these three examples. |
| **Longer** | Must name what cannot compress -- an ordering argument, a barrier-pairing diagram, a protocol state table, a hardware erratum, an algorithm derivation, a data structure's layout and its locking rules. Content no reformatting of the code could convey. |

If a paragraph could be three lines, make it three lines. If three lines
could be one, make it one. A block comment that could be one line is
the most common form of earned-nothing length.

There is no target comment *ratio* -- that is folklore, and no credible
study supports it. The budget is per comment, not per file.

## Banned openings

A comment whose first words announce that it is about to restate the
line below. Presume noise; do not write one. If the fact is real,
rewrite so the comment *leads with the why*, then re-run the gate.

`Now ...` · `This function ...` · `This method ...` · `Loop over ...` ·
`Iterate ...` · `Check if ...` · `Check whether ...` · `Set the ...` ·
`Get the ...` · `Increment ...` · `Decrement ...` · `Initialize the
...` · `Allocate ...` · `Free the ...` · `Handle the ... case` ·
`Helper to ...` · `Call ... to ...` · `Make sure ...` · `We ...` ·
any banner captioning a block, any `--- section ---` divider

```c
/* Now enable the transmitter */          /* banned: "Now" */
/* Check if the handle is stale */        /* banned: "Check if" */
/* Helper to free the reply buffer */     /* banned: "Helper to" */
```

Two exceptions, both on content rather than phrasing. The list does
not reach inside an API documentation block -- a kernel-doc summary
line opens `Allocate a struct svc_rqst` by convention, and `Return:`
and `Returns ...` are its grammar. And a caller obligation or hazard
is not narration: "Make sure the caller has dropped the lock before
this returns" states something the code cannot, so the banned string
at its front does not sink it. Neither exception says imperatives are
fine -- almost every entry on the list is an imperative already. Judge
on the gate.

## The always-comment floor

Over-commenting is a *named danger* in kernel coding-style. But
under-commenting new code is equally disfavored ("comments are most
notable by their absence"). The floor names what must not go
unrecorded:

- Every memory barrier or explicit ordering primitive -- one line
  on *why* it is necessary and, where it pairs, what it pairs
  with.
- The locking rules for a shared data structure -- somewhere
  central.
- Major data structures -- comprehensively.
- Any non-obvious "cleanup" or workaround -- *why* it is done that
  way.
- Non-obvious constraints and caller obligations.
- A known shortcoming -- an honest FIXME/TODO naming the hazard.

This is a floor, not a quota. It licenses nothing beyond itself, and a
comment outside this list still has to pass the gate.

## Voice

- **Why and what, never how.** Kernel coding-style is explicit:
  "NEVER try to explain HOW your code works." State the purpose or
  the rationale; let the code show the mechanism. The prohibition
  targets mechanism the code already shows -- a non-local ordering
  or barrier-pairing argument the code *cannot* show locally is
  why, not how, and earns its space.
- **Imperative mood, no pronouns.** "Drop the reply" not "we drop
  the reply." "Inform secondary MMUs" not "this tells the other
  MMUs." (maintainer-kvm-x86)
- **Describe mechanism and causation**, in order: what happens, in
  what order, why. This mirrors the cel-prose:prose-voice rule for
  all kernel prose.
- **Sentence case, ASCII, single blank between sentences.**
- **Wrap comment text** to the width the surrounding file uses,
  measured with `fmt`. The kernel's is `fmt -g 74 -w 74`.
- **Tail comments follow the project.** The kernel forbids them;
  other codebases use them idiomatically for short notes. Anything
  longer than a few words reads better as a freestanding comment
  above the code in any language.
- **Register:** old high-trust code sometimes reads informally
  ("belt and suspenders", "I'm not sure but"). That tone is earned
  in place; for new code write the plainer imperative form.

## The API-documentation exception

The gate does *not* govern an API documentation block -- kernel-doc
(`/** */`), rustdoc (`///`), a docstring. These state a contract for a
caller who cannot see the body, so **completeness governs**: what the
function does, every parameter, what it returns, and the conditions the
caller must satisfy (execution context, locks held or taken, sleeping
behavior).

**Never drop a parameter to save words.** kernel-doc requires every
parameter, in order; a missing one is a `make W=1` warning, and rustdoc
and docstring conventions expect the same completeness. The length
budget above does not apply here and neither does the redundancy gate.

Over-commenting applies to the *content* of each line, not to which
lines exist. Every parameter gets a line; make the line say what the
signature cannot -- units, ownership, lifetime, nullability, valid
range, what a flag actually selects:

```c
 * @lock: the lock                      /* nothing the signature lacks */
 * @timeo: timeout                      /* in what unit? 0 meaning? */
```
```c
 * @lock: acquired on entry, released before return
 * @timeo: timeout in jiffies; 0 waits forever
```

The kernel's grammar for this block, which symbols require one, and
the subsystems that forbid it on internal functions are in
[references/kernel.md](references/kernel.md).

## Worked calibration: before and after

**Restating the code -> delete it.**
```c
/* Now enable the transmitter */          // NO: mirrors the call
ew32(TCTL, tctl | E1000_TCTL_EN);
```
A reader could write that comment from the line below. Cut it.

**Narration -> the load-bearing why.**
```c
time = jiffies;   /* set the start time for the receive */   // NO
```
```c
/* Snapshot before the DMA so a stall shows up as elapsed time. */
time = jiffies;                                              // YES
```
The rewrite keeps only the fact the code cannot show -- what the
timestamp is *for*.

**A bare barrier -> barrier plus reason.**
```c
smp_wmb();                                          // NO: silent
```
```c
/* Publish the initialized node before the store that makes it
 * reachable; pairs with the load-acquire in the reader. */
smp_wmb();                                                  // YES
```
4.Coding.rst requires the why-line; naming the pairing site is the
kernel norm.

**An invariant a reader cannot see locally -> state it.**
```c
tlb_ubc->writable = true;                           // NO: silent
```
```c
/* If the PTE was dirty, assume writable. The caller must
 * try_to_unmap_flush() before the page is queued for IO. */
tlb_ubc->writable = true;                                   // YES
```
The caller obligation is invisible at this line and critical for
correctness -- exactly what a comment is for.

**One fact at several sites -> state it once.**
```c
/* An admin revoke stays on cl_revoked: NFS4ERR_ADMIN_REVOKED is
 * how the client learns of it. */
if (badhandle && !(sc_status & SC_STATUS_ADMIN_REVOKED))
	...
/* An administratively revoked @dp is left where it is: the
 * client has NFS4ERR_ADMIN_REVOKED still to collect. */  // NO
if (sc_status & SC_STATUS_ADMIN_REVOKED)
```
```c
/* An admin revoke stays on cl_revoked: NFS4ERR_ADMIN_REVOKED is
 * how the client learns of it. */
if (badhandle && !(sc_status & SC_STATUS_ADMIN_REVOKED))
	...
if (sc_status & SC_STATUS_ADMIN_REVOKED)                 // YES
```
Read alone, each block passes the gate: the fact is real and the code
cannot carry it. Read together they are one fact written twice. State
it where a reader first meets the condition and leave the later sites
bare.

## Quick reference

| Situation | Do |
|---|---|
| Comment restates the line below | Delete it |
| Comment opens with a banned string | Delete it, or rewrite to lead with the why |
| Fact already in the header, caller, or callee | Don't restate it; point at it if it is hard to find |
| A name/const/helper would remove the need | Refactor, don't comment |
| Memory barrier or ordering primitive | One line: why, and what it pairs with |
| Locking rule | State centrally; prefer an executable assertion in code |
| Non-obvious workaround / cleanup | Comment *why*, cite erratum/RFC if any |
| Known shortcoming | Honest FIXME/TODO naming the hazard |
| Public / exported function | Full API doc block: every param, return, caller obligations |
| Explaining *how* the code works | Rewrite the code instead |
| One rationale governs several sites | State it once; leave the rest bare |
| Placing a comment at end of line | Follow the project; the kernel forbids it |
| Judging a comment that already exists | [references/reviewing.md](references/reviewing.md) |

## Before you finish: the comment list

Per-comment checks structurally cannot catch duplication and volume,
because each instance passes on its own. So do this last, once:

**Extract every comment you added into a flat list, stripped of the
code around it, and read the list.** Out of context, narration and
repetition are obvious; in place, they are invisible.

Against that list:

- **Any two entries saying the same thing collapse to one.** Keep it
  where a reader first meets the condition.
- **Any entry that reads as a caption** -- a sentence that only makes
  sense next to the line it sits on -- is narration. Delete it, or
  refactor the code it was propping up.
- **Every remaining entry names its reason:** a floor item, or a fact
  the code cannot carry (intent, invariant, hazard, caller
  obligation). If you cannot name it, cut it.

Then, in place: every comment near code you **changed** must still be
true. A stale comment is worse than none; update it or drop it.

## Going deeper

- [references/reviewing.md](references/reviewing.md) -- judging comments that
  already exist: the four verdicts, the deletion test, review output
  format.
- [references/kernel.md](references/kernel.md) -- the Linux kernel
  overlay: kernel-doc grammar and which symbols require it, the
  74-column wrap, the tail-comment prohibition, and the sources
  behind the always-comment floor.
- [references/documentation.md](references/documentation.md) --
  the official kernel guidance, quoted: coding-style S8, kernel-doc
  grammar, 4.Coding's always-comment floor, maintainer-tip and
  -kvm-x86, checkpatch mechanics.
- [references/examples.md](references/examples.md) -- annotated
  specimens across mm/, sched/, locking/, net/, lib/, arch/x86,
  in five categories, with the e1000 driver as a counter-example
  control.
- [references/literature.md](references/literature.md) -- the
  empirical and practitioner evidence (Ousterhout, McConnell,
  Kernighan & Plauger, Martin; Padioleau, Tan, Fluri, Wen, Potdar
  & Shihab, Buse & Weimer) behind each rule, with weak claims
  flagged.

This skill is the home for code-comment guidance in any language or
project; the "Code comments" section in the kernel tree's CLAUDE.md
points here. It builds on the voice rules the cel-prose:prose-voice
skill owns, so load that skill first. When they disagree, the more
specific instruction wins; they are not meant to.
