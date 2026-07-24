# Snapshot buffer captures

The snapshot buffer holds a frozen copy of the trace buffer
taken at one instant, so a capture can cover the window
around a rare event without recording the run-up to it.
Tracing keeps running across the swap. Requires a kernel
built with `CONFIG_TRACER_SNAPSHOT`; the per-CPU form needs
`CONFIG_TRACER_SNAPSHOT_PER_CPU_SWAP` as well.

The buffer is filled two ways: automatically by a snapshot
event trigger, or manually with `trace-cmd snapshot -s`.
Either way, `trace-cmd extract -s` is what turns it into a
.dat file.

## Snapshot triggers

Event triggers take the form `command[:count] [if filter]`
and are written to the event's trigger file:

```bash
# Snapshot on every occurrence
echo 'snapshot' > \
  /sys/kernel/tracing/events/block/block_unplug/trigger

# Snapshot once, the first time the filter matches
echo 'snapshot:1 if nr_rq > 1' > \
  /sys/kernel/tracing/events/block/block_unplug/trigger

# Remove -- prefix with ! and repeat the filter exactly
echo '!snapshot:1 if nr_rq > 1' > \
  /sys/kernel/tracing/events/block/block_unplug/trigger
```

Only one snapshot trigger may exist per triggering event.
Reading the trigger file lists what is currently armed.
Filter field names must match the format definition, not the
abbreviated labels in report output -- verify them with
`trace-cmd dump -i <file> --events`.

## Manual snapshots

`trace-cmd snapshot` operates on the buffer directly, which
suits a condition no single event can express:

```bash
trace-cmd start -e <subsystem>   # tracing runs, nothing written
trace-cmd snapshot -s            # freeze the buffer now
trace-cmd snapshot               # dump the frozen copy as text
```

Options: `-s` take, `-r` clear the buffer, `-f` free it,
`-c <cpu>` operate on one CPU's snapshot, `-B <buf>` operate
within a named buffer instance.

## Extracting to a .dat file

```bash
trace-cmd extract -s -o <file>.dat
```

Without `-o` the file is written as trace.dat, and without
`-s` extract dumps the main trace buffer instead. Everything
downstream -- `trace-cmd report`, `trace-cmd dump` -- reads
the result like any other capture.

## Cleanup

Remove the trigger, then free the buffer:

```bash
echo '!snapshot:1 if nr_rq > 1' > \
  /sys/kernel/tracing/events/block/block_unplug/trigger
trace-cmd snapshot -f
```

The snapshot buffer is a second copy of the trace buffer and
holds that memory in the kernel until freed. The first `-s`
allocates it again if it is needed later.
