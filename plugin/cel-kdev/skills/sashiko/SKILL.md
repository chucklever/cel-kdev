---
name: sashiko
description: >-
  Load when the user asks to find, read, or interpret reviews
  from the sashiko kernel-patch review bot, or when they
  reference sashiko.dev.  Also load when a lore search for
  bot reviewer output returns empty, or a WebFetch against
  sashiko.dev returns only the SPA app shell -- this skill
  covers those failure signatures and the correct retrieval
  path.  Prefer over b4 and kreview when the review source
  is an LLM bot rather than a human reviewer.
invocation_policy: automatic
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

## CRITICAL: Do not run lore_search for sashiko output

By default `reply_all = false` in the bot's
`email_policy.toml`, so sashiko does not post reviews to
public mailing lists.  `lore_search` with
`from_patterns=["sashiko"]` or subject searches for the
bot's prose will return nothing for most subsystems -- do
not run one "to confirm" either.  Go directly to the
backend API.

## CRITICAL: Do not WebFetch the web UI URLs

`https://sashiko.dev/#/patchset/<msgid>?part=<n>` is a
client-side SPA route.  `WebFetch` receives only the app
shell and reports "no reviews found" even when reviews
exist.  Use the JSON API below instead.

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
  ]
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
if not reviews:
    statuses = collections.Counter(p.get("status") for p in parts.values())
    print(f"no reviews yet; patch status counts: {dict(statuses)}")
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

### Finding the cover-letter Message-ID for the current series

When the user is working on a b4 prep branch:

```bash
b4 prep --show-info | grep -E '^(change-id|revision|series-v)'
```

The `series-v<N>:` line gives `<range> <msgid>`, where
`<msgid>` is the patch-0 cover Message-ID to pass as
`?id=<msgid>`.

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

## Monitoring progress

Per-part `status` transitions: `null` -> `"In Review"` ->
`"Reviewed"`.  For a freshly sent series it is normal for
most parts to remain `"In Review"` for hours.  Poll
`/api/patchset?id=<msgid>` rather than the web UI.

## Privacy

The web UI is public: anyone with the cover-letter
Message-ID can read the reviews.  Confirm with the user
before sharing a sashiko.dev URL externally.
