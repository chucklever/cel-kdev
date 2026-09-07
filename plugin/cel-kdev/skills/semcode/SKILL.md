---
name: semcode
description: >-
  Use whenever you are about to query semcode -- any mcp__semcode__* tool,
  the `semcode` CLI, or `semcode-index` -- to look up functions, types,
  callers, call chains, or commits, or to search the local lore mailing-list
  archive. Load it BEFORE the first call, not after one goes wrong, and even
  when a sibling skill (sashiko, b4, kreview) is the reason you are querying.
  Triggers on any of these intents, however worded: "search lore", "check
  the lore archive", "did anyone reply to", "who calls this function",
  "find callers", "find the commit that changed X", "is this posted
  upstream". It fires just as much when the lookup is your own idea:
  verifying a claim about upstream state, checking whether a reply landed,
  confirming a Message-ID or a commit exists, or whenever `lore` is about
  to appear in a shell command. There is no `lore` executable; load this
  for the real spelling.
---

# semcode

semcode is a local semantic index over source trees and lore.kernel.org
archives. Its MCP tool descriptions document parameters well but say nothing
about how the index goes stale, what the archive actually contains, or which
query shapes are dangerous. Those are what generate false starts, and they are
what this skill covers.

## Before the first query

Five gates. Gates 1, 3, and 4 run before you send the query; gates 2 and 5
run before you use what came back. Each names the section that explains it;
run them, do not just read them.

1. **Code lookup via MCP, and HEAD has moved since `semcode-mcp` started?**
   Any commit or rebase moves it, and on an stg branch so does every
   `refresh`, `goto`, `push`, or `pop`. Reindex the changed files first:
   `semcode-index --git <range>..HEAD` -- on an stg branch the range start is
   `$(stg id {base})`, on a plain branch the upstream ref. If you cannot tell
   whether HEAD moved, run it; it is cheap and idempotent. The CLI's worktree
   overlay is not a substitute: it reflects uncommitted edits only, not
   committed-but-unindexed blobs. -- *Index freshness*
2. **About to trust a returned body?** Grep the reported `path:start` in the
   worktree, or look for a symbol the patch under review introduced. A hit
   proves the symbol was indexed at some point, not that it is in your tree.
   -- *Index freshness*
3. **Searching lore?** Run `ls $SEMCODE_DB/lore/` and read what it prints.
   That output is the only source for the archive roster; quote it, not a
   list remembered from elsewhere. -- *Lore: coverage*
4. **Expanding a thread?** By message-id. From a search, only with a small
   `limit`: the cost is a fixed per-message amount summed across every
   matched thread, and nothing shows you that number before you commit.
   -- *Searching is cheap*
5. **Asserting absence or completeness, or did a lore or commit search feed
   the conclusion?** Emit the scope line in the template's shape. A verified
   positive `find_function` hit does not need it. -- *Say what you searched*

## The two front ends

Both hit the same database, located by `$SEMCODE_DB`; on this setup the login
shell exports it, so the Bash tool and the MCP server both inherit it. Check
`echo $SEMCODE_DB` once. If it is empty, ask where the database lives rather
than passing `-d` guesses or searching the worktree: there is never a copy in
the kernel tree.

Binaries are on `$PATH` (typically `~/.cargo/bin`: `semcode`, `semcode-index`,
`semcode-mcp`, `semcode-lsp`). Locate them with `command -v semcode-mcp`,
never a build tree such as `target/release` -- an MCP registration pointing
there once died with ENOENT and cost a session.

There is no `lore` executable. `lore` is a subcommand of the CLI's query
language: `semcode -q "lore ..."`. `semcode -q "lore --help"` fails with
"Unknown option"; bare `semcode -q "lore"` prints usage, as does
`semcode -q "help lore"`.

Pick by job:

- **MCP for code lookups.** Structured, small, cheap.
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
semcode-index --git $(stg id {base})..HEAD    # indexes files changed in the range
```

`--git` reads blobs directly and needs no checkout. Use `--commits` alongside it
when you also want commit-message and diff search over those patches.

`list_branches` reports "No branches have been indexed yet" here -- nobody runs
`semcode-index --branch`. Do not pass `branch:`; pass `git_sha` or omit it.

## Lore: coverage first, then freshness

**Check what is mirrored before reading anything into an empty result:**

```bash
ls $SEMCODE_DB/lore/
```

On the day this was written the archive held five lists; lkml, linux-mm, and
every other list were absent. The set changes as archives get added, so the
roster comes from your own `ls` (gate 3), never from memory -- a remembered
list is how a coverage claim goes stale without anyone noticing.
lore.kernel.org blocks bots, so there is no live fallback for a list that is
not there.

Never report "not posted" or "lore has no copy" from an empty search. Say
"not found in the local lore archive, which mirrors only <the lists your `ls`
printed>" -- and if you have not run the `ls`, run it now. An mm patch posted
to linux-mm will never be found; a session once downgraded a sashiko lookup
to "patch was local-only" on exactly that mistake.

**The archive lags a day or two.** A reply sent yesterday is often not there
yet; that is lag, not silence. Refresh a *named* archive:

```bash
semcode-index --lore netdev
```

A bare `--lore` refreshes every archive ever indexed, lkml included -- far more
work than checking one thread justifies.

### Searching is cheap; expanding threads is what costs

The intuition that "regex is the expensive part" is wrong, and acting on it
makes you time out on searches that would have been free. A pattern search
runs as a full-text query over tokens with the regex applied in memory to the
candidates; measured once on netdev at 834 MB indexed, a sloppy multi-word
pattern search with `--limit 5` took 0.3 s. Search freely. (The archive only
grows: read the ratios, not the seconds, and never quote these numbers as
current.)

**Thread expansion is the multiplier, at roughly 0.2 s per message.** Every
message pulled in rescans the lore table (defect 3 in
`references/observed-bugs.md` has the mechanism), so a `show_thread` search
costs about 0.2 s times *the total messages across every matched thread* -- a
number you cannot see before you commit to the query. That is how a
`subject_patterns` search with `show_thread: true` reached eleven minutes at
1.1 GB RSS on netdev. The shape to refuse: any `*_patterns` search with
`show_thread` or `show_replies` (CLI `--thread`) and no small `limit`.

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

This is the reliable path to a review thread, and it is what the runaway regex
scan was reaching for the long way around.

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

Every rule above is about a result that looks more complete than it is. Emit
this line whenever the answer asserts absence or completeness -- "nobody
replied", "not posted", "no callers", "no commit touches X" -- or whenever a
lore or commit search fed the conclusion; a single positive `find_function`
or `find_type` hit verified against the worktree does not need it. The line
carries the shape of the search that produced the answer: what you covered,
how you bounded the work, and what you know you did not reach. A reader who
can see the scope can judge the gap; a reader given only the conclusion
cannot.

Put it in one line, adjacent to the finding it qualifies:

```
Searched: <archives or commit range>; <bounds applied>. Not covered: <gaps>.
```

Worked:

```
Searched: netdev + linux-nfs, since 2026-06-01, limit 5, no thread expansion.
Not covered: lkml, linux-mm; netdev mirror last refreshed 2026-08-06.
```

The line is not a hedge and not optional where it applies: a conclusion with
no stated scope reads as exhaustive, and the reader has no way to tell that
it is not.

## Reading results without over-concluding

- **"Called by: 0 functions" is usually not dead code.** Call edges are direct
  calls and function-like macros. A function reached only through an ops table
  -- `svc_tcp_recvfrom` via `svc_tcp_class` -- has no direct callers by
  construction.
- **"not found at git SHA X"** means either the symbol is absent at X *or* the
  file's current blob was never indexed. Check the tree before reporting
  absence.
- `vgrep_functions`, `vcommit_similar_commits`, and `vlore_similar_emails`
  need embeddings that may not be present in the database.

## Known semcode defects

`references/observed-bugs.md` records the upstream behaviours behind several
rules above -- the misleading SHA banner, cancellation that does not propagate,
the startup index's first-file skip check. Read it when semcode does something
inexplicable, or when filing an issue against `~/src/semcode`.
