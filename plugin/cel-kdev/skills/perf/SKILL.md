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
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 <command>
```

| Option | Rationale |
|--------|-----------|
| `-e cycles -e cpu-clock` | `cpu-clock` provides a wall-clock baseline for measuring true CPU idle time (see Common Pitfalls) |
| `--call-graph fp` | Kernel is built with frame pointers (`CONFIG_FRAME_POINTER=y`) |
| `-F99` | 99 Hz sampling avoids lock-step aliasing with timer interrupts |

To profile a running process by PID:

```bash
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 -p <pid>
```

To profile system-wide (all CPUs):

```bash
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 -a
```

`sudo` is needed for system-wide profiling (`-a`) and
for access to kernel symbols during later analysis.
Use it consistently for all `perf record` invocations
to avoid permission issues.

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
perf report --kallsyms=/proc/kallsyms
```

Do not use `sudo` for `perf report`, `perf diff`,
`perf script`, or `perf annotate`. Running as root
allows perf to open `/proc/kcore`, which collapses
all kernel module boundaries into a single
`[kernel.kallsyms]` DSO. This breaks `--dsos`
filtering by module name (see Common Pitfalls).

If module symbols still appear as hex addresses after using
`--kallsyms`, add `--symfs=/` so perf can locate the module
ELF files under `/lib/modules/` for full symbol resolution:

```bash
perf report --kallsyms=/proc/kallsyms --symfs=/
```

`--kallsyms` maps addresses to symbol names, but perf also
needs access to the module `.ko` files for certain operations
(annotation, inline frame expansion, DSO-level grouping).
`--symfs=/` directs perf to search the live root filesystem
for these binaries.

### Non-interactive Report

For scripted analysis or piping, add `--stdio`:

```bash
perf report --kallsyms=/proc/kallsyms --stdio > /tmp/perf-report.txt
```

To limit output depth or sort by specific fields:

```bash
# Flat profile (no call graph unfolding)
perf report --kallsyms=/proc/kallsyms --stdio --no-children

# Sort by overhead, show top entries (head -80 accounts
# for perf's header lines, yielding ~30 symbols)
perf report --kallsyms=/proc/kallsyms --stdio --no-children | head -80
```

### Caller/Callee View

```bash
perf report --kallsyms=/proc/kallsyms --stdio --call-graph callee
```

### Multi-Event Data

When recording with multiple events (`-e cycles -e cpu-clock`),
`perf report` outputs a separate histogram section for each
event. There is no `-e` flag on `perf report` to select a
single event. When piping through `head`, only the first
event's section may be visible.

To reach the cycles section (typically the second):

```bash
perf report --kallsyms=/proc/kallsyms --stdio \
  --no-children --comms=nfsd 2>&1 | \
  grep -A 200 'Samples:.*cycles'
```

The `cpu-clock` section includes idle time (useful for
utilization analysis). The `cycles` section excludes
C-state idle and concentrates on actual CPU work (useful
for optimization analysis). Always check which section
you are reading.

### Per-Symbol Drill-Down

```bash
perf report --kallsyms=/proc/kallsyms --stdio --symbol-filter=<function_name>
```

Note: `perf report` uses `--symbol-filter`; `perf annotate`
uses `--symbol`. These are different flags on different
subcommands.

**Caveat**: `--symbol-filter` with `--call-graph callee`
shows the filtered symbol and its full ancestor chain in
the hierarchy, not just its callees. To isolate the self
cost of specific functions, use `-S` instead:

```bash
# Self overhead of specific symbols only
perf report --kallsyms=/proc/kallsyms --stdio \
  --no-children --comms=nfsd \
  -S func_a,func_b,func_c
```

To find everything called beneath a parent function,
use the `-p` (parent) filter:

```bash
# All symbols with <parent_function> in their call chain
perf report --kallsyms=/proc/kallsyms --stdio \
  --no-children --comms=nfsd -p <parent_function>
```

## perf script

For detailed per-sample output (timestamps, stacks, CPUs):

```bash
perf script --kallsyms=/proc/kallsyms > /tmp/perf-script.txt
```

This output is the input for flamegraph generation and
custom post-processing.

### Useful perf script Fields

```bash
# Select specific fields
perf script --kallsyms=/proc/kallsyms \
  -F comm,pid,tid,cpu,time,event,sym,ip,dso
```

## Flamegraphs

Generate flamegraphs from perf script output using Brendan
Gregg's FlameGraph tools:

```bash
perf script --kallsyms=/proc/kallsyms | \
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

# Per-core breakdown (system-wide requires sudo)
sudo perf stat -e cycles,instructions -a -A -- sleep 5
```

## perf annotate

Source-level annotation of hot functions:

```bash
perf annotate --kallsyms=/proc/kallsyms --stdio --symbol=<function_name>
```

## perf diff

Use `perf diff` when comparing before/after profiles
to quantify the impact of a code change or tuning
adjustment. It replaces manual table construction with
automated delta computation.

```bash
perf diff /tmp/before.data /tmp/after.data \
  --kallsyms=/proc/kallsyms --stdio
```

Output shows baseline overhead, the delta, and the
symbol name. Positive deltas indicate functions that
grew hotter; negative deltas indicate improvement.

To focus on the largest changes:

```bash
perf diff /tmp/before.data /tmp/after.data \
  --kallsyms=/proc/kallsyms --stdio -o 0.5
```

`-o 0.5` filters out symbols with less than 0.5%
absolute delta, reducing noise from unchanged functions.

Sort by delta magnitude to surface the most significant
shifts:

```bash
perf diff /tmp/before.data /tmp/after.data \
  --kallsyms=/proc/kallsyms --stdio --sort delta
```

## perf lock

Use `perf lock` when `perf report` shows spinlock or
mutex functions dominating overhead (e.g., `_raw_spin_lock`,
`mutex_lock`, `rwsem_down_read_slowpath`).

```bash
# Record lock events (requires CONFIG_LOCK_STAT or
# CONFIG_LOCKDEP, and tracepoints enabled)
sudo perf lock record -- sleep 10
sudo perf lock record -a -- sleep 10   # system-wide

# Or record with a specific workload
sudo perf lock record -- <command>
```

Report contention:

```bash
perf lock report --stdio
```

The report shows per-lock statistics: number of
acquisitions, contention count, average and total wait
time, and max wait time. Sort by total wait time to
find the locks causing the most cumulative delay.

`perf lock contention` provides a more focused view
when supported:

```bash
perf lock contention --stdio
```

For call-chain context on which code paths contend:

```bash
sudo perf lock record --call-graph fp -- sleep 10
perf lock contention --stdio --call-graph
```

## perf sched

Use `perf sched` when investigating latency that is not
explained by CPU overhead — threads waiting long periods
to be scheduled, excessive migration between CPUs, or
unexplained idle time on busy systems.

```bash
# Record scheduler events
sudo perf sched record -- sleep 10
sudo perf sched record -a -- sleep 10   # system-wide
```

### Latency summary

```bash
perf sched latency --stdio
```

Shows per-task maximum and average scheduling latency
(time between wakeup and actually running). Latencies
above 1 ms are noteworthy; above 10 ms usually
indicates contention for CPU time or priority
inversion.

### Time history

```bash
perf sched timehist
```

Detailed per-event timeline showing context switches,
wakeup-to-run latency, and run duration for each task.
Add `--cpu <N>` to filter by CPU.

### Scheduler statistics

```bash
perf sched map
```

Visual CPU-to-task mapping over time. Frequent task
migration between CPUs suggests missing CPU affinity
or an overloaded subset of cores. Idle CPUs alongside
busy ones indicate imbalanced load distribution.

## perf probe

Use `perf probe` to create dynamic tracepoints for
ad-hoc instrumentation without modifying kernel source
or inserting `trace_printk()` calls.

Dynamic probes persist until explicitly removed.
Follow this sequence:

1. Add probes:

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

2. Record:

```bash
sudo perf record -e probe:<probe_name> -a -- sleep 10
```

3. Analyze:

```bash
perf script --kallsyms=/proc/kallsyms
```

4. Clean up probes when finished:

```bash
sudo perf probe --del <probe_name>
# or remove all probes
sudo perf probe --del '*'
```

List active probes with `sudo perf probe --list`.

### Measuring function duration

Combine entry and return probes to measure per-call
duration without kernel changes:

```bash
sudo perf probe --add 'myentry=<function_name>'
sudo perf probe --add 'myreturn=<function_name>%return'
sudo perf record -e probe:myentry -e probe:myreturn \
  -a -- sleep 10
```

Correlate timestamps in `perf script` output by CPU
and PID to compute per-invocation duration. Clean up
both probes afterward:

```bash
sudo perf probe --del 'myentry' --del 'myreturn'
```

## perf c2c

Use `perf c2c` when profiling reveals high overhead in
memory access paths but the cause is not obvious from
call chains alone — this often indicates false sharing
or cache line contention across CPUs. Requires hardware
memory access sampling (Intel PEBS on Intel, IBS on AMD).

```bash
# Record memory accesses
sudo perf c2c record -a -- sleep 10

# Report cache line contention
perf c2c report --stdio
```

The report groups memory accesses by cache line and
shows cross-CPU invalidation traffic (HITM events).
Cache lines with HITM percentages above a few percent
of total load/store samples warrant investigation.

The "Shared Data Cache Line" table identifies the
offending cache lines with their symbols and source
locations. If two frequently-accessed fields land in
the same cache line but are written by different CPUs,
that is false sharing. Cross-reference with structure
layouts to determine whether padding,
`____cacheline_aligned`, or per-CPU data conversion
is appropriate.

## Cache and Memory Events

The generic perf events (`LLC-load-misses`,
`LLC-store-misses`, `cache-misses`) work on Intel but
are not mapped on AMD Zen. This section covers
platform-specific events for cache hierarchy analysis,
memory bandwidth measurement, and lock contention
characterization.

### Detecting the platform

```bash
# Check CPU vendor
grep -m1 vendor_id /proc/cpuinfo
```

### AMD EPYC (Zen 3/4/5)

AMD exposes cache events through two PMU layers:

**L3 uncore events** (`amd_l3` PMU) are system-wide,
per-CCX counters. They require `-a` and do not
distinguish loads from stores — the L3 sees coherence
requests, not individual load/store instructions.

```bash
# L3 miss count and miss ratio
sudo perf stat -a \
  -e amd_l3/event=0x04,umask=0x01/ \
  -e amd_l3/event=0x04,umask=0xff/ \
  -- sleep 10
```

If the perf binary was built with JSON event tables,
symbolic names work:

```bash
sudo perf stat -a \
  -e l3_lookup_state.l3_miss \
  -e l3_lookup_state.all_coherent_accesses_to_l3 \
  -- sleep 10
```

**Core fill events** (`ls_dmnd_fills_from_sys`, event
0x43) are per-core and support per-process measurement.
They classify demand data cache fills by where the data
came from:

| Umask | Name | Source | Implication |
|-------|------|--------|-------------|
| 0x01 | `local_l2` | L2 cache | L1 miss, L2 hit |
| 0x02 | `local_ccx` | L3 or sibling L2 | L2 miss, L3 hit |
| 0x04 | `near_cache` | Another CCX, same NUMA | Cross-CCX coherence |
| 0x08 | `dram_io_near` | Local NUMA DRAM/MMIO | **L3 miss** |
| 0x10 | `far_cache` | Another CCX, remote NUMA | Remote coherence |
| 0x40 | `dram_io_far` | Remote NUMA DRAM/MMIO | **L3 miss, remote** |
| 0xff | `all` | All sources | Total fills |

Fills from `dram_io_near` + `dram_io_far` necessarily
missed L3. This is the per-process equivalent of
`LLC-load-misses`:

```bash
sudo perf stat \
  -e ls_dmnd_fills_from_sys.dram_io_near \
  -e ls_dmnd_fills_from_sys.dram_io_far \
  -e ls_dmnd_fills_from_sys.all \
  -- workload
```

**L3 miss latency** (Zen 4+):

```bash
sudo perf stat -a -M l3_read_miss_latency -- sleep 10
```

**Memory bandwidth**:

```bash
sudo perf stat -a \
  -M umc_mem_read_bandwidth,umc_mem_write_bandwidth \
  -- sleep 10
```

#### I/O workload recipe

For network I/O workloads (NFS, iSCSI, etc.) where
data flows between NIC DMA and kernel buffers:

```bash
sudo perf stat -a \
  -e l3_lookup_state.l3_miss \
  -e l3_lookup_state.all_coherent_accesses_to_l3 \
  -e ls_dmnd_fills_from_sys.dram_io_near \
  -e ls_dmnd_fills_from_sys.dram_io_far \
  -e ls_dmnd_fills_from_sys.near_cache \
  -e ls_dmnd_fills_from_sys.far_cache \
  -- sleep 10
```

High `dram_io_*` counts relative to total fills
indicate the working set exceeds the L3. High
`near_cache` / `far_cache` counts indicate cross-CCX
cacheline sharing — data touched by one CCX (e.g.,
NIC interrupt handler) then consumed by another
(e.g., nfsd thread).

#### Spinlock contention recipe

When `perf report` shows `native_queued_spin_lock_slowpath`
or `mutex_spin_on_owner`, the contended cacheline is
bouncing between cores. Characterize the cross-core
traffic:

```bash
sudo perf stat -a \
  -e ls_dmnd_fills_from_sys.local_ccx \
  -e ls_dmnd_fills_from_sys.near_cache \
  -e ls_dmnd_fills_from_sys.far_cache \
  -e ls_any_fills_from_sys.remote_cache \
  -- sleep 10
```

High `remote_cache` (cross-CCX) fill counts during
lock contention indicate the lock cacheline is
migrating across CCX boundaries. Pinning contending
threads to the same CCX via CPU affinity, or
restructuring to reduce cross-CCX sharing, can
reduce this overhead.

Combine with `perf c2c` (which uses IBS on AMD) to
identify the specific cache lines and data structures
involved.

### Intel (Skylake / Ice Lake and later)

The generic events work directly:

```bash
sudo perf stat \
  -e LLC-load-misses \
  -e LLC-store-misses \
  -e LLC-loads \
  -e LLC-stores \
  -- workload
```

For finer-grained fill source analysis, use
`mem_load_retired` events (Skylake+):

```bash
sudo perf stat \
  -e mem_load_retired.l3_miss \
  -e mem_load_retired.l3_hit \
  -e mem_load_retired.l2_miss \
  -e mem_load_retired.l2_hit \
  -- workload
```

For memory bandwidth, use the uncore IMC
(integrated memory controller) events or the
`-M` metric groups if available:

```bash
sudo perf stat -a -M Memory_BW -- sleep 10
```

For lock contention, the same `perf c2c` workflow
applies (using PEBS on Intel instead of IBS).

## Filtering

### By DSO (module or binary)

```bash
perf report --kallsyms=/proc/kallsyms --stdio \
  --dsos='[sunrpc]'

# Multiple DSOs
perf report --kallsyms=/proc/kallsyms --stdio \
  --dsos='[nfsd],[sunrpc],[svcrdma]'
```

Bracket syntax `[name]` denotes kernel modules.
User-space binaries use their full path or basename.

**Caveat**: `--dsos` only works for loadable kernel
modules (`.ko` files), not for subsystems built into
vmlinux. If a subsystem (e.g., sunrpc, nfsd) is
compiled in rather than loaded as a module, its symbols
appear under `[kernel.kallsyms]` and cannot be isolated
with `--dsos`. Use `--comms`, `-S`, or `-p` filters
instead.

### By CPU

```bash
perf report --kallsyms=/proc/kallsyms --stdio \
  --cpu=0,1,2

# CPU range
perf report --kallsyms=/proc/kallsyms --stdio \
  --cpu=0-3
```

### By time window

```bash
# Show only samples between 5% and 50% of the
# recording duration
perf report --kallsyms=/proc/kallsyms --stdio \
  --time '5%,50%'

# Absolute time range (seconds from start)
perf script --kallsyms=/proc/kallsyms \
  --time '10.0,20.0'
```

### By comm (process name)

```bash
perf report --kallsyms=/proc/kallsyms --stdio \
  --comms=nfsd

perf script --kallsyms=/proc/kallsyms \
  --comms=nfsd,kworker
```

### Combined filters

Filters compose: `--dsos`, `--cpu`, `--comms`, and
`--time` can all be used together to narrow analysis
to a specific module on specific CPUs during a
specific time window.

## Analysis Workflow

### Phase 1: Overview

Produce a top-level flat profile to identify the hottest
functions:

```bash
perf report --kallsyms=/proc/kallsyms --stdio --no-children 2>&1 | head -60
```

Record:
- Total sample count
- Top functions and their overhead percentages
- Which DSOs (kernel, modules, user-space) dominate

### Phase 2: Call Chain Analysis

For the top functions identified in Phase 1, examine call
chains to understand why they are hot:

```bash
perf report --kallsyms=/proc/kallsyms --stdio --call-graph callee \
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

When comparing before/after profiles, use `perf diff`
(see above) for automated comparison. For manual
summaries in reports:

```
Function                Before    After     Delta
nfsd_dispatch           12.3%     8.1%      -4.2%
svc_tcp_sendto           8.7%     5.2%      -3.5%
copy_page                6.1%     6.0%      -0.1%
```

## Common Pitfalls

- **Missing symbols**: `[unknown]` entries usually mean
  the module's ELF binary is inaccessible or stripped.
  See the Reporting section above for the `--kallsyms`
  and `--symfs=/` options that resolve kernel and module
  symbols. For user-space, ensure binaries are not
  stripped or provide a `--symfs` pointing to debuginfo.

- **Broken call graphs**: If call chains show `[unknown]`
  frames mid-stack, a library or module may lack frame
  pointers. Kernel-side stacks should be complete with
  `CONFIG_FRAME_POINTER=y`.

- **Sampling bias at 99 Hz**: A 99 Hz profile captures
  ~99 samples per second per CPU. Short-lived operations
  (under 10 ms) may not appear. Increase `-F` for finer
  granularity at the cost of higher overhead.

- **Idle time invisible to cycles profiling**: When a
  CPU enters a hardware C-state (via `cpuidle_enter_state`,
  `intel_idle`, `poll_idle`, etc.), the PMU stops counting
  cycles. Samples attributed to idle functions represent
  only the brief entry/exit path, not time spent sleeping.
  Do not use `swapper` or idle function overhead
  percentages from a cycles profile as idle time
  estimates — they dramatically undercount actual idle
  time.

  To measure real per-CPU utilization, add `cpu-clock`
  as a second event when recording:

  ```bash
  sudo perf record -e cycles -e cpu-clock \
    --call-graph fp -F99 -a
  ```

  Then compare the per-CPU sample distributions of
  each event:

  ```bash
  perf report --kallsyms=/proc/kallsyms \
    --stdio --no-children -s cpu
  ```

  The output contains separate histograms for each
  event. `cpu-clock` is a software event that ticks
  on wall-clock time regardless of C-state, so its
  samples distribute uniformly across CPUs. `cycles`
  samples concentrate on busy CPUs. A CPU showing
  10% of `cpu-clock` samples but 1% of `cycles`
  samples is mostly idle; one showing 10% of both
  is fully busy.

- **Garbled module symbols from inlining**: When call
  chains show implausible function names (e.g. READ
  functions appearing in a WRITE workload), the cause
  is aggressive inlining creating large gaps in the
  symbol table. Return addresses that fall inside an
  inlined region are attributed to whatever unrelated
  symbol precedes them in the address space.

  Diagnostic: check the addresses of the suspect
  symbols in `/proc/kallsyms` and compare them against
  the actual caller function's address range. If the
  suspect symbols sit in the gap between two large
  functions, inlining is the cause.

  `--no-inline` does not fix this — the problem is in
  the base symbol lookup, not DWARF inline expansion.
  Kernels built with `CONFIG_CC_OPTIMIZE_FOR_SIZE=y`
  (`-Os`) and recent GCC versions are most affected.
  Building the module of interest with
  `CFLAGS_<file>.o += -fno-inline` in the Makefile
  during profiling sessions restores symbol accuracy
  at the cost of changing the code layout slightly.

- **AMD SRSO mitigations**: On AMD Zen 3/4 CPUs,
  `srso_alias_safe_ret` and `srso_alias_return_thunk`
  appear as overhead from the Speculative Return Stack
  Overflow mitigation. This is an AMD-specific retbleed
  variant. In trusted environments, `spec_rstack_overflow=off`
  on the kernel command line eliminates this cost.

- **Distribution security hardening**: Fedora and similar
  distributions enable security features that add
  measurable profiling overhead. These are not bugs:

  - `CONFIG_HARDENED_USERCOPY`: `check_heap_object`,
    `__check_object_size`, `__virt_addr_valid` appear in
    data copy paths (e.g., `simple_copy_to_iter` during
    TCP receive). Can add several percent overhead to
    memcpy-heavy workloads.

  - `init_on_alloc=1` (boot parameter): The page allocator
    zeros all pages at allocation time. Shows up as
    `clear_page_erms` under `alloc_pages_bulk_noprof` even
    when the caller did not request `__GFP_ZERO`. Check
    `/proc/cmdline` before attributing page-clearing
    overhead to the calling code.

  When profiling for optimization, note these costs
  separately — they represent the distribution's security
  tax, not inefficiency in the code under analysis.

- **kcore collapses module DSOs**: When `perf report`
  runs as root, it can open `/proc/kcore`. If the
  perf.data was recorded on the currently running
  kernel, perf matches the kcore build-id embedded
  in the recording, opens kcore, and maps the entire
  kernel address space as a single monolithic DSO.
  All module symbols then appear under
  `[kernel.kallsyms]` rather than their respective
  `[rpcrdma]`, `[nfsd]`, `[sunrpc]` DSOs. This
  silently breaks `--dsos` filtering by module name
  -- the filter matches nothing and the report is
  empty.

  Run `perf report` (and `perf diff`, `perf script`,
  `perf annotate`) without `sudo` to prevent kcore
  access and preserve per-module DSO attribution.
  `sudo` is needed only for `perf record` and
  `perf top`.

- **perf.data location**: `perf record` writes to
  `./perf.data` by default. Use `-o <path>` to write
  elsewhere. `perf report` reads `./perf.data` by default;
  use `-i <path>` to specify a different file.
