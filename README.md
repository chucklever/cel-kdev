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

### b4

Teaches Claude Code the `b4` patch workflow for applying
patches from lore (`b4 am`), comparing series revisions
(`b4 diff`), and managing outbound patch series with
`b4 prep` and `b4 send`. Covers coexistence with StGit,
cover letter strategies, recipient management, and
non-interactive operation constraints.

### sashiko

Teaches Claude Code how to retrieve and interpret reviews
from the [sashiko](https://sashiko.dev) kernel-patch review
bot. Points at the unauthenticated `/api/patchset` endpoint
and away from two common dead ends: lore searches (the bot
does not post to public lists by default) and `WebFetch`
against the SPA web UI (returns only the app shell). Covers
the email delivery policy, review-status transitions, and
the false-positive rate that governs how review output
should be treated.

## Layout

```
.claude-plugin/
  marketplace.json   # marketplace manifest
  plugin.json        # top-level plugin metadata
plugin/cel-kdev/
  .claude-plugin/
    plugin.json      # plugin manifest
  skills/
    b4/SKILL.md
    drgn/SKILL.md
    stg/SKILL.md
    perf/SKILL.md
    sashiko/SKILL.md
    trace-cmd/SKILL.md
```

## Requirements

The `block-raw-git.sh` `PreToolUse` hook (installed by the
Claude Code manifest, wired in by hand on Codex) parses the
harness's tool-input JSON with `jq`, so `jq` must be present
on the host:

```
apt install jq      # Debian, Ubuntu
dnf install jq      # Fedora, RHEL
```

The hook aborts with a diagnostic when `jq` is missing rather
than failing open.

## Install

```
claude plugin marketplace add chucklever/cel-kdev
claude plugin install cel-kdev
```

## Codex

The `.claude-plugin/` wrapper packages these skills for Claude
Code. Codex consumes the same skills directly, either through
the `.codex-plugin/` manifest or by installing the individual
SKILL.md directories.

Codex reads the Claude-style marketplace at
`.claude-plugin/marketplace.json`, which points at the
`.codex-plugin/` manifest under `plugin/cel-kdev/`. The
preferred install path is therefore the marketplace:

```
codex plugin marketplace add chucklever/cel-kdev
```

Then complete the install from `/plugins` inside Codex.

If the marketplace path is unavailable, the skill installer
script fetches the SKILL.md directories directly as a fallback:

```
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo chucklever/cel-kdev \
  --path plugin/cel-kdev/skills/b4 \
  --path plugin/cel-kdev/skills/drgn \
  --path plugin/cel-kdev/skills/perf \
  --path plugin/cel-kdev/skills/sashiko \
  --path plugin/cel-kdev/skills/stg \
  --path plugin/cel-kdev/skills/trace-cmd
```

Restart Codex after installation.

## Codex hook setup

The Claude Code plugin manifest installs a `PreToolUse` hook
that blocks raw `git` commands on branches with an active stg
stack. The Codex plugin manifest cannot currently package
hooks, so Codex users wire the same protection in by hand.

Codex hook support is feature-flagged. Enable it in
`~/.codex/config.toml` (or a per-repo `.codex/config.toml`):

```
[features]
codex_hooks = true
```

Clone the plugin repo somewhere you can keep updated, for
example under `~/src/`:

```
git clone https://github.com/chucklever/cel-kdev.git ~/src/cel-kdev
```

Refresh later with:

```
git -C ~/src/cel-kdev pull --ff-only
```

Register it as a `PreToolUse` Bash hook by writing the
following JSON to `~/.codex/hooks.json` (user-level) or
`<repo>/.codex/hooks.json` (per-repo), per the
[Codex hooks documentation](https://developers.openai.com/codex/hooks):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^Bash$",
        "hooks": [
          {
            "type": "command",
            "command": "/home/YOU/src/cel-kdev/plugin/cel-kdev/hooks/block-raw-git.sh",
            "timeout": 5,
            "statusMessage": "Checking StGit policy"
          }
        ]
      }
    ]
  }
}
```

The script exits 2 with the reason on stderr when it blocks,
matching Codex's documented deny protocol. Codex notes that
shell interception is incomplete for newer streaming-shell
execution paths, so treat this hook as defense in depth rather
than a hard guarantee.

## Releasing

Claude Code keys its plugin cache off the manifest version, so
every push that changes plugin contents needs a fresh version.
Bump it with:

```
scripts/bump-version.sh 2.4.2
```

Both manifests are rewritten in place. Commit the bump as its
own patch, separate from the content change it accompanies:

```
git add .claude-plugin/marketplace.json plugin/cel-kdev/.codex-plugin/plugin.json
git commit -m "cel-kdev: Bump plugin version to 2.4.2"
```

Or with StGit:

```
stg new bump-2.4.2 -m "cel-kdev: Bump plugin version to 2.4.2"
stg refresh
```

A `pre-push` hook under `scripts/git-hooks/` enforces the bump
on every push that touches `.claude-plugin/` or `plugin/`, and
also fails when the two manifests disagree. Activate it once
after cloning:

```
git config core.hooksPath scripts/git-hooks
```

## License

MIT
