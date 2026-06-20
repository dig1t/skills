# anti-ai

Banned-word list for user-facing copy. Triggers on any client-facing text
generation to keep output from sounding like default AI. Ships as a plugin with
hooks.

## Installing as a plugin (for the hooks)

`anti-ai` is both a skill and a plugin. Symlinking it as a skill loads the
`SKILL.md` only; the hooks (block AI-footer commits, inject an anti-ai reminder
on copy prompts) load only when it is installed as a plugin:

```bash
npx skills add firebit-dev/skills
```

Run `./hooks/test.sh` to self-check the hook scripts.
