#!/bin/bash
# Block raw git commands that corrupt stg patch stacks.
# Only blocks when stg is active on the current branch.

if ! command -v jq >/dev/null 2>&1; then
    echo "block-raw-git: jq is required but not installed; install jq to enable the stg guard." >&2
    exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Delete heredoc bodies before any pattern looks at the text. A body
# is data the shell hands to a command, not command text, yet it is
# where prose naming a prohibited command lands (a commit message
# written with "cat > msg <<EOF", a test script, a prompt). The quote
# strip below cannot help: a body is unquoted. The body runs from the
# line after the operator to the line consisting of WORD alone
# (tab-indented with "<<-"); the terminator is a whole line, so it
# cannot be confused with command text. The operator is "<<" or
# "<<-", optional space, then WORD bare, quoted, or with a leading
# backslash. Several operators on one line open their bodies in
# order, as bash reads them. A here-string ("<<<") is not a heredoc
# and must not start a body: swallowing the rest of the command on
# one would fail open.
#
# Two more ways a body could swallow command text and fail open.
# WORD is any word bash accepts, not just an identifier: a narrower
# class truncates "END-OF" to "END", the terminator never matches,
# and every later line is deleted unchecked. And "<<" inside a
# quoted string, a comment, or an arithmetic expansion starts no
# body: the operator is looked for on a copy of the line with those
# removed, after unquoting the delimiter itself so that a quoted
# WORD survives the strip. A body still open at end of input is put
# back, since bash reads to end of input there too.
if [[ $COMMAND == *'<<'* ]]; then
COMMAND=$(echo "$COMMAND" | awk -v q="'" -v dq='"' '
    BEGIN {
        word = "[^[:space:]<>;|&" q dq "]+"
        quoted = "<<-?[[:space:]]*[" q dq "]" word "[" q dq "]"
        re = "<<-?[[:space:]]*" word
    }
    body {
        held = held $0 "\n"
        if (dash[i]) sub(/^\t+/, "")
        if ($0 == term[i]) {
            held = ""
            if (++i > n) body = 0
        }
        next
    }
    { print }
    {
        probe = $0
        while (match(probe, quoted)) {
            op = substr(probe, RSTART, RLENGTH)
            gsub("[" q dq "]", "", op)
            probe = substr(probe, 1, RSTART - 1) op \
                substr(probe, RSTART + RLENGTH)
        }
        gsub(dq "[^" dq "]*" dq, "", probe)
        gsub(q "[^" q "]*" q, "", probe)
        gsub(/\$\(\([^)]*\)\)/, "", probe)
        sub(/(^|[[:space:]])#.*/, "", probe)
        gsub(/<<<[^[:space:]]*/, "", probe)
        n = 0
        while (match(probe, re)) {
            term[++n] = substr(probe, RSTART, RLENGTH)
            dash[n] = (substr(term[n], 1, 3) == "<<-")
            sub(/^<<-?[[:space:]]*\\?/, "", term[n])
            probe = substr(probe, RSTART + RLENGTH)
        }
        if (n) { i = 1; body = 1 }
    }
    END { if (body) printf "%s", held }
')
fi

# Each "git -C <dir>" invocation targets <dir>; a bare "git
# <subcommand>" (no -C) targets the hook's cwd -- the session's primary
# branch. The guard must test stg-activity on the repo each subcommand
# actually mutates, so collect every -C target rather than only the
# first: a benign "git -C <plain> ..." must not vouch for a prohibited
# "git -C <stg> ..." chained on the same line.
#
# Collect the targets before the quote strip below, and accept a
# quoted target. Stripping first deletes a quoted target outright,
# and the subcommand that follows is then read as the target: the
# fold further down eats it, no prohibited pattern matches, and the
# command is allowed. That is a fail-open in the guard's own repo,
# since "git -C '<stg repo>' commit" is permitted.
C_TARGET="(\"[^\"]*\"|'[^']*'|[^[:space:]\"']+)"
mapfile -t GIT_C_DIRS < <(echo "$COMMAND" |
    grep -oE "\\bgit[[:space:]]+-C[[:space:]]+$C_TARGET" |
    sed -E "s/.*-C[[:space:]]+//; s/^\"(.*)\"\$/\\1/; s/^'(.*)'\$/\\1/")

# Replace each target with a neutral unquoted token so the quote strip
# leaves the -C form intact for the bare/-C distinction and the fold
# below.
COMMAND=$(echo "$COMMAND" | sed -E "s/\\bgit[[:space:]]+-C[[:space:]]+$C_TARGET/git -C DIR/g")

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

# A bare prohibited git (the subcommand immediately follows "git")
# targets the cwd. Detect it before folding the -C prefixes away, while
# bare and -C forms are still distinguishable.
BARE_PRESENT=no
if echo "$STRIPPED" | grep -qE '\bgit\s+(branch|commit|rebase|reset|cherry-pick|checkout|switch|restore|worktree|merge)\b'; then
    BARE_PRESENT=yes
fi

# Fold "git -C <dir>" down to a bare "git" so the prohibited-subcommand
# patterns still see the subcommand on git's word boundary; without
# this, "git -C <dir> commit" slips past the regex entirely.
STRIPPED=$(echo "$STRIPPED" | sed -E 's/\bgit[[:space:]]+-C[[:space:]]+[^[:space:]]+/git/g')

# Only check commands that match prohibited git operations
if ! echo "$STRIPPED" | grep -qE '\bgit\s+(branch|commit|rebase|reset|cherry-pick|checkout|switch|restore|worktree|merge)\b'; then
    exit 0
fi

# stg_active <dir>: succeed when the branch checked out in <dir> (the
# cwd when <dir> is empty) carries an stg stack ref. Leaves the branch
# name in STG_BRANCH so the BLOCKED line can name it.
stg_active() {
    local dir=$1
    local -a g=(git)
    [ -n "$dir" ] && g=(git -C "$dir")
    STG_BRANCH=$("${g[@]}" symbolic-ref --short HEAD 2>/dev/null) || return 1
    "${g[@]}" show-ref --verify "refs/stacks/$STG_BRANCH" >/dev/null 2>&1
}

# Block when any repo the command addresses carries an stg stack. A
# resolvable -C target is checked directly; an unresolvable one (e.g. a
# quoted shell variable stripped above) falls back to the cwd check,
# keeping the guard fail-closed. The cwd is checked when a bare git
# addresses it, or when an unresolvable -C falls back to it.
#
# Record which check tripped in HIT and print it in the BLOCKED line:
# a block that names only "this branch" cannot be told apart from a
# fallback, and the agent reads a stack in the target repo as the cwd
# vouching for it.
check_cwd=$BARE_PRESENT
addressed_stg=no
unresolved=
HIT=
for dir in "${GIT_C_DIRS[@]}"; do
    # The hook sees the command text before the shell runs it, so a
    # leading ~ or $HOME is still literal here. Expand the forms the
    # shell would, so a -C into a home-relative repo resolves rather
    # than falling back to the cwd check.
    case "$dir" in
        '~'|'~/'*)         dir="$HOME${dir#\~}" ;;
        '$HOME'|'$HOME/'*) dir="$HOME${dir#\$HOME}" ;;
        '${HOME}'*)        dir="$HOME${dir#\$\{HOME\}}" ;;
    esac
    if [ -d "$dir" ]; then
        if stg_active "$dir"; then
            addressed_stg=yes
            HIT="$dir (branch $STG_BRANCH)"
            break
        fi
    else
        check_cwd=yes
        [ -z "$unresolved" ] && unresolved=$dir
    fi
done
if [ "$addressed_stg" = no ] && [ "$check_cwd" = yes ] && stg_active ""; then
    addressed_stg=yes
    HIT="cwd $PWD (branch $STG_BRANCH)"
    [ -n "$unresolved" ] &&
        HIT="$HIT; fallback: -C target $unresolved did not resolve"
fi
[ "$addressed_stg" = no ] && exit 0

# Allow read-only forms of git branch and config-only changes
# (--set-upstream-to, --unset-upstream, --edit-description), which
# only touch .git/config and are invisible to stg. Block the forms
# that delete, rename, copy, or force-repoint branches, as those
# operations leave stg refs out of sync. Flagless creation passes;
# a brand-new branch carries no stack to desync. Likewise only
# worktree creation is prohibited; read-only worktree inspection
# does not move HEAD or update stg stack metadata.
#
# Test each simple command on its own line so a flag belonging to a
# neighboring command ("stg series -c" chained after a read-only
# "git branch --show-current") is not read as a branch-mutating flag,
# and so a read-only git branch cannot vouch for a prohibited
# subcommand chained on the same line. The allowed forms are rewritten
# to a neutral token and the remainder re-tested, mirroring the
# plumbing rewrite above.
SEGMENTS=$(echo "$STRIPPED" | tr ';|&' '\n')
if ! { echo "$SEGMENTS" | grep -E '\bgit\s+branch\b' |
           grep -qE '\s(--(delete|move|copy|force)\b|-[a-zA-Z]*[dDmMcCfF][a-zA-Z]*\b)'; } &&
   ! echo "$SEGMENTS" | grep -qE '\bgit\s+worktree\s+add\b'; then
    REST=$(echo "$SEGMENTS" |
        sed -E 's/\bgit[[:space:]]+(branch|worktree)\b/git ALLOWED/g')
    if ! echo "$REST" | grep -qE '\bgit\s+(branch|commit|rebase|reset|cherry-pick|checkout|switch|restore|worktree|merge)\b'; then
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

echo "BLOCKED: stg is active in $HIT." >&2
# Branch on HIT, not on $unresolved: an unresolved target followed by a
# resolved stg target is a genuine hit, and HIT carries no fallback
# note in that case.
case $HIT in
*'; fallback: '*)
    echo "The -C target did not resolve, so the cwd was checked in its place. Give the target as an absolute path or one starting with ~/, \$HOME/, or \${HOME}/ and rerun. If the cwd itself is the intended repo, use stg commands instead:" >&2 ;;
*)
    echo "Use stg commands instead:" >&2 ;;
esac
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
