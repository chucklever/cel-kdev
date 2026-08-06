---
name: cover-letter
description: Use when composing, editing, or reworking the *content* of a document that introduces a set of changes to the people who will review them -- a Linux kernel patch series cover letter (the [PATCH 0/N] blurb) and its per-version "Changes in vN" changelog, a GitHub pull request description, or a merge commit message taking a topic branch. Load this whenever you decide what such a document should say -- "write the cover", "rework the cover letter to match the series", "draft the changelog", "summarize the series for submission", "write the PR description" -- even when the request does not name one. Governs prose and content only; for where the cover/changelog files live and how a kernel series is sent, use the series-send and cel-kdev:b4 skills, and for a single patch's commit message use the cel-prose:commit-message skill. Not for a [GIT PULL] request to Linus, which is release notes for already-reviewed work.
---

# cover-letter

How to write the *content* of a document that introduces a set of
changes to the people who will review them, in Chuck's voice. The
Linux kernel patch series cover letter and its per-version changelog
are the main case, and the rules below are written against it. A
GitHub pull request description and a merge commit message do the
same job and take the same rules; "Other surfaces" at the end covers
where they differ. Where the cover and changelog files live and how a
kernel series is sent (b4/series-send) belong to the series-send and
cel-kdev:b4 skills; a single patch's commit message belongs to the
cel-prose:commit-message skill. Load those for the workflow, this for
the prose.

## What a cover letter is for

The cover directs reviewer attention. It carries what the diffs and
the commit messages do not advertise: design choices that span
several patches, subtle invariants, ordering constraints, and
contracts a later patch relies on. A reviewer reads the cover to
learn how to read the series.

So the test for every sentence is whether it earns its place against
that purpose. If a reviewer will find its content in the patch it
belongs to -- the subject, the commit message, the diff -- it is
redundant here; cut it. The cover is not a summary of the patches; it
records the cross-cutting design that no single patch carries.

The cover never enters git history: a part-zero cover is not applied
at all, and for a lone patch the same text sits below the "---" that
git strips at apply time. It lives only in the review thread. So the
cover coordinates the series but never substitutes for a patch's own
commit message -- anything a single patch needs to justify itself
belongs in that patch, not only in the cover.

## Before drafting: sourcing the rationale

The cover carries what the patches do not, so the patches cannot be
the only input. Reading the series tells you what it does. It rarely
tells you why it exists, and that is the half a reviewer is being
asked to accept. Go get it first:

- `git log --oneline -- <touched files>`, for what the code being
  changed has already cost. A series that replaces an interface is
  argued from that record.
- The `Fixes:` chain of the commits this series supersedes or
  deletes, and for each one its `Reported-by:` and whether it
  carried `Cc: stable`. `check-fixes-refs` (cel-tools) walks this.
- lore for the interface or subsystem name: the original bug report,
  and any objection raised on earlier postings of this work.
- The prior versions of this series, for what reviewers already
  demanded and whether this version answers them.

Then interview the author. Retrieval runs first so the questions are
informed -- never spend one on something `git log` would have
answered -- but the motivating incident usually sits in the author's
head and in no diff, and it does not surface unless asked for. Put
the questions as a single batch rather than a trickle:

- What makes this necessary now? If a specific incident drove it --
  a bug, a report, a production failure -- name it, with the commit
  hash and reporter if you have them.
- What will the maintainer push back on, and what would answer it?
- What did you consider and reject? Only the alternative a reviewer
  would otherwise propose.
- Is this the first step of something larger, and what follows?

Skip any question the retrieval already answered. Skip the interview
outright when the motivation is plain from the diffstat; a mechanical
cleanup does not need one. Draft after the answers are in, not
before.

When the author constrains the input ("write it from the commit
messages"), keep the constraint and name what it excludes before
drafting: "the patches carry no evidence for why the new method has
to exist, and a maintainer will ask for it -- supply it, or shall I
walk the Fixes: chain?" The constraint is theirs to keep. The silent
gap is not.

## The objection test

Name the objection the series invites, then check that the cover
answers it with specifics.

- A new API or method: why must this exist? Answer with the
  incidents that made it necessary -- commit hashes, the reporter,
  the stable tags -- not with a characterization of the old
  interface. "The old API is difficult to use" gets conceded and
  dismissed in one line. "Four consumers implemented it
  independently, all four got it wrong, two of the fixes carried
  Cc: stable" does not.
- A revert or removal: what harm does the current code do?
- A behavioral change: who observes it, and what breaks when they do?

A cover that cannot answer its own objection is not ready to send,
and what is missing is the argument rather than the prose.

## What to put in it

Ground each of these in the series as it stands -- the diffstat and
the diffs, never memory of the plan -- and take the reasons from the
record gathered above:

- Name the two or three design choices that shape the series and
  point to the patch that makes each. Give at most one clause of why
  -- the reason a reviewer needs to know what to check -- not the
  argument; that argument is in the patch's own commit message.
- When a decision is scattered across several patches -- a
  cross-cutting behavioral change, a workaround being retired, an
  invariant enforced in three places -- state it once in the cover.
  Otherwise the reviewer has to reconstruct the rationale from the
  individual commits, which is the work the cover exists to save.
- If the series is the first step of a larger plan, say so and say
  what the later steps are. A reviewer who knows the destination
  reviews the first step differently.

## What to keep out: the patch roll-call

Patches are the subject of the diffstat, not of the cover's
sentences. The common failure mode is a paragraph where each sentence
names a patch and restates what it does -- a roll-call that
duplicates the diffstat and the subject lines while adding nothing.

Patch numbers may appear as parenthetical pointers ("...the cap is
scoped to read_sock alone (patch 1)"), but not as the subject or main
referent of an explanatory sentence.

Collapsing several patches into one summary line is the same failure
compressed: "patches 2-4 clean up the accounting" still makes the
patches the subject and only restates the diffstat. A supporting or
cleanup patch that carries no cross-cutting rationale earns no mention
at all -- not a line, not a clause. A patch is named only when it is
load-bearing for a design choice, and then only as a parenthetical
pointer inside that choice's sentence.

Self-test: for each sentence, ask whether a patch -- one, or a batch
of them -- is its subject or main referent. If yes, cut it or recast
it so the subject is the design decision and the patch is only a
pointer.

## Length

Keep the cover under about 400 words. A longer cover competes with
the patches for the reviewer's attention, which is the scarce
resource the cover is meant to spend wisely.

A series with no cross-cutting design story earns a thin cover --
a sentence or two. Do not manufacture architecture to fill space.

## Subject line

The cover subject follows commit-subject conventions: short, a
subsystem prefix in the casing that subsystem's own patches use
(net:, tls: lowercase; NFSD:, SUNRPC: capitalized), no trailing
period. For a series that spans subsystems, a concise descriptive
phrase reads better than a forced single prefix. Do not put version
or prefix markers ([PATCH], v2, RFC) in the subject text -- the send
tool adds those. See cel-prose:commit-message for subject-line form.

## The changelog (v2 and later)

A reroll carries a changelog: what changed since the previous
posting, newest revision first, as terse bullets. Each bullet is a
single line of at most 72 columns. When a bullet runs long, tighten
the wording or split it into two bullets -- do not let it wrap onto
a second line. A line may exceed 72 columns only for an unbreakable
token it must carry, such as a URL or a pathname (the "Link to" line
is the usual case). Content rules:

- Ground every bullet in an actual diff of the prior version against
  the current series, not in memory of what you meant to change.
  Reconstruct the real delta -- a renamed method, an added patch, a
  dropped approach -- and list that.
- Credit a reviewer only when the change actually traces to their
  feedback. A self-driven change dressed as a reviewer's request
  misleads, and it sends that reviewer looking for their fix in a diff
  that does not contain it. When a concern was addressed elsewhere --
  a separate series, a prerequisite that has since landed -- the
  honest changelog omits it here rather than implying this series
  answered it.
- Include a "Link to v(N-1):" pointing at the prior posting so a
  reviewer can diff against it.

The changelog is a separate file the send tool prepends to the cover
at send time; where it lives is a series-send/b4 concern, not this
skill's.

A single-patch reroll has no cover letter. The send tool folds this
same changelog into the lone patch's commentary, below the "---"
divider -- git strips it at apply time, so it is reviewer-facing only.
The content rules above are unchanged, and the "Link to v(N-1):"
matters more here, since no cover carries context. Design rationale
for the patch belongs in its commit message (see
cel-prose:commit-message), not in that commentary. Which surface the
changelog lands on -- cover or
lone patch -- is chosen automatically by patch count, a series-send/b4
concern rather than this skill's.

## Other surfaces: PR descriptions and merge commits

A GitHub pull request description does the cover's job. Its readers
are going to read the diffs, and the description tells them how. Every
rule above holds: the roll-call prohibition, the 400-word cap, the
test that each sentence earn its place. Three things differ.

- The text is not stripped. GitHub folds a squash-merged PR body into
  the commit message, and a merge commit message is history by
  construction. The cel-prose:commit-message rules stack on top of
  these ones: why before what, and no narration of how the branch got
  here.
- There is no per-version changelog. A reroll on GitHub is a
  force-push, not a new posting, so what changed since the last review
  round goes in a comment rather than in the description.
- "Fixes #123" is machinery: it closes the issue on merge. It is not
  the kernel's `Fixes:` trailer. Write it only when you mean the issue
  to close.

A merge commit message that takes a topic branch into your own tree
follows the same shape. Name what the branch contributes and the
decisions that span it, never a walk through its commits.

A `[GIT PULL]` request to Linus is out of scope. That is release notes
for work already reviewed, and `git request-pull` generates the
shortlog and diffstat itself, so the enumeration a cover letter
forbids is the substance of that document.

## Voice

The cover and changelog follow the voice rules in the
cel-prose:prose-voice skill; load it before drafting.

## Example: recasting a patch roll-call

A roll-call cover, each sentence owned by a patch:

  Patch 1 bounds no-data records in tls_sw_read_sock(). Patch 2 adds
  the read_sock_rectype proto_ops method. Patch 3 implements it for
  kTLS. Patch 5 converts svcsock, and patch 6 removes the old
  sock_recvmsg path.

Recast so the subject is the design decision the reviewer must check,
with patches as pointers:

  The no-data cap comes first: control records reaching read_sock
  would otherwise hold the socket lock without bound (patch 1).
  svcsock is converted in two steps. The new path is added beside the
  old one so the two can be compared, and the old one goes in the
  patch after (patches 5-6).

The first tells the reviewer what the diffstat already tells them.
The second names each decision, points to its patch, and stops at one
clause of why -- the argument itself stays in the commit messages.
Note the sentence lengths in the recast: one causal link each, no
aside wedged into a clause that already carries one. An earlier draft
of this same passage read "The no-data cap is a prerequisite, not a
stand-alone fix -- without it, control records reaching read_sock
could pin the socket lock," and the posted cover built on it drew
"incomprehensible slop" from the maintainer.

## Example: a changelog entry

  Changes in v3:
  - Cap no-data records in tls_sw_read_sock() (per Jane's review).
  - Split the svcsock conversion so old and new paths coexist.
  - Link to v2: https://lore.kernel.org/r/20250601-tls-cap@kernel.org

  Changes in v2:
  - Add a read_sock_rectype proto_ops method for the record type.
  - Link to v1: https://lore.kernel.org/r/20250515-tls-cap@kernel.org

The cap bullet credits Jane because the change traces to her
review; the svcsock split carries no name because it was
self-driven -- crediting it would send a reviewer looking for a
fix she never asked for. Each bullet names a real delta and stays
on one line, and the newest revision leads, so v3 sits above v2.
