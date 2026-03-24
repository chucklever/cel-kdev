# trace-cmd report options and filter expressions

## Useful report flags

| Flag | Purpose |
|------|---------|
| `--first-event` | Timestamp of first event per CPU |
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

## Filter expressions

The `-F` flag accepts the kernel's event filter syntax,
not just bare event names. Filters select on individual
fields using relational operators, combined with `&&`
and `||`:

```bash
# Numeric field exceeds a threshold
trace-cmd report -i <file> \
  -F 'svc_stats_latency: execute-us > 1000'

# String glob matching (~ operator)
trace-cmd report -i <file> \
  -F 'svc_process: procedure ~ "*READ*"'

# Compound filter
trace-cmd report -i <file> \
  -F 'svc_xprt_dequeue: qtime-us > 500 || wakeup-us > 500'

# Filter by task name (COMM pseudo-field, all events)
trace-cmd report -i <file> -F '.*:COMM == "nfsd"'

# Invert: exclude matching events with -v before -F
trace-cmd report -i <file> -v -F 'svc_xprt_enqueue'
```

Numeric operators: `==`, `!=`, `<`, `<=`, `>`, `>=`,
`&` (bitmask).
String operators: `==`, `!=`, `~` (glob with `*`, `?`,
`[]`).

## .function modifier

The `.function` postfix converts a `long` field to a
function address range, allowing filtering by kernel
function name instead of raw address:

```bash
# Events where call_site falls within security_prepare_creds
trace-cmd report -i <file> \
  -F 'kmalloc: call_site.function == security_prepare_creds'
```

`.function` only works on `long`-sized fields and only
with `==` or `!=`. Use when attributing allocations or
other addressed operations to a specific kernel function.

## CPUS{} modifier

For cpumask fields or scalar fields encoding a CPU
number:

```bash
# Events where target_cpu is in the given set
trace-cmd report -i <file> \
  -F 'sched_switch: target_cpu & CPUS{0-3,8-11}'
```

Use `CPUS{}` when isolating events to a CPU range or
NUMA node.

## COMM pseudo-field

The `-F` filter supports a `COMM` pseudo-field for
matching the task name:

```bash
trace-cmd report -i <file> -F '.*:COMM != "trace-cmd"'
```

## Field name caveat

Field names in `-F` filters must match the kernel event
format definition exactly. These often differ from
abbreviated labels in report output. Use
`trace-cmd dump -i <file> --events` to discover exact
field names.

When field-level filters fail, fall back to awk-based
post-processing on saved report output (see
field-extraction.md).

Field-level filters are for targeted inspection: finding
outliers, isolating errors, or narrowing output before
reading individual events. They are not a substitute for
the full-extraction pipeline used in latency analysis.
