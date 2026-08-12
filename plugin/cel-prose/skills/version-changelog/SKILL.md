---
name: version-changelog
description: Use when writing or reworking the per-version changelog of a rerolled patch series -- the "Changes in vN:" block, with its "Link to v(N-1):" line, that b4 places below a "---" divider at send time. Load it whenever a v2-or-later posting needs its list of what changed since the previous one -- "write the changelog", "what changed since v2", "update the changelog for the reroll" -- whether that block rides in the series cover letter or below the "---" of a lone patch. Covers what earns a bullet, what a changelog leaves out, reviewer credit, and bullet form. Not for the commit message body, which the kernel docs also call a changelog; that is cel-prose:commit-message. For the cover letter's own prose use cel-prose:cover-letter, and for where the changelog file lives and how the series is sent, series-send and cel-kdev:b4.
---

# version-changelog

A reroll carries a changelog: what changed since the previous posting,
newest revision first, as terse bullets. b4 emits it under a `Changes
in vN:` heading, with a `Link to v(N-1):` bullet beneath.

Patch count decides which message carries the block -- the cover
letter for a multi-patch series, the lone patch when there is only
one -- but it lands below a `---` divider either way, so it stays
reviewer-facing and never enters git history. Which message is a
series-send/b4 concern rather than this skill's, and the content
rules below hold for both.

The kernel documentation calls this the "patch changelog"
(`submitting-patches.rst`), and uses "changelog" alone for the commit
message body that git keeps. This skill governs the first; the second
belongs to cel-prose:commit-message.

## Bullet form

Each bullet is a single line of at most 72 columns. When a bullet runs
long, tighten the wording or split it into two bullets -- do not let it
wrap onto a second line. A line may exceed 72 columns only for an
unbreakable token it must carry, such as a URL or a pathname (the "Link
to" line is the usual case).

Every block ends with a `Link to v(N-1):` bullet pointing at the
prior posting, so a reviewer can pull it up and diff against it.

Revisions accumulate, newest first: a v3 posting carries the v3 block
above the v2 block, both intact. A reviewer who last read v1 needs the
rounds in between.

## What earns a bullet

Every delta a reviewer would notice reading the new posting against
the old one: a changed patch, an added or dropped patch, a
reordering, a renamed identifier in the diff. A reroll that only
rebases still earns its bullet: write "Rebase on v6.12-rc1, no
functional change" rather than nothing, because a reviewer who sees
a new version and no explanation goes looking for the change that is
not there.

Ground every bullet in an actual diff of the prior version against
the current series, not in memory of what you meant to change. What
you remember changing and what the diff shows diverge in exactly the
cases a changelog exists to catch: a fix that got rebased away, a
rename that landed in only half the patches. Recover the real delta
with `b4 diff <msgid of v(N-1)>`, or `git range-diff` when both
versions are local branches (see cel-kdev:b4), and list what it
shows.

## Reviewer credit

Credit a reviewer only when the change actually traces to their
feedback. A self-driven change dressed as a reviewer's request
misleads, and it sends that reviewer looking for their fix in a diff
that does not contain it.

## What it leaves out

A changelog lists deltas to the series, not the discussion that
produced them. A reviewer suggestion you declined, an approach you
tried and rejected, a thread that ended in no code change: none of
these earns a bullet. Neither does a concern addressed elsewhere -- in
a separate series, or in a prerequisite that has since landed -- since
a bullet there implies this series answered it.

That reasoning still belongs somewhere. Put it in the commit message of
the patch the discussion was about, or in a reply on the thread.
`submitting-patches.rst` asks for exactly that when it says review
comments leading to no code change "should almost certainly bring about
a comment or changelog entry," using "changelog" in its commit-message
sense. If a declined suggestion changed how the series argues for
itself, what changes is the argument, not a line recording the
declining.

## A single-patch reroll

A lone patch has no cover letter. b4 folds this same changelog into the
patch's commentary below the `---` divider, which git strips at apply
time, so it stays reviewer-facing only. The rules above are unchanged,
and the "Link to v(N-1):" matters more here, since no cover carries the
context. Design rationale for the patch belongs in its commit message
(see cel-prose:commit-message), not in that commentary.

## Voice

The bullets follow the voice rules in the cel-prose:prose-voice skill;
load it before drafting.

## Example

  Changes in v3:
  - Cap no-data records in tls_sw_read_sock() (per Jane's review).
  - Split the svcsock conversion so old and new paths coexist.
  - Link to v2: https://lore.kernel.org/r/20250601-tls-cap@kernel.org

  Changes in v2:
  - Add a read_sock_rectype proto_ops method for the record type.
  - Link to v1: https://lore.kernel.org/r/20250515-tls-cap@kernel.org

The cap bullet credits Jane because the change traces to her review;
the svcsock split carries no name because it was self-driven --
crediting it would send a reviewer looking for a fix she never asked
for. Jane also asked for a retry loop the series does not add; that
answer went to her on the thread and into the patch's commit message,
and no bullet records it. Each bullet names a real delta and stays on
one line, and the newest revision leads, so v3 sits above v2.
