---
name: trace-cmd
description: >-
  Analyze trace-cmd captures (.dat files) from kernel tracing
  sessions. Covers latency measurement, throughput analysis,
  event pairing, filter expressions, histogram triggers, and
  dynamic kprobe/fprobe events. Supports nfsd, sunrpc, svcrdma,
  xprtrdma, rpcgss, workqueue, rdma, tcp, handshake, and sched
  subsystems.
invocation_policy: automatic
---

# Trace analysis

Analyze kernel trace captures to support the patch-measure-analyze
development cycle. Operate on trace-cmd .dat files or pre-generated
report output.

When the user provides a trace file path, begin analysis
immediately. If no specific question is asked, produce a
general summary first, then offer deeper analysis.

## CRITICAL: trace-cmd argument order

The input file MUST be specified with `-i` BEFORE any
filter flags. Positional file arguments after `-F` are
misinterpreted as filter files.

```
Correct:  trace-cmd report -i /tmp/trace.dat -F 'event_name'
Wrong:    trace-cmd report /tmp/trace.dat -F 'event_name'
Wrong:    trace-cmd report -F 'event_name' /tmp/trace.dat
```

## Output format

Each event line follows this layout:

```
        TASK-PID  [CPU] FLAGS  TIMESTAMP: EVENT:  field=val ...
```

The TASK-PID column has variable-width leading whitespace and
may contain slashes. Positional field numbers (`$1`, `$4`)
are unreliable. Match patterns instead:

```bash
# Extract timestamp
awk '{match($0, /[0-9]+\.[0-9]+:/); ts=substr($0,RSTART,RLENGTH-1)+0}'

# Extract process name (strip trailing PID)
awk '{gsub(/^[ \t]+/,""); sub(/-[0-9]+.*$/,""); print}'
```

## Pipeline reliability

trace-cmd report writes a multi-line header to stderr. Some
builds intermix event lines on stderr. Two rules:

1. **Always use `2>&1`** when piping report output, then
   filter out non-event lines with grep for the event name.
2. **Save filtered output to a temp file** before running
   multi-stage extraction pipelines.

```bash
# Save each event type to its own file early
for ev in svc_stats_latency svc_xprt_dequeue svc_xprt_enqueue; do
  trace-cmd report -i <file> -F "$ev" 2>&1 | \
    grep "$ev" > /tmp/${ev}.txt
done
```

**grep -oP pipe hazard**: `grep -oP` with broad character-class
patterns (`\S+`, `[^ ]+`) silently produces zero output when
piped on large files (100K+ lines). Narrower patterns like
`\w+` and `[0-9]+` are not affected. Avoid debugging this;
prefer awk for field extraction on large files.

## Compact field extraction

Use awk for `key=value` extraction from saved event files.
These patterns are portable, fast, and immune to the grep
pipe hazard:

```bash
# Extract a single numeric field
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt

# Count distinct values of a field
awk '{for(i=1;i<=NF;i++) if($i ~ /^proc=/)
  {split($i,a,"="); c[a[2]]++}}
  END{for(v in c) printf "%8d %s\n",c[v],v}' /tmp/latency.txt | sort -rn
```

See [references/field-extraction.md](references/field-extraction.md)
for the full recipe set including flag extraction, timestamp
windowing, and large-trace techniques.

## Phase 1: Ingestion

Determine what is available before analyzing:

```bash
trace-cmd report -i <file> --stat
```

### Buffer stats

Always check for data loss and report findings before
proceeding. If any loss counter is non-zero, state this
prominently:

- **overrun**: Ring buffer full, oldest events overwritten.
  Capture is incomplete.
- **commit overrun**: Nested tracing overflow. Should be
  zero; non-zero indicates extreme event rates.
- **dropped events**: Buffer full with overwrite disabled.
  Recent events were discarded.

Any non-zero loss count means overhead percentages and
event pairing are unreliable. The highest-rate events
are the most undercounted. Recommend re-recording with
a larger buffer (`trace-cmd record -b <size_kb>`).

### Trace clock

The `--stat` output shows which trace clock was used.
The `local` clock (default) is per-CPU and not
synchronized -- cross-CPU timestamp deltas are unreliable.
All other clocks (`global`, `mono`, `mono_raw`, `boot`,
`x86-tsc` with invariant TSC) are synchronized.

When cross-CPU event pairing is needed (e.g., enqueue on
one CPU, dequeue on another), check the clock. If `local`,
qualify cross-CPU latency results as approximate. Suggest
`trace-cmd record -C global` or `-C mono` for future
recordings.

### Fallback ingestion

If `--stat` is uninformative:

```bash
# Count events per type
trace-cmd report -i <file> 2>&1 | \
  awk '{for(i=1;i<=NF;i++) if($i ~ /:$/) {sub(/:$/,"",$i); c[$i]++}}
       END{for(e in c) printf "%8d %s\n",c[e],e}' | sort -rn | head -30

# Time range
trace-cmd report -i <file> --first-event
trace-cmd report -i <file> --last-event
```

### Event format discovery

When the capture contains unfamiliar events, extract the
embedded format definitions:

```bash
# List every event format stored in the .dat file
trace-cmd dump -i <file> --events

# Extract one event's format definition
trace-cmd dump -i <file> --events 2>&1 | \
  awk '/^name: svc_stats_latency$/,/^print fmt:/'
```

Do NOT use a blank-line delimiter (`/^$/`) -- format
blocks often lack trailing blank lines. Each format block
lists fields with type, name, offset, and size. Use this
to identify latency values, status codes, and pairing
identifiers rather than guessing from report text.

**Field name caveat**: The field names in `-F` filters
must match the format definition exactly. These often
differ from abbreviated labels in report output. For
example, a field defined as `procedure` may print as
`proc=READ`. The filter `-F 'event: proc == "READ"'`
fails silently. Always verify field names with
`trace-cmd dump --events`.

Exception: `bprint` and `bputs` events (from
`trace_printk()`) have no format block. See
[references/subsystems/trace-printk.md](references/subsystems/trace-printk.md).

Record:
- Total event count
- Time span of the capture
- Event types present
- CPUs and processes involved

## Phase 2: Event-specific analysis

Based on the events present, apply the appropriate strategy.
Multiple strategies may apply to a single capture.

### Latency analysis

For events with duration fields (execute-us, wakeup-us,
qtime-us), extract all values and compute distributions.
Work from saved temp files:

```bash
awk '{for(i=1;i<=NF;i++) if($i ~ /^execute-us=/)
  {split($i,a,"="); print a[2]}}' /tmp/latency.txt | \
  sort -n | \
  awk '{a[NR]=$1; s+=$1} END{n=NR;
    printf "n=%d min=%d p50=%d p90=%d p99=%d max=%d mean=%.0f\n",
      n, a[1], a[int(n*0.5)], a[int(n*0.9)], a[int(n*0.99)], a[n], s/n}'
```

Report: count, min, median, p90, p99, max, mean (and
standard deviation if count > 20).

For paired events without built-in duration (e.g.,
enqueue/dequeue), correlate by a shared key and compute
inter-event latency from timestamps.

Use field-level `-F` filters for targeted outlier
inspection, not for full distribution computation.
See [references/report-options.md](references/report-options.md)
for filter expression syntax.

### Throughput analysis

When the capture contains repeated operations, compute
operations per second (total and per-CPU), burst patterns,
and idle gaps between bursts.

### Phase detection

To identify workload phases (e.g., WRITE vs READ), filter
for a procedure or operation field and extract time
boundaries:

```bash
grep 'proc=WRITE' /tmp/latency.txt | head -1
grep 'proc=WRITE' /tmp/latency.txt | tail -1
```

Then use awk timestamp filters on saved temp files for
per-phase analysis.

### Error and anomaly detection

Scan for:
- Events with "err" in the name
- Non-zero error/status fields
- Unusually long gaps between expected event pairs
- Flag state changes indicating transport distress
  (XPT_CLOSE, XPT_DEAD in svc_xprt_enqueue flags)

## Phase 3: Reporting

Present results as plain text. Structure:

1. **Capture summary** -- time range, event counts, what was traced
2. **Key metrics** -- latency distributions, throughput numbers
3. **Observations** -- patterns, anomalies, bottleneck indicators
4. **Comparison** -- if a baseline trace is available

Latency distribution format:

```
svc_stats_latency (execute-us), N=1284:
  min     p50     p90     p99     max     mean
  12      45      128     892     4201    73
```

## Comparison mode

When the user provides two trace files or references a prior
capture, produce a side-by-side comparison:

```
Metric                  Before      After       Delta
svc_stats_latency p50   45 us       32 us       -29%
svc_stats_latency p99   892 us      410 us      -54%
svc_xprt_dequeue  p50   8 us        5 us        -37%
ops/sec                 28,400      31,200      +10%
```

Focus on metrics relevant to the patch being tested.

## Scope limits

- Does not set up trace-cmd recording sessions, but may
  set up histogram triggers or dynamic probes as part of
  targeted analysis
- Does not modify kernel code
- Does not interpret application-level semantics beyond
  what the trace events encode

## Reference files

- [references/report-options.md](references/report-options.md) --
  report flags, filter expression syntax, `.function` and `CPUS{}` modifiers
- [references/field-extraction.md](references/field-extraction.md) --
  full awk recipe set, flag extraction, large-trace techniques
- [references/histogram-triggers.md](references/histogram-triggers.md) --
  in-kernel histogram aggregation setup
- [references/dynamic-events.md](references/dynamic-events.md) --
  kprobe and fprobe instrumentation
- [references/subsystems/](references/subsystems/) --
  per-subsystem event tables and pairing rules
