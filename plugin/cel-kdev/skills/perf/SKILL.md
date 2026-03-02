---
name: perf
description: Analyze perf profiling data from Linux kernel and application workloads. Load when a perf.data file exists in the working directory, when asked to record a perf profile, analyze perf.data files, examine flamegraphs, or investigate CPU usage and performance bottlenecks.
invocation_policy: automatic
allowed-tools: Bash(*:perf *), Bash(*:sudo perf *)
---

# perf Profiling

Analyze CPU profiling captures to identify hot paths, measure
overhead, and guide optimization. Operate on perf.data files
or pre-generated perf report/script output.

## Recording

Use these options for `perf record`:

```bash
perf record --call-graph fp -F99 <command>
```

| Option | Rationale |
|--------|-----------|
| `--call-graph fp` | Kernel is built with frame pointers (`CONFIG_FRAME_POINTER=y`) |
| `-F99` | 99 Hz sampling avoids lock-step aliasing with timer interrupts |

To profile a running process by PID:

```bash
perf record --call-graph fp -F99 -p <pid>
```

To profile system-wide (all CPUs):

```bash
perf record --call-graph fp -F99 -a
```

Add `-g` to include kernel call chains when profiling
user-space from a non-root context (though `-a` already
implies it). Use `--` to separate perf options from the
target command.

## Reporting

`--kallsyms=/proc/kallsyms` provides the runtime kernel
symbol table, including module symbols at their loaded
addresses. This is required for resolving module symbols;
the build-id cache alone is not sufficient because perf
needs the runtime address-to-module mapping that only
kallsyms provides.

```bash
sudo perf report --kallsyms=/proc/kallsyms
```

`sudo` is needed for access to `/proc/kallsyms` and
`/proc/modules`.

### Non-interactive Report

For scripted analysis or piping, add `--stdio`:

```bash
sudo perf report --kallsyms=/proc/kallsyms --stdio > /tmp/perf-report.txt
```

To limit output depth or sort by specific fields:

```bash
# Flat profile (no call graph unfolding)
sudo perf report --kallsyms=/proc/kallsyms --stdio --no-children

# Sort by overhead, show top 30
sudo perf report --kallsyms=/proc/kallsyms --stdio --no-children | head -80
```

### Caller/Callee View

```bash
sudo perf report --kallsyms=/proc/kallsyms --stdio --call-graph callee
```

### Per-Symbol Drill-Down

```bash
sudo perf report --kallsyms=/proc/kallsyms --stdio --symbol-filter=<function_name>
```

## perf script

For detailed per-sample output (timestamps, stacks, CPUs):

```bash
sudo perf script --kallsyms=/proc/kallsyms > /tmp/perf-script.txt
```

This output is the input for flamegraph generation and
custom post-processing.

### Useful perf script Fields

```bash
# Select specific fields
sudo perf script --kallsyms=/proc/kallsyms \
  -F comm,pid,tid,cpu,time,event,sym,ip,dso
```

## Flamegraphs

Generate flamegraphs from perf script output using Brendan
Gregg's FlameGraph tools:

```bash
sudo perf script --kallsyms=/proc/kallsyms | \
  stackcollapse-perf.pl | flamegraph.pl > /tmp/flame.svg
```

If FlameGraph tools are not in `$PATH`, check
`~/FlameGraph/` or install from:
`https://github.com/brendangregg/FlameGraph`

## perf top

Live sampling display (no perf.data file needed):

```bash
sudo perf top --kallsyms=/proc/kallsyms
```

Add `--call-graph fp` for live call-chain display.

## perf stat

For event counting (no sampling), `perf stat` does not
need the recording options:

```bash
perf stat -e cycles,instructions,cache-misses,branch-misses \
  <command>

# Per-core breakdown
perf stat -e cycles,instructions -a -A -- sleep 5
```

## perf annotate

Source-level annotation of hot functions:

```bash
sudo perf annotate --kallsyms=/proc/kallsyms --stdio --symbol=<function_name>
```

## Analysis Workflow

### Phase 1: Overview

Produce a top-level flat profile to identify the hottest
functions:

```bash
sudo perf report --kallsyms=/proc/kallsyms --stdio --no-children 2>&1 | head -60
```

Record:
- Total sample count
- Top functions and their overhead percentages
- Which DSOs (kernel, modules, user-space) dominate

### Phase 2: Call Chain Analysis

For the top functions identified in Phase 1, examine call
chains to understand why they are hot:

```bash
sudo perf report --kallsyms=/proc/kallsyms --stdio --call-graph callee \
  --symbol-filter=<hot_function>
```

Identify:
- Which callers drive the most overhead into this function
- Whether the cost is from the function itself or its callees
- Common call paths that converge on the hot spot

### Phase 3: Reporting

Present results as plain text. Structure:

1. **Profile summary** - duration, sample count, dominant
   DSOs
2. **Hot functions** - top 5-10 with overhead percentages
3. **Call chain highlights** - notable paths into hot
   functions
4. **Observations** - bottleneck indicators, optimization
   opportunities

When comparing before/after profiles:

```
Function                Before    After     Delta
nfsd_dispatch           12.3%     8.1%      -4.2%
svc_tcp_sendto           8.7%     5.2%      -3.5%
copy_page                6.1%     6.0%      -0.1%
```

## Common Pitfalls

- **Missing symbols**: `[unknown]` entries usually mean
  the module's ELF binary is inaccessible or stripped.
  `--kallsyms=/proc/kallsyms` resolves kernel and module
  symbols via the runtime symbol table. For user-space,
  ensure binaries are not stripped or provide a `--symfs`
  pointing to debuginfo.

- **Broken call graphs**: If call chains show `[unknown]`
  frames mid-stack, a library or module may lack frame
  pointers. Kernel-side stacks should be complete with
  `CONFIG_FRAME_POINTER=y`.

- **Sampling bias at 99 Hz**: A 99 Hz profile captures
  ~99 samples per second per CPU. Short-lived operations
  (under 10 ms) may not appear. Increase `-F` for finer
  granularity at the cost of higher overhead.

- **perf.data location**: `perf record` writes to
  `./perf.data` by default. Use `-o <path>` to write
  elsewhere. `perf report` reads `./perf.data` by default;
  use `-i <path>` to specify a different file.
