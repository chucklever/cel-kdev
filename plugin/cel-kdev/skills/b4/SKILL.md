---
name: b4
description: >-
  Use when working with b4 for kernel patches: applying a
  series from lore (b4 am, optionally as stg patches via
  stg import), or preparing and sending your own series
  (b4 prep / b4 send) -- enrolling a branch, editing the
  cover letter and changelog, populating To/Cc from
  MAINTAINERS, and dry-running or sending. Covers single-
  and multi-patch series and the stg interaction rules that
  prevent patch stack corruption.
---

# b4 for kernel patch workflows

## CRITICAL: stg interaction hazards

**These b4 operations corrupt the stg stack. Never use them
when stg is active on the branch.**

| Prohibited | Why | Replacement |
| ---------- | --- | ----------- |
| `b4 am <msgid>` | Runs `git am`, which moves HEAD behind stg's back | `b4 am -l -o /tmp/series.mbx <msgid>` then `stg import -M /tmp/series.mbx`; a maintainer intake adds a step between the two (see "Applying patches from lore") |
| `b4 trailers -u` | Rebases commits to insert collected tags, breaking stg metadata | Avoid; run `stg repair` immediately after if unavoidable |

Check whether stg is active before choosing a command path.
See the stg skill for the two-step activation check.

## What b4 sees

b4 discovers the series as commits between the enrolled
fork-point and HEAD:

```
fork-point (e.g., origin/master)
  |
  + patch-a          <- applied stg patch, visible to b4
  + patch-b          <- applied stg patch, visible to b4
  > patch-c          <- HEAD, visible to b4
  - patch-d          <- unapplied, in refs/stacks/ only
  - patch-e          <- unapplied, NOT visible to b4
                        => stg push -a before b4 send
```

Unapplied patches exist only in stg metadata and are
invisible to b4. Apply all patches with `stg push -a`
before running `b4 send` or `b4 prep --format-patch`.

## Applying patches from lore

| Task | Command |
| ---- | ------- |
| Apply a series by message-id | `b4 am <msgid>` |
| Apply a series, write mbox only | `b4 am -o <dir> <msgid>` |
| Apply as stg patches | `b4 am -l -o /tmp/series.mbx <msgid>` then `stg import -M /tmp/series.mbx` |
| Cherry-pick specific patches (1-indexed, comma-separated, ranges ok) | `b4 am -P 1-2,4 <msgid>` |
| Show series diff between versions | `b4 diff <msgid>` |
| Retrieve thread as mbox | `b4 mbox <msgid>` |

The stg-import row is two steps, but a maintainer intake
interposes a third between them. Read "The maintainer intake
edit" below before importing.

`<msgid>` can be a Message-Id, a lore URL, or a lore
search query.

`-l` (`--add-link`) stamps a
`Link: https://patch.msgid.link/<msgid>` trailer into each
patch before the mbox is written; no config key enables it
by default, so always pass it on the stg-import path above.
The trailer turns a later "match this applied commit back to
its posting" step into a direct msgid lookup instead of
fuzzy subject matching, and it survives a correct intake
edit into the applied commit. It sits in the same
commit-message span that edit rewrites, though, so an
over-broad pattern takes it too.

Keep the mbox as a file rather than piping `b4 am` straight
into `stg import`. An import that conflicts has to be retried
as `stg import -M -3 /tmp/series.mbx` (see the
`stg import -M` conflicts pitfall below), and a pipeline has
already consumed the mbox by then. The intake edit below
needs a file to rewrite in place for the same reason.

### The maintainer intake edit

When the series is one you will carry in your own tree, a
third step goes between `b4 am` and `stg import`: an
in-place edit of the mbox that removes
`Cc: stable@vger.kernel.org` from the commit-message region
only, leaving the `Cc:` delivery header and the diff
untouched. The command that performs it is local to the
maintainer's setup: ask which command to run, do not
substitute an ad-hoc `sed` rewrite, and do not `stg import`
until the edit has been made and verified. Read
[references/intake.md](references/intake.md) for the
scoping, the copy-and-diff check, and what a wrong edit
looks like. A series you are applying only to read or test
needs no such edit; import the mbox as written.

## Sending patch series

### Series metadata files

Check `git config b4.prep-cover-strategy` first. When the
strategy is `file`, b4 stores per-series state under
`.git/b4-prep/<change-id>/`:

| File | Contents |
| ---- | -------- |
| `cover` | Cover letter (subject, blank line, body) |
| `changelog` | Per-revision changelog, newest first |
| `recipients` | Per-patch To/Cc from `--auto-to-cc` |

`b4 prep --show-info change-id` prints the bare change-id.
Edit these files directly; b4 reads them at send time.

Under the `branch-description` strategy there are no such
files: the cover and changelog live in
`branch.<name>.description` and the recipients live in
`.git/config`. See [references/cover-strategies.md](references/cover-strategies.md)
for that strategy and the changelog format.

### Single-patch series

Edit the `changelog` (and `cover`) file exactly as for a
multi-patch series -- b4 chooses placement automatically by
patch count. A one-patch series has no `0/1` cover: b4
detects the count and, via `mixin_cover`, appends the cover
body and changelog *below* the patch's `---` line (the
under-the-cut area `git am` strips) rather than emitting a
separate cover. `b4 send --force-cover-letter` overrides
this to send a standalone cover for the lone patch.

Put durable design rationale for a lone patch in the commit
message, not the cover body -- prose below `---` is
discarded by `git am`, so nothing in the cover body reaches
the applied commit.

### Setup

b4 prep and stg coexist on the same branch when b4 uses
the `branch-description` cover strategy. stg owns the
commits; b4 tracks metadata (cover letter, version,
recipients) in `.git/config` without inserting tracking
commits.

```bash
b4 prep --enroll <base>   # base = tag, branch, or commit;
                          # omit to use the branch's configured upstream
```

`--enroll` (`-e`) takes the base as its own optional value.
b4 records that base as the branch's `base-branch`; the
"fork-point" wording below and in `--show-info` names this
same value -- distinct from the `-f`/`--fork-point` flag
warned against next.

**Never** `b4 prep --enroll -f <base>`: `-f`/`--fork-point`
belongs to `b4 prep --new`, not the enroll path, and is
silently ignored here. It enrolls against the branch's
configured upstream instead of `<base>` (or fails outright
when the branch has no upstream).

Verify with `b4 prep --show-info` that the fork-point
and series-range are correct.

The fork-point is the upstream ref the series is based on
(e.g., `origin/main`). When stg is active, it is the stack
base's upstream ref: compose it per the stg skill's
references/stack-base.md rather than naively joining
`branch.<name>.remote` and `stgit.parentbranch` -- that
composition's failure modes are documented there. A tag or
an explicit remote ref passes directly.

### Describing the base branch

Whenever you name the base branch in prose -- a cover
letter, a reply on the list, a note to the maintainer --
take the description from the subsystem's maintainer entry
profile rather than characterizing the branch yourself. The
series' MAINTAINERS entry names the profile directly: its
`P:` line is the path, and `get_maintainer.pl` prints it
next to the `T:` lines that name the branch:

    ./scripts/get_maintainer.pl --sections -f <a file the series touches>

Grep `Documentation/` for the branch name only as a
fallback, and only with a repo-absolute pathspec -- a bare
`Documentation/` matches nothing from a subdirectory such as
`fs/nfsd/`:

    git grep -n '<branch name>' -- :/Documentation/

A hit outside a maintainer profile does not count:
`origin/master` appears in `Documentation/` only in a build
guide, and `net-next` matches a BPF Q&A document and a
translation as often as the netdev profile.

With a profile in hand, describe the branch only in its own
published terms -- quote or paraphrase them. Supply no
characterization of your own, in any part of speech: not
"volatile" or "unstable", not "churns" or "a staging area".
A characterization you supply reads as a judgment on the
maintainer's workflow. NFSD's profile,
Documentation/filesystems/nfs/nfsd-maintainer-entry-profile.rst,
calls nfsd-testing a topic branch that is rebased and
"always open to new submissions", and names it as the
branch to rebase on "just before each submission". Profiles
differ in what they say -- netdev's gives when `net-next`
closes and reopens and nothing about its stability; tip's
names branches with no character language at all -- so
reuse whatever the profile says rather than hunting for
these particular words.

With no `P:` line, or a profile that says nothing about the
branch's character, name the branch and stop. b4 stamps the
`base-commit:` trailer either way, so anyone applying the
series never depends on the sentence.

### Workflow

| Step | Command |
| ---- | ------- |
| Edit cover letter | See [references/cover-strategies.md](references/cover-strategies.md); to name the base branch in the prose, "Describing the base branch" above |
| Populate To/Cc from MAINTAINERS | `b4 prep --auto-to-cc` |
| Show series state | `b4 prep --show-info` |
| Export patches to directory | `b4 prep --format-patch <dir>` |
| Run pre-flight checks | `b4 prep --check` |
| Compare to prior version | `b4 prep --compare-to vN` |
| Set series prefix (e.g., RFC) | `b4 prep --set-prefixes RFC` |
| Bump version after external send | `b4 prep --manual-reroll <msgid>` |
| Clean up after series accepted | `b4 prep --cleanup` |
| Dry-run send | `b4 send -d` |
| Send to yourself only | `b4 send --reflect` |
| Send to specific address | `b4 send --preview-to <addr>` |
| Send for real | `b4 send` |

After `b4 send` completes, b4 auto-increments the version
(v1 to v2) and adds changelog placeholders to the cover
letter.

## Avoiding interactive editors

`b4 prep --edit-cover` launches `$EDITOR`, which is
unavailable in non-interactive agent shells.

- **`file` strategy**: edit `.git/b4-prep/<change-id>/cover`
  directly. No editor trick needed.
- **`branch-description` strategy**: write content to a temp
  file and override EDITOR:
  ```
  EDITOR="cp /tmp/cover.txt" b4 prep --edit-cover
  ```
  See [references/cover-strategies.md](references/cover-strategies.md)
  for the full procedure and cover letter format.

## Pitfalls

**Fork-point goes stale after rebase**: After `stg rebase`
onto a new base, the fork-point b4 recorded at enrollment
time no longer matches, and b4 has no CLI command to update
`base-branch` on an already-enrolled branch (`-f` is a
`b4 prep --new` option, not an enrollment one; see Setup).
If the series has not yet been sent, `b4 prep --cleanup`
followed by re-enrollment is simplest. To preserve an
in-flight change-id and cover letter, rewrite the
`base-branch` field in the `branch.<name>.b4-tracking` JSON
instead -- see "The b4-tracking JSON" in
[references/config.md](references/config.md) -- then verify
with `b4 prep --show-info` that `base-commit` and
`series-range` look correct.

**GPG/patatt signing requires pinentry**: Signing is
interactive and unavailable in non-interactive agent shells. Default
posture is to keep the patch signed: ask the user to
pre-cache the GPG passphrase in a separate terminal before
sending. Use `--no-sign` (or set `b4.send-no-patatt-sign`
to `true`) only after the user has explicitly authorized
sending the series unsigned -- bypassing signing without
that authorization violates the harness signing policy.

**`b4 send` requires enrollment**: `b4 send` cannot send
arbitrary patch files. The branch must be enrolled with
`b4 prep --enroll` first.

**`stg import -M` conflicts**: A plain `stg import -M`
that does not apply aborts with a clean worktree and
creates no patch. Re-run with `stg import -M -3` for
resolvable conflict markers, then follow the stg skill's
"Conflicting `stg import` creates no patch" pitfall for
the recovery -- a bare `stg refresh` after resolving
folds the change into the current top patch instead of a
patch of its own. To abandon the import outright,
`stg undo`.

## Troubleshooting

- If `b4 prep -e` fails with a cover-strategy conflict,
  check `git config b4.prep-cover-strategy`. It must be
  `branch-description` or `file`. Remove any existing
  prep tracking and re-enroll.
- If `b4 am` cannot find the series, try passing the full
  lore URL rather than a bare message-id. Incomplete
  series on lore (missing parts) will also cause failures;
  use `b4 mbox` to inspect what is available.
- If `b4 send` fails with SMTP errors, check
  `~/.gitconfig` for `sendemail.*` and `b4.smtp-*`
  settings. Use `b4 send -d` to verify the series is
  well-formed before diagnosing SMTP issues.

## References

- [references/config.md](references/config.md) -- b4 git
  config options and the b4-tracking JSON
- [references/intake.md](references/intake.md) -- the
  maintainer intake edit's scoping and verification
- [references/cover-strategies.md](references/cover-strategies.md)
  -- cover letter strategies and changelog format
