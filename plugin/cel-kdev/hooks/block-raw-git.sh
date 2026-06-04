#!/bin/bash
# Block raw git commands that corrupt stg patch stacks.
# Only blocks when stg is active on the current branch.

if ! command -v jq >/dev/null 2>&1; then
    echo "block-raw-git: jq is required but not installed; install jq to enable the stg guard." >&2
    exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Strip quoted strings so that "git commit" inside a message
# argument (e.g. stg edit -m "...git commit...") is not matched.
STRIPPED=$(echo "$COMMAND" | sed -e 's/"[^"]*"//g' -e "s/'[^']*'//g")

# Plumbing forms (git merge-tree/commit-tree/merge-base/merge-file)
# only write objects or read history; none move HEAD or update a ref,
# so none can desync stg metadata. Rewrite them to a neutral token so
# the broad branch/commit/merge patterns below do not catch the
# hyphenated subcommand on its word boundary. Stripping the token --
# rather than allowing the whole command -- still blocks a real
# prohibited subcommand chained on the same line (e.g.
# "git merge-base x y; git merge z").
STRIPPED=$(echo "$STRIPPED" | sed -E 's/\bgit[[:space:]]+(commit-tree|merge-tree|merge-base|merge-file)\b/git PLUMBING/g')

# Only check commands that match prohibited git operations
if ! echo "$STRIPPED" | grep -qE '\bgit\s+(branch|commit|rebase|reset|cherry-pick|checkout|switch|restore|worktree|merge)\b'; then
    exit 0
fi

# Allow if stg is not active on this branch
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || exit 0
if ! git show-ref --verify "refs/stacks/$BRANCH" >/dev/null 2>&1; then
    exit 0
fi

# Allow read-only forms of git branch and config-only changes
# (--set-upstream-to, --unset-upstream, --edit-description), which
# only touch .git/config and are invisible to stg.
# Block only forms that create, delete, rename, or copy branches,
# as those operations leave stg refs out of sync.
if echo "$STRIPPED" | grep -qE '\bgit\s+branch\b'; then
    if ! echo "$STRIPPED" | grep -qE '\s-[dDmMcC]\b'; then
        exit 0
    fi
fi

# Only worktree creation is prohibited here. Read-only worktree
# inspection does not move HEAD or update stg stack metadata.
if echo "$STRIPPED" | grep -qE '\bgit\s+worktree\b'; then
    if ! echo "$STRIPPED" | grep -qE '\bgit\s+worktree\s+add\b'; then
        exit 0
    fi
fi

# git checkout/switch/restore are blocked in every form. The branch
# forms bypass stg's metadata bookkeeping. The pathspec forms
# (git checkout -- <file>, git restore <file>) do not move HEAD, but
# they conflate "discard this from the worktree" with "keep this out
# of the patch": once a change is folded in, restoring the worktree
# leaves the stale diff baked into the patch commit where stg refresh
# cannot reach it. Scope the next refresh with a pathspec, or git
# stash the unwanted change, instead of discarding it.

echo "BLOCKED: stg is active on this branch. Use stg commands instead:" >&2
echo "  git branch       -> stg branch (manages stg metadata alongside branches)" >&2
echo "  git commit       -> stg new + stg refresh" >&2
echo "  git commit --amend -> stg edit / stg refresh" >&2
echo "  git rebase <base> -> stg rebase <base> (move stack onto new base)" >&2
echo "  git rebase -i    -> stg sink / stg float / stg edit / stg delete" >&2
echo "                      (no stg squash; see \"Combining patches\" in the stg skill)" >&2
echo "  git reset HEAD~N -> stg pop (unapply patches)" >&2
echo "  git reset --hard -> stg reset --hard (restore to last stg state)" >&2
echo "  git cherry-pick  -> stg pick" >&2
echo "  git checkout/switch <branch> -> stg branch <branch>" >&2
echo "  git checkout/restore <file> -> scope 'stg refresh <pathspec>' or git stash; never discard a refreshed change this way" >&2
echo "  git worktree add -> unsupported on stg branches" >&2
echo "  git merge        -> no stg merge; build a base merge commit, then stg rebase onto it" >&2
echo "                      (git merge-tree/commit-tree plumbing is allowed)" >&2
exit 2
