#!/bin/bash
# analyze-all.sh — repo-wide luau-lsp type check for a house-stack Roblox repo.
#
# Purpose: run the SAME flag set as the PostToolUse hook
# (scripts/luau-analyze-hook.sh) over a whole directory instead of one file,
# plus --ignore="DevPackages/**" so Jest Lua's internal type errors don't
# drown the signal. Prints deduplicated diagnostics and a one-line summary.
#
# Usage (from anywhere inside the project repo):
#   .claude/skills/roblox-diagnostics-and-tooling/scripts/analyze-all.sh [path]
#   path defaults to src/
#
# Exit codes: 0 = clean, 1 = diagnostics found, 2 = preconditions missing.
# Unlike the hook (which silently exits 0 when sourcemap.json or
# globalTypes.d.luau are missing), this script fails LOUDLY on missing
# preconditions — a silent pass is worse than an error.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 2
target="${1:-src/}"

if [[ ! -f sourcemap.json ]]; then
	echo "ERROR: sourcemap.json missing. Run: npm run build:sourcemap" >&2
	exit 2
fi
if [[ ! -f globalTypes.d.luau ]]; then
	echo "ERROR: globalTypes.d.luau missing. Start a Claude session (the setup-lsp SessionStart hook fetches it) or download it from JohnnyMorganz/luau-lsp." >&2
	exit 2
fi
if ! command -v luau-lsp > /dev/null; then
	echo "ERROR: luau-lsp not on PATH. Run: aftman install" >&2
	exit 2
fi

raw=$(luau-lsp analyze \
	--defs=globalTypes.d.luau \
	--sourcemap=sourcemap.json \
	--no-strict-dm-types \
	--ignore="Packages/**" \
	--ignore="DevPackages/**" \
	--ignore="*.spec.lua" \
	--ignore="*.spec.luau" \
	"$target" 2>&1)
status=$?

# luau-lsp can report the same diagnostic twice: once with an absolute path
# plus a "[game/...]" DataModel annotation, once with a relative path.
# Normalize both forms to "relative(path)(line,col): Category: msg" and dedupe.
repo_root="$(pwd)"
diagnostics=$(echo "$raw" \
	| grep -v '^\[INFO\]' \
	| grep -E '\([0-9]+,[0-9]+\): ' \
	| sed -e "s| \[game/[^]]*\]||" -e "s|^$repo_root/||" \
	| sort -u)

if [[ -n "$diagnostics" ]]; then
	echo "$diagnostics"
fi

total=0
if [[ -n "$diagnostics" ]]; then
	total=$(echo "$diagnostics" | wc -l | tr -d ' ')
fi
errors=$(echo "$diagnostics" | grep -c 'TypeError:' || true)
files=0
if [[ -n "$diagnostics" ]]; then
	files=$(echo "$diagnostics" | sed 's|(.*||' | sort -u | wc -l | tr -d ' ')
fi

echo "SUMMARY: $total diagnostics ($errors TypeError, $((total - errors)) other) in $files files under $target"

if [[ $status -ne 0 || $total -gt 0 ]]; then
	exit 1
fi
exit 0
