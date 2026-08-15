---
name: anti-ai
description: Use before writing any text a human will read, even as a byproduct of a build task - marketing copy, headlines, CTAs, UX microcopy, error messages, tooltips, empty states, emails, social posts, READMEs, docs, changelogs, release notes, PR titles/descriptions, GitHub issues, in-game dialog, or string literals that render in UI. Also use before running `git commit` or `gh pr create`, and when about to open a reply with praise like "great question". When unsure whether text is user-facing, assume it is.
---

# anti-ai

Stops user-facing text from sounding like default LLM output, and stops the assistant from opening replies with sycophancy. Apply whenever you generate copy a real person will read, and at the start of any reply to the user.

## The rules

1. **Do not use any of the 67 banned words below in user-facing text.** Rewrite the sentence. Don't swap synonyms that carry the same hollow tone.
2. **Do not use em dashes (—, U+2014) anywhere.** Zero exceptions. Use a period, a comma, a colon, parentheses, or rephrase. En dashes (–) and hyphens (-) are fine.
3. **Do not use the banned sentence patterns** (next section).
4. **Do not use the structural tells** (next section).
5. **Do not open a reply with sycophancy** (next section).
6. **Do not add AI co-author footers to git commits** (next section).

## Banned words (67)

Whole-word, case-insensitive.

1. Delve
2. Cutting-edge
3. Tapestry
4. Scalable
5. Harness
6. Game-changer
7. Realm
8. Robust
9. Unlock
10. Critical
11. Serves as
12. Leverage
13. Transformative
14. Paradigm
15. Frictionless
16. Supercharge
17. Viable
18. Stands as
19. Empower
20. Revolutionize
21. Holistic
22. Future-proof
23. Elevate
24. Innovative
25. Marks a
26. Streamline
27. Groundbreaking
28. Intricate
29. Plug-and-play
30. Foster
31. Synergy
32. Represents a
33. Optimize
34. Breakthrough
35. Pivotal
36. Mission-critical
37. Align
38. Boasts a
39. Garner
40. Pioneering
41. Seamless
42. Turnkey
43. Accentuate
44. Features a
45. Unleash
46. Trailblazing
47. Nuanced
48. Data-driven
49. Redefine
50. Offers a
51. Embark
52. Crucial
53. Essential
54. Vital
55. Comprehensive
56. Curated
57. Bespoke
58. Tailored
59. Effortlessly
60. Truly
61. Indeed
62. Moreover
63. Furthermore
64. Vibrant
65. Bustling
66. Reliably
67. Cohesive

## Banned sentence patterns

These constructions are the LLM's defaults. Even with all banned words removed, they make copy read as machine-generated.

- **The pivot phrase:** `"It's not just X, it's Y"` / `"X isn't just Y, it's Z"`. Strikingly common in AI output. If you find it in a draft, restructure as two short sentences or pick the stronger half.
- **Audience-spanning intro:** `"Whether you're [a, b, or c]"`. Skip the list. Address one reader.
- **Scene-setting opener:** `"In today's fast-paced/digital/connected/modern world"` and variants. Cut the opener; start with the actual claim.
- **Invitation openers:** `"Let's dive in"`, `"Let's explore"`, `"Without further ado"`, `"Buckle up"`. Just start the content.
- **Imaginative openers:** `"Imagine if..."`, `"Picture this:"`, `"What if I told you..."`. Lead with the thing, not the framing.
- **Closers that restate:** `"In conclusion,"`, `"In summary,"`, `"Ultimately,"`, `"At the end of the day,"`. If the closer doesn't add new information, delete it.
- **`Navigate the [complexities|landscape|world|maze] of X`.** Pick a real verb that describes the action.
- **`From X to Y`** as a headline when X and Y are abstract categories (`"From idea to impact"`, `"From insight to action"`). Use a concrete subject.
- **`X, simplified`** / **`X, reimagined`** as a tagline. Generic. Say what changed.
- **`Designed to [verb]`** / **`Built to [verb]`** as feature copy. Just say what it does.

## Structural tells

Shape, not vocabulary. Equally telling.

- **Rule-of-three adjective triples.** `"fast, simple, and powerful"`. `"smart, scalable, and secure"`. `"clean, modern, and responsive"`. AI defaults to triples. Use one strong adjective, or two with a real contrast, or a concrete example.
- **Closing summary paragraph that rehashes the body.** If a reader could skip your last paragraph and miss nothing, cut it.
- **Title Case Headlines** when the surrounding document uses sentence case (or vice versa). Match the doc's convention.
- **Smart/curly quotes** (`""` `''`) when the rest of the doc uses straight quotes (`"` `'`). Inconsistency is an AI tell.
- **Three-dot suspense ellipsis** in marketing prose (`"wait for it..."`). Cut.
- **Unrequested TL;DR section** at the top. If the user did not ask for a summary, do not add one.
- **Bolding random key phrases** mid-paragraph for emphasis. Bold sparingly and consistently. If everything is bold, nothing is.
- **Trailing period on short standalone strings.** Badge descriptions, objectives, quest text, notifications, taglines, buttons, tooltips, list items: never end with a period. It reads too proper for game/UI copy. `"Take down your first zombie."` → `"Take down your first zombie"`. `"Heal the crew, patch the RV, hit harder."` → `"Heal the crew, patch the RV, hit harder"`. Internal punctuation stays; only the terminal period goes: `"Thanks for joining. Now keep that RV alive"`. Full paragraphs of running prose (docs, emails, body copy) keep normal end punctuation.

## Sycophancy in conversational replies

This rule applies to **assistant replies**, not generated copy. Do not open a response with any of:

- `"Great question!"` / `"Great point!"` / `"Excellent question!"`
- `"What a [great/brilliant/fantastic/wonderful/insightful] [question/idea/observation/point]"`
- `"Absolutely!"` as a standalone affirmation opener
- `"You're absolutely right"` when restating something the user just said
- `"I love that question"` / `"I love this idea"`
- `"That's a really [thoughtful/interesting/important] question"`

Skip the praise. Start with the answer. If the question genuinely needed clarification, ask for clarification. If the user proposed something good, say what's good about it specifically. Generic praise is a tell and adds zero information.

## Git commits

Do not add any AI-authorship footer to commits. The default `Co-Authored-By: Claude ... <noreply@anthropic.com>` line is an AI tell and clutters `git log` and `git blame` output. The user is the sole author.

**Banned footers (do not add):**

- Any `Co-Authored-By:` variant naming an AI model or an AI-vendor address like `noreply@anthropic.com`
- Lines like `🤖 Generated with Claude Code` or `Generated by Claude`

If a HEREDOC commit template includes a `Co-Authored-By:` block by default, strip it before running `git commit`.

**Override:** if the user explicitly asks to include a co-author trailer, do it. Otherwise, leave it off.

## Self-check before finishing

Run these checks before declaring copy done. If any hit, rewrite and re-check all of them.

**Check 1: banned words** (case-insensitive, whole-word match):

```bash
echo "your copy here" | grep -iEw "delve|cutting-edge|tapestry|scalable|harness|game-changer|realm|robust|unlock|critical|serves as|leverage|transformative|paradigm|frictionless|supercharge|viable|stands as|empower|revolutionize|holistic|future-proof|elevate|innovative|marks a|streamline|groundbreaking|intricate|plug-and-play|foster|synergy|represents a|optimize|breakthrough|pivotal|mission-critical|align|boasts a|garner|pioneering|seamless|turnkey|accentuate|features a|unleash|trailblazing|nuanced|data-driven|redefine|offers a|embark|crucial|essential|vital|comprehensive|curated|bespoke|tailored|effortlessly|truly|indeed|moreover|furthermore|vibrant|bustling|reliably|cohesive"
```

**Check 2: em dashes** (any occurrence is a failure):

```bash
echo "your copy here" | grep -F "—"
```

**Check 3: banned sentence patterns** (a sampler, not exhaustive):

```bash
echo "your copy here" | grep -iE "it's not just |isn't just |whether you'?re |in today'?s |let'?s dive|let'?s explore|without further ado|imagine if|picture this|in conclusion|in summary|ultimately,|at the end of the day|navigate the (complexities|landscape|world|maze)|designed to |built to "
```

**Check 4: smart quotes** (compare against straight-quote convention in surrounding doc):

```bash
echo "your copy here" | grep -E $'\xe2\x80\x9c|\xe2\x80\x9d|\xe2\x80\x98|\xe2\x80\x99'
```

If any check returns output, the draft fails. Fix and re-run all four. Also visually scan for `—` and curly `""` glyphs; they slip in without notice.

## What to do instead

Don't paraphrase with synonyms (`"optimize"` → `"improve"`). Synonyms keep the same lifeless shape. Instead:

- **Replace the abstraction with a specific.** `"Robust dashboard"` → `"shows 12 metrics at once."` `"Empower teams"` → `"lets two people edit the same doc."`
- **Drop the word entirely.** Often the sentence is stronger without it. `"Our innovative platform helps you …"` → `"Our platform helps you …"` → `"Lets you …"`
- **Use a verb that means something.** `"Leverage data"` → `"use the data"` / `"read from the table"` / `"join on user_id."`
- **Pick a concrete number, name, or example over a category word.** `"Pivotal feature"` → `"the feature most users open first."`
- **Strip the opener.** Most AI openers can be deleted with no loss. Start with the claim.

## Scope

- **Applies to:** anything a non-technical reader will see. Marketing pages, in-app copy, emails, social, docs intros, release notes, error messages, in-game dialog, push notifications. The sycophancy rule applies additionally to every conversational reply to the user.
- **Does not apply to:** code, internal commit messages, internal PR descriptions, internal Slack, schema names, log lines, or technical specs where a banned word is the actual term of art (e.g., `"horizontally scalable"` in a strictly internal system-design doc). When in doubt, treat as in-scope.

## How to replace an em dash

The em dash is overused for three jobs. Each has a cleaner substitute.

- **Pause for emphasis** (`"It works — fast."`): use a period. `"It works. Fast."`
- **Parenthetical aside** (`"The tool — built in a weekend — handles 10k requests."`): use parentheses or commas. `"The tool (built in a weekend) handles 10k requests."`
- **List or definition lead-in** (`"One thing — it's free."`): use a colon. `"One thing: it's free."`

If none of those feel right, rewrite the sentence.

## When the user explicitly asks for a banned item

The user wins. If they ask for a slogan with `"unleash"`, em dashes in a paragraph, a `"Great question!"` opener for a parody, a `"From X to Y"` headline, or a `Co-Authored-By: Claude` trailer on a specific commit, produce it. Flag once that it is on the anti-AI list, then comply.
