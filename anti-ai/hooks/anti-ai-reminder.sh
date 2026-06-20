#!/usr/bin/env bash
# UserPromptSubmit: when the prompt looks like it will produce user-facing text,
# inject a one-line reminder to invoke the anti-ai skill. Stdout on exit 0 is added
# to context for this event. Gated so it stays quiet on pure-code prompts.
# ponytail: keyword gate over the raw event JSON, no parser needed.
input=$(cat)

printf '%s' "$input" | grep -qiE 'copywrit|copy[^a-z]|headline|subhead|tagline|slogan|landing page|marketing|microcopy|\bcta\b|readme|changelog|release notes|newsletter|\btweet\b|caption|blurb|onboarding|error message|tooltip|empty state|push notification|\bemail\b|\bblog\b|\bdocs?\b|\bpr (title|description|body)\b|write .*(text|copy|description|message)|build .*(page|landing|site|hero|component|form|modal)' || exit 0

echo "[anti-ai] This prompt may produce user-facing text. Invoke the anti-ai skill before writing any copy, and run its self-check (banned words, em dashes, smart quotes, sycophancy) before finishing."
exit 0
