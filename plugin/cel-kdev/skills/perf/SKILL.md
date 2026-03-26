---
name: perf
description: >-
  Linux perf profiling and tracing. Guides perf record, perf report,
  perf diff, perf stat, flamegraph generation, and cache/lock/scheduler
  analysis. Handles symbol resolution, DSO attribution, AMD and Intel
  platform events, and common profiling pitfalls.
invocation_policy: automatic
---

# perf profiling

Analyze CPU profiling captures to identify hot paths, measure
overhead, and guide optimization. Operate on perf.data files
or pre-generated perf report/script output.

## Key defaults

### Standard recording invocation

```bash
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 <command>
```

| Option | Rationale |
|--------|-----------|
| `-e cycles -e cpu-clock` | `cpu-clock` provides a wall-clock baseline for measuring true CPU idle time (see Pitfalls) |
| `--call-graph fp` | Kernel is built with frame pointers (`CONFIG_FRAME_POINTER=y`) |
| `-F99` | 99 Hz sampling avoids lock-step aliasing with timer interrupts |

Add `-p <pid>` for a running process or `-a` for system-wide.

### Stripped kallsyms for DSO attribution

Generate once before analysis:

```bash
sudo grep -v '\[' /proc/kallsyms > /tmp/vmlinux-kallsyms.txt
```

This removes module symbols so perf resolves vmlinux
addresses from the file and module addresses from the
recorded MMAP records, preserving per-module DSO
attribution. Without this, `--kallsyms=/proc/kallsyms`
collapses all kernel symbols into `[kernel.kallsyms]`.

Pass `--kallsyms=/tmp/vmlinux-kallsyms.txt` to all
`perf report`, `perf script`, and `perf annotate`
invocations. `perf diff` does not support `--vmlinux`,
so the stripped kallsyms workaround is the only way to
maintain DSO separation in comparisons.

## Analysis workflow

### Phase 1: Overview

Produce a top-level flat profile:

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --no-children 2>&1 | head -60
```

Record:
- Total sample count
- Top functions and their overhead percentages
- Which DSOs (kernel, modules, user-space) dominate

### Phase 2: Call chain analysis

For the top functions, examine call chains:

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --call-graph callee \
  --symbol-filter=<hot_function>
```

Identify:
- Which callers drive the most overhead into this function
- Whether the cost is from the function itself or its callees
- Common call paths that converge on the hot spot

### Phase 3: Reporting

Present results as plain text:

1. **Profile summary** -- duration, sample count, dominant DSOs
2. **Hot functions** -- top 5-10 with overhead percentages
3. **Call chain highlights** -- notable paths into hot functions
4. **Observations** -- bottleneck indicators, optimization
   opportunities

When comparing before/after profiles, use `perf diff`
for automated comparison (see references/subcommands.md).

## Common pitfalls

- **Missing symbols**: `[unknown]` entries usually mean
  the module's ELF binary is inaccessible or stripped.
  Use `--kallsyms` or `--symfs=/` to resolve kernel and
  module symbols. For user-space, ensure binaries are not
  stripped or provide `--symfs` pointing to debuginfo.

- **Broken call graphs**: `[unknown]` frames mid-stack
  indicate a library or module lacks frame pointers.
  Kernel-side stacks should be complete with
  `CONFIG_FRAME_POINTER=y`.

- **No `-e` on `perf report`**: `perf report` has no `-e`
  flag to select a single event from multi-event data.
  Each event produces a separate histogram section in the
  output. Use `grep -A` to reach the desired section
  (see references/reporting.md for examples).

- **Sampling bias at 99 Hz**: A 99 Hz profile captures
  ~99 samples per second per CPU. Short-lived operations
  (under 10 ms) may not appear. Increase `-F` for finer
  granularity at the cost of higher overhead.

- **Idle time invisible to cycles profiling**: When a
  CPU enters a hardware C-state, the PMU stops counting
  cycles. Samples attributed to idle functions represent
  only the brief entry/exit path, not time spent sleeping.
  Do not use `swapper` or idle function overhead from a
  cycles profile as idle time estimates.

  Compare `cpu-clock` (wall-clock, uniform across CPUs)
  against `cycles` (concentrates on busy CPUs) to measure
  real utilization:

  ```bash
  sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
    --stdio --no-children -s cpu
  ```

  A CPU showing 10% of `cpu-clock` samples but 1% of
  `cycles` samples is mostly idle; one showing 10% of
  both is fully busy.

- **Garbled module symbols from inlining**: When call
  chains show implausible function names (e.g., READ
  functions in a WRITE workload), aggressive inlining
  creates large gaps in the symbol table. Return addresses
  in the gap are attributed to whatever unrelated symbol
  precedes them. `--no-inline` does not fix this.
  Building the module with `CFLAGS_<file>.o += -fno-inline`
  restores accuracy at the cost of changing code layout.

- **AMD SRSO mitigations**: On AMD Zen 3/4 CPUs,
  `srso_alias_safe_ret` and `srso_alias_return_thunk`
  appear as overhead from the Speculative Return Stack
  Overflow mitigation. In trusted environments,
  `spec_rstack_overflow=off` eliminates this cost.

- **Distribution security hardening**: Fedora and similar
  distributions enable features that add profiling overhead:

  - `CONFIG_HARDENED_USERCOPY`: `check_heap_object`,
    `__check_object_size`, `__virt_addr_valid` in data
    copy paths. Can add several percent to memcpy-heavy
    workloads.

  - `init_on_alloc=1`: Page allocator zeros all pages at
    allocation time. Shows as `clear_page_erms` under
    `alloc_pages_bulk_noprof` even without `__GFP_ZERO`.
    Check `/proc/cmdline` before attributing page-clearing
    overhead to the calling code.

  Note these costs separately -- they represent the
  distribution's security tax, not inefficiency in the
  code under analysis.

- **Lost samples**: If perf warns about lost samples or
  `perf report --header-only` shows `PERF_RECORD_LOST`,
  overhead percentages are unreliable -- the highest-rate
  functions are the most undercounted. See
  references/recording.md for the `-m` fix.

- **perf.data location**: `perf record` writes to
  `./perf.data` by default. Use `-o <path>` to write
  elsewhere. `perf report` reads `./perf.data` by default;
  use `-i <path>` to specify a different file.

## Reference files

- [references/recording.md](references/recording.md) --
  recording options, ring buffer sizing, sudo/permissions
- [references/reporting.md](references/reporting.md) --
  symbol resolution, report modes, filtering
- [references/subcommands.md](references/subcommands.md) --
  perf diff, lock, sched, probe, c2c, script, flamegraphs
- [references/platform-events/amd.md](references/platform-events/amd.md) --
  AMD EPYC cache, memory, and lock contention events
- [references/platform-events/intel.md](references/platform-events/intel.md) --
  Intel cache and memory events
