# cel-kdev

Claude Code skills for Linux kernel development workflows.

## Skills

### stg

Teaches Claude Code to use [StGit](https://stacked-git.github.io/)
for patch management instead of raw git commands. When StGit is
active on a branch, Claude Code creates, edits, reorders, and
squashes patches through `stg` rather than `git commit` and
`git rebase`, avoiding stack corruption. Covers conflict
resolution, series navigation, and the prohibition on parallel
stg operations across subagents.

### perf

Guides Claude Code through analyzing `perf record` captures:
recording options, symbol resolution with kallsyms, call-graph
analysis, flamegraph generation, and a structured reporting
workflow (overview, drill-down, comparison).

### drgn

Teaches Claude Code to inspect a running kernel through
`/proc/kcore` using [drgn](https://drgn.readthedocs.io/).
Covers core API patterns (Object creation, pointer handling,
type introspection), per-CPU variable access, stack traces,
container_of usage, and slab cache inspection. Includes
subsystem-specific recipes for SUNRPC, NFS, and AIO, along
with workarounds for common pitfalls.

### trace-cmd

Guides Claude Code through analyzing kernel trace captures
(.dat files) from `trace-cmd`. Covers event ingestion,
latency distributions, throughput measurement, phase detection,
and filter expressions. Includes a subsystem reference for
NFS/RDMA server and client events (sunrpc, svcrdma, xprtrdma,
nfsd), RPCGSS, workqueue, scheduler, TCP, and TLS handshake
tracepoints.

## Layout

```
.claude-plugin/
  marketplace.json   # marketplace manifest
  plugin.json        # top-level plugin metadata
plugin/cel-kdev/
  .claude-plugin/
    plugin.json      # plugin manifest
  skills/
    drgn/SKILL.md
    stg/SKILL.md
    perf/SKILL.md
    trace-cmd/SKILL.md
```

## Install

```
claude plugin marketplace add chucklever/cel-kdev
claude plugin install cel-kdev
```

## License

MIT
