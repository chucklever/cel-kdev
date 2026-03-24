# perf subcommands reference

## perf script

For detailed per-sample output (timestamps, stacks, CPUs):

```bash
sudo perf script --kallsyms=/tmp/vmlinux-kallsyms.txt \
  > /tmp/perf-script.txt
```

This output is the input for flamegraph generation and
custom post-processing.

### Useful fields

```bash
sudo perf script --kallsyms=/tmp/vmlinux-kallsyms.txt \
  -F comm,pid,tid,cpu,time,event,sym,ip,dso
```

## Flamegraphs

Generate flamegraphs from perf script output using Brendan
Gregg's FlameGraph tools:

```bash
sudo perf script --kallsyms=/tmp/vmlinux-kallsyms.txt | \
  stackcollapse-perf.pl | flamegraph.pl > /tmp/flame.svg
```

If FlameGraph tools are not in `$PATH`, check
`~/FlameGraph/` or install from:
`https://github.com/brendangregg/FlameGraph`

## perf top

Live sampling display (no perf.data file needed):

```bash
sudo perf top --kallsyms=/tmp/vmlinux-kallsyms.txt
```

Add `--call-graph fp` for live call-chain display.

## perf stat

For event counting (no sampling):

```bash
perf stat -e cycles,instructions,cache-misses,branch-misses \
  <command>

# Per-core breakdown (system-wide requires sudo)
sudo perf stat -e cycles,instructions -a -A -- sleep 5
```

## perf annotate

Source-level annotation of hot functions:

```bash
sudo perf annotate --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --symbol=<function_name>
```

## perf diff

Compare before/after profiles to quantify the impact of
a code change or tuning adjustment:

```bash
sudo perf diff /tmp/before.data /tmp/after.data \
  --kallsyms=/tmp/vmlinux-kallsyms.txt
```

Use the stripped kallsyms file to preserve per-module DSO
attribution. If any data file was recorded on the currently
running kernel and `--kallsyms=/proc/kallsyms` is used,
all module symbols collapse into `[kernel.kallsyms]`,
preventing accurate per-module comparison.

`perf diff` is always stdio-only (no TUI mode), so
`--stdio` is neither needed nor accepted.

Output shows baseline overhead, the delta, and the
symbol name. Positive deltas indicate functions that
grew hotter; negative deltas indicate improvement.

Sort by delta magnitude:

```bash
sudo perf diff /tmp/before.data /tmp/after.data \
  --kallsyms=/tmp/vmlinux-kallsyms.txt --sort delta
```

## perf lock

Use when `perf report` shows spinlock or mutex functions
dominating overhead (e.g., `_raw_spin_lock`, `mutex_lock`,
`rwsem_down_read_slowpath`).

```bash
# Record lock events
sudo perf lock record -- sleep 10
sudo perf lock record -a -- sleep 10   # system-wide

# Report contention
sudo perf lock report --stdio
```

The report shows per-lock statistics: acquisitions,
contention count, average/total/max wait time. Sort
by total wait time to find the locks causing the most
cumulative delay.

`perf lock contention` provides a more focused view:

```bash
sudo perf lock contention --stdio
```

For call-chain context on which code paths contend:

```bash
sudo perf lock record --call-graph fp -- sleep 10
sudo perf lock contention --stdio --call-graph
```

## perf sched

Use when investigating latency not explained by CPU
overhead -- threads waiting long periods to be scheduled,
excessive migration between CPUs, or unexplained idle
time on busy systems.

```bash
# Record scheduler events
sudo perf sched record -- sleep 10
sudo perf sched record -a -- sleep 10   # system-wide
```

### Latency summary

```bash
sudo perf sched latency --stdio
```

Shows per-task maximum and average scheduling latency
(time between wakeup and actually running). Latencies
above 1 ms are noteworthy; above 10 ms usually
indicates contention for CPU time or priority inversion.

### Time history

```bash
sudo perf sched timehist
```

Detailed per-event timeline showing context switches,
wakeup-to-run latency, and run duration for each task.
Add `--cpu <N>` to filter by CPU.

### Scheduler map

```bash
sudo perf sched map
```

Visual CPU-to-task mapping over time. Frequent task
migration between CPUs suggests missing CPU affinity
or an overloaded subset of cores.

## perf probe

Create dynamic tracepoints for ad-hoc instrumentation
without modifying kernel source.

Dynamic probes persist until explicitly removed.

### Adding probes

```bash
# At function entry
sudo perf probe --add <function_name>

# At a specific line (requires debuginfo)
sudo perf probe --add '<function_name>:<line_number>'

# Capture local variables
sudo perf probe --add '<function_name> var1 var2'

# Return probe
sudo perf probe --add '<function_name>%return $retval'
```

### Recording and analyzing

```bash
sudo perf record -e probe:<probe_name> -a -- sleep 10
sudo perf script --kallsyms=/tmp/vmlinux-kallsyms.txt
```

### Measuring function duration

Combine entry and return probes:

```bash
sudo perf probe --add 'myentry=<function_name>'
sudo perf probe --add 'myreturn=<function_name>%return'
sudo perf record -e probe:myentry -e probe:myreturn \
  -a -- sleep 10
```

Correlate timestamps in `perf script` output by CPU
and PID to compute per-invocation duration.

### Cleanup

```bash
sudo perf probe --del <probe_name>
# or remove all probes
sudo perf probe --del '*'
```

List active probes with `sudo perf probe --list`.

## perf c2c

Use when profiling reveals high overhead in memory access
paths but the cause is not obvious from call chains alone
-- this often indicates false sharing or cache line
contention across CPUs. Requires hardware memory access
sampling (Intel PEBS or AMD IBS).

```bash
# Record memory accesses
sudo perf c2c record -a -- sleep 10

# Report cache line contention
sudo perf c2c report --stdio
```

The report groups memory accesses by cache line and shows
cross-CPU invalidation traffic (HITM events). Cache lines
with HITM percentages above a few percent of total
load/store samples warrant investigation.

The "Shared Data Cache Line" table identifies the
offending cache lines with their symbols and source
locations. If two frequently-accessed fields land in
the same cache line but are written by different CPUs,
that is false sharing. Cross-reference with structure
layouts to determine whether padding,
`____cacheline_aligned`, or per-CPU data conversion
is appropriate.
