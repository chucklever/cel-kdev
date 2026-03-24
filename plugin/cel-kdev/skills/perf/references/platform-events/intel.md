# Intel cache and memory events (Skylake / Ice Lake and later)

## Detecting the platform

```bash
grep -m1 vendor_id /proc/cpuinfo
```

## Generic LLC events

The generic events work directly on Intel:

```bash
sudo perf stat \
  -e LLC-load-misses \
  -e LLC-store-misses \
  -e LLC-loads \
  -e LLC-stores \
  -- workload
```

## Fill source analysis (Skylake+)

For finer-grained fill source analysis, use
`mem_load_retired` events:

```bash
sudo perf stat \
  -e mem_load_retired.l3_miss \
  -e mem_load_retired.l3_hit \
  -e mem_load_retired.l2_miss \
  -e mem_load_retired.l2_hit \
  -- workload
```

## Memory bandwidth

Use the uncore IMC (integrated memory controller) events
or the `-M` metric groups if available:

```bash
sudo perf stat -a -M Memory_BW -- sleep 10
```

## Lock contention

The same `perf c2c` workflow applies (using PEBS on Intel
instead of IBS on AMD). See subcommands.md for the `perf c2c`
reference.
