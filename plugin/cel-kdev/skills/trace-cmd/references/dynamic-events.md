# Dynamic trace events (kprobe / fprobe)

When static tracepoints do not cover a code path of
interest, dynamic events provide ad-hoc instrumentation
without kernel rebuilds. Set up probes before recording;
they appear as normal trace events in the capture.

**Always remove dynamic probes after use**, even if the
analysis hit an error. Probes persist until explicitly
removed.

## kprobe events

Probe any kernel function (except `NOKPROBE_SYMBOL`).
Requires `CONFIG_KPROBE_EVENTS=y`. Entry probes use
`p:`, return probes use `r:`. Arguments are positional
(`$arg1`, `$arg2`); return probes can capture `$retval`.

```bash
# Entry probe capturing two arguments
echo 'p:myprobe nfsd_dispatch $arg1 $arg2' > \
  /sys/kernel/tracing/kprobe_events

# Return probe capturing return value
echo 'r:myretprobe nfsd_dispatch $retval' >> \
  /sys/kernel/tracing/kprobe_events

# Record
trace-cmd record -e probe:myprobe -e probe:myretprobe \
  -b 4096 -- sleep 10

# Clean up
echo '-:myprobe' >> /sys/kernel/tracing/kprobe_events
echo '-:myretprobe' >> /sys/kernel/tracing/kprobe_events
```

## fprobe events

Function-entry/exit probes with BTF-aware argument
access. Requires `CONFIG_FPROBE_EVENTS=y` and
`CONFIG_DEBUG_INFO_BTF=y`. Arguments are referenced
by name rather than positional `$argN`. Prefer fprobes
over kprobes when BTF is available -- named arguments
are self-documenting and types are inferred
automatically.

```bash
# Probe vfs_read capturing named arguments
echo 'f:myprobe vfs_read count pos' > \
  /sys/kernel/tracing/dynamic_events

# Return probe
echo 'f:myret vfs_read%return $retval' >> \
  /sys/kernel/tracing/dynamic_events

# Record
trace-cmd record -e fprobes:myprobe -e fprobes:myret \
  -b 4096 -- sleep 10

# Clean up
echo '-:fprobes/myprobe' >> /sys/kernel/tracing/dynamic_events
echo '-:fprobes/myret' >> /sys/kernel/tracing/dynamic_events
```

## Measuring function duration

Combine entry and return probes to measure per-call
duration:

```bash
# kprobe variant
echo 'p:myentry nfsd_dispatch' > /sys/kernel/tracing/kprobe_events
echo 'r:myreturn nfsd_dispatch $retval' >> /sys/kernel/tracing/kprobe_events
trace-cmd record -e probe:myentry -e probe:myreturn \
  -b 4096 -- sleep 10
```

Correlate timestamps in `trace-cmd report` output by CPU
and PID to compute per-invocation duration.

## Listing and removing

```bash
# List all active kprobe events
cat /sys/kernel/tracing/kprobe_events

# List all dynamic events (kprobe, fprobe, eprobe)
cat /sys/kernel/tracing/dynamic_events

# Remove all kprobe events
echo > /sys/kernel/tracing/kprobe_events

# Remove all dynamic events
echo > /sys/kernel/tracing/dynamic_events
```
