---
name: code-comments
description: Use when writing, editing, or reviewing a code comment in any codebase -- calibrating a comment's voice and verbosity, deciding whether a comment earns its place, judging whether to comment at all, or writing an API documentation block (kernel-doc, rustdoc, a docstring). Linux kernel trees take references/kernel.md on top of it. For a commit message use the cel-prose:commit-message skill; for a doc-focused kernel patch review use kdoc.
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

## Code first: eliminate before you explain

Before writing a comment, try to make it unnecessary. Most
first-draft comments are a signal that the code has not yet said
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
verbose one. Reach for a comment only once the code-level moves are
exhausted and a non-obvious fact still remains. The examples that
follow all assume you have already done this step.

This skill is the home for code-comment guidance in any language
or project; the "Code comments" section in the kernel tree's
CLAUDE.md points here. It builds on the voice rules the
cel-prose:prose-voice skill owns, so load that skill first. This
one adds the examples, the official guidance, and the evidence
that justify each rule. When they disagree, the more specific
instruction wins; they are not meant to.

**Linux kernel trees take one more file.** Read
[references/kernel.md](references/kernel.md) before writing a
comment in one: the kernel-doc grammar, the 74-column wrap, the
tail-comment prohibition, and the always-comment floor live there.
Everything below still applies.

## The bar: three questions before you write

Apply in order. Most first-draft comments fail one of these.

1. **Can the code carry this itself?** Apply the code-first moves
   above. If any removes the need, do that instead. A comment
   cannot rescue inscrutable code; it only adds a second thing to
   keep in sync.

2. **Can a reader already gather this?** Not only from the line
   below, but from anywhere they would naturally look: the struct
   definition, the header declaration, the caller, the callee, a
   comment already sitting elsewhere in the file. Look outside the
   diff before deciding. The patch is your frame, not the reader's,
   and a comment restating what a header two directories away
   already records is redundant even though nothing in the diff
   shows it. `/* Decrement refcount and check for zero */` over
   `if (!--x)` is the local case; the same failure at a distance is
   a comment restating a caller obligation the callee's own
   documentation already states. When the fact is recorded
   elsewhere and the reader might not find it, point at that place
   rather than copying what it says.

3. **What breaks if I delete it?** If nothing -- if no future
   reader loses a constraint, a rationale, or a warning -- it was
   noise. If something does (a caller obligation, a barrier
   pairing, why the non-obvious path exists), that surviving fact
   is the comment. Write only it.

The deletion test (question 3) is the one to internalize: keep a
comment for the fact that would be *lost*, not for the narration
that would merely be *absent*.

## Reviewing existing comments

When the comment already exists -- a patch under review, a block
you are editing -- run the same three questions backward and land
on one of four verdicts:

- **Keep as-is.** It records a surviving fact (an invariant, a
  barrier pairing, a caller obligation, a rationale) that the code
  cannot carry. Leave it alone.
- **Tighten to the surviving why.** It buries one load-bearing fact
  in narration. Cut the narration; keep the fact. (See the
  jiffies-snapshot rewrite below.)
- **Delete as noise.** It survives the deletion test without loss
  -- it restates the line, captions the call, or decodes nothing a
  reader could not read directly.
- **The code should change instead.** The comment is propping up
  inscrutable code -- a magic number, an unnamed block, an
  unstated precondition. Recommend the name, constant, helper, or
  assertion that removes the need, not a better comment.

For API documentation blocks, judge by completeness (below), not
the deletion test.

**Review output.** Per comment, emit the location, the quoted
line, one of the four verdicts, and -- for tighten or refactor --
the replacement. Nothing else:

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

## Voice

- **Why and what, never how.** Kernel coding-style is explicit:
  "NEVER try to explain HOW your code works." State the purpose or
  the rationale; let the code show the mechanism. The prohibition
  targets mechanism the code already shows -- a non-local ordering
  or barrier-pairing argument the code *cannot* show locally is
  why, not how, and earns its space (see Verbosity).
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

## Verbosity

Over-commenting is a *named danger* in kernel coding-style, and it
applies to API documentation blocks too -- do not add boilerplate
that restates a signature. But under-commenting new code is
equally disfavored ("comments are most notable by their absence").
The target is neither: comment the subtle, let readable code carry
the rest.

**Always comment (the floor):**
- Every memory barrier or explicit ordering primitive -- one line
  on *why* it is necessary and, where it pairs, what it pairs
  with.
- The locking rules for a shared data structure -- somewhere
  central.
- Major data structures -- comprehensively.
- Any non-obvious "cleanup" or workaround -- *why* it is done that
  way.
- Non-obvious constraints and caller obligations.

This is a floor, not a quota. It names what must not go
unrecorded. It licenses nothing beyond itself, and a comment
outside this list still has to survive the three questions.

**A longer block comment must earn its length.** It is justified
for an ordering argument, a barrier-pairing diagram, or algorithm
rationale that genuinely cannot compress -- content no
reformatting of the code could convey. If a paragraph could be
three lines, make it three lines.

## The API-documentation exception

The deletion test does *not* govern an API documentation block --
kernel-doc (`/** */`), rustdoc (`///`), a docstring. These state a
contract for a caller who cannot see the body, so completeness
governs rather than surprise: what the function does, every
parameter, what it returns, and the conditions the caller must
satisfy (execution context, locks held or taken, sleeping
behavior). Even here over-commenting applies -- do not restate what
the signature already says. `@lock: the lock` adds nothing.

The kernel's grammar for this block, which symbols require one, and
the subsystems that forbid it on internal functions are in
[references/kernel.md](references/kernel.md).

## Worked calibration: before and after

**Restating the code -> delete it.**
```c
/* Now enable the transmitter */          // NO: mirrors the call
ew32(TCTL, tctl | E1000_TCTL_EN);
```
The comment survives deletion without loss. Cut it.

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
Read alone, each block passes the deletion test: the fact is real
and the code cannot carry it. Read together they are one fact
written twice. State it where a reader first meets the condition
and leave the later sites bare.

## Quick reference

| Situation | Do |
|---|---|
| Comment restates the line below | Delete it |
| Fact already in the header, caller, or callee | Don't restate it; point at it if it is hard to find |
| A name/const/helper would remove the need | Refactor, don't comment |
| Memory barrier or ordering primitive | One line: why, and what it pairs with |
| Locking rule | State centrally; prefer an executable assertion in code |
| Non-obvious workaround / cleanup | Comment *why*, cite erratum/RFC if any |
| Known shortcoming | Honest FIXME/TODO naming the hazard |
| Public / exported function | Full API doc block: params, return, caller obligations |
| Explaining *how* the code works | Rewrite the code instead |
| One rationale governs several sites | State it once; leave the rest bare |
| Placing a comment at end of line | Follow the project; the kernel forbids it |

## Common mistakes

- **Commenting around bad code.** A banner summarizing a block, or
  a comment decoding a magic number, is the code asking to be
  refactored -- extract a named helper or a named constant instead
  of narrating.
- **Echoing the code.** The single most common failure; the
  staleness studies show it is also the most likely to rot.
- **A wrong or stale comment.** Worse than no comment -- it
  actively misleads (empirically confirmed to seed bugs). When you
  change code, change the comment above it or delete it.
- **Boilerplate API documentation.** `@lock: the lock` adds
  nothing; over-commenting applies to doc blocks too.
- **Restating what the reader can already see elsewhere.** The
  fact is in the header, the callee's own documentation, or
  earlier in the same file. Every per-comment check inside the
  diff passes, because the duplication is outside the diff. Look
  there before adding.
- **A block comment that could be one line.** Length must be
  earned by content that cannot compress.
- **The same fact written at every site it governs.** Each block
  passes the deletion test on its own, so no per-comment check
  catches it; only reading the patch's comments together does.
- **Chasing a comment-density target.** There is no defensible
  ratio; content and accuracy carry value, not quantity.

## Before you finish

Run the bar backward over your own diff. Read the added comments
**together** before judging them one at a time -- a rationale
repeated at each site it governs clears every per-comment check
below and still doubles the comment volume.

- Every non-obvious fact must appear **once** where a reader will
  look, which is wider than the diff. Before adding a comment,
  grep the file, the header, and the callee for the fact already
  written down. Keep it where a reader first meets the condition;
  the later sites go bare, inside the diff and outside it.
- Every comment you **added** must name a fact the code cannot
  carry -- an intent, invariant, hazard, or caller obligation. If
  it only narrates the mechanism, delete it or refactor the code.
- Every comment you **kept** must fail the deletion test: something
  is lost if it goes. If nothing is, it was noise.
- Every comment near code you **changed** must still be true. A
  stale comment is worse than none; update it or drop it.

## Going deeper

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
