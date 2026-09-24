# Cover letters: the author's own samples

Verbatim cover bodies from Chuck Lever's 2024 linux-nfs postings,
stopping where the changelog, shortlog, and diffstat begin. Each
carries its posting Message-ID. The `From:` export line, the
signature, and any "Changes since" block are dropped; the changelog
belongs to cel-prose:version-changelog and is not part of the
cover's prose. Word counts are of the body alone, without the
subject line.

These are the postings as sent, not edited to the skill. Where a
sample's wording departs from cel-prose:prose-voice or from
SKILL.md, the rule governs the draft; the sample is evidence for
length, what a cover says, and what it leaves out, not for the
phrasing that carries it. Each annotation names the departure, so
an unmarked construction is one to copy.

These are kernel postings. What transfers to a pull request
description or any other cover is the length, the design fact the
patch list cannot show, and what the cover leaves out. What does
not: the RFC references and the lore and git.kernel.org
conventions, which follow SKILL.md's "Other surfaces" section
elsewhere.

Calibration first, and calibrate on the number, not on the set.
Across 44 covers posted that year, the median body is about 50
words and the longest prose body is about 140. The 400 word ceiling
in the skill is a ceiling, not a target. The samples skew long: a
30-word cover shows nothing to annotate, so four of the five here
sit above the median. Sample 1 is the common case; samples 3 to 5
are the upper end, not the center. Each cover states what the
series does and the design fact the shortlog cannot show, then
stops. None restates the patch list.

One cover was left out of the set on purpose: a 241-word v2 cover
whose bulk is a pasted fstests log. The log was the evidence for a
specific question a reviewer had raised, so it belonged in that
thread, but the form is not one to imitate in a fresh cover.

## 1. Thin cover for a series with no design story

2024-05-31, `<20240531131550.64044-4-cel@kernel.org>`, 31 words.

```
Fix ADDR_CHANGE event handling for NFSD

Sagi recently pointed out that the CM ADDR_CHANGE event handler in
svcrdma has a bug similar to one he fixed in the NVMe target. This
series attempts to address that issue.
```

Two patches, one bug, one precedent. The cover names the reporter,
the defect's location, and the sibling fix that motivated it. There
is no architecture to explain, so none is manufactured. "Attempts
to address" is the hedge prose-voice drops; "fixes that bug" is the
sentence.

## 2. The design choice that spans the patches

2024-02-04, `<170708844422.28128.2979813721958631192.stgit@bazille.1015granger.net>`,
62 words.

```
NFSD RDMA transport improvements

These were left over from the last series (for 6.8).

The idea here is to post all work needed for sending one Reply with
just a single ib_post_send() -- the Send WR and all Write WRs are
chained together.

The purpose of that is to reduce the number of doorbells and
completions per RPC, which will hopefully improve transport
scalability per NIC.
```

Twelve patches, and the cover spends one sentence on the mechanism
they build together and one on the cost it removes. That is the
whole design story, and it is the thing a reader of the shortlog
could not have reconstructed from twelve subjects. The scalability
sentence is the unmeasured case stated as a hope. The number is
not owed, but the hedge is not the way to say so; write what is
unknown instead: "The effect on per-NIC scalability has not been
measured."

## 3. What the series does, what it does not, and where the rest is

2024-10-31, `<20241031134000.53396-10-cel@kernel.org>`, 81 words.

```
async COPY fixes for NFSD

Extend the life of async COPY state IDs so that clients get
actionable OFFLOAD_STATUS results after COPY operations complete.
This lifetime extension comports with RFC 7862, although does not
bring NFSD fully into compliance.

There are a number of other small fixes to improve observability,
behavior during temporary resource shortages, and behavior during
client shutdown.

Async COPY remains disabled in NFSD until the Linux client has grown
support for OFFLOAD_STATUS. Patches for that are available in the
"fix-async-copy" branch of:

  https://git.kernel.org/pub/scm/linux/kernel/git/cel/linux.git
```

Paragraph one is the cross-cutting change and its relation to the
specification, including the gap that remains. Its imperative
opener predates the tense rule; the cover is never applied to a
tree, so SKILL.md's form is "This series extends the life of ...".
Paragraph two groups the rest of the series by effect, not by
patch. Paragraph three names what the series deliberately does not
do, which SKILL.md asks for; its second sentence points at a git
branch that is not on lore, and SKILL.md cuts that reference
however it is worded. The first sentence of that paragraph is the
form to copy; the branch pointer is not. The eight patches are
never enumerated.

## 4. Status, residual gap, and a reviewer's alternative answered

2024-12-26, `<20241226162853.8940-1-cel@kernel.org>`, 111 words.

```
Fix XDR encoding near page boundaries

Refresh the patch series to address the longstanding bug pointed out
by J David and Rick Macklem.

I believe we have identified and addressed this issue in all of
the NFSv4 COMPOUND operation encoders on the server side. Only the
GSS integrity and privacy encoders are still vulnerable but "safe
for now". Barring further review comments, this series is code-
complete.

Neil suggests xdr_reserve_space() should not ever be open-coded in
NFSv4 code. That seems difficult to enforce: nfsd4_encode_operation()
is certainly an XDR encode function; it lives in fs/nfsd/nfs4xdr.c,
for instance. So xdr_reserve_space() seems like a reasonable thing
to see in that function. I'm not sure exactly where to draw that
line.
```

A v3 cover. Its "Refresh the patch series" opener is the same
imperative as sample 3, and takes the same correction. It says how
far the fix now reaches and names the two
encoders it leaves alone, so a reviewer does not have to find that
gap themselves. The third paragraph is the alternative a reviewer
actually raised, with the reason it was not taken and the
uncertainty stated rather than papered over. It runs five
sentences where SKILL.md budgets one; the sentence to keep is
"nfsd4_encode_operation() is an XDR encode function, so
xdr_reserve_space() belongs in it", and the rest is the reply that
belongs in the thread. The bug
itself is not re-explained: the first patch's message carries that.

## 5. One dependency named, one design choice explained

2024-09-29, `<20240930005016.13374-1-cel@kernel.org>`, 141 words.

```
Continued work on xdrgen

This series (intended for v6.13) contains some clean-ups and new
features for the xdrgen tool.

The "Exit status should be zero ..." patch is needed so that "make"
co-operates properly with xdrgen. I've prototyped some Makefile
stanzas that can generate encoder and decoder functions to ensure
this is working correctly (to appear in a later series).

"enum" types are now generated as C typedefs, without the "enum"
classifier. This is to enable the same type name to be used to
represent either an enum (CPU-endian) or a __be32 (network-endian).

So, instead of generating, say, "enum nfsstat3 {};" xdrgen now
generates "nfsstat3" which can be either an enum or a __be32,
depending on a new pragma directive. The goal is to handle the
special case where the upper layer prefers to use __be32
discriminant values for XDR union types.

Comments are welcome.
```

Six patches. One is named, because a reader would otherwise wonder
why an exit-status fix sits in a feature series, and the sentence
gives the dependency that explains it. The remaining prose is a
single design choice, the enum typedef, with the case it exists to
serve. The other four patches go unmentioned. This is the boundary
between naming a patch to explain a relationship, which the skill
allows, and the roll-call, which it forbids.
