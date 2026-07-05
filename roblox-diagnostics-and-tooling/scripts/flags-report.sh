#!/bin/bash
# flags-report.sh — one-command visibility into every toggle in a
# house-stack Roblox repo.
#
# Purpose: print (1) the FeatureFlags table from
# src/Shared/Class/FeatureFlags.luau and (2) every top-level `local *DEBUG*`
# constant in src/ with file:line:value, then flag any DEBUG toggle whose
# value is not `false` (drift candidates that may be live in production).
#
# Usage (from anywhere inside the project repo):
#   .claude/skills/roblox-diagnostics-and-tooling/scripts/flags-report.sh
#
# Read-only. Exit 0 always (it reports, it does not judge builds).
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

flags_file="src/Shared/Class/FeatureFlags.luau"

echo "=== FeatureFlags ($flags_file) ==="
if [[ -f "$flags_file" ]]; then
	# Flag entries are tab-indented `Name = true/false,` lines inside the
	# `local flags` table.
	grep -nE '^\s+[A-Za-z0-9_]+ = (true|false),' "$flags_file" \
		| sed -e 's/^\([0-9]*\):[[:space:]]*/  :\1  /' -e 's/,.*$//'
else
	echo "  ERROR: $flags_file not found" >&2
fi

echo ""
echo "=== DEBUG constants in src/ (file:line: declaration) ==="
debug_lines=$(grep -rnE '^local [A-Z_0-9]*DEBUG[A-Z_0-9]*[[:space:]]*(:[^=]*)?=' \
	src --include="*.luau" | sed 's|^\./||')
echo "$debug_lines" | sed 's/^/  /'

echo ""
echo "=== Telemetry toggles (src/Server/Features/Telemetry/) ==="
grep -rnE '^local ENABLED' src/Server/Features/Telemetry --include="*.luau" 2> /dev/null \
	| sed 's/^/  /' || echo "  (none found)"

echo ""
echo "=== DEBUG values that are NOT false (check these before a release) ==="
live=$(echo "$debug_lines" | grep -vE '=\s*false\b' || true)
if [[ -n "$live" ]]; then
	echo "$live" | sed 's/^/  ! /'
else
	echo "  (none — all DEBUG constants are false)"
fi
