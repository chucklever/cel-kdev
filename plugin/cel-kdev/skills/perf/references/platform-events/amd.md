# AMD EPYC cache and memory events (Zen 3/4/5)

## Detecting the platform

```bash
grep -m1 vendor_id /proc/cpuinfo
```

## Overview

The generic perf events (`LLC-load-misses`,
`LLC-store-misses`, `cache-misses`) work on Intel but
are not mapped on AMD Zen. AMD exposes cache events
through two PMU layers.

## L3 uncore events

`amd_l3` PMU events are system-wide, per-CCX counters.
They require `-a` and do not distinguish loads from
stores -- the L3 sees coherence requests, not individual
load/store instructions.

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

## Core fill events

`ls_dmnd_fills_from_sys` (event 0x43) events are per-core
and support per-process measurement. They classify demand
data cache fills by where the data came from:

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

## L3 miss latency (Zen 4+)

```bash
sudo perf stat -a -M l3_read_miss_latency -- sleep 10
```

## Memory bandwidth

```bash
sudo perf stat -a \
  -M umc_mem_read_bandwidth,umc_mem_write_bandwidth \
  -- sleep 10
```

## I/O workload recipe

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
cacheline sharing -- data touched by one CCX (e.g.,
NIC interrupt handler) then consumed by another
(e.g., nfsd thread).

## Spinlock contention recipe

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
