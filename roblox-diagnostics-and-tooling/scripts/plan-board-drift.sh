#!/bin/bash
# plan-board-drift.sh — doc-debt detector for docs/plans/.
#
# Purpose: list every docs/plans/*.md with its frontmatter status and
# checkbox counts, then flag drift:
#   - status: done but file still in docs/plans/ (should be in archive/)
#   - no unchecked boxes + some checked boxes, but status is not done
#     (plan probably finished and never closed out)
#   - no status frontmatter at all (predates the plan workflow)
#
# The project's CLAUDE.md owns the plan lifecycle rules; this script only
# measures compliance. Usage (from anywhere inside the project repo):
#   .claude/skills/roblox-diagnostics-and-tooling/scripts/plan-board-drift.sh
#
# Read-only. Exit 0 always.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

plans_dir="docs/plans"
printf '%-45s %-8s %5s %7s\n' "PLAN" "STATUS" "OPEN" "CHECKED"
printf '%-45s %-8s %5s %7s\n' "----" "------" "----" "-------"

drift=""
for f in "$plans_dir"/*.md; do
	[[ -f "$f" ]] || continue
	name=$(basename "$f")
	status=$(awk 'NR<=5 && /^status:/ { print $2; exit }' "$f")
	[[ -n "$status" ]] || status="(none)"
	open=$(grep -cE '^\s*- \[ \]' "$f" || true)
	checked=$(grep -cE '^\s*- \[[xX]\]' "$f" || true)
	printf '%-45s %-8s %5s %7s\n' "$name" "$status" "$open" "$checked"

	if [[ "$status" == "done" ]]; then
		drift+="  ! $name: status done but not moved to $plans_dir/archive/"$'\n'
	elif [[ "$open" -eq 0 && "$checked" -gt 0 && "$status" != "done" ]]; then
		drift+="  ? $name: all $checked boxes checked but status is '$status' (finished but never closed out?)"$'\n'
	fi
done

archived=$(find "$plans_dir/archive" -name "*.md" 2> /dev/null | wc -l | tr -d ' ')

echo ""
echo "Archive: $archived plan(s) in $plans_dir/archive/"
echo ""
echo "=== Drift flags ==="
if [[ -n "$drift" ]]; then
	printf '%s' "$drift"
else
	echo "  (none)"
fi
echo "  i $(grep -L '^status:' "$plans_dir"/*.md 2> /dev/null | wc -l | tr -d ' ') plan(s) have no status frontmatter (predate the workflow)"
