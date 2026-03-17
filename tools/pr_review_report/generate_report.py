#!/usr/bin/env python3
"""CLI entrypoint for generating the pull request review report."""

from __future__ import annotations

import argparse
import sys

from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.pr_review_report.report import collect_pending_reviews, render_report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-base-url", default="https://api.github.com", help="GitHub API base URL")
    parser.add_argument("--owner", default="signalfx", help="Repository owner")
    parser.add_argument("--repo", default="splunk-otel-ios", help="Repository name")
    parser.add_argument("--include-drafts", action="store_true", help="Include draft pull requests")
    parser.add_argument("--output", help="Optional path to write the rendered report to")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pending_reviews = collect_pending_reviews(
        api_base_url=args.api_base_url,
        owner=args.owner,
        repo=args.repo,
        include_drafts=args.include_drafts
    )
    report = render_report(pending_reviews)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(f"{report}\n", encoding="utf-8")

    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
