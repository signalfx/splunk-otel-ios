#!/usr/bin/env python3
"""
Build a pending-review report for open pull requests in a public GitHub repository.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

ACCEPT_HEADER = "application/vnd.github+json, application/vnd.github.mockingbird-preview+json"
USER_AGENT = "splunk-otel-ios-pr-review-report"
PER_PAGE = 100
REVIEW_STATES_THAT_CLEAR_PENDING = {"APPROVED", "CHANGES_REQUESTED", "COMMENTED"}


@dataclass(frozen=True)
class PendingReview:
    reviewer_display_name: str
    reviewer_login: str
    pull_request_number: int
    pull_request_title: str
    pull_request_url: str
    pending_since: datetime


class GitHubClient:
    def __init__(self, api_base_url: str) -> None:
        self.api_base_url = api_base_url.rstrip("/")
        self.token = os.environ.get("GITHUB_TOKEN", "").strip()
        self._user_name_cache: dict[str, str | None] = {}

    def get_json(self, path: str) -> Any:
        url = path if path.startswith("http") else f"{self.api_base_url}{path}"
        request = urllib.request.Request(url, headers=self._headers())

        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub API request failed: {error.code} {url}\n{body}") from error
        except urllib.error.URLError as error:
            raise RuntimeError(f"GitHub API request failed: {url}\n{error}") from error

    def paged_get(self, path: str) -> list[Any]:
        page = 1
        items: list[Any] = []

        while True:
            separator = "&" if "?" in path else "?"
            page_path = f"{path}{separator}per_page={PER_PAGE}&page={page}"
            page_items = self.get_json(page_path)

            if not isinstance(page_items, list):
                raise RuntimeError(f"Expected a list response from GitHub for {page_path}")

            items.extend(page_items)

            if len(page_items) < PER_PAGE:
                return items

            page += 1

    def get_user_display_name(self, login: str) -> str:
        if login not in self._user_name_cache:
            user = self.get_json(f"/users/{urllib.parse.quote(login, safe='')}")
            name = user.get("name") if isinstance(user, dict) else None
            self._user_name_cache[login] = name.strip() if isinstance(name, str) and name.strip() else None

        return self._user_name_cache[login] or login

    def _headers(self) -> dict[str, str]:
        headers = {
            "Accept": ACCEPT_HEADER,
            "User-Agent": USER_AGENT
        }

        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        return headers


def collect_pending_reviews(api_base_url: str, owner: str, repo: str, include_drafts: bool = False) -> list[PendingReview]:
    client = GitHubClient(api_base_url)
    open_pull_requests = client.paged_get(f"/repos/{owner}/{repo}/pulls?state=open")

    relevant_pull_requests = [
        pull_request
        for pull_request in open_pull_requests
        if include_drafts or not pull_request.get("draft", False)
    ]

    timeline_events_by_pr: dict[int, list[dict[str, Any]]] = {}
    reviews_by_pr: dict[int, list[dict[str, Any]]] = {}
    commits_by_pr: dict[int, list[dict[str, Any]]] = {}
    reviewer_names: dict[str, str | None] = {}

    for pull_request in relevant_pull_requests:
        pull_request_number = int(pull_request["number"])
        requested_reviewers = pull_request.get("requested_reviewers", [])

        if not requested_reviewers:
            continue

        timeline_events_by_pr[pull_request_number] = client.paged_get(
            f"/repos/{owner}/{repo}/issues/{pull_request_number}/timeline"
        )
        reviews_by_pr[pull_request_number] = client.paged_get(
            f"/repos/{owner}/{repo}/pulls/{pull_request_number}/reviews"
        )
        commits_by_pr[pull_request_number] = client.paged_get(
            f"/repos/{owner}/{repo}/pulls/{pull_request_number}/commits"
        )

        for reviewer in requested_reviewers:
            login = reviewer.get("login")
            if login and login not in reviewer_names:
                reviewer_names[login] = client.get_user_display_name(login)

    return analyze_pending_reviews(
        pull_requests=relevant_pull_requests,
        timeline_events_by_pr=timeline_events_by_pr,
        reviews_by_pr=reviews_by_pr,
        commits_by_pr=commits_by_pr,
        reviewer_names=reviewer_names
    )


def analyze_pending_reviews(
    pull_requests: list[dict[str, Any]],
    timeline_events_by_pr: dict[int, list[dict[str, Any]]],
    reviews_by_pr: dict[int, list[dict[str, Any]]],
    commits_by_pr: dict[int, list[dict[str, Any]]],
    reviewer_names: dict[str, str | None],
    now: datetime | None = None
) -> list[PendingReview]:
    current_time = now or datetime.now(timezone.utc)
    pending_reviews: list[PendingReview] = []

    for pull_request in pull_requests:
        requested_reviewers = pull_request.get("requested_reviewers", [])

        if not requested_reviewers:
            continue

        pull_request_number = int(pull_request["number"])
        pull_request_title = str(pull_request["title"])
        pull_request_url = str(pull_request["html_url"])
        fallback_request_time = parse_github_datetime(str(pull_request["created_at"]))
        latest_commit_at = extract_latest_commit_timestamp(
            commits_by_pr.get(pull_request_number, []),
            fallback=fallback_request_time
        )
        latest_request_by_reviewer = extract_latest_review_request_timestamps(
            timeline_events_by_pr.get(pull_request_number, []),
            current_reviewer_logins={
                reviewer["login"]
                for reviewer in requested_reviewers
                if reviewer.get("login")
            },
            fallback=fallback_request_time
        )
        latest_review_by_reviewer = extract_latest_clearing_review_timestamps(
            reviews_by_pr.get(pull_request_number, [])
        )

        for reviewer in requested_reviewers:
            login = reviewer.get("login")
            if not login:
                continue

            request_time = latest_request_by_reviewer.get(login, fallback_request_time)
            pending_since = max(request_time, latest_commit_at)
            latest_clearing_review = latest_review_by_reviewer.get(login)

            if latest_clearing_review and latest_clearing_review >= pending_since:
                continue

            pending_reviews.append(
                PendingReview(
                    reviewer_display_name=reviewer_names.get(login) or login,
                    reviewer_login=login,
                    pull_request_number=pull_request_number,
                    pull_request_title=pull_request_title,
                    pull_request_url=pull_request_url,
                    pending_since=pending_since
                )
            )

    return sorted(
        pending_reviews,
        key=lambda review: (review.reviewer_display_name.casefold(), review.pull_request_number)
    )


def render_report(pending_reviews: list[PendingReview], now: datetime | None = None) -> str:
    current_time = now or datetime.now(timezone.utc)
    lines = ["Who needs to review where", ""]

    reviews_by_reviewer: dict[tuple[str, str], list[PendingReview]] = {}
    for pending_review in pending_reviews:
        key = (pending_review.reviewer_display_name, pending_review.reviewer_login)
        reviews_by_reviewer.setdefault(key, []).append(pending_review)

    if reviews_by_reviewer:
        for reviewer_key in sorted(reviews_by_reviewer, key=lambda key: key[0].casefold()):
            reviewer_reviews = sorted(
                reviews_by_reviewer[reviewer_key],
                key=lambda review: ((current_time - review.pending_since).total_seconds(), review.pull_request_number),
                reverse=True
            )
            review_summary = ", ".join(
                f"#{review.pull_request_number} ({format_duration(current_time - review.pending_since)})"
                for review in reviewer_reviews
            )
            lines.append(f"@{reviewer_key[0]} -> {review_summary}")
    else:
        lines.append("No pending individual review requests.")

    lines.extend(["", "PRs waiting longest (max pending reviewer wait per PR)", ""])

    longest_wait_by_pr: dict[int, PendingReview] = {}
    for pending_review in pending_reviews:
        current_winner = longest_wait_by_pr.get(pending_review.pull_request_number)
        if current_winner is None or pending_review.pending_since < current_winner.pending_since:
            longest_wait_by_pr[pending_review.pull_request_number] = pending_review

    if longest_wait_by_pr:
        ordered_pull_requests = sorted(
            longest_wait_by_pr.values(),
            key=lambda review: ((current_time - review.pending_since).total_seconds(), review.pull_request_number),
            reverse=True
        )
        for pending_review in ordered_pull_requests:
            lines.append(
                f"#{pending_review.pull_request_number} "
                f"{pending_review.pull_request_title} - {format_duration(current_time - pending_review.pending_since)}"
            )
    else:
        lines.append("No pending individual review requests.")

    return "\n".join(lines)


def extract_latest_review_request_timestamps(
    timeline_events: list[dict[str, Any]],
    current_reviewer_logins: set[str],
    fallback: datetime
) -> dict[str, datetime]:
    latest_request_by_reviewer = {login: fallback for login in current_reviewer_logins}

    for event in timeline_events:
        if event.get("event") != "review_requested":
            continue

        requested_reviewer = event.get("requested_reviewer") or {}
        login = requested_reviewer.get("login")

        if login not in current_reviewer_logins:
            continue

        created_at = parse_github_datetime(str(event["created_at"]))
        previous = latest_request_by_reviewer.get(login)

        if previous is None or created_at > previous:
            latest_request_by_reviewer[login] = created_at

    return latest_request_by_reviewer


def extract_latest_clearing_review_timestamps(reviews: list[dict[str, Any]]) -> dict[str, datetime]:
    latest_review_by_reviewer: dict[str, datetime] = {}

    for review in reviews:
        login = (review.get("user") or {}).get("login")
        submitted_at = review.get("submitted_at")
        state = str(review.get("state", "")).upper()

        if not login or not submitted_at or state not in REVIEW_STATES_THAT_CLEAR_PENDING:
            continue

        submitted_at_datetime = parse_github_datetime(str(submitted_at))
        previous = latest_review_by_reviewer.get(login)

        if previous is None or submitted_at_datetime > previous:
            latest_review_by_reviewer[login] = submitted_at_datetime

    return latest_review_by_reviewer


def extract_latest_commit_timestamp(commits: list[dict[str, Any]], fallback: datetime) -> datetime:
    latest_commit_timestamp = fallback

    for commit in commits:
        commit_payload = commit.get("commit") or {}
        author_payload = commit_payload.get("committer") or commit_payload.get("author") or {}
        committed_at = author_payload.get("date")

        if not committed_at:
            continue

        committed_at_datetime = parse_github_datetime(str(committed_at))
        if committed_at_datetime > latest_commit_timestamp:
            latest_commit_timestamp = committed_at_datetime

    return latest_commit_timestamp


def parse_github_datetime(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def format_duration(delta: Any) -> str:
    total_seconds = max(0, int(delta.total_seconds()))
    days, remainder = divmod(total_seconds, 86_400)
    hours, remainder = divmod(remainder, 3_600)
    minutes = remainder // 60

    if days > 0:
        return f"{days}d {hours}h" if hours > 0 else f"{days}d"
    if hours > 0:
        return f"{hours}h {minutes}m" if minutes > 0 else f"{hours}h"
    return f"{minutes}m"
