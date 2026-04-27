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

# Only check commands that match prohibited git operations
if ! echo "$STRIPPED" | grep -qE '\bgit\s+(branch|commit|rebase|reset|cherry-pick)\b'; then
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

echo "BLOCKED: stg is active on this branch. Use stg commands instead:" >&2
echo "  git branch       -> stg branch (manages stg metadata alongside branches)" >&2
echo "  git commit       -> stg new + stg refresh" >&2
echo "  git commit --amend -> stg edit / stg refresh" >&2
echo "  git rebase <base> -> stg rebase <base> (move stack onto new base)" >&2
echo "  git rebase -i    -> stg reorder / stg squash / stg edit / stg delete" >&2
echo "  git reset HEAD~N -> stg pop (unapply patches)" >&2
echo "  git reset --hard -> stg reset --hard (restore to last stg state)" >&2
echo "  git cherry-pick  -> stg pick" >&2
exit 2
