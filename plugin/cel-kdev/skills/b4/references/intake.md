# The maintainer intake edit

Entered from "Applying patches from lore" in SKILL.md: a
series you will carry in your own tree takes an in-place
mbox edit between `b4 am` and `stg import`.

The edit removes `Cc: stable@vger.kernel.org` from the
commit-message region only -- the span between the RFC822
headers and the `---` diff separator -- leaving the mbox
`Cc:` delivery header and the diff untouched. The
maintainer's backport judgment replaces the submitter's
after review and list discussion. Restoring the trailer is a
later, per-patch decision and is not part of this intake;
the `kernel-stable` skill covers that decision.

The command that performs the edit is local to the
maintainer's setup and is not part of this plugin, so it is
not named here. Do not substitute an ad-hoc `sed` rewrite:
an over-broad pattern also takes the delivery header or a
`Cc:` the submitter meant to keep, and the resulting import
looks clean. Ask which command to run, and do not
`stg import` until the edit has been made.

Copy the mbox before the edit and `diff` the two afterward.
An over-broad pattern leaves an mbox that still imports
cleanly, so no later step catches it; the diff is the check.
Every removed line should be a `Cc: stable@vger.kernel.org`
from a commit-message region. A removed delivery header, a
dropped `Link:` trailer, or any change inside a diff hunk
means the edit was wrong: discard the mbox and re-run
`b4 am`.
