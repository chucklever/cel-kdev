# Verifying a cited rule ID

Loaded from the sashiko skill, when a finding cites a named
rule.  The verify-and-label rule these citations sit under is
"Do not propagate sashiko claims unverified" in `SKILL.md`.

Sashiko grounds some findings in named rules (e.g.
`SUNRPC-RDMA-004`, `SUNRPC-GSS-007`).  The SUNRPC rule
families are real and defined in
`~/src/review-prompts/kernel/subsystem/sunrpc.md` (a local
checkout of the `masoncl/review-prompts` guide set):
`SUNRPC-CORE-NNN`, `SUNRPC-RDMA-NNN`, `SUNRPC-GSS-NNN`, and
`SUNRPC-SOCK-NNN`.  The numbered-ID convention is not unique
to SUNRPC -- other guides carry their own (e.g. `RCU-001`,
`BPF-001`) -- so never judge a cited ID invented from memory.
Grep the guides first, whatever the subsystem.

Substitute the cited ID and search the guides.  `-i` covers
case; separators and zero-padding drift more often, since the
files store three-digit IDs (`SUNRPC-RDMA-004`).  Use `$HOME`,
not `~`: a tilde inside a quoted path does not expand, and the
empty result then reads like a missing rule.  If the directory
itself is absent, the checkout lives elsewhere or is missing;
say "I cannot locate the rule guides" rather than treating
every cited ID as ungrounded.

```bash
grep -rin "SUNRPC-RDMA-004" "$HOME/src/review-prompts/kernel/subsystem/"
```

Interpret the result:

- A full match: the rule exists; treat the citation as
  grounded (not the same as the finding being correct --
  still verify the claim against the code).
- No match: a literal miss is often formatting drift, not a
  missing rule.  Retry with separators and padding loosened
  (the `\b` keeps `-4` from matching `040` or `400`):

  ```bash
  grep -rinE "SUNRPC.?RDMA.?0*4\b" "$HOME/src/review-prompts/kernel/subsystem/"
  ```

  Still nothing?  The full-ID grep cannot tell a missing
  number from a missing family, so re-grep the family stem
  alone:

  ```bash
  grep -rinoE "SUNRPC-RDMA-[0-9]+" "$HOME/src/review-prompts/kernel/subsystem/" | sort -u
  ```

  - The stem lists other numbers but not the cited one:
    report "rule family <family> exists, but <id> is not
    defined," not "fabricated."
  - The stem matches nothing either: prefer "I cannot find
    this rule" over "fabricated."

A rule you do not recognize is not the same as a rule that
does not exist.
