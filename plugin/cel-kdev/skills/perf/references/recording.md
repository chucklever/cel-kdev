# perf recording reference

## Recording modes

```bash
# Profile a command
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 <command>

# Profile a running process by PID
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 -p <pid>

# System-wide (all CPUs)
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 -a
```

`sudo` is needed for system-wide profiling (`-a`) and
for access to kernel symbols during later analysis.
Use it consistently for all `perf record` invocations
to avoid permission issues.

Use `--` to separate perf options from the target command.

## Unprivileged profiling

If `sudo` is unavailable, check the current restriction
level with `sysctl kernel.perf_event_paranoid` -- values
`>=2` restrict monitoring to user-space per-process events
only; `-1` removes all restrictions.

**Option 1** -- lower the paranoid level:

```bash
sudo sysctl kernel.perf_event_paranoid=-1
```

**Option 2** -- grant capabilities to the perf binary
(preferred for least-privilege; requires Linux v5.9+
for `CAP_PERFMON`):

```bash
sudo setcap "cap_perfmon,cap_sys_ptrace,cap_syslog=ep" \
  $(which perf)
```

`CAP_SYS_PTRACE` enables cross-process observation;
`CAP_SYSLOG` enables `/proc/kallsyms` access.

Add `-g` to include kernel call chains when profiling
user-space from a non-root context (though `-a` already
implies it).

## Ring buffer sizing

`perf record` allocates a per-CPU ring buffer for
transporting samples from kernel to user space. The
default size is controlled by `-m` / `--mmap-pages=`
(rounded up to a power of two in pages). When the
event rate exceeds the buffer's capacity, samples are
dropped and perf emits `PERF_RECORD_LOST` records.

Check for lost samples in the report header:

```bash
sudo perf report --kallsyms=/tmp/vmlinux-kallsyms.txt \
  --stdio --header-only 2>&1 | grep -i lost
```

No output from the grep indicates zero losses.

If losses appear, increase the buffer:

```bash
sudo perf record -e cycles -e cpu-clock \
  --call-graph fp -F99 -m 512 -a
```

The total memory consumed is roughly `mmap_pages *
page_size * nr_cpus`. On a 64-CPU system, `-m 512`
allocates 512 * 4 KiB * 64 = 128 MiB.

Each user's per-CPU mmap allocation is capped by the
`perf_event_mlock_kb` sysctl (default 516 KiB per
CPU). If a `perf record` invocation fails with
`failed to mmap with 12 (Cannot allocate memory)`,
the combined allocation of all active perf sessions
exceeds this budget. Either reduce per-session
buffer size with `-m` or raise the limit:

```bash
sudo sysctl kernel.perf_event_mlock_kb=4096
```
