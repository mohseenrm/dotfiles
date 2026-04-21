---
name: request-pr-review
description: >
  Request PR reviews from GitHub users or teams using the GitHub CLI, and optionally
  notify a Slack channel. Use when the user wants to add reviewers to a pull request,
  request code reviews, assign team reviewers, send Slack notifications about PRs,
  or automate review requests. Triggers on tasks involving PR reviews, code review
  requests, reviewer assignment, Slack notifications for PRs, or review automation.
metadata:
  author: mohseenrm
  version: "0.3.0"
---

# Request PR Review

Request code reviews on GitHub pull requests using the `gh` CLI, with optional Slack channel notifications. Supports individual users, teams, smart reviewer discovery via git blame and CODEOWNERS, and posting review requests to Slack.

## When to use this skill

Use this skill when the user wants to:

- Request a code review on a pull request
- Add reviewers (individuals or teams) to an existing PR
- Remove reviewers from a PR
- Find the right reviewers for a PR based on code ownership
- Automate review requests as part of a PR workflow
- Check who has been requested for review or has already reviewed
- Re-request review after addressing feedback
- Send a Slack message to a team channel about a PR
- Notify a Slack channel when requesting reviews

## Prerequisites

The GitHub CLI (`gh`) must be installed and authenticated:

```bash
gh auth status  # Verify authentication
```

The user must have push access to the repository (or be a collaborator) to request reviews.

For Slack notifications, the **Slack CLI** (`slack`) must be installed and authenticated:

```bash
slack auth list  # Verify authentication
```

The Slack CLI stores a user token in `~/.slack/credentials.json` after running `slack login`. This token is used automatically for sending messages — no separate bot token or app setup required.

If the Slack CLI is not installed, install it with:

```bash
curl -fsSL https://downloads.slack-edge.com/slack-cli/install.sh | bash
slack login  # Follow the interactive auth flow
```

## Agent rules

1. **Always detect the current PR context first.** Before requesting reviews, determine the PR number. Use `gh pr view --json number` if on a PR branch, or ask the user for the PR number/URL.
2. **Never request review from the PR author.** GitHub rejects this. Check the author first with `gh pr view --json author`.
3. **Use `@org/team-slug` format for team reviewers.** Individual usernames are bare (e.g., `alice`), teams require the org prefix (e.g., `@opendoor/backend-team`).
4. **Confirm before requesting reviews from large lists.** If requesting from 4+ reviewers, confirm with the user first.
5. **Handle errors gracefully.** Common failures: user is not a collaborator (422), insufficient permissions (403), user is the PR author. Report the error clearly and suggest alternatives.
6. **Prefer team reviewers when the user says "the team" or similar.** If the user says "request review from the backend team", use team syntax, not individual usernames.
7. **Always ask for the Slack channel before sending.** Never assume a channel name. If the user says "notify Slack", ask which channel.
8. **Check Slack CLI auth before attempting notifications.** Run `slack auth list` to verify. If not authenticated, tell the user to run `slack login`. Do not silently fail.
9. **Extract the Slack CLI token from `~/.slack/credentials.json`** using `jq` to read the token for the first (or matching) workspace entry. Use this token with `curl` to call the Slack Web API.
10. **Use Slack mrkdwn formatting for messages.** Bold with `*text*`, links with `<url|text>`, mentions with `<!here>` or `<@USER_ID>`. Do not use standard Markdown.
11. **Include the PR link in every Slack notification.** Always include a clickable link to the PR.

## Core commands

### Request review from individuals

```bash
# Single reviewer
gh pr edit <PR_NUMBER> --add-reviewer username

# Multiple reviewers (comma-separated)
gh pr edit <PR_NUMBER> --add-reviewer user1,user2,user3
```

### Request review from teams

```bash
# Team reviewer (requires @org/ prefix)
gh pr edit <PR_NUMBER> --add-reviewer @org/team-slug

# Mix of individuals and teams
gh pr edit <PR_NUMBER> --add-reviewer user1,@org/team-slug
```

### Remove reviewers

```bash
gh pr edit <PR_NUMBER> --remove-reviewer username
gh pr edit <PR_NUMBER> --remove-reviewer @org/team-slug
```

### Request review at PR creation time

```bash
gh pr create --title "My PR" --body "Description" --reviewer user1,user2
```

## Workflows

### Standard review request

1. Determine the PR number:
   ```bash
   gh pr view --json number --jq '.number'
   ```

2. Check the PR author (to avoid self-review request):
   ```bash
   gh pr view --json author --jq '.author.login'
   ```

3. Request review:
   ```bash
   gh pr edit <PR_NUMBER> --add-reviewer user1,user2
   ```

4. Verify the request was applied:
   ```bash
   gh pr view --json reviewRequests --jq '.reviewRequests[].login'
   ```

### Smart reviewer discovery

When the user asks "who should review this?" or wants automatic reviewer suggestions:

1. Get the list of changed files:
   ```bash
   gh pr diff --name-only
   ```

2. Check CODEOWNERS for automatic assignments:
   ```bash
   cat .github/CODEOWNERS 2>/dev/null || cat CODEOWNERS 2>/dev/null || echo "No CODEOWNERS file found"
   ```

3. Use git blame to find recent contributors to changed files:
   ```bash
   # Get top contributors to changed files
   gh pr diff --name-only | head -5 | xargs -I{} git log --format='%ae' --since='6 months ago' -- {} | sort | uniq -c | sort -rn | head -5
   ```

4. Present the suggested reviewers to the user and confirm before requesting.

### Re-request review after updates

When the user has addressed feedback and wants to re-request review:

1. Find who already reviewed:
   ```bash
   gh pr view --json reviews --jq '.reviews[] | select(.state != "COMMENTED") | .author.login' | sort -u
   ```

2. Re-request from those reviewers:
   ```bash
   gh pr edit <PR_NUMBER> --add-reviewer <previous_reviewers>
   ```

### Check review status

```bash
# Who has been requested
gh pr view --json reviewRequests --jq '.reviewRequests[].login'

# Who has reviewed and their verdict
gh pr view --json reviews --jq '.reviews[] | "\(.author.login): \(.state)"'

# Full review status summary
gh pr view --json reviewRequests,reviews,reviewDecision --jq '{
  requested: [.reviewRequests[].login],
  reviews: [.reviews[] | {reviewer: .author.login, state: .state}],
  decision: .reviewDecision
}'
```

### Mark PR as ready for review (draft PRs)

```bash
# Mark draft PR as ready before requesting reviews
gh pr ready <PR_NUMBER>

# Then request reviews
gh pr edit <PR_NUMBER> --add-reviewer user1,user2
```

## Slack notifications

### How it works

The Slack CLI stores a user token in `~/.slack/credentials.json` after `slack login`. This token is extracted with `jq` and used with `curl` to call the Slack Web API directly. No separate bot token or Slack app setup is needed.

### Extracting the Slack CLI token

```bash
SLACK_TOKEN=$(jq -r 'to_entries[0].value.token' ~/.slack/credentials.json)
```

If the user has multiple workspaces, extract by team domain:

```bash
SLACK_TOKEN=$(jq -r 'to_entries[] | select(.value.team_domain == "myworkspace") | .value.token' ~/.slack/credentials.json)
```

### Verifying Slack auth

Before sending, always verify:

```bash
if ! slack auth list 2>&1 | grep -q "User ID"; then
  echo "Slack CLI not authenticated. Run: slack login"
  exit 1
fi
```

### Send a Slack message about a PR

```bash
SLACK_TOKEN=$(jq -r 'to_entries[0].value.token' ~/.slack/credentials.json)

curl -s -X POST 'https://slack.com/api/chat.postMessage' \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H 'Content-type: application/json' \
  --data "$(jq -nc \
    --arg channel '#channel-name' \
    --arg text ':eyes: *PR #<NUMBER> is ready for review*: <PR_URL|View PR>' \
    '{channel: $channel, text: $text}')"
```

### Validating Slack API response

Always check the response:

```bash
response=$(curl -s -X POST 'https://slack.com/api/chat.postMessage' \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H 'Content-type: application/json' \
  --data "$(jq -nc \
    --arg channel '#channel-name' \
    --arg text 'message' \
    '{channel: $channel, text: $text}')")

if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
  echo "Message sent successfully"
else
  echo "Failed: $(echo "$response" | jq -r '.error')"
fi
```

### Slack message formatting (mrkdwn)

| Format | Syntax |
|--------|--------|
| Bold | `*bold*` |
| Italic | `_italic_` |
| Strikethrough | `~strike~` |
| Code | `` `code` `` |
| Code block | ` ```code``` ` |
| Link | `<https://url\|display text>` |
| Channel link | `<#C1234567890>` |
| User mention | `<@U1234567890>` |
| @here | `<!here>` |
| @channel | `<!channel>` |

### Example messages

Simple review request:
```
:eyes: *PR #123 is ready for review*
<https://github.com/org/repo/pull/123|View Pull Request>
```

Detailed review request:
```
:mag: *Code review requested*
*PR:* <https://github.com/org/repo/pull/123|#123 - Add user auth flow>
*Author:* alice
*Reviewers:* bob, carol
*Changes:* 5 files, +120 -30
Please review when you get a chance :pray:
```

## Workflows (continued)

### Full review request with Slack notification

1. Determine PR context:
   ```bash
   PR_NUMBER=$(gh pr view --json number --jq '.number')
   PR_URL=$(gh pr view --json url --jq '.url')
   PR_TITLE=$(gh pr view --json title --jq '.title')
   PR_AUTHOR=$(gh pr view --json author --jq '.author.login')
   ```

2. Request reviewers on GitHub:
   ```bash
   gh pr edit "$PR_NUMBER" --add-reviewer user1,user2
   ```

3. Extract Slack token and notify channel:
   ```bash
   SLACK_TOKEN=$(jq -r 'to_entries[0].value.token' ~/.slack/credentials.json)

   curl -s -X POST 'https://slack.com/api/chat.postMessage' \
     -H "Authorization: Bearer $SLACK_TOKEN" \
     -H 'Content-type: application/json' \
     --data "$(jq -nc \
       --arg channel '#team-channel' \
       --arg text ":eyes: *Review requested on PR #${PR_NUMBER}*\n<${PR_URL}|${PR_TITLE}>\n*Author:* ${PR_AUTHOR}\n*Reviewers:* user1, user2" \
       '{channel: $channel, text: $text}')"
   ```

4. Verify both succeeded.

## Quick reference

| Action | Command |
|--------|---------|
| Add reviewer | `gh pr edit <N> --add-reviewer user` |
| Add team reviewer | `gh pr edit <N> --add-reviewer @org/team` |
| Add multiple | `gh pr edit <N> --add-reviewer a,b,@org/t` |
| Remove reviewer | `gh pr edit <N> --remove-reviewer user` |
| List requested | `gh pr view --json reviewRequests` |
| List reviews | `gh pr view --json reviews` |
| Review decision | `gh pr view --json reviewDecision` |
| Mark ready | `gh pr ready <N>` |
| Create with reviewer | `gh pr create --reviewer user1,user2` |
| Slack token | `jq -r 'to_entries[0].value.token' ~/.slack/credentials.json` |
| Slack notify | `curl -s -X POST 'https://slack.com/api/chat.postMessage' -H "Authorization: Bearer $SLACK_TOKEN" ...` |
| Slack auth check | `slack auth list` |

## Error handling

| Error | Cause | Fix |
|-------|-------|-----|
| `422 Unprocessable` | User is not a collaborator | Verify username, check repo access |
| `403 Forbidden` | Insufficient permissions | Check `gh auth status`, re-auth if needed |
| `Could not resolve` | Invalid username or team slug | Verify the username/team exists in the org |
| Self-review rejected | Requesting review from PR author | Check author first, skip them |
| `not_in_channel` | User not in private channel | Join the channel first, or use a public channel |
| `channel_not_found` | Wrong channel name or ID | Verify channel name (include `#`), or use channel ID |
| `invalid_auth` | Expired Slack CLI token | Run `slack login` to re-authenticate |
| `token_expired` | Slack CLI token needs refresh | Run `slack login` to get a fresh token |
| No credentials file | `~/.slack/credentials.json` missing | Run `slack login` to authenticate |
