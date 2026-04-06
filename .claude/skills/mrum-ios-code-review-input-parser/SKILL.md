---
name: mrum-ios-code-review-input-parser
description: Parse and resolve user input (PR numbers, ticket IDs, branch names, URLs, natural language) into confirmed review targets with structured metadata. Use as the first step whenever the user provides ambiguous or shorthand input for the code review agent.
user-invocable: false
model: opus
---

# Input Parser

You are the input resolution layer for the mrum-ios-code-review agent. Your job is to take raw user input, figure out what they want reviewed, resolve it to concrete targets, extract any behavioral modifiers, and get confirmation before handing off to downstream skills.

## Project Constants

- **GitHub repo**: `signalfx/splunk-otel-ios`
- **Repo URL**: `https://github.com/signalfx/splunk-otel-ios`
- **PR URL pattern**: `https://github.com/signalfx/splunk-otel-ios/pull/{number}`
- **Branch URL pattern**: `https://github.com/signalfx/splunk-otel-ios/tree/{branch}`
- **Ticket prefix**: `DEMRUM`
- **Ticket regex**: `DEMRUM-\d{4,5}`
- **Default diff base**: `develop` (the daily working branch; PRs typically target this)
- **Default repo directory**: The current working directory of the session (assumed to be the repo root unless the user specifies otherwise)

## Step 0: Detect Help Requests and Empty Input

Before parsing for review targets, check whether the user is asking for help or provided no actionable input.

### Trigger conditions
Match any of these (case-insensitive, ignoring leading/trailing whitespace):
- Empty input, whitespace-only, or no message at all
- `help`, `-h`, `-help`, `--help`
- `?`, `usage`, `what can you do`, `how do I use this`
- Any message that is clearly asking about capabilities rather than requesting a review (e.g., "what is this", "explain yourself", "what are you")

### Help response

When triggered, respond with this help text (adapt phrasing naturally, but cover all the content):

```
# Code Review Agent

I review Swift and Objective-C code for the splunk-otel-ios project. I can review code on GitHub or on your local filesystem.

## Quick start

Just tell me what to review. Use natural language — these are examples, not exact commands:

  590                          Review PR #590 on GitHub
  #590                         Same thing (# prefix is optional)
  DEMRUM-4814                  Find PRs for ticket DEMRUM-4814
  4814                         Smart lookup: tries PR #4814, then ticket DEMRUM-4814
  review this branch           Review your current local branch against develop
  look at my changes           Review uncommitted local changes

You don't need to match these phrases exactly. Say it however feels natural —
"check my stuff", "look at what I've got", "review my work", etc. all work.
I use the meaning, not the exact words.

## What I accept

- **PR numbers**: 590, #590, "590", "#590"
- **Ticket IDs**: DEMRUM-4814, demrum-4814 (case-insensitive)
- **Branch names**: DEMRUM-4814-navigation-foundation, feature/foo
- **URLs**: https://github.com/signalfx/splunk-otel-ios/pull/590
- **Natural language**: anything that conveys what you want reviewed and how

## Review modes

- **GitHub PR review**: Fetches the PR diff and existing reviewer comments from GitHub.
- **Local branch review**: Reads code from your filesystem, diffs against a base branch.

If a branch exists both locally and as a PR, I'll ask which mode you prefer.

## Modifiers

You can add instructions to customize the review. Some examples of the kinds
of things you can say:

  "ignore the existing comments"    Skip existing PR review comments (fresh review)
  "just look at concurrency"        Review only specific domains
  "diff against main instead"       Override the default diff base (develop)
  "only flag critical stuff"        Filter by severity

Again, phrasing is flexible. I'm reading for intent, not keywords.

## Examples

These show the range of what you can say — mix and match however you like:

  take a look at PR 590, but ignore the existing comments
  check DEMRUM-4814, just the local code
  review this branch and focus on memory safety
  what's the status of #588
  look at the code in ~/other-repo
  590 — fresh review, concurrency only
```

After presenting help, do NOT proceed with any review workflow. Wait for the user to provide a review target.

### Insufficient but non-help input

If the input is not a help request but also doesn't contain enough information to resolve a target (e.g., "do a review", "check something", "go"), treat it as the "no clear identifier" case in Step 2h — check the current branch and suggest options — but also append a brief hint:

```
Tip: type "help" for full usage, or just give me a PR number, ticket ID, or branch name.
```

## Step 1: Classify the Raw Input

Parse the user's message to extract one or more of:

### A. Target identifier
Identify what the user wants to review. Strip quotes and normalize.

| Pattern | Classification | Confidence | Examples |
|---------|---------------|------------|---------|
| `#\d+` or bare `\d{1,4}` (1-4 digits, plausible PR range) | PR number candidate | High if `#`-prefixed, Medium if bare | `#590`, `590`, `"590"`, `"#590"` |
| `DEMRUM-\d{4,5}` (case-insensitive) | Ticket ID | High | `DEMRUM-4814`, `demrum-4775` |
| Bare `\d{4,5}` (4-5 digits, no `#`) | Ambiguous: could be PR or ticket suffix | Low | `4814` |
| String matching branch name pattern (contains `/`, ticket prefix, or kebab-case segments) | Branch name | Medium | `DEMRUM-4814-navigation-foundation`, `feature/foo` |
| `https://github.com/signalfx/splunk-otel-ios/pull/\d+` | PR URL | Definitive | Full PR URL |
| `https://github.com/signalfx/splunk-otel-ios/tree/.*` | Branch URL | Definitive | Full branch URL |
| Other GitHub URL from same repo | Repo artifact | High | Compare, commit URLs |
| No clear identifier found | Unclear | — | Ask for clarification |

### B. Review mode and location qualifiers

Determine whether the user wants a **GitHub PR review** or a **local branch review** (or both/unclear). This is the most important classification — it determines the entire downstream workflow.

**GitHub PR review** — the agent fetches the PR diff from GitHub, reads existing review comments, and produces findings against the PR as it exists on GitHub:
- Trigger phrases: "the PR", "pull request", "on github", "remote", "PR #590"
- Implicit: any PR number, PR URL, or ticket ID (since tickets map to PRs)

**Local branch review** — the agent reads code from the local filesystem, diffs against a base branch, and reviews the local state of the code:
- Trigger phrases: "locally", "on my disk", "on the filesystem", "in this directory", "this branch", "my branch", "my changes", "my code", "what I have here"
- Implicit: when the user provides a branch name without mentioning a PR, or says "review this branch"

**Directory override** — the user may specify a different directory:
- Trigger phrases: "in /path/to/repo", "in ~/other-repo", "at /some/path", "the repo at ..."
- When detected, verify the path exists and is a git repository:
  ```bash
  git -C "<path>" rev-parse --git-dir 2>/dev/null
  ```
- If it's a valid git repo, use that path as the working directory for all subsequent git commands. Record it in the resolution record as `repo_dir`.
- If it's not a valid git repo, report the error and ask for clarification.

**Both/unspecified** — no clear qualifier, or ambiguous phrasing like "review this":
- Search both GitHub and local. If a branch has a corresponding open PR, present both options:
  - "Review PR #590 on GitHub (includes existing reviewer comments)"
  - "Review the local branch `DEMRUM-4775-navigation-foundation` (your local code, may differ from what's pushed)"
- Let the user choose. If the local branch is ahead of or behind the remote, mention this in the confirmation.

### C. Behavioral modifiers
Extract any instructions that modify how the review should be conducted. These are passed through to downstream skills as flags.

Known modifiers (extensible — apply LLM judgment for similar phrasings):

| Modifier | Trigger phrases | Output key |
|----------|----------------|------------|
| Ignore existing PR comments | "ignoring comments", "ignore current comments", "fresh review", "from scratch", "pretend no one has reviewed" | `ignore_existing_comments: true` |
| Scope restriction | "only the Swift files", "just the networking code", "focus on Tests/", "only changed files" | `scope_hint: "<extracted scope>"` |
| Severity filter | "only critical issues", "just warnings and above", "everything including nitpicks" | `severity_filter: "<level>"` |
| Specific domain focus | "focus on concurrency", "check memory safety", "just the API surface" | `domain_focus: ["<domain>", ...]` |
| Compare against base | "compare against main", "diff from develop" | `base_override: "<branch>"` |

If you detect a modifier-like instruction that doesn't match the known list, still extract it as `custom_modifiers: ["<description>"]` and include it in the confirmation prompt so the user can verify you understood correctly.

### D. Action intent
What does the user want to do with the target?

- **Review**: "review", "look at", "check", "examine" (default if not specified)
- **Read comments**: "read comments", "what feedback", "what did reviewers say", "PR status"
- **Compare**: "compare", "diff between"
- **Summarize**: "summarize", "what does this PR do", "overview"

## Step 2: Resolve the Target

Use the classification from Step 1 to resolve to concrete artifacts. Execute the resolution strategies below in order until you have a confirmed target.

### 2a. PR Number (high confidence: `#`-prefixed or URL)

```bash
gh pr view <number> --repo signalfx/splunk-otel-ios --json number,title,url,headRefName,baseRefName,state,author,reviewDecision,statusCheckRollup,additions,deletions,changedFiles
```

If this succeeds, also check for a local branch:
```bash
git branch --list "*$(gh pr view <number> --repo signalfx/splunk-otel-ios --json headRefName -q '.headRefName')*" 2>/dev/null
```

And check if we're on it:
```bash
git branch --show-current
```

### 2b. PR Number (medium confidence: bare number, 1-4 digits)

Try as PR first:
```bash
gh pr view <number> --repo signalfx/splunk-otel-ios --json number,title,url,headRefName,state,author 2>/dev/null
```

If that succeeds, proceed as 2a. If it fails (no such PR), note the failure and fall through to 2d (ambiguous number).

### 2c. Ticket ID (explicit: `DEMRUM-NNNN`)

Always normalize to uppercase `DEMRUM-NNNN`.

Search GitHub PRs:
```bash
gh pr list --repo signalfx/splunk-otel-ios --state all --search "DEMRUM-<number>" --json number,title,url,headRefName,state,author
```

Also search by branch name pattern (catches PRs where the ticket is in the branch but not the title):
```bash
gh pr list --repo signalfx/splunk-otel-ios --state all --json number,title,url,headRefName,state,author | jq '[.[] | select(.headRefName | test("DEMRUM-<number>"; "i"))]'
```

Deduplicate results by PR number.

Search local branches:
```bash
git branch --list "*DEMRUM-<number>*"
```

Check current branch:
```bash
git branch --show-current
```

### 2d. Ambiguous Number (4-5 digits, no `#`, no `DEMRUM-` prefix)

This is the tricky case. The number could be a PR or a ticket suffix.

**Step 1**: Try as PR number:
```bash
gh pr view <number> --repo signalfx/splunk-otel-ios --json number,title,url,headRefName,state,author 2>/dev/null
```

**Step 2**: Search for ticket `DEMRUM-<number>`:
```bash
gh pr list --repo signalfx/splunk-otel-ios --state all --search "DEMRUM-<number>" --json number,title,url,headRefName,state,author
```

**Step 3**: Search local branches:
```bash
git branch --list "*DEMRUM-<number>*"
git branch --list "*<number>*"
```

**Disambiguation logic**:
- If PR exists AND ticket PRs exist: Present both options, ask user which they meant.
- If only PR exists: Assume PR, but mention in confirmation.
- If only ticket results exist: Assume ticket. Format as `DEMRUM-<number>`.
- If local branches match but no GitHub results: Present branches, note no GitHub PR found.
- If nothing matches: Report clearly. Ask for clarification.

### 2e. Branch Name

Check local existence:
```bash
git branch --list "<branch>"
git branch --show-current
```

Check remote existence:
```bash
git ls-remote --heads origin "<branch>" 2>/dev/null
```

Find associated PRs:
```bash
gh pr list --repo signalfx/splunk-otel-ios --head "<branch>" --state all --json number,title,url,state,author,baseRefName
```

Extract ticket from branch name:
```bash
echo "<branch>" | grep -oiE 'DEMRUM-[0-9]{4,5}'
```

If the review mode is local (or both/unspecified and the branch exists locally), also gather git state — see Step 2i.

### 2f. PR URL

Extract number from URL path (`/pull/(\d+)`), then proceed as 2a.

### 2g. Branch URL

Extract branch name from URL path (`/tree/(.*)`), URL-decode, then proceed as 2e.

### 2i. Git State (for local branch reviews)

When the review mode is local or the user is on a feature branch, gather the working tree state. This information is included in the resolution record so the agent can decide how to proceed.

Use the repo directory from the directory override (if specified) or the current working directory.

```bash
# Working tree status (clean, dirty, merge in progress, etc.)
git status --porcelain=v2 --branch
```

Parse the output to determine:

| State | How to detect | Record as |
|-------|--------------|-----------|
| **Clean** | No output lines starting with `1`, `2`, `u`, or `?` | `working_tree: clean` |
| **Unstaged changes** | Lines starting with `1` or `2` where the worktree column shows modification | `working_tree: unstaged_changes` with file count |
| **Staged changes** | Lines starting with `1` or `2` where the index column shows modification | `working_tree: staged_changes` with file count |
| **Both staged and unstaged** | Mix of the above | `working_tree: mixed_changes` with counts |
| **Untracked files** | Lines starting with `?` | `untracked_files: <count>` (note but don't alarm) |
| **Merge in progress** | `.git/MERGE_HEAD` exists, or `u` lines in status | `working_tree: merge_in_progress` |
| **Rebase in progress** | `.git/rebase-merge/` or `.git/rebase-apply/` exists | `working_tree: rebase_in_progress` |
| **Conflict** | `u` lines in status (unmerged entries) | `working_tree: conflicted` with file count |

Also check ahead/behind status relative to the upstream tracking branch:
```bash
# The --porcelain=v2 --branch output includes:
# branch.ab +<ahead> -<behind>
```

Record as `ahead: N, behind: N` relative to the remote tracking branch (if any).

### 2j. Diff Base Detection (for local branch reviews)

Determine what to diff against for the local review. The diff base is critical — it defines the scope of "what changed."

**Priority order for determining diff base:**

1. **User-specified base** (`base_override` from behavioral modifiers): "compare against main", "diff from develop". Use exactly what the user said.

2. **PR base branch** (if a corresponding PR exists): The PR's `baseRefName` from the `gh pr list` output. This is the most accurate base because it's what the PR will merge into.

3. **Default base**: `develop` (the project's daily working branch).

Once determined:
```bash
# Verify the base branch exists locally
git rev-parse --verify "<base>" 2>/dev/null

# If not, try the remote version
git rev-parse --verify "origin/<base>" 2>/dev/null
```

```bash
# Get the merge base (common ancestor) — this gives the cleanest diff
git merge-base "<base>" HEAD
```

```bash
# Count changed files and lines for the summary
git diff --stat "$(git merge-base <base> HEAD)"..HEAD
```

Record in the resolution record:
- `diff_base: <branch>`
- `diff_base_source: user-specified | pr-base | default`
- `merge_base_commit: <sha>` (short form)
- `files_changed: N`
- `insertions: N`
- `deletions: N`

### 2h. Natural Language (no clear identifier)

If the user's message contains review intent but no extractable target:
- Check if we're on a non-default branch and ask if they mean the current branch.
- Check if there's a recent PR by the current git user.
- Otherwise, ask with examples:
  ```
  What would you like me to review? Here are some things I can work with —
  use natural language, these are just examples:

    590                      A PR number (with or without #)
    DEMRUM-4814              A ticket ID
    look at this branch      Your current local branch
    check my changes         Your uncommitted work
    <paste a PR URL>         A full GitHub PR URL

  Say it however you like — I read for intent, not exact wording.
  Type "help" for the complete usage guide.
  ```

## Step 3: Build the Resolution Record

Assemble all findings into a structured summary. This is the output other skills consume.

```
## Resolved Target

**Review mode**: github-pr | local-branch
**Type**: PR | Ticket | Branch | Ambiguous
**Primary target**: #590 | DEMRUM-4814 | branch-name
**Repo directory**: /Users/me/work/splunk-otel-ios (or: default CWD)

### PR(s)
| # | Title | State | Author | Base | URL |
|---|-------|-------|--------|------|-----|
| #590 | Navigation foundation | open | @author | develop | https://github.com/signalfx/splunk-otel-ios/pull/590 |

**Checks**: green | yellow | red (rolled up from statusCheckRollup)
**Review decision**: APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | <none>
**Changes (GitHub)**: +X -Y across Z files

### Local State
- **Current branch**: `DEMRUM-4814-navigation-foundation`
- **On target branch**: yes | no
- **Local branches matching**: `DEMRUM-4814-navigation-foundation` (exists locally)
- **Working tree**: clean | unstaged_changes (N files) | staged_changes (N files) | mixed_changes (N staged, M unstaged) | merge_in_progress | rebase_in_progress | conflicted (N files)
- **Untracked files**: N
- **Ahead/behind remote**: +N ahead, -M behind (or: no upstream tracking branch)

### Diff Base (for local review)
- **Diff base**: develop | main | <user-specified>
- **Diff base source**: user-specified | pr-base | default
- **Merge base commit**: abc1234
- **Changes (local)**: +X -Y across Z files

### Ticket
- **Ticket ID**: DEMRUM-4814 (or: no ticket extracted)

### Behavioral Modifiers
- ignore_existing_comments: false
- scope_hint: <none>
- severity_filter: <none>
- domain_focus: <none>
- base_override: <none>
- custom_modifiers: <none>

### Action Intent
- review | read-comments | compare | summarize
```

Sections are omitted when not applicable. For a GitHub PR review, the "Diff Base" section is omitted (the PR diff comes from GitHub). For a local-only review with no associated PR, the "PR(s)" section is omitted.

## Step 4: Confirm with the User

**Always** present the resolution record to the user and ask for confirmation before proceeding. The confirmation prompt should be concise but complete.

### Confirmation prompt format:

**GitHub PR review (clear target):**
```
I found PR #590: "Navigation foundation" by @author (open, checks green).
URL: https://github.com/signalfx/splunk-otel-ios/pull/590
Ticket: DEMRUM-4775
+123 -45 across 8 files

Proceeding with: GitHub PR review of #590

OK to proceed?
```

**Local branch review (clear target):**
```
Reviewing local branch `DEMRUM-4775-navigation-foundation` (you are on it).
Diff base: `develop` (default)
Working tree: clean
+89 -32 across 6 files (local diff against develop)
Associated PR: #590 (open, checks green)

Proceeding with: local code review against develop

OK to proceed?
```

**Local branch review with dirty working tree:**
```
Reviewing local branch `DEMRUM-4775-navigation-foundation` (you are on it).
Diff base: `develop` (default)
Working tree: 3 staged changes, 2 unstaged changes, 1 untracked file
+89 -32 across 6 files (committed), plus uncommitted work

Do you want me to:
1. Review only committed changes (diff of commits against develop)
2. Review committed + staged changes
3. Review everything including unstaged changes

Pick 1-3, or clarify:
```

**Local branch with concerning state:**
```
Branch `DEMRUM-4775-navigation-foundation` has a merge in progress with 2 conflicted files.
You may want to resolve the merge before requesting a review.

Proceed anyway? (review will be based on the current file contents, which may include conflict markers)
```

**Ambiguous target (PR vs local):**
```
Branch `DEMRUM-4775-navigation-foundation` exists both locally and as PR #590 on GitHub.
Your local branch is 2 commits ahead of the remote.

How would you like to review?
1. **GitHub PR #590** — review the PR as it exists on GitHub (includes reviewer comments)
2. **Local branch** — review your local code against develop (includes your unpushed commits)

Pick 1 or 2:
```

**Ambiguous number:**
```
"4814" could refer to:

1. **PR #4814** — does not exist on GitHub
2. **Ticket DEMRUM-4814** — found 1 PR:
   - #588: "DEMRUM-4775: navigation foundation" (open)
   Local branch: `DEMRUM-4814-some-branch` (you are on it)

Which did you mean? (1 or 2, or clarify)
```

**With behavioral modifiers:**
```
I found PR #590: "Navigation foundation" by @author (open, checks green).

I also understood these instructions:
- Ignore existing PR review comments (fresh review)
- Focus on: concurrency, memory safety

Proceed with fresh GitHub PR review of #590, focused on concurrency and memory safety?
```

### Rules for confirmation:
- Always show the full ticket ID with `DEMRUM-` prefix when displaying ticket references.
- Always show PR numbers with `#` prefix.
- Always show the PR URL.
- If the PR is closed or merged, warn prominently and ask if they really want to proceed.
- If multiple PRs match a ticket, list them all and ask the user to pick.
- If behavioral modifiers were detected, list them explicitly so the user can correct misunderstandings.
- If nothing was found, say so clearly and suggest alternative inputs.

## Step 5: Hand Off

Once the user confirms, pass the resolution record to the requesting skill. The record format above is the contract between this skill and downstream consumers (the code review agent, the PR reader, etc.).

If the user corrects or clarifies during confirmation, update the resolution record and re-confirm.

## Edge Cases

- **User says "this branch"**: Resolve to `git branch --show-current`. Gather git state. Find any associated PR. Default to local review mode unless the user mentions the PR.
- **User says "review my changes"**: Check `git status` and `git diff` for uncommitted work. If on a feature branch, also look for an associated PR. This is always a local review.
- **User says "review my changes on github"**: Find the PR associated with the current branch. This is a GitHub PR review.
- **User provides multiple targets**: "Review PRs 588 and 590". Resolve each independently, present both, confirm scope.
- **User provides a PR from a different repo**: If the URL is not `signalfx/splunk-otel-ios`, note this explicitly in the confirmation. The review can still proceed but project-specific context (known debt, ticket prefix, etc.) won't apply.
- **GitHub API failures**: If `gh` commands fail (auth, rate limit, network), report the failure clearly. Fall back to local-only resolution where possible (branch checks, git log for ticket extraction). Suggest local review as an alternative.
- **User says "please review <branch name>"**: Treat the text after "review" as a branch name candidate. Verify it exists locally or remotely before assuming it's a branch. Default to local review mode if the branch exists locally.
- **User says "review the code in /some/path"**: Validate the path is a git repo. Set `repo_dir` to that path. All subsequent git commands use `-C <path>`. Default to local review mode.
- **On `develop` or `main` branch**: If the user says "review this branch" but we're on the default base branch, warn: "You're on `develop` — there's nothing to diff against. Did you mean to review a specific PR or switch to a feature branch?"
- **Local branch has no commits ahead of base**: If `git merge-base` and HEAD are the same, note: "This branch has no commits beyond `develop`. Nothing to review." Ask for clarification.
- **Local branch diverged from remote**: If ahead AND behind, note both counts in the confirmation so the user knows the local state differs from what's on GitHub.
