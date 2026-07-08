# Cover letter strategies

b4 supports multiple cover-letter strategies. The strategy
determines where the cover letter and changelog are stored.

| Strategy | Storage | stg compatible |
| -------- | ------- | -------------- |
| `branch-description` | `git config branch.<name>.description` | yes |
| `file` | `.git/b4-prep/<change-id>/` | yes |

## branch-description strategy

The cover letter is stored in the git branch description.
To edit it non-interactively, write content to a temp file
and override EDITOR:

```bash
cat > /tmp/cover.txt << 'EOF'
Cover letter subject

Cover letter body...

---
Changes in v2:
- description of change
EOF
EDITOR="cp /tmp/cover.txt" b4 prep --edit-cover
```

b4 invokes `$EDITOR <tempfile>`, so `cp` replaces the temp
file contents, which b4 reads back. The first line becomes
the subject (after the `[PATCH vN 0/N]` prefix), then a
blank line, then the body. Changelog entries go at the
bottom after a `---` separator.

## file strategy

When `b4.prep-cover-strategy` is `file`, series metadata
lives in `.git/b4-prep/<change-id>/`. To find the
change-id for the current branch:

```bash
b4 prep --show-info change-id
```

| File | Contents |
| ---- | -------- |
| `cover` | Cover letter: first line is the subject, then blank line, then body |
| `changelog` | Version history, newest first. Placed after a `---` separator in the sent cover |
| `recipients` | Per-patch To/Cc populated by `--auto-to-cc` |

Edit these files directly -- no `$EDITOR` trick needed.

The changelog goes in the separate `changelog` file, never
inlined into `cover`. b4 adds the `---` separator itself at
send time (when a changelog exists), so the `changelog` file
holds bare entries -- never begin it with `---`.

This is the opposite of `branch-description`, where cover and
changelog share one text field and the changelog *is* inlined
under a `---` (as in the `branch-description` example above).
The strategy decides whether the changelog is separate (`file`)
or inlined (`branch-description`); getting this backwards is the
most common mistake.

## Changelog format

Each version is a block starting with `Changes in vN:`
followed by bullet points. After `b4 send` or
`b4 prep --manual-reroll`, b4 adds a new `Changes in vN+1:`
placeholder with `EDITME` lines: prepended directly above the
existing entries on later rerolls (v2->v3 onward), or appended
at the bottom (after a `---` separator) on the first reroll
(v1->v2). Replace the
`EDITME` lines in that placeholder with the real changelog for
the new version.
