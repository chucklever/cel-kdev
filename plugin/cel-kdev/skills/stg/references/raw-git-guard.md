# The block-raw-git.sh guard hook

Mechanics of the guard that blocks raw git on stg branches,
for the case where an stg session also drives a second,
non-stg repository. The rule itself is in SKILL.md; this
file explains why the `git -C <abs-path>` form is required
and what the fallback does.

The hook checks stg-activity against the repo the command
targets: a leading `git -C <dir>` retargets the check at
`<dir>` when `<dir>` resolves to a directory, otherwise it
falls back to the hook's cwd -- the session's primary branch
-- keeping the guard fail-closed. That fallback blocks the
command whenever the session's primary branch is stg, even
though the target repo is not, and the BLOCKED message names
the primary branch, not the target.

The hook cannot see a `cd <repo> &&` prefix; the harness
resets cwd between calls. So drive the second repo with
`git -C <repo> <subcommand>`, giving `<repo>` as an absolute
path or one starting with `~/`, `$HOME/`, or `${HOME}/`. The
hook inspects the command text before the shell expands it
and expands only those three prefixes itself; `~user/` or
any other variable in `<repo>` is unresolvable and triggers
the cwd fallback. The guard then resolves `<repo>`, and once
it confirms `<repo>` carries no stg stack it permits raw git
there. This is not a license to bypass the guard on an
actual stg branch.
