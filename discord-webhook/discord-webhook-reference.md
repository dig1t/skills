# Discord Webhook API Reference

## Webhook Object

| Field | Type | Description |
|-------|------|-------------|
| id | snowflake | the id of the webhook |
| type | integer | the type of the webhook (1=Incoming, 2=Channel Follower, 3=Application) |
| guild_id? | ?snowflake | the guild id this webhook is for, if any |
| channel_id | ?snowflake | the channel id this webhook is for, if any |
| user? | user object | the user this webhook was created by |
| name | ?string | the default name of the webhook |
| avatar | ?string | the default user avatar hash of the webhook |
| token? | string | the secure token of the webhook (returned for Incoming Webhooks) |
| application_id | ?snowflake | the bot/OAuth2 application that created this webhook |
| url? | string | the url used for executing the webhook |

## Execute Webhook

```
POST /webhooks/{webhook.id}/{webhook.token}
```

You must provide a value for at least one of: `content`, `embeds`, `components`, `file`, or `poll`.

### Query String Params

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| wait | boolean | waits for server confirmation before response (default false) | false |
| thread_id | snowflake | send message to specified thread within webhook's channel | false |
| with_components | boolean | whether to respect the components field (default false) | false |

### JSON/Form Params

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| content | string | message contents (up to 2000 characters) | one of content, file, embeds, poll |
| username | string | override the default username of the webhook | false |
| avatar_url | string | override the default avatar of the webhook | false |
| tts | boolean | true if this is a TTS message | false |
| embeds | array of up to 10 embed objects | embedded rich content | one of content, file, embeds, poll |
| allowed_mentions | allowed mention object | allowed mentions for the message | false |
| components | array of message component | components to include with the message | false |
| files[n] | file contents | contents of the file being sent | one of content, file, embeds, poll |
| payload_json | string | JSON encoded body of non-file params (multipart/form-data only) | false |
| attachments | array of partial attachment objects | attachment objects with filename and description | false |
| flags | integer | message flags bitfield (only SUPPRESS_EMBEDS, SUPPRESS_NOTIFICATIONS, IS_COMPONENTS_V2) | false |
| thread_name | string | name of thread to create (forum/media channels only) | false |
| applied_tags | array of snowflakes | tag ids to apply to thread (forum/media channels only) | false |
| poll | poll request object | a poll | one of content, file, embeds, poll |

### Notes

- For webhook embeds, you can set every field except `type`, `provider`, `video`, and any `height`, `width`, or `proxy_url` values for images.
- Discord may strip invalid unicode characters or characters causing unexpected formatting.
- Use `allowed_mentions` to prevent unexpected mentions in user-generated content.
- When `IS_COMPONENTS_V2` flag is set, the message can only contain components (no content, embeds, files, or poll).

---

## Embed Object

For webhook embeds, `type` is always `rich` regardless of what you set.

### Embed Structure

| Field | Type | Description |
|-------|------|-------------|
| title | string | title of embed |
| description | string | description of embed |
| url | string | url of embed (makes title a hyperlink) |
| timestamp | ISO8601 timestamp | timestamp displayed in footer area |
| color | integer | color code in **decimal** (not hex) |
| footer | embed footer object | footer information |
| image | embed image object | image information |
| thumbnail | embed thumbnail object | thumbnail information |
| author | embed author object | author information |
| fields | array of embed field objects | fields information (max 25) |

### Embed Footer

| Field | Type | Description |
|-------|------|-------------|
| text | string | footer text |
| icon_url | string | url of footer icon |

### Embed Image

| Field | Type | Description |
|-------|------|-------------|
| url | string | source url of image |

### Embed Thumbnail

| Field | Type | Description |
|-------|------|-------------|
| url | string | source url of thumbnail (displayed top-right) |

### Embed Author

| Field | Type | Description |
|-------|------|-------------|
| name | string | name of author |
| url | string | url of author (makes name a hyperlink) |
| icon_url | string | url of author icon |

### Embed Field

| Field | Type | Description |
|-------|------|-------------|
| name | string | name of the field |
| value | string | value of the field |
| inline | boolean | whether field should display inline (side-by-side) |

---

## Character Limits

| Element | Max Characters |
|---------|---------------|
| content | 2,000 |
| embed title | 256 |
| embed description | 4,096 |
| embed field name | 256 |
| embed field value | 1,024 |
| embed footer text | 2,048 |
| embed author name | 256 |
| **total per embed** | **6,000** |
| embeds per message | 10 |
| fields per embed | 25 |

Inline fields display up to 3 per row (2 if thumbnail is present).

---

## Markdown Support

| Location | Markdown Supported? |
|----------|-------------------|
| content | Yes |
| embed description | Yes |
| embed field value | Yes |
| embed field name | Yes (limited) |
| embed title | Yes (limited) |
| embed footer text | **No** |
| embed author name | **No** |

Mentions in embeds render correctly only in `description` and `field value`, and will NOT trigger notifications.

---

## Color Reference

Colors must be in **decimal** format, not hex.

| Color | Decimal | Hex |
|-------|---------|-----|
| Red | 15158332 | #E74C3C |
| Green | 3066993 | #2ECC71 |
| Blue | 3447003 | #3498DB |
| Yellow | 16776960 | #FFFF00 |
| Orange | 15105570 | #E67E22 |
| Purple | 10181046 | #9B59B6 |
| White | 16777215 | #FFFFFF |
| Black | 0 | #000000 |
| Blurple (Discord) | 5793266 | #5865F2 |

To convert hex to decimal: `0xRRGGBB` as an integer. Example: `#FF5733` = `16734003`.

---

## Rate Limits

- 30 messages per minute per webhook.
- HTTP 429 response means rate limited. Check `retry_after` field in the response body.

---

## Example Payloads

### Simple Text Message

```json
{
  "content": "Hello from the webhook!"
}
```

### With Username and Avatar Override

```json
{
  "username": "Build Bot",
  "avatar_url": "https://example.com/avatar.png",
  "content": "Deployment complete."
}
```

### Single Embed

```json
{
  "embeds": [
    {
      "title": "Build Status",
      "description": "All checks passed.",
      "color": 3066993,
      "fields": [
        { "name": "Branch", "value": "main", "inline": true },
        { "name": "Commit", "value": "abc1234", "inline": true }
      ],
      "footer": { "text": "CI Pipeline" },
      "timestamp": "2026-02-06T12:00:00.000Z"
    }
  ]
}
```

### Embed with All Sections

```json
{
  "embeds": [
    {
      "title": "Release v1.2.0",
      "url": "https://github.com/user/repo/releases/tag/v1.2.0",
      "description": "New features and bug fixes.\n\n**Highlights:**\n- Feature A\n- Fix B",
      "color": 5793266,
      "author": {
        "name": "Release Bot",
        "icon_url": "https://example.com/icon.png",
        "url": "https://example.com"
      },
      "thumbnail": { "url": "https://example.com/thumb.png" },
      "image": { "url": "https://example.com/banner.png" },
      "fields": [
        { "name": "Version", "value": "1.2.0", "inline": true },
        { "name": "Environment", "value": "Production", "inline": true },
        { "name": "Changes", "value": "12 commits", "inline": true }
      ],
      "footer": {
        "text": "Deployed by CI",
        "icon_url": "https://example.com/ci-icon.png"
      },
      "timestamp": "2026-02-06T12:00:00.000Z"
    }
  ]
}
```

### Content + Embed Together

```json
{
  "content": "New update available!",
  "embeds": [
    {
      "title": "Update Details",
      "description": "Check the changelog for details.",
      "color": 16776960
    }
  ]
}
```

---

## Other Endpoints

### Edit Webhook Message

```
PATCH /webhooks/{webhook.id}/{webhook.token}/messages/{message.id}
```

To edit, use `?wait=true` on the execute call to get the message ID back, then PATCH with updated fields.

### Delete Webhook Message

```
DELETE /webhooks/{webhook.id}/{webhook.token}/messages/{message.id}
```

Returns 204 No Content on success.

### Get Webhook Message

```
GET /webhooks/{webhook.id}/{webhook.token}/messages/{message.id}
```

Returns the message object.

### Slack-Compatible Endpoint

```
POST /webhooks/{webhook.id}/{webhook.token}/slack
```

Accepts Slack-formatted payloads. Does not support `channel`, `icon_emoji`, `mrkdwn`, or `mrkdwn_in`.

### GitHub-Compatible Endpoint

```
POST /webhooks/{webhook.id}/{webhook.token}/github
```

Use as GitHub webhook "Payload URL". Supported events: `commit_comment`, `create`, `delete`, `fork`, `issue_comment`, `issues`, `member`, `public`, `pull_request`, `pull_request_review`, `pull_request_review_comment`, `push`, `release`, `watch`, `check_run`, `check_suite`, `discussion`, `discussion_comment`.
