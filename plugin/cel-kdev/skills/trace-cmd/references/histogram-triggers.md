# In-kernel histogram triggers

When a capture shows ring buffer overruns, histogram
triggers can aggregate data inside the kernel without
generating individual trace records. The aggregation is
lossless regardless of event rate. Set up histograms when
per-event capture has proven insufficient, or when only
distribution shape matters.

## Basic syntax

`hist:key=<field>:val=<field>:sort=<field>.<order>`

Histograms are written to the event's trigger file
and read back from its hist file:

```bash
# Set up a histogram keyed on call_site with byte totals
echo 'hist:key=call_site.sym:val=bytes_req:sort=bytes_req.descending' > \
  /sys/kernel/tracing/events/kmem/kmalloc/trigger

# Let the workload run, then read results
cat /sys/kernel/tracing/events/kmem/kmalloc/hist

# Clean up -- prefix with ! to remove
echo '!hist:key=call_site.sym:val=bytes_req' > \
  /sys/kernel/tracing/events/kmem/kmalloc/trigger
```

## Key modifiers

| Modifier | Effect |
|----------|--------|
| `.sym` | Address to symbol name |
| `.execname` | PID to comm name |
| `.log2` | Logarithmic bucketing |
| `.buckets=N` | Fixed-width bucketing |
| `.usecs` | Timestamp as microseconds |

Use `common_stacktrace` as a key for stack-keyed
aggregation.

## Compound keys

Up to three fields can be combined as keys, producing
per-combination entries.

The implicit `hitcount` val tracks event count.

## Runtime control

Control a running histogram without removing it by
appending `:pause`, `:continue`, or `:clear` with
`>>` (append mode).

## Cleanup

Always clean up histogram triggers after reading
results. Triggers persist until explicitly removed.
