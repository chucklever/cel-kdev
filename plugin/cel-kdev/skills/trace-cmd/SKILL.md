---
name: trace-cmd
description: Analyze trace-cmd captures (.dat files) from kernel tracing sessions. Use when asked to look at a trace file, analyze tracing output, measure latency, or compare before/after trace captures. Supports nfsd, sunrpc, svcrdma, xprtrdma, rpcgss, workqueue, rdma, tcp, handshake, sched, and general ftrace events.
invocation_policy: automatic
---

# Trace Analysis

Analyze kernel trace captures to support the patch-measure-analyze
development cycle. Operate on trace-cmd .dat files or pre-generated
report output.

## Invocation

When the user provides a trace file path (typically /tmp/trace.dat
or similar), begin analysis immediately. If no specific question is
asked, produce a general summary first, then offer deeper analysis.

## trace-cmd Argument Order

CRITICAL: The input file MUST be specified with `-i` BEFORE any
filter flags. Positional file arguments after `-F` are
misinterpreted as filter files.

Correct:  `trace-cmd report -i /tmp/trace.dat -F 'event_name'`
Wrong:    `trace-cmd report /tmp/trace.dat -F 'event_name'`
Wrong:    `trace-cmd report -F 'event_name' /tmp/trace.dat`

## trace-cmd report Output Format

Each event line follows this layout:

```
        TASK-PID  [CPU] FLAGS  TIMESTAMP: EVENT:  field=val ...
```

The TASK-PID column has variable-width leading whitespace and
may contain slashes (e.g., `tcp-recv/192.16-5586`).  Positional
field numbers (`$1`, `$4`, etc.) are unreliable.

To extract the **process name** (strip trailing PID):

```bash
awk '{gsub(/^[ \t]+/,""); sub(/-[0-9]+.*$/,""); print}'
```

To extract the **timestamp**, match the pattern rather than
relying on a column number:

```bash
awk '{match($0, /[0-9]+\.[0-9]+:/); ts=substr($0,RSTART,RLENGTH-1)+0}'
```

## Useful trace-cmd report Options

Beyond `-i`, `-F`, and `--stat`, these flags are available:

| Flag | Purpose |
|------|---------|
| `--first-event` | Timestamp of first event per CPU (fast time-range check) |
| `--last-event`  | Timestamp of last event per CPU |
| `--ts-diff`     | Show delta between consecutive events |
| `-t`            | Full nanosecond timestamps |
| `-w`            | Compute wakeup latency (needs sched_switch + sched_wakeup) |
| `--profile`     | Automatic per-task profiling summary |
| `-I`            | Exclude hard-IRQ context events |
| `-S`            | Exclude soft-IRQ context events |
| `-v`            | Invert the next `-F` filter (exclude matches) |
| `-P`            | List stored `trace_printk()` format strings |
| `--event regex` | Show only events matching a regex |

The `-F` filter supports a `COMM` pseudo-field for matching
the task name:

```bash
trace-cmd report -i <file> -F '.*:COMM != "trace-cmd"'
```

## Phase 1: Ingestion

Determine what is available before analyzing:

```bash
# Event summary and buffer stats
trace-cmd report -i <file> --stat
```

If `--stat` is uninformative, fall back to:

```bash
# Count events per type
trace-cmd report -i <file> 2>&1 | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /:$/) {sub(/:$/,"",$i); c[$i]++}}
       END{for(e in c) printf "%8d %s\n",c[e],e}' | sort -rn | head -30
```

```bash
# Time range: fast method
trace-cmd report -i <file> --first-event
trace-cmd report -i <file> --last-event
```

```bash
# CPU and process summary
trace-cmd report -i <file> 2>&1 | \
  awk '{gsub(/^[ \t]+/,""); sub(/-[0-9]+.*$/,""); c[$0]++}
       END{for(p in c) printf "%8d %s\n",c[p],p}' | \
  sort -rn | head -20
```

When the capture contains unfamiliar events, extract the embedded
format definitions to discover all available fields and their types:

```bash
# List every event format stored in the .dat file
trace-cmd dump -i <file> --events
```

To extract a single event's format, match from the `name:` line
to the `print fmt:` line. Do NOT use a blank-line delimiter
(`/^$/`) -- format blocks often lack trailing blank lines, causing
awk range patterns to run past the intended boundary:

```bash
# Extract one event's format definition
trace-cmd dump -i <file> --events 2>&1 | \
  awk '/^name: svc_stats_latency$/,/^print fmt:/'
```

Each format block lists fields with type, name, offset, and size.
Numeric fields can be filtered and sorted; string fields support
glob matching. Use this output to identify which fields carry
latency values, status codes, identifiers for pairing, etc.,
rather than guessing from the report text. Note that the field
names in the format definition may differ from the abbreviated
labels in report output (see Filter Expressions below).

Exception: `bprint` and `bputs` events (from `trace_printk()`)
have no format block. Their content is free-form text. See the
trace_printk section under Subsystem Reference for handling.

Record:
- Total event count
- Time span of the capture
- Event types present
- CPUs and processes involved

## Pipeline Reliability

trace-cmd report writes a multi-line header (kernel version,
uptime, `cpus=N`) to stderr. Event data goes to stdout, but
some builds or invocations intermix event lines on stderr.
Two consequences:

1. **Always use `2>&1`** when piping report output, then
   filter out non-event lines with a grep for the event name.
2. **Save filtered output to a temp file** before running
   multi-stage extraction pipelines.

**grep -oP pipe hazard**: `grep -oP` with certain character-
class patterns (`\S+`, `[^ ]+`) silently produces zero output
when piped on large files (100K+ lines), even though redirecting
to a file works correctly. More restrictive patterns like `\w+`
and `[0-9]+` are not affected.  Do not debug this; avoid it:

- **Always redirect `grep -oP` output to a file first**, then
  pipe from the file.
- **Prefer awk** for field extraction on large files (see
  Field Extraction Recipes below). awk has no pipe issues.

```bash
# UNRELIABLE -- grep -oP piped on large traces:
grep -oP 'execute-us=\K[0-9]+' /tmp/latency.txt | sort -n | ...

# RELIABLE -- redirect first, then pipe:
grep -oP 'execute-us=\K[0-9]+' /tmp/latency.txt > /tmp/vals.txt
sort -n /tmp/vals.txt | awk '...'

# BEST -- use awk directly, no pipe issues:
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt | sort -n | awk '...'
```

When running a multi-phase analysis (WRITE vs READ, per-CPU
breakdown, flag analysis), save separate event files early
in Phase 1 and work from them throughout:

```bash
# Capture each event type to its own file
for ev in svc_stats_latency svc_xprt_dequeue svc_xprt_enqueue; do
  trace-cmd report -i <file> -F "$ev" 2>&1 | \
    grep "$ev" > /tmp/${ev}.txt
done
```

## Field Extraction Recipes

Use awk for extracting `key=value` fields from saved event
files. These patterns are portable, fast on large files, and
immune to the grep pipe hazard.

```bash
# Extract a single numeric field
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt

# Count distinct values of a field (replaces sort|uniq -c)
awk '{for(i=1;i<=NF;i++) if($i ~ /^proc=/)
  {split($i,a,"="); c[a[2]]++}}
  END{for(v in c) printf "%8d %s\n",c[v],v}' /tmp/latency.txt | sort -rn

# Extract flags (contain | characters)
grep -oE 'flags=[A-Za-z0-9x|_]+' /tmp/enqueue.txt

# Count flag combinations
awk '{match($0,/flags=[A-Za-z0-9x|_]+/);
  if(RSTART) c[substr($0,RSTART,RLENGTH)]++}
  END{for(f in c) printf "%8d %s\n",c[f],f}' /tmp/enqueue.txt | sort -rn
```

For counting patterns over large files (400K+ lines),
`sort | uniq -c | sort -rn` is slow. Use awk associative
arrays as shown above.

## Phase 2: Event-Specific Analysis

Based on the events present, apply the appropriate analysis
strategy. Multiple strategies may apply to a single capture.

### Latency Analysis

For events that encode duration fields (execute-us, wakeup-us,
qtime-us), extract all values and compute distributions.
Always work from a saved temp file (see Pipeline Reliability):

```bash
# Save events first
trace-cmd report -i <file> -F 'svc_stats_latency' 2>&1 | \
  grep 'svc_stats_latency' > /tmp/latency.txt

# Extract values and compute distribution
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt | \
  sort -n | \
  awk '{a[NR]=$1; s+=$1} END{n=NR;
    printf "n=%d min=%d p50=%d p90=%d p99=%d max=%d mean=%.0f\n",
      n, a[1], a[int(n*0.5)], a[int(n*0.9)], a[int(n*0.99)], a[n], s/n}'
```

Compute and report:
- Count
- Min / median / p90 / p99 / max
- Mean and standard deviation if count > 20

To inspect individual outliers rather than computing a full
distribution, use field-level `-F` filters instead (see Filter
Expressions below).

For paired events without built-in duration (e.g., enqueue/dequeue,
post_send/wc_read), correlate by a shared key (xid, transport
address, or CQ completion ID) and compute inter-event latency from
timestamps.

### Throughput Analysis

When the capture contains repeated operations (RPC calls, RDMA
posts, completions), compute:
- Operations per second (total and per-CPU)
- Burst patterns (events clustered in time)
- Idle gaps between bursts

### Phase Detection

To identify workload phases (e.g., WRITE vs READ in an iozone
trace), filter for a procedure or operation field and extract the
time boundaries:

```bash
# Find WRITE phase boundaries
grep 'proc=WRITE' /tmp/latency.txt | head -1
grep 'proc=WRITE' /tmp/latency.txt | tail -1

# Count events per phase using timestamp windows
awk '{match($0,/[0-9]+\.[0-9]+:/);
  ts=substr($0,RSTART,RLENGTH-1)+0;
  if(ts>=516.5 && ts<=527.0) wr++;
  else if(ts>=528.7 && ts<=545.0) rd++}
  END{print "WRITE:",wr+0; print "READ:",rd+0}' /tmp/enqueue.txt
```

### Error and Anomaly Detection

Scan for:
- Events with "err" in the name (svcrdma_send_err, svc_alloc_arg_err)
- Non-zero error/status fields
- Unusually long gaps between expected event pairs
- Flag state changes that indicate transport distress (XPT_CLOSE,
  XPT_DEAD in svc_xprt_enqueue flags)

## Phase 3: Reporting

Present results as plain text suitable for notes or commit message
drafts. Structure:

1. **Capture summary** - time range, event counts, what was traced
2. **Key metrics** - latency distributions, throughput numbers
3. **Observations** - patterns, anomalies, bottleneck indicators
4. **Comparison** - if a baseline trace was provided or is available
   from a prior conversation, compare the two

When reporting latency distributions, use a compact table:

```
svc_stats_latency (execute-us), N=1284:
  min     p50     p90     p99     max     mean
  12      45      128     892     4201    73
```

## Subsystem Reference

### SunRPC Server Events (sunrpc.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| svc_xprt_enqueue | flags | Transport queued for service; flags show state |
| svc_xprt_dequeue | wakeup-us, qtime-us | Thread picked up transport; wakeup-us = thread wake latency, qtime-us = time on queue |
| svc_process | xid, procedure | RPC request dispatch |
| svc_stats_latency | procedure, execute-us | RPC execution time |
| svc_alloc_arg_err | (none) | Page allocation failure |
| svc_replace_page_err | (none) | Page replacement failure |

Pairable: svc_xprt_enqueue -> svc_xprt_dequeue (by transport addr)

### svcrdma Server Events (rpcrdma.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| svcrdma_decode_rqst | xid, hdrlen | Incoming RDMA request decode |
| svcrdma_post_send | cq_id | RDMA send posted |
| svcrdma_wc_read | cq_id, status | RDMA read completion |
| svcrdma_send_err | status | Send failure |
| svcrdma_rq_post_err | status | Receive post failure |
| svcrdma_qp_error | | Queue pair error |
| svcrdma_sq_post_err | | Send queue post failure |
| svcrdma_dma_map_rw_err | | DMA mapping failure |
| svcrdma_send_pullup | | Inline send data copy |
| svcrdma_cc_release | | Chunk completion release |

Pairable: svcrdma_post_send -> completion events (by cq_id)

### xprtrdma Client Events (rpcrdma.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| xprtrdma_post_send | task_id, client_id, cq_id, cid | Client RDMA send posted |
| xprtrdma_post_send_err | status | Client send failure |
| xprtrdma_post_recvs | count | Receive buffers posted |
| xprtrdma_post_recvs_err | status | Receive post failure |
| xprtrdma_reply | task_id, xid, credits | Reply received |
| xprtrdma_marshal | task_id, xid, hdrlen, rtype, wtype | Request marshalled |
| xprtrdma_marshal_failed | task_id, status | Marshal failure |
| xprtrdma_op_connect | | Connection attempt |
| xprtrdma_createmrs | count | MR pool growth |
| xprtrdma_nomrs_err | task_id | MR exhaustion |
| xprtrdma_frwr_alloc | | FRWR allocated |
| xprtrdma_frwr_dereg | | FRWR deregistered |

Pairable: xprtrdma_marshal -> xprtrdma_post_send -> xprtrdma_reply
(by task_id/xid)

### NFSD Events (fs/nfsd/trace.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| nfsd_compound | xid, opcnt, tag | Compound request arrival |
| nfsd_compound_status | op, name, status | Per-op completion status |
| nfsd_compound_decode_err | | XDR decode failure |
| nfsd_read_start | xid, fh_hash, offset, len | Read I/O begin |
| nfsd_read_io_done | xid, fh_hash, offset, len | Read I/O complete |
| nfsd_read_done | xid, fh_hash, offset, len | Read op complete |
| nfsd_write_start | xid, fh_hash, offset, len | Write I/O begin |
| nfsd_write_io_done | xid, fh_hash, offset, len | Write I/O complete |
| nfsd_write_done | xid, fh_hash, offset, len | Write op complete |
| nfsd_read_err | xid, fh_hash, offset, status | Read error |
| nfsd_write_err | xid, fh_hash, offset, status | Write error |
| nfsd_file_acquire | | File cache lookup |
| nfsd_drc_found | | Duplicate request cache hit |
| nfsd_drc_mismatch | | DRC mismatch |
| nfsd_cb_* | | Callback events |

Pairable: nfsd_read_start -> nfsd_read_io_done -> nfsd_read_done
(by xid); same for write. nfsd_compound brackets per-op events.

### RPCGSS Events (rpcgss.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| rpcgss_svc_authenticate | xid | Server-side GSS authentication |
| rpcgss_svc_wrap_failed | xid | Wrap failure |
| rpcgss_svc_unwrap_failed | xid | Unwrap failure |
| rpcgss_svc_seqno_bad | xid, seqno | Sequence number violation |
| rpcgss_svc_seqno_low | xid, seqno | Late sequence number |
| rpcgss_svc_accept_upcall | | Upcall to gssd |
| rpcgss_upcall_msg | | Client upcall message |
| rpcgss_upcall_result | status | Upcall result |
| rpcgss_context | | Context establishment |
| rpcgss_seqno | task_id, xid, seqno | Client sequence number |

Useful for: authentication failures, GSS context churn,
upcall latency (pair svc_accept_upcall with context events).

### Workqueue Events (workqueue.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| workqueue_queue_work | work, function, workqueue | Work item queued |
| workqueue_activate_work | work | Work item activated |
| workqueue_execute_start | work, function | Work handler begins |
| workqueue_execute_end | work, function | Work handler ends |

Pairable: workqueue_queue_work -> workqueue_execute_start (queue
latency); workqueue_execute_start -> workqueue_execute_end
(execution time). Filter by function name to isolate specific
handlers (e.g., svc_xprt_do_enqueue).

### Handshake Events (handshake.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| handshake_submit | req, sk | TLS handshake submitted |
| handshake_complete | req, sk, status | TLS handshake completed |
| handshake_notify_err | req, sk, err | Handshake notification error |
| handshake_cancel | req, sk | Handshake cancelled |
| tls_contenttype | sk, type | TLS record content type |
| tls_alert_send | sk, level, description | TLS alert sent |
| tls_alert_recv | sk, level, description | TLS alert received |

Pairable: handshake_submit -> handshake_complete (by req pointer,
measures full TLS negotiation time).

### Scheduler Events (sched.h)

| Event | Use |
|-------|-----|
| sched_switch | Context switches; look for nfsd/kworker preemption |
| sched_wakeup | Wake latency for service threads |

Useful for correlating: high svc_xprt_dequeue wakeup-us with
sched_switch events showing the nfsd thread was preempted or
migrated.

### trace_printk Events (bprint / bputs)

Kernel code instrumented with `trace_printk()` emits free-form
printf-style events. These lack a structured format descriptor, so
they appear under the generic `bprint` or `bputs` event names
rather than a subsystem-specific tracepoint.

Use `trace-cmd report -P` to list the stored `trace_printk()`
format strings from the `.dat` file.  This is useful for
identifying what instrumentation is present without scanning
all events.

In trace-cmd report output they look like:

```
  nfsd-1234  [002]  1234.567890: bprint: my_function: xid=0x1a2b count=5
  kworker-56 [001]  1234.567891: bputs:  do_something: entering slow path
```

`bprint` carries a printf format string with arguments; `bputs` is
a constant-string variant with no format arguments.

Because these events have no typed fields:
- Field-level `-F` filters do not apply; use `grep` on report
  output instead
- The `trace-cmd dump --events` output contains no format block
  for them
- Values embedded in the text must be extracted with awk

When bprint/bputs events are present, treat them as developer-added
debug instrumentation. Extract structure from the message text:

```bash
# List distinct bprint messages (prefix before first colon after bprint:)
trace-cmd report -i <file> -F 'bprint' 2>&1 | \
  grep 'bprint' | sed -n 's/.*bprint: *//p' | \
  cut -d: -f1 | sort | uniq -c | sort -rn

# Extract a numeric value from a trace_printk message
trace-cmd report -i <file> -F 'bprint' 2>&1 | \
  grep 'my_function' | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /^count=/)
    {split($i,a,"="); print a[2]}}' | sort -n
```

### TCP Events

| Event | Use |
|-------|-----|
| tcp_send_reset | RST sent; connection teardown |
| tcp_receive_reset | RST received |
| tcp_retransmit_skb | Retransmission; indicates loss or congestion |
| tcp_retransmit_synack | SYN-ACK retransmit |
| tcp_probe | cwnd, ssthresh, srtt; congestion state |

Useful for: correlating NFS/RPC latency spikes with TCP
retransmissions or resets on the same connection.

## Comparison Mode

When the user provides two trace files or references a prior
capture, produce a side-by-side comparison:

```
Metric                  Before      After       Delta
svc_stats_latency p50   45 us       32 us       -29%
svc_stats_latency p99   892 us      410 us      -54%
svc_xprt_dequeue  p50   8 us        5 us        -37%
ops/sec                 28,400      31,200      +10%
```

Focus the comparison on metrics relevant to the patch being tested.

## Filter Expressions

The `-F` flag accepts the kernel's event filter syntax, not just
bare event names. Filters can select on individual fields using
relational operators, combined with `&&` and `||`:

```bash
# Events where a specific numeric field exceeds a threshold
trace-cmd report -i <file> -F 'svc_stats_latency: execute-us > 1000'

# String glob matching (~ operator)
trace-cmd report -i <file> -F 'svc_process: procedure ~ "*READ*"'

# Compound filter with logical operators
trace-cmd report -i <file> -F 'svc_xprt_dequeue: qtime-us > 500 || wakeup-us > 500'

# Filter by task name (COMM pseudo-field, all events)
trace-cmd report -i <file> -F '.*:COMM == "nfsd"'

# Invert: exclude matching events with -v before -F
trace-cmd report -i <file> -v -F 'svc_xprt_enqueue'
```

Numeric operators: `==`, `!=`, `<`, `<=`, `>`, `>=`, `&` (bitmask).
String operators: `==`, `!=`, `~` (glob with `*`, `?`, `[]`).

**Field name caveat**: The field names in `-F` filters must
match the kernel event format definition exactly. These often
differ from the abbreviated labels in report output. For
example, a field defined as `procedure` in the format may
print as `proc=READ` in the report. The filter
`-F 'event: proc == "READ"'` fails silently because `proc`
is not the actual field name.

To discover exact field names, use:
```bash
trace-cmd dump -i <file> --events 2>&1 | \
  awk '/^name: svc_stats_latency$/,/^print fmt:/'
```

When field-level filters fail or the field names are unclear,
fall back to awk-based post-processing on saved report output
(see Field Extraction Recipes above):
```bash
grep 'proc=READ' /tmp/latency.txt | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
    {split($i,a,"="); print a[2]}}'
```

Field-level filters are for targeted inspection: finding outliers,
isolating errors, or narrowing output before reading individual
events. They are not a substitute for the full-extraction pipeline
in Latency Analysis, which requires all values to compute
percentiles and means.

## Working With Large Traces

For captures with millions of events:
- Save filtered events to temp files early (see Pipeline
  Reliability) and work from the files for all subsequent analysis
- Use field-level `-F` filters to narrow output before saving
- Process per-CPU if needed: trace-cmd report -i <file> --cpu <N>
- For phase-based analysis (e.g., WRITE phase vs READ phase),
  use awk timestamp filters on the saved temp files:

```bash
# Extract events within a time window from a saved file
awk '{match($0, /[0-9]+\.[0-9]+:/);
  ts=substr($0,RSTART,RLENGTH-1)+0;
  if (ts >= 395.9 && ts <= 402.0) print}' /tmp/dequeue.txt | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /^wakeup-us=/)
    {split($i,a,"="); print a[2]}}' | sort -n | awk '...'
```

## What This Skill Does Not Do

- Does not set up trace-cmd recording sessions (the user manages
  capture separately)
- Does not modify kernel code (that happens outside this skill)
- Does not interpret application-level semantics beyond what the
  trace events encode
