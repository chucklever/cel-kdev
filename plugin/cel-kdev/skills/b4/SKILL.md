---
name: b4
description: >-
  b4 patch workflow for kernel development. Covers applying
  patches from lore with b4 am, and the b4 prep workflow for
  sending multi-revision patch series. Includes stg interaction
  rules to prevent stack corruption.
---

# b4 for kernel patch workflows

## CRITICAL: stg interaction hazards

**These b4 operations corrupt the stg stack. Never use them
when stg is active on the branch.**

| Prohibited | Why | Replacement |
| ---------- | --- | ----------- |
| `b4 am <msgid>` | Runs `git am`, which moves HEAD behind stg's back | `b4 am -o /tmp/series.mbx <msgid>` then `stg import -M /tmp/series.mbx` |
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

`<msgid>` can be a Message-Id, a lore URL, or a lore
search query.

`-l` (`--add-link`) is a `b4 am` flag that stamps a
`Link: https://patch.msgid.link/<msgid>` trailer into each
patch before the mbox is written, independent of `stg import`.
It composes with `-o`, so always pass `-l` on the stg-import
path above. The Link trailer turns a later "match this applied
commit back to its patchwork patch" step into a direct msgid
lookup instead of fuzzy subject matching. b4 has no config key
to enable it by default.

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
(e.g., `origin/main`). When stg is active, derive it from
`branch.<name>.stgit.parentbranch` (a bare local branch
name like `master`) and `branch.<name>.remote` (e.g.,
`origin`), combining them as `origin/master`. If the
fork-point is a tag or an explicit remote ref, pass it
directly.

### Workflow

| Step | Command |
| ---- | ------- |
| Edit cover letter | See [references/cover-strategies.md](references/cover-strategies.md) |
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
time no longer matches. b4 has no CLI command to update
`base-branch` on an already-enrolled branch (`-f` is a
`b4 prep --new` option, not an enrollment one; see Setup).
Update the tracking JSON directly:

The tracking value is a JSON object like:
```
{"base-branch":"origin/master","series-id":"...","prefixes":["PATCH"]}
```

```bash
# Read current tracking
git config branch.<name>.b4-tracking

# Write back with corrected "base-branch" value
git config branch.<name>.b4-tracking '<updated JSON>'
```

The `base-branch` field determines which
remote ref b4 uses to compute `base-commit` (the
merge-base). After updating, verify with
`b4 prep --show-info` that `base-commit` and
`series-range` look correct.

If the series has not yet been sent, `b4 prep --cleanup`
followed by re-enrollment is simpler. Use the `git config`
path when preserving an in-flight change-id and cover
letter matters.

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
creates no patch. Re-run with `stg import -M -3` for a
3-way merge that leaves resolvable conflict markers,
then follow the stg skill's "Conflicting `stg import`
creates no patch" pitfall: mark resolved
(`stg resolved <file>`), recreate the patch
(`stg new <name> --file ...`, recovering author and
message from the mbox), then `stg refresh`. A bare
`stg refresh` would fold the change into the current
top patch instead. To abandon the import outright,
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
  config options
- [references/cover-strategies.md](references/cover-strategies.md)
  -- cover letter strategies and changelog format
