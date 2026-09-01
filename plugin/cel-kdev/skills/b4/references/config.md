# b4 configuration reference

## Relevant git config options

| Option | Purpose |
| ------ | ------- |
| `b4.prep-cover-strategy` | `branch-description` or `file`; both are stg-compatible |
| `b4.send-no-patatt-sign` | Set `true` to skip patatt/gpg signing |
| `b4.send-same-thread` | `no`, `yes`, or `shallow` for threading v2 as reply to v1 |
| `b4.send-series-to` | Default To: addresses |
| `b4.send-series-cc` | Default Cc: addresses |
| `b4.send-auto-to-cmd` | Command to compute per-patch To: (default: `get_maintainer.pl`) |
| `b4.send-auto-cc-cmd` | Command to compute per-patch Cc: |
| `b4.prep-pre-flight-checks` | `disable-all` or comma-separated list of checks to skip |

## The b4-tracking JSON

`branch.<name>.b4-tracking` holds enrollment state as a JSON
object:

```
{"base-branch":"origin/master","series-id":"...","prefixes":["PATCH"]}
```

The `base-branch` field determines which remote ref b4 uses
to compute `base-commit` (the merge-base). b4 has no CLI
command to update it on an already-enrolled branch, so when
it must change (see the "Fork-point goes stale after rebase"
pitfall in SKILL.md), rewrite the value directly:

```bash
# Read current tracking
git config branch.<name>.b4-tracking

# Write back with corrected "base-branch" value
git config branch.<name>.b4-tracking '<updated JSON>'
```

After updating, verify with `b4 prep --show-info` that
`base-commit` and `series-range` look correct.
