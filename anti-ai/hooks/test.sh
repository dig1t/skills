#!/usr/bin/env bash
# Self-check for the hook scripts. Run: ./hooks/test.sh
set -u
dir="$(cd "$(dirname "$0")" && pwd)"

run() { printf '%s' "$1" | "$dir/$2" >/dev/null 2>&1; echo $?; }

# no-ai-footer: commit WITH footer is blocked (exit 2)
[ "$(run '{"tool_input":{"command":"git commit -m \"feat: x\\n\\nCo-Authored-By: Claude <noreply@anthropic.com>\""}}' no-ai-footer.sh)" = 2 ] || { echo "FAIL: footer commit not blocked"; exit 1; }

# no-ai-footer: clean commit is allowed (exit 0)
[ "$(run '{"tool_input":{"command":"git commit -m \"feat: x\""}}' no-ai-footer.sh)" = 0 ] || { echo "FAIL: clean commit blocked"; exit 1; }

# no-ai-footer: grepping for the footer (no git commit) is NOT blocked (exit 0)
[ "$(run '{"tool_input":{"command":"grep -r \"Co-Authored-By: Claude\" ."}}' no-ai-footer.sh)" = 0 ] || { echo "FAIL: non-commit false positive"; exit 1; }

# reminder: copy-ish prompt emits a reminder line
out=$(printf '%s' '{"prompt":"write the landing page headline"}' | "$dir/anti-ai-reminder.sh")
[ -n "$out" ] || { echo "FAIL: reminder did not fire on copy prompt"; exit 1; }

# reminder: pure-code prompt stays quiet
out=$(printf '%s' '{"prompt":"refactor the binary search to be iterative"}' | "$dir/anti-ai-reminder.sh")
[ -z "$out" ] || { echo "FAIL: reminder fired on code prompt"; exit 1; }

echo "ok"
