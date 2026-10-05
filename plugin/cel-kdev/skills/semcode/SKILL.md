---
name: semcode
description: >-
  Use whenever you are about to query semcode -- any mcp__semcode__* tool,
  the `semcode` CLI, or `semcode-index` -- to look up functions, types,
  callers, call chains, or commits, or to search the local lore mailing-list
  archive. Load it too on a "failed to connect" notice for the semcode MCP
  server: that can be deliberate, and the CLI covers every lookup. Load it
  BEFORE the first call, not after one goes wrong, and even when a sibling
  skill (sashiko, b4, kreview) is the reason you are querying. It fires on
  the intent, however worded, and just as much when the lookup is your own
  idea: who calls a function, whether anyone replied to a thread, whether
  a patch, Message-ID, or commit exists upstream, or whenever `lore` is
  about to appear in a shell command. There is no `lore` executable; load
  this for the real spelling.
---

# semcode

semcode is a local semantic index over source trees and lore.kernel.org
archives. Its MCP tool descriptions (or, with no MCP, `semcode -q "help"`)
document parameters well but say nothing about how the index goes stale, what the archive actually contains, or which
query shapes are dangerous. Those are what generate false starts, and they are
what this skill covers.

## Before the first query

Six gates. Gates 1, 3, 4, and 5 run before you send the query; gates 2 and 6
run before you use what came back. Each names the section that explains it;
run them, do not just read them.

1. **Code lookup, and HEAD may have moved since the index last saw it?**
   Through the MCP that is since `semcode-mcp` started. Through the CLI it
   is since the last `semcode-index --git` run that reached HEAD, which
   before a session's first CLI lookup you cannot know, so treat HEAD as
   moved. Any commit or rebase moves HEAD, and on an stg branch so does
   every `refresh`, `goto`, `push`, or `pop`. Reindex first:
   `semcode-index --git <base>..HEAD` from the tree whose code you are
   asking about (command and caveats under *Refresh source*). It is cheap
   and idempotent, and a `--commits` run does not count. -- *Index
   freshness*
2. **About to trust a returned body?** A semcode hit shows the symbol was
   indexed at some point, not that it is in your tree. Grep the reported
   `path:start` in the worktree: a start line that does not match means a
   stale record. For "is this in the committed tree", look in the body for
   a symbol the patch under review introduced, or rerun with `--git-only`.
   -- *Index freshness*
3. **Searching lore?** Run `ls $SEMCODE_DB/lore/` and read what it prints.
   That output is the only source for the archive roster; quote it, not a
   list remembered from elsewhere. A list it did not print cannot be
   answered from semcode: go to the marc.info fallback, not to another
   query. -- *Lore: coverage*
4. **First lore search of the session?** Refresh the mirror before sending
   the query. Two forms, one each: at session start, bare
   `semcode-index --lore`, which fetches every archive `ls` printed and
   cannot clone a new one; it is slower than a named list, not unsafe. For
   a later "no replies" check on one thread, `semcode-index --lore <list>`
   for that thread's list, only if `ls` printed it; on any other list it
   clones the entire archive. The mirror lags a day or two, and a search
   that runs before the refresh can miss a reroll or reply posted since
   the last one. If you cannot tell whether this session refreshed,
   refresh; it is idempotent. Run it with a Bash `timeout` of 600000 ms:
   an already-current mirror finishes in about two minutes, a lagging one
   takes longer. If the refresh fails, search anyway and say "mirror not
   refreshed" in the scope line. A "no replies" claim made later refreshes
   again (step 1 of the sequence).
   -- *Lore: coverage first, then freshness*
5. **Expanding a thread?** By message-id. From a search, only with a small
   `limit`: the cost is a fixed per-message amount summed across every
   matched thread, and nothing shows you that number before you commit.
   -- *Searching is cheap*
6. **Asserting absence or completeness, or did a lore or commit search feed
   the conclusion?** Emit the scope line in the template's shape. A verified
   positive `find_function` hit does not need it. When the absence is "no
   replies" or "no review" on a thread -- including a thread that returned
   only the author's own messages -- run the refresh-and-cross-check sequence
   on a mirrored list before making the claim, not after; on an unmirrored
   list, answer from marc.info and the lore t.mbox.gz. -- *Say what you
   searched*,
   *Lore: coverage first, then freshness*

## The two front ends

Both hit the same database, located by `$SEMCODE_DB`; on this setup the login
shell exports it, so the Bash tool and the MCP server both inherit it. Check
`echo $SEMCODE_DB` once. If it is empty, ask where the database lives rather
than passing `-d` guesses or searching the worktree: there is never a copy in
the kernel tree.

The MCP server may be absent on purpose. It keeps its query working set
resident for the whole session, so a memory-constrained host disables the
semcode plugin. A "failed to connect" notice for the semcode MCP server, or
a session with no `mcp__semcode__*` tools, is therefore a configuration, not
a fault to repair: do not re-enable the semcode plugin, edit the MCP
configuration, or debug the server registration unless the user asks. Use
the CLI for every lookup; each MCP lookup has a CLI spelling (tables below).

Binaries are on `$PATH` (typically `~/.cargo/bin`: `semcode`, `semcode-index`,
`semcode-mcp`, `semcode-lsp`); `command -v` finds them, never a build tree
such as `target/release`.

There is no `lore` executable. `lore` is a subcommand of the CLI's query
language: `semcode -q "lore ..."`. `semcode -q "lore --help"` fails with
"Unknown option"; bare `semcode -q "lore"` prints usage, as does
`semcode -q "help lore"`.

Pick by job:

- **MCP for code lookups when the server is present; otherwise the CLI.**
  The MCP is structured, small, cheap. Without it nothing is lost: every
  code lookup has a CLI spelling (second table below;
  `semcode -q "help"` prints the full list). Use those. Read a single
  exact-name `func` or `type` directly. Send every other code query to a
  file in the session scratchpad, never the worktree; `wc -l` it, then
  read the ranges you need. The CLI takes HEAD from the current
  directory's repository, so run it from the indexed tree or pass
  `semcode --git-repo <tree> -q "..."`; from any other directory a lookup
  reports the symbol absent (the strings are under *Reading results
  without over-concluding*).
- **CLI for lore bodies and threads.** Redirect to a file and read the ranges
  you need; the MCP has an output cap you will hit on any thread of substance.
  Strip colour when saving: `sed 's/\x1b\[[0-9;]*m//g'`.

The lore rules below are phrased in MCP parameter names. The CLI spells them
thus:

| MCP `lore_search` | CLI `semcode -q "lore ..."` |
|---|---|
| `from_patterns` / `subject_patterns` / `body_patterns` / `recipients_patterns` / `symbols_patterns` | `-f` / `-s` / `-b` / `-t` / `-g` (each repeatable) |
| `message_id` | `-m <msgid>` |
| `show_thread` / `verbose` | `--thread` / `-v` |
| `limit` / `since_date` / `until_date` | `--limit N` / `--since D` / `--until D` |

The code rules are phrased in MCP tool names too. The CLI spells them thus:

| MCP tool | CLI `semcode -q "..."` |
|---|---|
| `find_function` / `find_type` | `func <name>` / `type <name>` |
| `find_callers` / `find_calls` / `find_callchain` | `callers <name>` / `calls <name>` / `callchain <name>` |
| `find_implementors` / `find_registrations` | `implementors <type>.<member>` / `registrations <name>` |
| `grep_functions` / `vgrep_functions` | `grep [-v] <pattern>` / `vgrep <text>` |
| `find_commit` (`git_ref`, `git_range`, `symbol_patterns`) | `commit [ref]`, `--git <range>`, `-s <symbol>` |
| `vcommit_similar_commits` / `dig` / `list_branches` | `vcommit <text>` / `dig <commit>` / `branches` |

## Index freshness: the failure that looks like success

This is the pitfall that matters most, because nothing in the output announces
it.

Function and type records are keyed on the file's git blob. A lookup at a
commit whose blobs were never indexed does not fail -- it returns an older
indexed version of that file. The banner then prints **the SHA you asked
for**, not the commit the record came from:

```
Function: svc_tcp_recvfrom (git SHA: db99a024605b...)   <- your HEAD, always
File: net/sunrpc/svcsock.c:1271-1411                     <- possibly from weeks ago
```

Fresh and stale output are textually identical.

Worse, the record need not come from your history at all. The index keeps
blobs from rewritten and abandoned commits -- reachable only through the
reflog -- and will answer with them, stamped with current HEAD (defect 0 in
`references/observed-bugs.md` has the worked case).

This bites hardest on an stg branch, where every refresh orphans the commit it
replaced. Treat a semcode hit as evidence that the symbol was indexed at some
point, not that it is in the tree you are looking at. When the question is "is
this in my tree", `git grep` answers it and semcode does not.

What keeps the index current is narrower than it looks:

- `semcode-mcp` auto-indexes **once, at server start**, for whatever commit
  was HEAD then. Your query does not trigger indexing, and the startup pass
  can skip files (defect 4 in `references/observed-bugs.md`), so "the server
  just started" is not proof of freshness. After any commit or stack move
  (gate 1) the server's picture is behind.
- `semcode-index --commits <range>` populates **only the commits table**: it
  makes `find_commit` and `dig` see your patches (`dig <commit>` finds the
  lore mail for a commit -- the "is this posted upstream" question) and does
  nothing at all for `find_function`, `find_type`, or `grep_functions`. The
  kernel review flows in this tree run `--commits` before a review; that is
  right for commit search and is not a code refresh.

So:

**Verify before trusting a body.** The reported `File: path:start-end` is
checkable against the worktree in one call:

```bash
grep -n "^static int svc_tcp_recvfrom" net/sunrpc/svcsock.c
```

A start line that does not match means the record is stale, and the check costs
one grep.

Note what a *match* does and does not prove. The CLI applies a working-directory
overlay by default (`--git-only` turns it off), so a query can reflect
uncommitted edits -- agreement with the worktree may come from the overlay
rather than from a fresh index. When the question is specifically "what is in
the committed tree", pass `--git-only`. The sharpest check is content, not line
numbers: look for a symbol the patch under review introduced. If the returned
body contains it, the record cannot have come from a pre-patch blob.

**Refresh source when it is stale:**

```bash
semcode-index --git $(stg id {base})..HEAD    # stg branch; on a plain branch the range start is the upstream ref
```

`--git` reads blobs directly and needs no checkout. It refreshes only files
the range's commits touch: if the base itself may have moved since the index
was built, a body from any other file is unverified until the grep check
above passes. `semcode-index` takes the repository, and so the range, from
the current directory; from another tree pass `-s <tree>` and resolve the
range there (`stg -C <tree> id {base}`). The CLI's worktree overlay is not a
substitute: it reflects uncommitted edits only, not committed-but-unindexed
blobs. Add `--commits` when you also want commit-message and diff search
over those patches; a `--commits` run alone is not a code refresh.

`list_branches` reports "No branches have been indexed yet" here -- nobody runs
`semcode-index --branch`. Do not pass `branch:`; pass `git_sha` or omit it.

## Lore: coverage first, then freshness

**Check what is mirrored before reading anything into an empty result:**

```bash
ls $SEMCODE_DB/lore/
```

The set of mirrored lists changes as archives get added, so the roster comes
from your own `ls` (gate 3), never from memory -- a remembered list is how a
coverage claim goes stale without anyone noticing.
lore.kernel.org answers 403 to a plain fetch of its HTML, `raw`, search, and
atom-feed paths, so lore itself offers no live *search*; for a list that is
not mirrored, search a different archive (next paragraph). The one lore path
that does answer is the thread mbox,
`https://lore.kernel.org/<list>/<msgid>/t.mbox.gz`, which plain curl fetches
with a 200 (when last checked). It needs a Message-ID you already hold, so
it settles "did anyone reply to this thread" and nothing broader.

**When `ls` does not print the list, do not query semcode for it; search
marc.info instead.** Ten queries against an unmirrored list return the same
nothing as one. The one local query worth
making is a single subject or recipient search, because a copy Cc'd to a
mirrored list is in the index; then stop. marc.info carries most kernel
lists, vger and kvack alike, under their bare names (linux-nfs, netdev,
linux-mm, linux-kernel) and answers curl (when last checked):

```bash
curl -fsSL 'https://marc.info/?l=<list>&s=<word+word>'   # search; join words with +
curl -fsSL 'https://marc.info/?i=<msgid>'                # one message
```

A literal space in the search URL makes curl reject it. A 404 on `?l=`
means marc.info does not carry the list, and then no fallback search
exists: say so in the scope line ("no fallback archive found for <list>")
and do not go back to semcode. A 200 page reading "No hits found" means the
list is there and the search matched nothing.

A search hit links to `?l=<list>&m=<number>`; the search page prints no
Message-IDs. Fetch that page (append `&q=raw` for plain text with headers)
and read its `Message-ID:` line. marc.info obfuscates addresses in what it
prints, including inside a Message-ID: ` () ` stands for `@` and ` ! ` for
`.`, and nothing else is altered -- dots left of the `@` print as-is. So
`178867037632.207413.7103786340154818903 () noble ! neil ! brown ! name` is
`178867037632.207413.7103786340154818903@noble.neil.brown.name`. Restore it
before handing the ID to lore (`?i=` accepts either form). With the ID in
hand, fetch the lore t.mbox.gz if you need the whole thread.

Never report "not posted" or "lore has no copy" from an empty search. An
empty result on an unmirrored list is a coverage statement, not a search
result: say "not mirrored locally" and which fallback archive you checked.
On a mirrored list, say "not found in the local lore archive, which mirrors
only <the lists your `ls` printed>".

**Before you report that a thread has no replies, run this sequence.** It
fires on the claim, not on the shape of the result: "no replies", "no
review", "nobody responded". A lookup that returned the author's own patches
and nothing else is the same unanswered question as an empty result, and it
is the shape the failure actually took. The archive lags a day or two, and
lag is a reason to refresh, not a finding to report.

1. Refresh the *named* archive now, unless your context shows a
   `semcode-index --lore` run covering it made for this same question
   moments ago. A refresh from earlier in the session does not count:
   replies arrive after it regardless of how old the thread is. If you
   cannot tell when the archive was last refreshed, refresh:

   ```bash
   semcode-index --lore netdev
   ```

   Named lists only, per gate 4.

2. Re-run the same query.
3. Confirm the archive's newest indexed mail is later than the reply window
   you care about. A recipient search over a narrow recent window prints the
   mail the index holds for that list address:

   ```bash
   semcode -q "lore -t netdev@vger.kernel.org --since yesterday --limit 0"
   ```

   Read the *last* entry printed: output is sorted oldest first. Do not pass
   a small `--limit`; the limit truncates the match set *before* that sort,
   so `--limit 5` prints an arbitrary five of the window, and the latest
   date among them is not the newest mail the index holds. Without thread
   expansion the query is cheap at any limit; `--since` trims the output,
   not the scan (defect 3a in `references/observed-bugs.md`). The lore
   table has no list column,
   so this measures mail addressed to that list across every mirrored
   archive. Treat it as a floor: if the last date printed is older than the
   posting, the refresh did not reach the window and the local archive
   cannot answer. The converse does not prove it did.
4. Cross-check against lore itself. Fetch the thread mbox for the Message-ID
   of any message in the thread and count its messages:

   ```bash
   curl -fsSL 'https://lore.kernel.org/<list>/<msgid>/t.mbox.gz' \
       | zcat | grep -c '^From '
   ```

   The local count is the `Thread: Found N message(s) in thread:` line that
   `lore -m <msgid> --thread` prints; do not count the entries by eye. The
   pipe leaves nothing on disk; if you want the bodies, write the file to
   the session scratchpad, never into the worktree.

   Lore's mbox is one list's copy of the thread, while the local index
   threads across every mirrored archive at once, so a cross-posted thread
   can legitimately show a *higher* local count. What settles the question
   is whether lore holds a message the local thread does not: read the
   mbox's `From:` lines and look for a sender who is not the author. If lore
   has one, lore's copy is the answer and the local archive is behind it.

   When either side fails -- `curl -f` exits non-zero (lore may have
   tightened the 403 since), or `-m` returns "not found" (see
   *Pull a thread by message-id instead*) -- the cross-check did not run.
   Say so in the scope line and report the local result as unconfirmed. Do
   not report a bare "no replies".

Report the outcome in the scope line below: the newest indexed timestamp
from step 3 and whether the lore cross-check in step 4 ran.

### Searching is cheap; expanding threads is what costs

A pattern search is cheap: a full-text query over tokens with the regex
applied in memory to the candidates, answering in well under a second even
on the largest archive. Search freely.

**Thread expansion is the multiplier, at roughly 0.2 s per message.** Every
message pulled in rescans the lore table (defect 3 in
`references/observed-bugs.md` has the mechanism and the measurements), so a
`show_thread` search costs about 0.2 s times *the total messages across
every matched thread* -- a number you cannot see before you commit to the
query, and one that has run past ten minutes. The shape to refuse: any
`*_patterns` search with `show_thread` or `show_replies` (CLI `--thread`)
and no small `limit`.

- Leave `show_thread` and `show_replies` off unless you actually need the
  thread. "Does this exist" never needs them.
- When you do want a thread, get there by message-id -- `lore -m <msgid>
  --thread` expands exactly one thread and nothing else.
- If you must expand from a search, keep `limit` small: it bounds the match
  set before expansion, so it is a real cost control. `since_date` helps the
  same way -- fewer matches to expand -- not by narrowing the scan.

Cancellation does not save you: `TaskStop` reports success but only detaches the
client request. `semcode-mcp` runs to completion, so a query you regret has to
be killed at the process: `pkill -f semcode-mcp`. The next MCP call needs a
fresh server, and its startup index runs again, so re-check gate 1 afterward.

A bare `--until <date>` parses as midnight, so it excludes that date's own
traffic: `--since 2026-08-06 --until 2026-08-06` returns nothing, while
`--until 2026-08-07` returns the day's mail. An empty result from a same-day
window is this, not absence.

### Pull a thread by message-id instead

Message-id lookup is indexed and returns instantly:

```bash
semcode -q "lore -m <cover-msgid> --thread"          # thread skeleton
semcode -q "lore -m <cover-msgid> --thread -v"       # with bodies -- redirect
```

This is the reliable path to a review thread.

It is not infallible, though: some indexed messages cannot be retrieved by
their own Message-ID. `git-patchwork-notify` mail is reproducibly in this
state (a `-f patchwork` search prints it; a `-m` lookup of that displayed
Message-ID returns "not found", with or without angle brackets). A failed
`-m` lookup is not evidence the message is absent; fall back to a filtered
search before concluding anything.

### Output caps are recoverable

`show_thread` plus `verbose`, or a broad `body_patterns` with a large `limit`,
exceeds the MCP token cap. The tool writes the full result to a file and returns
the path -- read ranges from it rather than re-running. A bounded query first is
still cheaper.

`lore_search` takes no free-text query. Transcripts show `query_text:
"placeholder"` and `query: ""` invented to satisfy a required field that does
not exist. The filters are `message_id` and the `*_patterns` arrays.

## Parameter shapes that get transposed

The two families differ in ways that look like typos and are not:

| | commit tools | lore tools |
|---|---|---|
| commit selection | `git_ref` / `git_range` | n/a |
| symbols | `symbol_patterns` (singular, AND'd) | `symbols_patterns` (plural, OR'd) |
| dates | not accepted | `since_date` / `until_date` |

Regexes are already case-insensitive; `(?i)` is noise. `limit: 0` means
unlimited except where a tool declares a max, which wins.

## Say what you searched

Emit this line whenever the answer asserts absence or completeness --
"nobody replied", "not posted", "not mirrored locally", "no callers", "no
commit touches X" -- or whenever a lore or commit search fed the
conclusion; a single positive `find_function` or `find_type` hit verified
against the worktree does not need it.

Put it in one line, adjacent to the finding it qualifies:

```
Searched: <archives or commit range>; <bounds applied>. Not covered: <gaps>.
```

Worked:

```
Searched: netdev + linux-nfs, since 2026-06-01, limit 5, no thread expansion.
Not covered: lkml, linux-mm; netdev mirror last refreshed 2026-08-06.
```

When the claim is about replies to a thread, the line also carries the
newest mail the archive holds and whether lore was consulted:

```
Searched: linux-nfs thread <msgid>, refreshed 2026-09-04, newest indexed
mail 2026-09-04 09:12; lore t.mbox.gz holds 11 messages, local 11.
Not covered: lkml.
```

When the list is not mirrored locally, the fallback archive is what was
searched and the mirror is the gap:

```
Searched: marc.info linux-kernel, subject "guarded+OPEN"; lore t.mbox.gz
for <msgid>, 4 messages. Not covered: local semcode mirror (lkml absent
from `ls`).
```

## Reading results without over-concluding

- **"Called by: 0 functions" is usually not dead code.** Call edges are direct
  calls and function-like macros. A function reached only through an ops table
  -- `svc_tcp_recvfrom` via `svc_tcp_class` -- has no direct callers by
  construction.
- **"not found at git SHA X"**: through the CLI, first rule out the wrong
  repository. Unless you passed `--git-repo`, the lookup ran against the
  current directory's repository, and from the wrong one `func` and `type`
  print "No function" / "No type or typedef ... found at git SHA <that
  repository's HEAD>" (all zeros outside any repository), while `callers`
  and `calls` print "No function ... found in database" with no SHA. If
  `git rev-parse --show-toplevel` is not the tree you meant to query, rerun
  with `--git-repo <tree>`. Otherwise the message means either the symbol
  is absent at X *or* the file's current blob was never indexed. Check the
  tree before reporting absence.
- `vgrep_functions`, `vcommit_similar_commits`, and `vlore_similar_emails`
  need embeddings that may not be present in the database.

## Known semcode defects

`references/observed-bugs.md` records the upstream behaviours behind several
rules above -- the misleading SHA banner, cancellation that does not propagate,
the startup index's first-file skip check. Read it when semcode does something
inexplicable, or when filing an issue against `~/src/semcode`.
