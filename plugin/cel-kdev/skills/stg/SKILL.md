---
name: stg
description: >-
  StGit (stg) patch stack management. When stg is active on a
  branch, replaces git commit, amend, rebase, and reset with stg
  equivalents to prevent stack corruption. Covers patch creation,
  reordering, squashing, conflict resolution, and series management.
invocation_policy: automatic
allowed-tools: Bash(*:stg series *), Bash(*:stg show *), Bash(*:stg log *), Bash(*:stg id *), Bash(*:stg diff *), Bash(*:stg files *), Bash(*:stg patches *), Bash(*:git diff *), Bash(*:git log *), Bash(*:git reflog *)
---

# stg: patch stack management

When stg is active on a branch, use stg commands instead of
raw git for all commit operations. Check activation with:

```bash
git show-ref --verify "refs/stacks/$(git symbolic-ref --short HEAD)" >/dev/null 2>&1
```

## CRITICAL: Prohibited git commands

**NEVER use these git commands when stg is active. They move
HEAD behind stg's back, corrupting the stack metadata.**

| Prohibited | Replacement |
| ---------- | ----------- |
| `git commit` | `stg new <name> -m "msg"` + `stg refresh` |
| `git commit --amend` | `stg refresh` or `stg edit --file <path>` |
| `git rebase` | `stg rebase`, `stg sink`, `stg float` |
| `git reset` | `stg pop`, `stg undo` |
| `git cherry-pick` | `stg pick` or `stg import` |
| `git rebase -i` (reorder) | `stg sink`, `stg float` |
| `git rebase -i` (squash) | `stg squash` |

This applies to all agents and subagents.

## CRITICAL: No parallel stg operations

The stg stack is a single shared resource. Every mutating
command (`new`, `refresh`, `goto`, `push`, `pop`, `float`,
`sink`) changes HEAD and on-disk metadata. Concurrent stg
operations from parallel agents corrupt the stack.

**Do NOT delegate patch creation or editing to parallel
subagents.** All stg operations on a given branch must run
in a single sequential session. Parallelism is safe only
for read-only work (research, building, testing).

## Stack model

```
+ patch-a          <- applied, ancestor of HEAD
+ patch-b          <- applied, ancestor of HEAD
> patch-c          <- current top patch = HEAD
- patch-d          <- unapplied, not ancestor of HEAD
- patch-e          <- unapplied, not ancestor of HEAD
```

Applied patches (`+` and `>`) form a contiguous commit
sequence above the stack base. HEAD points at the topmost
applied patch (`>`).

Unapplied patches (`-`) are commit objects in stg metadata
but not ancestors of HEAD. They do not appear in `git log`.
Use `stg show` with patch names from `stg series --unapplied`
to examine them -- not `HEAD~N`.

## Pitfalls

**`stg diff` without `-r`**: `stg diff <patch-name>` treats
the argument as a file path, producing silent wrong output.
Use `stg diff -r <patch-name>~..<patch-name>` for a patch diff.

**`stg fold` positioning**: `stg fold` applies to the current
top patch only. Use `stg goto` first to position the stack.

**Options vs patch names**: Commands accepting `[patch]...`
arguments (`squash`, `float`, `sink`, `push`, `pop`) consume
everything after the first patch name as patch names. Place
all options before patch names.

**Merge commits and repair**: `stg repair` cannot convert
merge commits into patches. Use `stg undo` to remove an
accidental merge before running `stg repair`.

**`stgit.autosign` trailer**: When `stgit.autosign` is set
in git config (e.g., to `Signed-off-by`), `stg new`,
`stg import`, and `stg edit` automatically append that
trailer. The `-m` flag on `stg import` selects mail/mbox
input format and has no effect on trailer behavior.

## Avoiding interactive editors

Always provide `-m` to `stg new` and `--file <path>` to
`stg edit`. Write multi-line messages to a temp file and
pass `-f /tmp/msg.txt` to `stg squash`.

Use `-s` / `--sign` to auto-generate Signed-off-by from
git config.

## Merge conflict resolution

When `stg push` or `stg rebase` produces conflicts:

1. Run `git reflog` to examine the pre-merge patch state.
2. Edit conflicted files to resolve each conflict.
3. Mark resolved files with `stg resolved <file>` (not
   `git add`).
4. Run `stg refresh` to finalize the resolution.

To abort: `stg undo` reverts the failed operation.

## Command reference

See [references/commands.md](references/commands.md) for
the full command table covering creation, navigation,
reordering, splitting, importing, exporting, and email.
