# Submitting a patch to a sashiko instance

Loaded from the sashiko skill.  For retrieving and interpreting
a review once it exists, for the patchset JSON shape, and for
the status vocabulary this file refers to, see `SKILL.md`.

## Submitting a patch

`submit --type mbox` is the path for a local daemon and a
private remote instance alike, and the only one: it is the
sole input form that ships patch content.  The `remote` and
`range` forms ship a bare ref that the daemon resolves with
`git rev-parse` in *its own* clone -- true of a local daemon
too -- so a local sha either fails to resolve or resolves to
different code and comes back as a clean review of something
else.  A bare `submit` with no input and no pipe defaults to
`remote HEAD` and does exactly that.  The `thread` form is
different again: it takes a Message-Id and fetches that series
from lore, so it reviews what was posted rather than anything
in the local tree.  `--baseline` is read on the mbox path
only; the other three drop it without a word.

Auto-detection picks `thread` only for an input carrying an
`@` and no slash, and falls back to `remote` for anything else
that is not an existing file.  A lore URL has slashes, so it
lands on `remote` and the daemon tries to `git rev-parse` the
URL.  Pass `--type thread` with the bare Message-Id instead.

The daemon parses an mbox as email, so it needs the headers a
mailed patch carries, and the local export tools omit them.
A missing header fails silently: the submit exits 0 and hands
back an ID.  The access gate does not -- the CLI prints
`Submission failed (403 Forbidden):` and exits 1 -- and an
unresolvable `--baseline` surfaces later, as a `Failed To
Apply` patchset (see "Monitoring progress" in `SKILL.md`).
Read the exit status before polling: otherwise a 403 reads as
the parse drop below and sends you to re-mint headers that
were never the problem.

**Give `--baseline` a commit the daemon's own clone can
resolve, and settle that before exporting.**  A patch sitting
on unposted work has to be rebased onto a public ref first
(`stg rebase <public-ref>`).  Rebasing after the export
invalidates the mbox, so the export has to be redone.

**Add a `Message-Id` to a single patch.**  Neither `stg
email format` nor `git format-patch` writes one by default;
`git send-email` adds it at send time.  Sashiko's parser drops a
message without one, and the drop leaves no client-visible
trace, because the inject path creates no placeholder
patchset row.  The HTTP 200 `accepted` and the returned ID
mean only that the event reached the daemon's channel.  The daemon log
carries the sole signal, `Parse error for unknown: No
Message-ID header`.

`--thread` makes git write the header, and `stg email format`
forwards options to `git format-patch` with `-G`.  Prefer
this over inserting the header by hand:

```bash
stg email format -G --thread=shallow -o <dir> <patch>
POLLID=$(sed -n 's/^[Mm]essage-[Ii][Dd]: //p' <dir>/0001-*.patch | head -1)
[ -n "$POLLID" ] || { echo "no Message-Id in the export" >&2; exit 1; }
POLLID=${POLLID#<}; POLLID=${POLLID%>}   # the id to poll with, below
sashiko-cli --server <url> submit --type mbox \
    <dir>/0001-*.patch --baseline <public-commit>
```

Git spells the header `Message-ID` and b4 spells it
`Message-Id`.  Sashiko lowercases before matching, so both
ingest -- but a case-sensitive `grep` or `sed` written
against one silently finds nothing in the other's output.

**Thread every part of a series.**  Grouping keys on
`In-Reply-To` alone; `References` is parsed and stored but
never consulted.  `b4 prep --format-patch` writes a
`Message-Id` but neither threading header, and it offers no
way to ask for them: that path calls b4's exporter with
threading hardcoded off.  The `--thread` above is a
`git format-patch` option and does not reach it.  So a
concatenated mbox ingests cleanly and still fragments into
one `Incomplete` patchset per message.  The unthreaded
fallback cannot rescue it: it compares the substring before
the first `-` in the Message-Id and requires more than 10
characters.  That holds for `git send-email` ids
(`20231025202513.12358-2-...`) and not for b4's
date-prefixed ones
(`20260815-recall-any-keep-count-v5-1-<hash>@kernel.org`,
whose prefix is the 8-character `20260815`).  Point each
part at the cover:

```bash
b4 prep --format-patch <dir>
# Match either spelling.  This path writes Message-Id, but b4
# writes Message-ID on others, and a miss here is silent: the
# awk below adds no header and the mbox still looks well-formed.
COVER=$(sed -n 's/^[Mm]essage-[Ii][Dd]: //p' <dir>/0000-*.patch | head -1)
[ -n "$COVER" ] || { echo "no cover Message-Id under <dir>" >&2; exit 1; }
POLLID=${COVER#<}; POLLID=${POLLID%>}   # the id to poll with, below
# Match all four digits.  000[1-9] reads as "every part but the
# cover" and is not: it stops at 0009, so a series of ten or
# more loses parts 10 and up -- landing as the Incomplete
# patchset this recipe exists to avoid.
for f in <dir>/[0-9][0-9][0-9][0-9]-*.patch; do
    case "${f##*/}" in 0000-*) continue ;; esac
    awk -v c="$COVER" \
        '!d && /^[Mm]essage-[Ii][Dd]:/ {print; print "In-Reply-To: " c;
                                        print "References: " c; d=1; next}
         {print}' \
        "$f"
done | cat <dir>/0000-*.patch - > <dir>/series.mbox
# Two checks.  The message count catches a lost part.  It does
# not catch an unthreaded one -- an mbox the awk left untouched
# passes it -- so count the In-Reply-To headers too, one per
# part but the cover.
NPARTS=$(ls <dir>/[0-9][0-9][0-9][0-9]-*.patch | wc -l | tr -d ' ')
[ "$(grep -c '^From ' <dir>/series.mbox)" = "$NPARTS" ] \
  || { echo "series.mbox is missing parts" >&2; exit 1; }
[ "$(grep -c '^In-Reply-To: ' <dir>/series.mbox)" = "$((NPARTS - 1))" ] \
  || { echo "parts are not threaded to the cover" >&2; exit 1; }
sashiko-cli --server <url> submit --type mbox \
    <dir>/series.mbox --baseline <public-commit>
```

`b4 send -o <dir>` writes threaded messages and skips all of
this, but it patatt-signs first and dies on a gpg pinentry
timeout in a non-interactive shell.  Adding the two headers
by hand touches nothing b4 tracks; do not reach for
`--no-sign` without the user's say-so.

For a series that is not on a b4 prep branch, skip the loop
entirely -- `stg email format --cover-letter -G
--thread=shallow -o <dir> <first>..<last>` threads every part
against the cover in one command.  Two things remain.  Fill
in the `*** SUBJECT HERE ***` placeholder the generated cover
carries, and concatenate: `submit --type mbox` reads one
file, so submitting the parts one at a time recreates the
fragmentation this recipe avoids.

```bash
stg email format --cover-letter -G --thread=shallow \
    -o <dir> <first>..<last>
# edit <dir>/0000-*.patch to replace *** SUBJECT HERE ***
cat <dir>/[0-9][0-9][0-9][0-9]-*.patch > <dir>/series.mbox
POLLID=$(sed -n 's/^[Mm]essage-[Ii][Dd]: //p' <dir>/0000-*.patch | head -1)
[ -n "$POLLID" ] || { echo "no cover Message-Id under <dir>" >&2; exit 1; }
POLLID=${POLLID#<}; POLLID=${POLLID%>}   # the id to poll with, below
sashiko-cli --server <url> submit --type mbox \
    <dir>/series.mbox --baseline <public-commit>
```

**A remote instance rejects writes by default.**  `submit`,
`rerun`, and `cancel` require a loopback source address or a
daemon started with `--enable-unsafe-all-submit`.  The 403
carries no body, and read endpoints stay ungated, so an
instance that answers `/api/stats` still refuses a
submission.

The public `https://sashiko.dev` deployment is not a submit
target.  It runs without that flag, and the tunnel below
needs shell access on the host, so neither way through is
open.  It ingests from the lore lists it tracks; a review
there means posting the series to one of them.  Everything
here is for a private instance you or the user runs.

Tunnel rather than reconfigure.  It touches nothing on the
host, and it doubles as the diagnostic: both gates return a
bare 403, so a 403 that survives the tunnel is the separate
`read_only` check (daemon started with `--no-api`), which
fires first and leaves reads working.  Submit to
`http://127.0.0.1:18080`, which arrives from loopback, and
tear the tunnel down after:

```bash
ssh -f -N -o ExitOnForwardFailure=yes -M -S /tmp/sashiko-tun \
    -L 18080:127.0.0.1:8080 <host>
# ... submit ...
ssh -S /tmp/sashiko-tun -O exit <host>
```

`ExitOnForwardFailure=yes` turns a busy local port into a
non-zero exit; without it `-f` backgrounds a tunnel that
forwards nothing.  Restarting the daemon with
`--enable-unsafe-all-submit` is the other way through, but it
removes the only access control on queueing for every client.
That is the user's call: ask before proposing it, and only
for a trusted LAN.

**`sashiko-cli local` does not target a remote instance.**
Its server-vs-local decision probes `server.host:port` from
a `Settings.toml` in the *current directory*, falling back to
`~/.config/sashiko.toml` -- note the file, not a
`~/.config/sashiko/` directory -- and ignoring `--server`
throughout.  The submit it builds then passes a local
filesystem *path* the remote daemon cannot resolve.  Run
where neither file configures a server, it reviews locally
and says nothing about it.  Use `submit --type mbox`.

## Confirming a submit landed

The returned `sashiko-inject-<ts>-<rand>` ID is not a lookup
key; polling it 404s forever.  The ingest path rewrites the
group `api-submit` to `manual` and keys the record on the
mbox's own Message-Id, so poll `/api/patchset?id=<that
Message-Id>` instead -- stripped of its angle brackets.
Sashiko trims them on ingest and the lookup is an exact
match, so a raw captured id 404s until you strip them.  Each
recipe above leaves that stripped id in `$POLLID`.  A 404 for
a stripped id,
after a submit that exited 0, means the message was dropped
in parsing, not that the review is still queued.

`/api/stats` lags.  It reported `patchsets: 39` while a
direct `/api/patchset` lookup returned the record just
ingested.  Do not read the counter as an empty queue.

For a series, compare `received_parts` against `total_parts`.
Both are fields of the same `/api/patchset` response, so the
poll above already carries them.  Do not reach for
`sashiko-cli show`: its text output renders neither field.
Cover letters never count toward `received_parts`, so a
healthy 8-patch series reads 8 of 8, not 9.  Fewer means the
threading failure above.

Redoing a failed submit is safe: `b4 prep --format-patch`
mints a fresh Message-Id suffix on every run, so the
corrected series lands as a new patchset rather than
colliding with the first attempt.  The wreckage stays,
though.  Nothing sweeps `Incomplete` -- the status changes
only when the missing parts arrive -- and there is no delete
route and no CLI delete.  `sashiko-cli cancel <id>` flips the
row to `Cancelled` and is the whole cleanup story; it is
allowed from `Incomplete` without `--force`.  `<id>` is one
numeric patchset id -- there is no range form -- and it is
the `id` field of the `/api/patchset` response, not the
Message-Id you polled with.  A status that cannot be
cancelled comes back HTTP 200 `not_modified` with exit 0, so
a loop reports success while cancelling nothing.  Cancelling
writes to a shared instance and cannot be undone: confirm
with the user before any `cancel`, one id or many.
