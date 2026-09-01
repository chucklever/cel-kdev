# Stack recovery procedures

Each section below is entered from the distinctive error or
stack state its heading names. Read the matching section
whole before running any recovery command; the first
command chosen wrong can destroy the state the rest of the
procedure needs.

## "HEAD and stack top are not the same": stack detached by a raw reset

When the branch was reset to a commit far ahead of the stack
base (catching master up to origin without stg, say), HEAD
and the stack top diverge and `stg new`, `goto`, `push`, and
the rest refuse with "HEAD and stack top are not the same."
The same error follows any raw git that moved HEAD. The two
recoveries below diverge on whether the branch is meant to
sit on the reset target, and nothing in either one recovers
that intent, so settle it with the user before running
either.

### The reset was unwanted: restore the pre-reset state

The stack log still holds the state recorded before the
reset, and restoring that state is the whole recovery. A raw
reset records no log entry of its own, so the newest state
listed is the pre-reset one:

```bash
stg log             # stack states, newest first; the first
                    # column is the state's meta-sha
stg reset <state>   # re-attach HEAD to that state
```

`stg reset` is the one command that consumes that meta-sha
directly; it is not a git revision anywhere else (see
"Tracing patch evolution with stg log" in SKILL.md).

Prefer this over `stg undo` here. Undo steps back one
recorded *stg* operation, and a raw reset records none, so
it reverses whatever stg last did before the reset as well.
Plain `stg reset` with no state resets worktree changes
only, and `stg reset --hard` discards them; neither
re-attaches the stack.

### The reset target is kept: rebuild on the new HEAD

```bash
stg repair       # commits between the old base and the new
                 # HEAD become applied patches; local patches
                 # unreachable from HEAD go unapplied
stg series -d    # read it; it decides the next step -- see
                 # the three cases below
stg commit -a    # fold those commits into the base, which
                 # advances to the reset target
stg push -a      # replay the local patches on top -- use
                 # stg goto <former-top> instead when only
                 # part of the stack was applied before the
                 # reset (see the "stg push -a overshoots"
                 # pitfall in SKILL.md)
```

How much repair sweeps up depends on the history it walks:
it follows first parents down from the new HEAD and stops at
the first merge commit, so it reaches the old base only when
that path is merge-free. Do not predict the outcome -- read
`stg series -d` and branch on it:

- Applied set is upstream commits only: `stg commit -a`,
  then `stg push -a`, as above. On a busy tree the repair
  turns hundreds of commits into patches; that is the
  intended intermediate state, so do not stop there thinking
  it created junk, because `stg commit -a` is the step that
  absorbs them into the base.
- A local patch sits among the applied ones, because the
  reset target already carries its commit: commit the
  upstream ones by count instead (`stg commit -n <N>`),
  since `stg commit -a` would finalize the local patch into
  the base too.
- Nothing applied and no new patches: the walk hit a merge
  commit before reaching the old base, which is what a
  mainline reset target usually produces. Repair has already
  made the new HEAD the base, so skip `stg commit -a` -- it
  has nothing to absorb -- and go straight to the replay.

Every step here is a recorded stack operation, so `stg undo`
reverses it, including the commit; the reflog is a last
resort, not the first. Patches the maintainer already took
empty out on the replay rather than conflict -- resolve
conflicts as usual, then `stg clean` to drop the ones that
emptied. If the former top cannot be recovered from
`stg log`, ask rather than applying the whole stack.

Note the `stg commit -a` here absorbs upstream history that
`stg repair` turned into patches, not a patch of yours a
remote took; retiring a patch upstream has taken goes
through `stg rebase -m` instead (see
[retiring.md](retiring.md)).

Prevention: catch a stack up to upstream with
`stg rebase <upstream-ref>`; the raw reset is what detaches
the stack in the first place.

## Patches "hidden below the merge commit": accidental raw merge

Raw `git merge` on an stg branch commits the merge to the
stack's HEAD, leaving the patches below the merge commit.
`stg repair` cannot convert a merge commit into a patch: it
warns that the patches are "hidden below the merge commit",
marks them unapplied, and moves the branch head to the
stack base, leaving the merge commit off the branch. The
recovery is the same whether or not repair has run --
discard the merge by re-attaching the stack to the newest
state recorded before it:

```bash
stg log             # stack states, newest first
stg reset <state>   # meta-sha of the newest state that is
                    # neither "external modifications" nor
                    # "repair"
```

The merge itself records no stack log entry; a later stg
command notices it and stamps an "external modifications"
entry, and repair adds a "repair" entry on top. Skip both
kinds when picking the state: the one below them is the
pre-merge stack.

Prefer `stg reset <state>` over `stg undo` here. Before
repair has run, `stg undo` does remove the merge, but it
steps past the stamped "external modifications" entry and
reverses the last real stg operation as well -- a
just-refreshed patch comes back as an applied
`refresh-temp`. After repair, one undo reverses only the
repair, putting the merge back on HEAD, and a second is
needed for the recorded merge. The single reset lands
exactly on the pre-merge state in both cases.

To combine branches deliberately, build the merge below the
stack base instead of on its HEAD -- see "Combining
branches: there is no stg merge" in SKILL.md.

## Mutating command aborted by a broken pipe

Entered from "Never pipe a mutating stg command" in
SKILL.md: a mutating stg command was piped into a consumer
that stopped reading early, and stg aborted mid-operation.

What the abort leaves behind varies. `push` and `sink` roll
the stack back, though not always cleanly -- an aborted
`sink` can leave an unresolved conflict (`UU`) in the
worktree, and later stg commands then refuse with "resolve
outstanding conflicts first" -- clear it per
[conflict-resolution.md](conflict-resolution.md) before
re-running. `import` is worse: it commits each patch as its
own transaction, so piping a five-patch mbox into `head -1`
applies the first patch and strands the rest.

The exit status hides it. Rust ignores SIGPIPE, so stg does
not die on the signal; its next write fails with EPIPE, stg
prints `error: Broken pipe (os error 32)` on stderr and
exits 2 (stg 2.5). But `$?` on a pipeline carries the
consumer's status, so a bare check reads as success, and
`2>&1 |` hides the message as well. Check
`${PIPESTATUS[0]}`. Confirm with `stg series -d` how far the
stack actually moved, then re-run without the pipe,
redirecting instead to a file outside the repo (see the
pitfall in SKILL.md for the redirect form).
