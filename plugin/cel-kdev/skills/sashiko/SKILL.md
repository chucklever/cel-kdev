---
name: sashiko
description: >-
  Load when the user asks to find, read, or interpret reviews
  from the sashiko kernel-patch review bot, or when they
  reference sashiko.dev.  Also load when a lore search for
  bot reviewer output returns empty, or fetching sashiko.dev
  returns only the SPA app shell -- this skill
  covers those failure signatures and the correct retrieval
  path.  Load it also to submit a patch or series to a
  sashiko instance for review, or when a submit reports
  success but no patchset appears, a series shows up as
  several Incomplete patchsets instead of one, or the
  server answers 403.  Prefer
  over b4 and kreview when the review source is an LLM bot
  rather than a human reviewer.
---

# sashiko: retrieving bot reviews for kernel patch series

Sashiko is an agentic LLM-based kernel patch reviewer.  It
monitors lore mailing lists for new submissions, produces an
inline-style review per patch with the
`gemini-3.1-pro-preview` model by default, stores results in
a backend database, and optionally emails the review out.
Self-reported detection rate is 53.6% of known-buggy commits
at roughly 20% false positives, so treat output as a
hint-generator rather than a verdict.

## CRITICAL: Do not propagate sashiko claims unverified

Roughly one in five flagged issues is spurious.  For every
finding in `inline_review`, trace the primary claim into the
code, label it "confirmed real" or "false positive" with a
one-line evidence summary, and surface both categories to
the user.  Do not quote sashiko output into commit messages,
PR comments, or review replies without that verification
step.

### Verify cited rule IDs before calling them fabricated

Sashiko grounds some findings in named rules (e.g.
`SUNRPC-RDMA-004`, `SUNRPC-GSS-007`).  The SUNRPC rule
families are real and defined in
`~/src/review-prompts/kernel/subsystem/sunrpc.md` (a local
checkout of the `masoncl/review-prompts` guide set):
`SUNRPC-CORE-NNN`, `SUNRPC-RDMA-NNN`, `SUNRPC-GSS-NNN`, and
`SUNRPC-SOCK-NNN`.  The numbered-ID convention is not unique
to SUNRPC -- other guides carry their own (e.g. `RCU-001`,
`BPF-001`) -- so never judge a cited ID invented from memory.
Grep the guides first, whatever the subsystem.

Substitute the cited ID and search the guides.  `-i` covers
case; separators and zero-padding drift more often, since the
files store three-digit IDs (`SUNRPC-RDMA-004`).  Use `$HOME`,
not `~`: a tilde inside a quoted path does not expand, and the
empty result then reads like a missing rule.  If the directory
itself is absent, the checkout lives elsewhere or is missing;
say "I cannot locate the rule guides" rather than treating
every cited ID as ungrounded.

```bash
grep -rin "SUNRPC-RDMA-004" "$HOME/src/review-prompts/kernel/subsystem/"
```

Interpret the result:

- A full match: the rule exists; treat the citation as
  grounded (not the same as the finding being correct --
  still verify the claim against the code).
- No match: a literal miss is often formatting drift, not a
  missing rule.  Retry with separators and padding loosened
  (the `\b` keeps `-4` from matching `040` or `400`):

  ```bash
  grep -rinE "SUNRPC.?RDMA.?0*4\b" "$HOME/src/review-prompts/kernel/subsystem/"
  ```

  Still nothing?  The full-ID grep cannot tell a missing
  number from a missing family, so re-grep the family stem
  alone:

  ```bash
  grep -rinoE "SUNRPC-RDMA-[0-9]+" "$HOME/src/review-prompts/kernel/subsystem/" | sort -u
  ```

  - The stem lists other numbers but not the cited one:
    report "rule family <family> exists, but <id> is not
    defined," not "fabricated."
  - The stem matches nothing either: prefer "I cannot find
    this rule" over "fabricated."

A rule you do not recognize is not the same as a rule that
does not exist.

## CRITICAL: Do not run lore_search for sashiko output

By default `reply_all = false` in the bot's
`email_policy.toml`, so sashiko does not post reviews to
public mailing lists.  `lore_search` with
`from_patterns=["sashiko"]` or subject searches for the
bot's prose will return nothing for most subsystems -- do
not run one "to confirm" either.  Go directly to the
backend API.

## CRITICAL: Do not fetch the web UI URLs

`https://sashiko.dev/#/patchset/<msgid>?part=<n>` is a
client-side SPA route. Generic web fetch tools receive only
the app shell and report "no reviews found" even when
reviews exist. Use the JSON API below instead.

## Backend API (unauthenticated)

Base URL: `https://sashiko.dev`

| Endpoint                            | Purpose                                           |
| ----------------------------------- | ------------------------------------------------- |
| `/api/patchset?id=<msgid>`          | Full patchset JSON, **includes `reviews[]`**      |
| `/api/message?id=<msgid>`           | Single message lookup                             |
| `/api/review?id=<patch_numeric_id>` | Review run log (token counts, stage traces)       |
| `/api/lists`                        | Tracked mailing lists                             |
| `/api/stats`, `/api/stats/reviews`  | Aggregate metrics                                 |

The `msgid` is the patchset cover-letter Message-ID (patch 0
of a series), URL-encoded.  The `part=<n>` in web-UI URLs is
a `part_index` used by the SPA; the API does not take it as
a query parameter.

### Patchset JSON shape

```
{
  "message_id": "...",
  "model_name": "gemini-3.1-pro-preview",
  "patches": [
    { "id": <int>, "part_index": <1..N>,
      "status": "Reviewed"|"In Review"|null,
      "message_id": "...", "subject": "..." },
    ...
  ],
  "reviews": [
    { "patch_id": <matches patches[].id>,
      "status": "Reviewed"|"In Review",
      "result": "Review completed successfully." | null,
      "summary": <usually null -- prose is in inline_review>,
      "inline_review": "<git-style quoted-diff with interleaved reviewer text>",
      "model": "...", "tokens_in": ..., "tokens_out": ... },
    ...
  ],
  "id": <int: numeric patchset id -- what `cancel` takes>,
  "total_parts": <int>,
  "received_parts": <int: cover letters never count toward this>,
  "status": <patchset-level: "Incomplete"|"Pending"|"In Review"|
             "Reviewed"|"Failed"|"Failed To Apply"|"Cancelled"|
             "Skipped">,
  "failed_reason": <string when status is a failure state, else null>,
  "baseline_logs": <string: the baselines tried, when apply failed; else null>,
  "baseline": <baseline ref applied onto, or null>
}
```

### One-shot retrieval recipe

`curl -fG --data-urlencode` handles URL encoding so
Message-IDs containing `+`, `&`, `%`, or stray angle brackets
reach the server intact, and `-f` turns HTTP errors into a
non-zero exit instead of feeding an HTML error page into
`json.load`.  A 404 most often means the cover Message-ID is
wrong or the series has not yet been ingested -- wait and
retry, or re-check the msgid with `b4 prep --show-info`
(strip any surrounding `<...>` before passing it in).

```bash
MSGID='20260422-case-sensitivity-v9-0-be023cc070e2@oracle.com'
curl -fsSG --data-urlencode "id=$MSGID" \
  https://sashiko.dev/api/patchset | \
  python3 -c '
import json, sys, collections
d = json.load(sys.stdin)
parts = {p["id"]: p for p in d.get("patches", [])}
reviews = d.get("reviews", [])
pstatus = d.get("status")
if pstatus in ("Failed", "Failed To Apply"):
    print(f"ingested, {pstatus!r}, not clean")
    print("failed_reason:", d.get("failed_reason"))
    print("baseline_logs:", d.get("baseline_logs"))
    if not reviews:
        sys.exit(0)
    print(f"NOTE: {len(reviews)} partial review(s) present despite {pstatus!r}:")
    # fall through to print the partial reviews below
elif pstatus in ("Cancelled", "Skipped"):
    print(f"terminal: patchset status {pstatus!r}; no review will be produced")
    sys.exit(0)
elif not reviews:
    statuses = collections.Counter(p.get("status") for p in parts.values())
    print(f"patchset status {pstatus!r}; no reviews yet; "
          f"patch status counts: {dict(statuses)}")
    sys.exit(0)
for r in sorted(reviews, key=lambda r: parts.get(r["patch_id"], {}).get("part_index", 0)):
    p = parts.get(r["patch_id"], {})
    pi = p.get("part_index", "?")
    subj = p.get("subject", "(unknown patch)")
    st, res = r.get("status"), r.get("result")
    print(f"\n=== Part {pi}: {subj} ===")
    print(f"status={st}  result={res}")
    print(r.get("inline_review") or "(none)")
'
```

### Pitfall: keep the python heredoc single-quoted

The recipe relies on `python3 -c '...'` (single-quoted), so
double-quoted Python strings (`"patches"`, `"part_index"`)
inside the script reach the interpreter unmodified.  Do not
flip the quoting to `python3 -c "..."` with embedded `\"`:
when the command is issued through a wrapper that already
shell-quotes the outer string (agent shell tools, most
subprocess shells), the nested escapes collapse and Python
fails with `SyntaxError: unexpected character after line
continuation character`.  Curl then exits with error 23
("Failure writing output to destination") because its pipe
partner has gone away.  The symptom resembles a sashiko or
network failure; the root cause is the quoting change.

For scripts longer than a few lines, or any script that
needs to embed single-quoted Python literals, write the
JSON to a file and read it from a quoted heredoc:

```bash
curl -fsSG --data-urlencode "id=$MSGID" \
  https://sashiko.dev/api/patchset > /tmp/sashiko.json
python3 <<'PY'
import json
with open("/tmp/sashiko.json") as f:
    d = json.load(f)
# ... your code with any quoting style ...
PY
```

### Pitfall: an empty lore_search is not proof a patch is unposted

The CRITICAL block above ("Do not run lore_search for sashiko
output") concerns searching for the bot's **output**.  The
inverse -- searching lore for the **patch itself**, e.g. to
recover a cover Message-ID -- is fine; the trap is only in how
you read an empty result.  The local semcode lore archive
mirrors only the lists pulled into it; many subsystem lists
(linux-mm among them) are absent, and `lore_search` queries
only that local archive.  So when a patch-search comes back
empty, that reflects which lists the archive carries, not
whether the patch was ever posted.

Never turn an empty result into any claim about posting status
-- not "not posted," not "lore has no copy," not "local-only."
Phrase it as "not found in the local lore archive, which may
not mirror this subsystem's list," and leave a Message-ID hunt
at "could not locate a Message-ID" rather than escalating it
into a claim about whether the patch was posted.

There is no live fallback the agent can use: lore.kernel.org
blocks the web-fetch path, and pulling a list's public-inbox
git archive to chase one Message-ID is not worth it.  Treat an
empty local result as the end of the road for posting status --
stop there.  To recover a cover Message-ID, use the method
below.

### Finding the cover-letter Message-ID for the current series

When the user is working on a b4 prep branch:

```bash
b4 prep --show-info | grep -E '^(change-id|revision|series-v)'
```

The `series-v<N>:` line gives `<range> <msgid>`, where
`<msgid>` is the patch-0 cover Message-ID to pass as
`?id=<msgid>`.

When the series was imported into the working tree rather than
managed on a prep branch (e.g. `b4 am` piped into `stg import`),
`b4 am` and `stg import` commonly drop the `Link:` trailer, so an
absent commit trailer is not evidence the patch is local-only.
The cover Message-ID is in the `Message-Id:` header of the
b4-left `*.cover` file. Any per-part `*.mbx` id yields the cover
id by replacing the part-number field -- the `-<n>-` immediately
before the trailing hash token -- with `-0-` (e.g.
`...-v1-3-<hash>@...` -> `...-v1-0-<hash>@...`); an id already
ending `-0-<hash>@...` is itself the cover id.

## Local sashiko-cli

When the sashiko source is checked out locally (typically
at `~/src/sashiko/`) and the daemon is running, prefer the
`sashiko-cli` wrapper over hitting the JSON API directly.
Subcommands are stable, default output is human-readable,
and `--format json` returns the same shape as the Backend
API above.

Default server is `http://127.0.0.1:8080`.  Override with
`--server <url>` or `SASHIKO_SERVER=<url>`.  Build via
`cargo run --bin sashiko-cli -- <subcommand>` from the
sashiko source tree, or install per the upstream README.

| Command | Purpose |
| ------- | ------- |
| `sashiko-cli show <id>` | Print the review for a patchset (numeric id, or `latest`) |
| `sashiko-cli list [filter]` | List patchsets (`pending`, `failed`, list-name, etc.) |
| `sashiko-cli status` | Daemon status and aggregate counts |
| `sashiko-cli submit <input>` | Queue a commit, range, mbox file, or lore.kernel.org thread for review (for a patch of your own, `--type mbox` -- see "Submitting a patch") |
| `sashiko-cli local [<input>]` | Run a one-shot review without enqueuing on a daemon (defaults to `HEAD`) |
| `sashiko-cli rerun <id>` | Re-review a completed patchset |
| `sashiko-cli cancel <id>` | Cancel a pending review |

When a numeric patchset id appears in user input (e.g.,
"run `sashiko-cli show 10`"), it refers to the local
daemon's patchset id, not the public sashiko.dev id; the
two are independent.

Fall back to the Backend API for the public sashiko.dev
deployment, or when no local daemon is running.

### Submitting a patch

`submit --type mbox` is the path for a local daemon and a
private remote instance alike, and the only one: it is the
sole input form that ships patch content.  The daemon resolves
a ref in its own clone either way, so remoteness is not what
decides this.  The `remote`, `range`, and `thread` forms ship
a bare ref that the daemon resolves with `git rev-parse` in
*its own* clone, so a local sha either fails to resolve or
resolves to different code and comes back as a clean review
of something else.  A bare `submit` with no input and no pipe
defaults to `remote HEAD` and does exactly that.  `--baseline`
is read on the mbox path only; the other three drop it
without a word.

The daemon parses an mbox as email, so it needs the headers a
mailed patch carries, and the local export tools omit them.
A missing header fails silently: the submit exits 0 and hands
back an ID.  The access gate does not -- the CLI prints
`Submission failed (403 Forbidden):` and exits 1 -- and an
unresolvable `--baseline` surfaces later, as a `Failed To
Apply` patchset (see "Monitoring progress").  Read the exit
status before polling: otherwise a 403 reads as the parse
drop below and sends you to re-mint headers that were never
the problem.

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

### Confirming a submit landed

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

## Email delivery policy

Defaults in `email_policy.toml` (in the `sashiko-dev/sashiko`
repo) are silent; per-subsystem blocks keyed by mailing-list
address override.  An absent list-visible review is not a
missing review -- check the backend API before concluding
the series was not reviewed.

## Interpreting reviews

The `inline_review` field is markdown-ish prose with quoted
diff context interleaved with reviewer commentary.  Apply
the verify-and-label rule from the CRITICAL block above.

Replies do not reach the bot.  Sashiko is a one-shot
generator, not a conversation partner; replies to its email
go to the SMTP `sender_address` and are not ingested back
into its context.  Decisions and rationale belong in the
cover letter or commit message of the next revision, not in
an email thread with the bot.

## Attributing reviews in commit messages

When a patch exists to address something sashiko flagged,
credit the bot with a trailer pair following the syzbot
precedent:

```
Reported-by: sashiko-bot <sashiko-bot@kernel.org>
Closes: https://sashiko.dev/#/patchset/<cover-msgid>?part=<n>
```

Use `Suggested-by:` (same address) when the bot proposed an
improvement rather than reporting a defect.

The `Closes:` URL is the SPA route, fragile but the only
canonical reference when the review never reached a public
list.  Prefer a `lore.kernel.org/r/<bot-message-id>` URL
when sashiko's `email_policy.toml` routes reviews to the
destination list (i.e., `reply_all = true` for that block).

Avoid `Reviewed-by:` and `Co-developed-by:` for the bot;
these are routinely stripped by maintainers and overstate
the bot's role given the self-reported false-positive rate.

The sender address `sashiko-bot@kernel.org` is greppable
and worth using verbatim so downstream tooling can match
on it.

## Monitoring progress

Per-part `status` transitions: `null` -> `"In Review"` ->
`"Reviewed"`.  For a freshly sent series it is normal for
most parts to remain `"In Review"` for hours.  Poll
`/api/patchset?id=<msgid>` rather than the web UI.

A patchset-level `status` of `"Failed To Apply"` means sashiko
ingested the series but could not construct a baseline to apply
it onto: `reviews[]` is empty and no findings exist. This state
is distinct from not-ingested (404), pending (`Pending` or
`In Review`), and clean -- where "clean" means `status`
`"Reviewed"` with a populated `reviews[]` carrying zero flagged
issues. Read `failed_reason` for the cause and `baseline_logs`
for the baselines tried (often the `Fixes:` commit, then
`cel/HEAD`, `linux-next/HEAD`, `HEAD`); it is typical for a fix
that depends on an unmerged series whose base is not a public
ref. Report it as "ingested, failed to apply, no findings" --
never "clean." The sibling status `"Failed"` (the review errored
out) is likewise not "clean": report the status and its
`failed_reason`. Unlike `"Failed To Apply"`, a `"Failed"` run can
still carry partial `reviews[]` from parts that completed before
the error, so surface those findings rather than discarding them.
The terminal statuses `"Cancelled"` (review cancelled) and
`"Skipped"` (sashiko declined the series) likewise never become
clean: they produce no further findings, so report the status
rather than advising a re-poll.

## Privacy

The web UI is public: anyone with the cover-letter
Message-ID can read the reviews.  Confirm with the user
before sharing a sashiko.dev URL externally.
