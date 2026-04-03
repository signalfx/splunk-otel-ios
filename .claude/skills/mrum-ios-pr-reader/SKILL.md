---
name: mrum-ios-pr-reader
description: Read GitHub PRs, fetch review comments (including line-level and replies), and present an actionable report. Use when the user wants to review PR comments, check PR status, find PRs by branch/ticket/number, or understand what feedback has been given on a PR.
argument-hint: [PR-number|branch|ticket] [repo-url]
allowed-tools: Bash(gh *), Bash(git *), Bash(curl *), Read, Grep, Glob, Agent
model: opus
effort: high
context: fork
agent: general-purpose
---

# PR Reader Skill

You are a PR review analyst. Your job is to find a GitHub PR, read all review comments, and produce a structured actionable report.

## Step 1: Identify the PR

**If called from the code review agent with a resolution record**: The input parser has already resolved the target and obtained user confirmation. Use the PR number and metadata from the resolution record directly. Skip to Step 2.

**If called standalone (directly invoked by the user)**: Use the `mrum-ios-code-review-input-parser` skill's playbook to resolve the user's input. The input parser handles all input forms: PR numbers (bare, `#`-prefixed, quoted), ticket IDs (`DEMRUM-NNNN`), branch names, URLs, natural language, and ambiguous bare numbers. It will resolve, disambiguate, and get confirmation.

Once you have a confirmed PR target, note:
- **If the PR is closed or merged**: Do NOT proceed with the full review. Inform the user and only continue if they explicitly insist.
- The input parser's resolution record includes checks rollup, state, and local branch info.

## Step 2: Gather PR Data

Once the PR is identified, fetch all relevant data in parallel where possible:

### PR metadata:
```bash
gh pr view <number> --repo <owner/repo> --json number,title,url,headRefName,baseRefName,state,author,body,mergeable,reviewDecision,statusCheckRollup,additions,deletions,changedFiles
```

### Review comments (conversation-level):
```bash
gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate
```

### Line-level review comments (with diff context):
```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate
```

### Issue-style comments (general PR conversation):
```bash
gh api repos/<owner>/<repo>/issues/<number>/comments --paginate
```

### PR diff (for cross-referencing whether comments have been addressed):
```bash
gh pr diff <number> --repo <owner/repo>
```

## Step 3: Organize Comments into Threads

Group the data into coherent threads:

1. **Review-level comments**: Top-level review submissions (APPROVED, CHANGES_REQUESTED, COMMENTED) from `reviews` endpoint.
2. **Line-level comments**: Comments attached to specific lines/files. Group them by `in_reply_to_id` to form threads (a comment with no `in_reply_to_id` is a thread root; those with one are replies).
3. **General comments**: Issue-level comments on the PR conversation.

For each thread, track:
- The original comment author, timestamp, and body
- The file and line(s) it references (if line-level)
- All replies in chronological order
- The diff hunk context (`diff_hunk` field)

## Step 4: Assess Actionability

For each comment thread, classify it:

### Categories:
- **Actionable - Open**: A requested change, bug report, or suggestion that has NOT been addressed yet. Look for:
  - The comment requests a code change, and the current diff does not reflect that change
  - No reply from the PR author acknowledging or resolving it
  - The review is marked CHANGES_REQUESTED and not superseded by a later APPROVED review from the same reviewer
- **Actionable - Resolved**: A requested change that HAS been addressed. Look for:
  - A reply from the PR author saying "done", "fixed", "addressed", or similar
  - The current diff shows the requested change was made
  - A subsequent APPROVED review from the same reviewer
  - The comment was marked as resolved (if GitHub's resolved status is available via `gh api repos/<owner>/<repo>/pulls/<number>/comments` — check the `resolved` or `is_resolved` field if present, or check for `RESOLVED` in review thread data)
- **Non-actionable - Discussion**: Questions, explanations, praise, acknowledgments, or general discussion that don't require code changes.
- **Non-actionable - Nitpick/Optional**: Comments explicitly marked as nitpicks, suggestions marked optional, or style preferences that don't affect correctness.
- **Non-actionable - Outdated**: Comments on lines that no longer exist in the current diff (check `position` is null or `outdated` is true).

### Heuristics for assessing resolution:
- Check if the file/line referenced still exists in the latest diff
- Look at commit timestamps vs comment timestamps — commits after a comment may address it
- Check for author replies containing resolution language
- Cross-reference the requested change against the current state of the diff

## Step 5: Present the Report

Format the output as a structured report:

```
# PR Review Report: <title> (#<number>)

**URL**: <pr_url>
**Branch**: <head> -> <base>
**Author**: <author>
**State**: <state> | **Review Decision**: <reviewDecision>
**Changes**: +<additions> -<deletions> across <changedFiles> files

---

## Summary
<Brief summary of what the PR does based on the body and diff>

## Review Status
| Reviewer | Status | Date |
|----------|--------|------|
| @reviewer1 | APPROVED | 2024-01-15 |
| @reviewer2 | CHANGES_REQUESTED | 2024-01-14 |

---

## Actionable Comments (Open) - <count>

### 1. [<file>:<line>] @<reviewer> — <date>
> <comment body, truncated if very long>

**Replies:**
- @<author> (<date>): <reply>

**Status**: Open - no resolution detected

---

## Actionable Comments (Resolved) - <count>

### 1. [<file>:<line>] @<reviewer> — <date>
> <comment body>

**Resolution**: <how it was resolved — author reply, code change, or reviewer approval>

---

## Discussion / Non-Actionable - <count>

### 1. [<file>:<line>] @<reviewer> — <date>
> <comment body>

**Type**: Discussion | Nitpick | Outdated | Praise

---

## Outdated Comments - <count>
<Comments on lines that no longer exist>
```

## Important Notes

- Always paginate API results (use `--paginate` with `gh api`)
- Handle rate limiting gracefully — if you get a 403, inform the user
- If the PR has a very large number of comments (>100), summarize by category counts first, then offer to show details per category
- When assessing whether a comment has been acted on, err on the side of marking it "Open" if uncertain — it's better to flag something for review than to miss it
- Use `jq` for JSON processing when needed
- If `gh` is not authenticated or not installed, inform the user and suggest `gh auth login`
