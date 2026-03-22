#!/bin/bash
# Block raw git commands that corrupt stg patch stacks.
# Only blocks when stg is active on the current branch.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check commands that match prohibited git operations
if ! echo "$COMMAND" | grep -qE '\bgit\s+(commit|rebase|reset|cherry-pick)\b'; then
    exit 0
fi

# Allow if stg is not active on this branch
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || exit 0
if ! git show-ref --verify "refs/stacks/$BRANCH" >/dev/null 2>&1; then
    exit 0
fi

echo "BLOCKED: stg is active on this branch. Use stg commands instead:" >&2
echo "  git commit       -> stg new + stg refresh" >&2
echo "  git commit --amend -> stg edit / stg refresh" >&2
echo "  git rebase <base> -> stg rebase <base> (move stack onto new base)" >&2
echo "  git rebase -i    -> stg reorder / stg squash / stg edit / stg delete" >&2
echo "  git reset HEAD~N -> stg pop (unapply patches)" >&2
echo "  git reset --hard -> stg reset --hard (restore to last stg state)" >&2
echo "  git cherry-pick  -> stg pick" >&2
exit 2
