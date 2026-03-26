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
