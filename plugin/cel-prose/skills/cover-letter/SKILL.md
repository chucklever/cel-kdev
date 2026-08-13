---
name: cover-letter
description: Use when composing, editing, or reworking the *content* of a document that introduces a set of changes to the people who will review them -- a Linux kernel patch series cover letter (the [PATCH 0/N] blurb), a GitHub pull request description, or a merge commit message taking a topic branch. Load this whenever you decide what such a document should say -- "write the cover", "rework the cover letter to match the series", "summarize the series for submission", "write the PR description" -- even when the request does not name one. Governs prose and content only; for where the cover file lives and how a kernel series is sent, use the series-send and cel-kdev:b4 skills, for a reroll's "Changes in vN" changelog the cel-prose:version-changelog skill, and for a single patch's commit message the cel-prose:commit-message skill. Not for a [GIT PULL] request to Linus, which is release notes for already-reviewed work.
---

# cover-letter

How to write the *content* of a document that introduces a set of
changes to the people who will review them, in Chuck's voice. The
Linux kernel patch series cover letter is the main case, and the
rules below are written against it. A GitHub pull request description
and a merge commit message do the same job and take the same rules;
"Other surfaces" at the end covers where they differ. Where the cover
file lives and how a kernel series is sent (b4/series-send) belong to
the series-send and cel-kdev:b4 skills; a reroll's changelog belongs
to the cel-prose:version-changelog skill, and a single patch's commit
message to the cel-prose:commit-message skill. Load those for the
workflow, this for the prose.

## What a cover letter is for

The cover directs reviewer attention. It carries what the diffs and
the commit messages do not advertise: design choices that span
several patches, subtle invariants, ordering constraints, and
contracts a later patch relies on. A reviewer reads the cover to
learn how to read the series.

So the test for every sentence is whether it earns its place against
that purpose. If a reviewer will find its content in the patch it
belongs to -- the subject line in the shortlog, the commit message,
the diff -- it is redundant here; cut it. The defect the series
answers is the exception. State it here even though the fixing patch
states it too. The cover is not a summary of the patches; it records
the cross-cutting design that no single patch carries.

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

Sort each candidate sentence by what it is *about*. Two kinds of
content belong in the cover and one does not. Ground all of it in the
series as it stands -- the diffstat and the diffs, never memory of
the plan.

**Keep: the code as it stands, and how it is broken.** This is the
bulk of a good cover and it is where the argument lives. "A control
record's octets are credited to the RPC stream, and a consumed
control record leaves the server transport unmarked" carries no
clause of why and needs none; the defect stated plainly is the case
for the series. Draw on the record gathered above -- the commit that
introduced the defect, the report that surfaced it, what the current
interface has already cost. The alternative a reviewer would
otherwise propose belongs here too, with the reason it was rejected;
one sentence, and only for the alternative they would actually raise.

**Keep: the design choices that span the patches, and the
relationships the shortlog cannot show.** The send tool puts the
shortlog and diffstat directly below the prose, so the reviewer
already has the list of patches. What the list cannot give them is
how the entries relate:

- An ordering constraint or dependency, especially one that accounts
  for patches that otherwise look unrelated. "The CB_RECALL send
  buffer budget has to be correct before a referring call list can
  ride in it" is the only thing that explains six budgeting patches
  sitting in front of the fix.
- A design choice scattered across several patches -- a cross-cutting
  behavioral change, a workaround being retired, an invariant
  enforced in three places. State it once, here.
- A contract a later patch relies on, and the user-visible behavior
  changes taken together rather than one patch at a time.
- What the series deliberately does not do, and what follows it. A
  reviewer who knows the destination reviews the first step
  differently, and a limitation you name is one they do not spend a
  pass discovering.

**Cut: what a patch in this series does.** The shortlog is right
there and the commit message is one click away. This is the content
that bloats a cover, and it is the last an author cuts, because each
sentence looks defensible on its own.

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

Self-test: for each sentence, ask what it is about, not what its
grammatical subject is. A paragraph that names no patch at all can
still be a compressed copy of one patch's commit message, and the
grammatical test waves it through. A cover whose paragraphs run in
patch order, one per patch, reads as a disguised roll-call however
its sentences are built. If a sentence is about what a patch does,
cut it; if it is about the defect or about how the patches relate,
keep it.

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

A reroll carries a changelog of what changed since the previous
posting, which the send tool appends below the cover's `---` at send
time. Its content rules -- and the single-patch case, where there is
no cover to carry it -- belong to the cel-prose:version-changelog
skill. Load that to write one.

## Other surfaces: PR descriptions and merge commits

A GitHub pull request description does the cover's job. Its readers
are going to read the diffs, and the description tells them how. Every
rule above holds: the roll-call prohibition, the 400-word cap, the
test that each sentence earn its place. Those rules are argued above
from the shortlog sitting directly below the cover's prose; on GitHub
the commit list is a tab away instead. That changes how far the
reviewer reaches for it and nothing about what to cut. Three things
differ.

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

The cover follows the voice rules in the cel-prose:prose-voice
skill; load it before drafting.

## Example: recasting a patch roll-call

A roll-call cover, each sentence owned by a patch:

  Patch 1 bounds no-data records in tls_sw_read_sock(). Patch 2 adds
  the read_sock_rectype proto_ops method. Patch 3 implements it for
  kTLS. Patch 5 converts svcsock, and patch 6 removes the old
  sock_recvmsg path.

Recast so the subject is the design decision the reviewer must check,
with patches as pointers:

  The no-data cap comes first: control records reaching read_sock
  would otherwise hold the socket lock without bound (patch 1). The
  svcsock conversion adds the new path beside the old so the two can
  be compared before the old one goes (patches 5-6).

The first tells the reviewer what the shortlog already tells them.
The second keeps only what the shortlog cannot show: that patch 1 is
a prerequisite rather than a fix in its own right, and why the
svcsock conversion is split across two patches. An earlier version of
this recast opened its second half with "svcsock is converted in two
steps" -- true, already in the shortlog, and therefore gone.

Note the sentence lengths as well: one causal link each, no aside
wedged into a clause that already carries one. An earlier draft of
the first sentence read "The no-data cap is a prerequisite, not a
stand-alone fix -- without it, control records reaching read_sock
could pin the socket lock," and the posted cover built on it drew
"incomprehensible slop" from the maintainer.

## Example: the roll-call in disguise

The roll-call that survives a subject-line check names no patch at
all:

  The kTLS read_sock path puts no bound on control records, so a
  stream of them can hold the socket lock indefinitely. Bounding them
  requires knowing the record type, which the existing proto_ops
  cannot report, so a new method returns it. kTLS implements that
  method from the record header it has already parsed.

No patch is the subject of any sentence, and each one reads as
design. But the paragraph is patches 1-3 in order, one sentence
apiece, each a commit message compressed. Apply the test: every
clause of it reaches the reviewer anyway, in a commit message they
have to read regardless. What does not reach them is that patch 1 has
to land first -- which is the clause the recast above spends on it,
and the rest of the paragraph is gone.
