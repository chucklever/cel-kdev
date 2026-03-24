# perf reporting reference

## Symbol resolution and DSO attribution

`/proc/kallsyms` contains symbols for vmlinux **and** all
loaded modules in a single flat address-to-name table.
When `--kallsyms=/proc/kallsyms` is passed to perf, it
resolves all kernel addresses through that table and
attributes every symbol to `[kernel.kallsyms]`, collapsing
the distinction between vmlinux and individual module
DSOs (`[sunrpc]`, `[rpcrdma]`, `[nfsd]`, etc.).

This collapse only affects data recorded on the currently
running kernel, where the recorded addresses match the
live kallsyms entries. Data from a different kernel build
has modules at different addresses; those addresses do
not match the current kallsyms, so perf falls through to
the recorded MMAP data and resolves symbols from the
`.ko` files, preserving correct DSO attribution.

**Workaround -- stripped kallsyms**: Create a kallsyms
file containing only vmlinux symbols (no module symbols).
perf uses it to resolve vmlinux addresses, and falls back
to the recorded MMAP records plus `.ko` files for module
addresses, preserving per-module DSO attribution:

```bash
sudo grep -v '\[' /proc/kallsyms > /tmp/vmlinux-kallsyms.txt
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt
```

Module symbols in `/proc/kallsyms` are identified by a
trailing `[module_name]` field; `grep -v '\['` removes
them.

**Alternative -- `--vmlinux`**: `perf report` (but not
`perf diff`) accepts `--vmlinux=<path>` which provides
vmlinux symbol resolution without absorbing module
symbols. Do not combine with `--kallsyms`:

```bash
sudo perf report \
  --vmlinux=/lib/modules/$(uname -r)/build/vmlinux
```

**When DSO separation does not matter**: If the analysis
only needs symbol names and does not depend on DSO-level
filtering or grouping, `--kallsyms=/proc/kallsyms` is
simpler and resolves all symbols in one pass:

```bash
sudo perf report --kallsyms=/proc/kallsyms
```

## Non-interactive report

For scripted analysis or piping, add `--stdio`:

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio > /tmp/perf-report.txt
```

To limit output depth or sort by specific fields:

```bash
# Flat profile (no call graph unfolding)
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --no-children

# Top entries (head -80 accounts for perf's header lines,
# yielding ~30 symbols)
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --no-children | head -80
```

## Caller/callee view

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --call-graph callee
```

## Multi-event data

When recording with multiple events (`-e cycles -e cpu-clock`),
`perf report` outputs a separate histogram section for each
event. There is no `-e` flag on `perf report` to select a
single event. When piping through `head`, only the first
event's section may be visible.

To reach the cycles section (typically the second):

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --no-children --comms=nfsd 2>&1 | \
  grep -A 200 'Samples:.*cycles'
```

The `cpu-clock` section includes idle time (useful for
utilization analysis). The `cycles` section excludes
C-state idle and concentrates on actual CPU work (useful
for optimization analysis). Always check which section
you are reading.

## Per-symbol drill-down

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --symbol-filter=<function_name>
```

Note: `perf report` uses `--symbol-filter`; `perf annotate`
uses `--symbol`. These are different flags on different
subcommands.

**Caveat**: `--symbol-filter` with `--call-graph callee`
shows the filtered symbol and its full ancestor chain,
not just its callees. To isolate the self cost of specific
functions, use `-S` instead:

```bash
# Self overhead of specific symbols only
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --no-children --comms=nfsd \
  -S func_a,func_b,func_c
```

To find everything called beneath a parent function,
use the `-p` (parent) filter:

```bash
# All symbols with <parent_function> in their call chain
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --no-children --comms=nfsd -p <parent_function>
```

## Filtering

### By DSO (module or binary)

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --dsos='[sunrpc]'

# Multiple DSOs
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --dsos='[nfsd],[sunrpc],[svcrdma]'
```

Bracket syntax `[name]` denotes kernel modules.
User-space binaries use their full path or basename.

**Caveat**: `--dsos` only works for loadable kernel
modules (`.ko` files), not for subsystems built into
vmlinux. If a subsystem is compiled in rather than
loaded as a module, its symbols appear under
`[kernel.kallsyms]` and cannot be isolated with
`--dsos`. Use `--comms`, `-S`, or `-p` filters instead.

### By CPU

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --cpu=0,1,2

# CPU range
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --cpu=0-3
```

### By time window

```bash
# Show only samples between 5% and 50% of recording duration
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --time '5%,50%'

# Absolute time range (seconds from start)
sudo perf script --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --time '10.0,20.0'
```

### By comm (process name)

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --comms=nfsd

sudo perf script --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --comms=nfsd,kworker
```

### Combined filters

Filters compose: `--dsos`, `--cpu`, `--comms`, and
`--time` can all be used together to narrow analysis.
