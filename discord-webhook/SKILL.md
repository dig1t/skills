---
name: discord-webhook
description: |
  Posts a message to a Discord webhook. Use when the user asks to
  send a webhook, notify a channel, or post an update to Discord.
  The webhook URL is read from the .env file at the project root.
  Invoke with: /discord-webhook <message>
allowed-tools: Bash, Read
files:
  - ./discord-webhook-reference.md
---

# Discord Webhook Poster

You post messages to a Discord webhook URL configured in the project's `.env` file.

## Setup

The `.env` file at the project root must contain:

```
WEBHOOK_URL=https://discord.com/api/webhooks/{webhook.id}/{webhook.token}
```

## Steps

1. **Read the webhook URL** from the project `.env` file by parsing the `WEBHOOK_URL` line.
2. If the `.env` file is missing or `WEBHOOK_URL` is not set, tell the user to create `.env` with `WEBHOOK_URL=<url>` and stop.
3. **Determine the payload:**
   - If the user provided a simple message as arguments, use that as the `content` field.
   - If the user wants rich formatting, construct an embed payload (see reference docs).
   - If no message was provided, ask what they want to send.
4. **Build the JSON payload** following the Discord webhook API format. Write it to a temp file to avoid shell escaping issues:

```bash
WEBHOOK_URL=$(grep '^WEBHOOK_URL=' .env | cut -d '=' -f 2-)
cat > /tmp/webhook_payload.json << 'PAYLOAD'
{"content": "message here"}
PAYLOAD
curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d @/tmp/webhook_payload.json
```

5. **Report the result:**
   - 200 or 204: Message sent successfully.
   - 429: Rate limited. Report the retry_after if available.
   - Other: Show the status code and suggest the user check their webhook URL.

## Message Splitting (CRITICAL)

The `content` field has a hard limit of **2000 characters**. If your message exceeds this:

1. **Split the text** into chunks of 2000 characters or fewer.
2. **Split at natural boundaries**: prefer splitting at newlines (`\n`), then sentence endings (`. `), then word boundaries (` `). Never split mid-word.
3. **Send each chunk as a separate webhook POST**, sequentially (wait for each to return before sending the next).
4. **Respect rate limits**: if sending many chunks, add a brief delay between requests to avoid hitting 30/min.

This also applies to embed fields:
- `description` max: 4096 chars
- `field.value` max: 1024 chars
- `field.name` max: 256 chars
- `footer.text` max: 2048 chars
- Total per embed: 6000 chars
- Max 10 embeds per message

If embed content exceeds these limits, split across multiple embeds or multiple messages.

## Rules

- Never hardcode or log the webhook URL in output shown to the user (redact it).
- Always JSON-escape message content to avoid injection.
- Always check content length before sending (see Message Splitting above).
- Discord does NOT support markdown in all embed fields. See the reference doc for which fields support markdown.
- Keep payloads simple (`{"content": "..."}`) unless the user asks for embeds or richer formatting.
- When using embeds, always refer to `discord-webhook-reference.md` for field names, types, and limits.
- Respect the 30 messages/minute rate limit.
