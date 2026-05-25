#!/bin/bash
# Validate Codex-facing plugin packaging metadata.

set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
failures=0

fail() {
    echo "FAIL: $*"
    failures=$((failures + 1))
}

require_file() {
    local path=$1

    if [ ! -f "$REPO_ROOT/$path" ]; then
        fail "missing $path"
        return 1
    fi
    return 0
}

require_jq() {
    local path=$1
    local filter=$2
    local want=$3
    local got

    got=$(jq -r "$filter" "$REPO_ROOT/$path" 2>/dev/null) ||
        fail "jq failed for $path filter $filter"

    if [ "$got" != "$want" ]; then
        fail "$path $filter: got '$got', want '$want'"
    fi
}

require_file "plugin/cel-kdev/.codex-plugin/plugin.json" &&
    require_jq "plugin/cel-kdev/.codex-plugin/plugin.json" '.skills' "./skills/"

require_file ".agents/plugins/marketplace.json" &&
    require_jq ".agents/plugins/marketplace.json" '.name' "cel-kdev" &&
    require_jq ".agents/plugins/marketplace.json" '.plugins[0].name' "cel-kdev" &&
    require_jq ".agents/plugins/marketplace.json" '.plugins[0].source.source' "local" &&
    require_jq ".agents/plugins/marketplace.json" '.plugins[0].source.path' "./plugin/cel-kdev" &&
    require_jq ".agents/plugins/marketplace.json" '.plugins[0].policy.installation' "AVAILABLE" &&
    require_jq ".agents/plugins/marketplace.json" '.plugins[0].policy.authentication' "ON_INSTALL"

require_file "plugin/cel-kdev/hooks/hooks.json" &&
    require_jq "plugin/cel-kdev/hooks/hooks.json" '.hooks.PreToolUse[0].matcher' "^Bash$" &&
    require_jq "plugin/cel-kdev/hooks/hooks.json" '.hooks.PreToolUse[0].hooks[0].command' '${PLUGIN_ROOT}/hooks/block-raw-git.sh'

for skill in b4 drgn perf sashiko stg trace-cmd; do
    require_file "plugin/cel-kdev/skills/$skill/agents/openai.yaml"
done

if [ "$failures" -ne 0 ]; then
    exit 1
fi

echo "Codex plugin metadata tests passed"
