---
name: commit-message
description: Use when writing, amending, or rewording a git commit message in any repository -- drafting the log for a new commit, rewriting an stg patch's description, or fixing up a message before pushing or sending. Covers subject-line form, the why-first body, trailers, line widths, and the prose voice. Reach for this whenever a commit log needs prose, even if the request just says "commit this" or "write the patch description." Linux kernel patches take references/kernel.md on top of it. For a series cover letter, pull request description, or merge commit message, use the cel-prose:cover-letter skill; for sign-off and patch mechanics, cel-kdev:stg.
---

# commit-message

How to write a commit message in Chuck's voice, in any repository.
This skill governs the *message text*. The mechanics of committing
(git, stg) and sending (b4/series-send) live in the cel-kdev:stg and
series-send skills; load those for the workflow, this for the prose.

**Linux kernel patches take one more file.** Read
[references/kernel.md](references/kernel.md) before drafting one.
Everything below still applies; the reference covers where the kernel
departs from it -- subject case, the trailer block, sign-off ownership
-- and carries the kernel worked examples.

## The shape of a commit message

```
component: imperative summary, no trailing period

Body that opens with why the change is necessary -- the problem,
the user-visible symptom, the invariant being restored -- before
it says what changed. Flowing prose, wrapped at 72 columns.

Trailers, when the project uses them.
```

## Subject line

The subject is a one-line claim a reader scans in `git log
--oneline`, so it must read as a specific action, not a topic.

- Prefix with the component, then `: `, then an imperative summary
  (`fix`, `add`, `remove` -- not `fixed`, `adds`, `fixing`).
- Find the prevailing prefix by reading `git log --oneline` for the
  files you touched; match what that project already uses (`stg:`,
  `mcp:`, `reviewer:`, `scripts:`). Do not invent a new prefix where
  one is established, and do not impose one on a project whose log
  carries none -- the Internet-Draft repositories take a bare
  imperative summary.
- Capitalization after the prefix follows the project, so read it off
  the same `git log --oneline`: your own repositories capitalize the
  summary (`stg: Scope the orientation call on a deep stack`), while
  the Linux kernel lowercases it.
- No trailing period. Keep it under ~70 columns; the summary should
  survive on its own.

## Body: why before what

Lead with why the change is necessary, not what changed. The diff
already shows what changed; what it cannot show is the problem that
made the change necessary -- the race, the leak, the spec
requirement, the symptom a user hit. Open there. Only once the
motivation is established does the body say what the commit does
about it.

Not every what earns its lines. The body states what the commit
does; going further, into how it does it, earns space in the
commit message only when the prose illuminates a design choice
the diff cannot convey: a reference taken rather than borrowed,
a lock held across a wider region, an ordering that now matters.
A paragraph narrating a mechanical factoring, defending a
structural choice no reviewer would stop on, or restating a
comment the change itself adds, is padding, not rationale.

Two paragraphs is the common shape: why, then what. A third has
to answer a question the code raises, and if you cannot name the
question, cut it. Then read the draft one sentence at a time and
ask what the reader could not reconstruct from the diff without
that sentence. One that survives only because it is true has not
earned its line.

Two shapes fail that test every time. A bullet per added test,
or a paragraph per new function, restates names the diff already
lists; say what the set of them accomplishes and stop. And a
walk through a new function's steps -- which field is filled
first, what is copied where -- is the diff in prose.

For a non-fix commit (a feature, cleanup, or optimization), the
why is a limitation, a missing capability, or a cost the change
removes rather than a bug. Open on that need; do not manufacture
a symptom the change does not fix.

When the diff does not tell you why the change is necessary, do
not infer it from the diff. A why reconstructed that way is the
what in different words. The reason lives in the history of the
code (`git log` on the touched files, the `Fixes:` chain of
whatever this replaces), in the bug report, or in the author's
head -- go and get it, and ask when the searches come up short.
The cel-prose:cover-letter skill's "sourcing the rationale" section
lists the retrieval moves.

Flowing prose, not bullet lists. A reader reconstructs a causal
chain more reliably from connected sentences than from fragments,
and a commit log is read as narrative. Reserve lists for genuinely
enumerable things (a set of affected configs), never for the
reasoning.

## Rerolling: rewrite, do not accrete

A message grows longest across review cycles, because each round
appends to the last one. When review changes the code, re-derive the
body from the current diff instead of bolting a paragraph onto what
is there. The reader of v4 has not read v1 and cannot make sense of
a sentence that answers a question asked on v2.

The two paragraphs most likely to accumulate this way are a defense
of the design against an alternative that was raised and dropped,
and an explanation of why some neighboring path needs no equivalent
change. Both answer a reviewer, not a reader. A rejected alternative
earns a sentence only when a reader would otherwise propose it, and
then as a property of the design ("an iteration count cannot bound
how long a thread is held"), never as a report of what was tried.

What review produces belongs elsewhere: what changed between
versions goes in the changelog (see cel-prose:cover-letter), and
commentary meant only for this posting goes below the `---`, which
git strips at apply time. Series bookkeeping -- "a follow-up patch
retires that path" -- is cover-letter material too. The log reads as
though the current code were written that way from the start.

The check on a reroll is that the message is no longer than the one
before it unless the code itself grew more subtle.

## Trailers

Follow the project. Most of your own repositories carry no trailers
at all, and a commit that invents them reads as imported from
somewhere else. Where a project does use them, they form a single
block at the end, no blank lines between trailers. The kernel's set
-- `Fixes:`, the attribution trailers, `Link:` -- is in the kernel
reference.

Do not hand-write `Signed-off-by:`. Sign-off is owned by the commit
workflow, not the message text: `git commit -s` appends it, as do
`stg new`/`stg import` when `stgit.autosign` is set, so writing it by
hand duplicates the trailer. Where the workflow adds none, no
sign-off is wanted unless the user asks. See cel-kdev:stg for the
autosign rules and the `stg edit` cases that preserve a sign-off the
patch already carries. When present, the sign-off sorts last.

## Line widths and measuring

- Body text: `fmt -g 72 -w 72`.
- Measure with `git log --format=%B <ref>`. Bare `git log` indents
  the body four spaces, which hides the true column count and leads
  to over-wrapping.

## Voice

The commit body follows the voice rules in the
cel-prose:prose-voice skill; load it before drafting. One rule
specific to a commit message:

- Do not pad to look thorough. A two-sentence message for a
  two-line fix is correct.

## Examples

A fix in one of your own repositories: capitalized summary after the
prefix, no trailers, and a body that establishes the wrong behavior
and its cause before naming the correction.

```
commit: Fix path_patterns no-match message to say ANY (OR)

The query tool's commit-summary output printed "No commits matched
ALL N path pattern(s)" when a path filter excluded everything.
path_patterns is OR'd, though: the filter keeps a commit when ANY
pattern matches any changed file (matches_any_pattern), and the
sibling author and subject messages already say "matched ANY". Only
the path branch said "ALL".

Say "ANY" to match the OR behavior, mirroring the same fix in the
MCP server's find_commit and vcommit_similar_commits output. The
regex and symbol messages, which really are AND'd, keep "ALL".
```

A small change gets a small message. Two sentences is a complete
log when the diff is two lines, and nothing here is missing.

```
cli: Report the byte offset when a header fails to parse

The parse error names the field but not where it occurred, so a
malformed header in a large capture cannot be located without
re-running under a debugger. Report the offset alongside the field
name.
```

The shape to calibrate against is this one, from a posting that
drew "run on sentences full of terms no kernel developer would
use":

```
Only tls_sw_read_sock() needs this cap. Its consumers drive the
receive loop from kernel context -- a work item or service thread
holding the socket lock across the whole call with no return to
userspace -- so an unbounded empty-record stream keeps that
context and the lock pinned for as long as the flood lasts. The
cap supplies the return boundary that a system call would
otherwise provide.
```

That middle sentence runs 47 words and carries two causal links
with an aside wedged between them, and "the return boundary that a
system call would otherwise provide" is a coined phrase for the
syscall return. The same content, in the subsystem's own words:

```
Only tls_sw_read_sock() needs the cap. Its callers hold the socket
lock across the whole call and never return to userspace, so
nothing else bounds the loop.
```

The kernel worked examples -- a bug fix carrying `Fixes:` and a
`Reported-by:`, and an optimization carrying no trailers at all --
are in [references/kernel.md](references/kernel.md), alongside the
rules they illustrate.
