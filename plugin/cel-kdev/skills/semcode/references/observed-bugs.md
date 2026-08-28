# Observed semcode defects

Behaviours found while mining session transcripts and reading
`~/src/semcode` on 2026-08-08. Each entry gives the symptom, the
evidence, and where the code lives, so it can be turned into an issue
without re-deriving anything. None of these has been reported upstream
yet.

Source tree at the time: `68d82ea9ec52` ("lore: Build the FTS indices
sequentially to avoid a deadlock").

## 0. Lookups return blobs from commits unreachable from any branch

**Symptom.** A symbol that exists nowhere in the repository's branches
is returned as a complete record, stamped with current HEAD, as though
it were present in the working tree.

**Evidence.** `find_function("sock_read_sock")` returns a full body at
`net/socket.c:1170-1211` with `git SHA: db99a024605b` (current HEAD of
`tls-read-sock-2`). `git grep sock_read_sock` finds nothing in the
worktree; `git log -S sock_read_sock --all` finds nothing; `git log -S
sock_read_sock --reflog` finds `4110eba7e3ee` and `2ed2c90b1c00`, and
`git branch --contains 4110eba7e3ee` is empty. Those commits were
orphaned by `stg refresh` (one is literally titled "Refresh of
net-sock-read-sock") and survive only in the reflog.

This is severe on an stg branch, where every `stg refresh` orphans the
commit it replaced, so the pool of unreachable-but-indexed blobs grows
with ordinary work. Note the failure is specific: symbols that *are*
present at HEAD resolve correctly. It is absence that is answered
wrongly, which is the case where a caller has no reason to doubt the
result.

**Fix shape.** Filter git-aware lookups by reachability from the
queried commit, and return "not found" when the only candidates are
unreachable. Defect 1 below compounds this: with the record's own
provenance hidden, the caller cannot tell.

## 1. Query banner prints the requested SHA, not the record's provenance

**Symptom.** `find_function` output always reads `git SHA: <the sha you
asked for>`, including when the returned record was indexed at some
older commit. Stale answers and current answers are textually
identical, so nothing prompts a caller to check.

**Evidence.** `src/bin/semcode-mcp.rs:134` (and the shorter form at
`:73`) formats the header from
the `git_sha` query argument, not from the record. The record itself
(`FunctionInfo`, `src/types.rs:6-19`) carries `git_file_hash` -- the
blob hash of the indexed file version -- which never reaches the
output. Observed in session `1830788c`: a lookup of `sock_read_sock`,
a function not present in this worktree, came back stamped with current
HEAD.

**Fix shape.** Emit the record's `git_file_hash`, or the commit the
lookup resolved to, alongside (or instead of) the queried SHA. Either
one makes staleness detectable by the caller; today the only check is
grepping the reported line range against the file.

## 2. Client cancellation does not stop an in-flight query

**Symptom.** A long `lore_search` moved to the background can be
"stopped" from the client -- `TaskStop` reports success -- while
`semcode-mcp` keeps running to completion. The only effective stop is
killing the process.

**Evidence.** Session `1830788c`, 2026-08-06: a `lore_search` with
`subject_patterns` and `show_thread: true` exceeded the 120s tool
window, was backgrounded, and was still burning ~2 cores across 63
tokio threads at 1.1 GB RSS eleven minutes later, after the client
request had been cancelled.

**Fix shape.** Thread a cancellation token from the JSON-RPC request
into the search loops so a dropped request aborts the work.

## 3. Thread expansion rescans the whole table once per message

**Symptom.** `show_thread`/`show_replies` cost far more than the search
that feeds them, and the cost is invisible before the query runs. A
`subject_patterns` search with `show_thread: true` ran eleven-plus
minutes on netdev; the same archive answers a pattern search in 0.3 s.

**Evidence.** `get_lore_emails_referencing()`
(`src/database/connection.rs:5365`) runs two queries per message: an
equality filter on `in_reply_to`, and `regexp_like` on the
`references` column. The second has no index and no `select`
projection, so it scans the table and materializes every column,
message bodies included. The thread walk
(`src/search.rs:1017-1031`) calls it once per message in BFS order,
and the search path calls that once per match.

Measured 2026-08-08 on this database: 0.3 s for a pattern search with
no expansion, 2.1 s for a 9-message thread by message-id, 5.5 s for a
3-match search expanding 26 messages -- about 0.2 s per message
expanded, linear, with user+sys time well above wall time (multiple
cores busy per query).

**Fix shape.** Project only the columns the walk needs, and index or
denormalize the thread relation so descendants can be found without a
regex scan of `references`. A cost estimate that warns before
expanding an unbounded match set would also help; the CLI's
message-id path expands exactly one thread and is the shape callers
usually want.

## 3a. Date filtering is documented as pushed down, but is a post-filter

**Symptom.** `since_date`/`until_date` do not reduce the work a lore
search does; they only shrink its output (which does cut downstream
thread expansion, so the parameter is still worth passing).

**Evidence.** `query_lore_by_fields_intersection()` comments at
`src/database/connection.rs:4826-4829` and again at the call site
(`:5104-5106`) state the date range is "pushed into FTS queries so the
candidate set is already bounded before intersection." The
implementation in `query_field_impl` fetches up to `effective_limit`
(100000 when unlimited) FTS candidates first and applies both the
regex and the date range in memory afterwards.

**Fix shape.** Either push the date predicate into the query, or
correct the comments so callers do not expect a bound the code does
not provide.

## 4. Startup auto-index skip check samples only the first changed file

**Symptom.** The MCP server's background indexer can decide "already
indexed, skipping" and leave other files of the same commit unindexed.

**Evidence.** `src/bin/semcode-mcp.rs:5410-5435`: the check diffs
`HEAD~1..HEAD`, takes the *first* added/modified file with a supported
extension, and returns early if that one path/blob pair is already in
`processed_files`. Nothing looks at the remaining changed files. The
window it examines is also a single commit, so files changed by
commits between the last index and HEAD are never considered.

**Fix shape.** Test the full changed-file set against
`processed_files`, and diff from the newest indexed commit rather than
`HEAD~1`.

## 4a. Some indexed messages are unreachable by Message-ID

**Symptom.** `lore -m <id>` reports "not found" for a message the
search path happily returns, so the recommended retrieval route
silently fails on part of the archive.

**Evidence.** `semcode -q "lore -f 'patchwork' --limit 2 -v"` prints
`Message-ID: <178614240590.2445639.1288172802373951589.git-patchwork-notify@kernel.org>`.
Looking that id up with `-m` returns "Email not found" in all three
spellings tried: bare, angle-bracketed, and space-prefixed. Reported
independently by a test run that could not retrieve patchwork-bot
bodies and fell back to header lines.

Cause not established -- a normalization mismatch between the ingest
and lookup paths is the leading hypothesis, but it was not confirmed.
Worth checking whether the stored `message_id` for these rows differs
from the displayed one.

**Fix shape.** Normalize `message_id` identically on ingest and
lookup, and add a round-trip test asserting that every message the
search path returns can be fetched by the Message-ID it displays.

## 5. `lore --help` errors instead of printing usage

**Symptom.** `semcode -q "lore --help"` returns `Error: Unknown option
or missing value: --help`. Bare `lore` prints usage, so the
information exists; the conventional spelling just fails. Session
`1dea7c38` burned a call on it.

**Fix shape.** Accept `--help`/`-h` in the query-language subcommands
and print the same usage text.
