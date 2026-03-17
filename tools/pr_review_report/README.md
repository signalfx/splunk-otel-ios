# PR Review Report

This directory contains a small report generator for open pull requests in public GitHub repositories.

The script uses the public GitHub REST API to gather:

- Open pull requests.
- Current individually requested reviewers.
- Review-request timeline events to find the latest request timestamp per reviewer.
- Review submissions to determine whether a reviewer has already responded after the latest relevant request or commit.
- Pull request commits to find the latest commit timestamp.

The pending-review wait is calculated as:

`now - max(requested_review_timestamp_for_reviewer, last_commit_timestamp_on_pr)`

## Current limitations

- Team review requests are ignored.
- The script is optimized for scheduled reporting, not for high-frequency polling.
- For public repositories it works without a token. If rate limiting becomes an issue later, set `GITHUB_TOKEN` in the job environment and the script will use it automatically.

## Local usage

```bash
python3 tools/pr_review_report/generate_report.py
```

To write the report to a file:

```bash
python3 tools/pr_review_report/generate_report.py --output artifacts/pr-review-report.txt
```

## GitLab pipeline

The repository root includes a `.gitlab-ci.yml` file with a `pr-review-report` job.

The job:

- Generates the report from the public GitHub API.
- Prints the report to the job log.
- Stores the rendered report as `artifacts/pr-review-report.txt`.

To schedule it daily, create a GitLab pipeline schedule in the mirror repository UI. Slack delivery is intentionally left out for now so the rendered message can be reviewed first.
