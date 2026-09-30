"""
Vision Test Farm Command Line Interface (v0.1)

Provides operators and automation with clean commands:
- list: show catalogue scenarios and metadata
- dry-run: preflight scenario resolution against host without execution
- run: execute selected scenarios and produce evidence bundles
- safe-smoke: execute the canonical safe pack of real scenarios
- aggregate: aggregate existing run directories into aggregate.json + AGGREGATE.md
- swa-suite: execute the mandatory Software Acceptance test suite (SWA-01..13)
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# Ensure harness directory is on python path
HARNESS_DIR = Path(__file__).resolve().parent
REPO_ROOT = HARNESS_DIR.parent.parent
if str(HARNESS_DIR) not in sys.path:
    sys.path.insert(0, str(HARNESS_DIR))

from tf_environment import probe_environment
from tf_resolver import ScenarioResolver, PreflightDecision
from tf_runner import ScenarioRunner, ScenarioRunResult
from tf_aggregator import Aggregator


def print_table(headers: List[str], rows: List[List[str]]) -> None:
    """Print clean ASCII table."""
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))

    header_line = " | ".join(h.ljust(widths[i]) for i, h in enumerate(headers))
    sep_line = "-+-".join("-" * widths[i] for i in range(len(headers)))
    print(header_line)
    print(sep_line)
    for row in rows:
        print(" | ".join(str(cell).ljust(widths[i]) for i, cell in enumerate(row)))


def cmd_list(args: argparse.Namespace) -> int:
    catalogue_dir = HARNESS_DIR / "scenarios"
    resolver = ScenarioResolver(catalogue_dir, REPO_ROOT)
    scenarios = resolver.load_all_scenarios()

    headers = ["Scenario ID", "Category", "Title", "Flags", "Tags"]
    rows = []
    for sc in scenarios:
        sid = sc.get("resolved_id", sc.get("id", "unknown"))
        cat = sc.get("category", "")
        title = sc.get("title", "")
        flags = sc.get("flags", {})
        flag_strs = [k for k, v in flags.items() if v]
        tags = ",".join(sc.get("tags", []))
        rows.append([sid, cat, title[:40], ",".join(flag_strs[:2]), tags[:30]])

    print(f"\n--- Vision Test Farm Catalogue ({len(scenarios)} scenarios) ---")
    print_table(headers, rows)
    return 0


def cmd_dry_run(args: argparse.Namespace) -> int:
    env = probe_environment(REPO_ROOT)
    catalogue_dir = HARNESS_DIR / "scenarios"
    resolver = ScenarioResolver(catalogue_dir, REPO_ROOT)

    tags = set(args.tags.split(",")) if args.tags else None
    plan = resolver.plan(
        env=env,
        pack=args.pack,
        tags=tags,
        category=args.category,
        scenario_id=args.scenario,
    )

    headers = ["Resolved ID", "Preflight Status", "Category", "Reasons"]
    rows = []
    counts = {"RUNNABLE": 0, "SKIPPED_CAPABILITY": 0, "BLOCKED_INTERVENTION": 0, "INVALID": 0}

    for p in plan:
        status = p.status
        counts[status] = counts.get(status, 0) + 1
        cat = p.scenario.get("category", "")
        reasons = "; ".join(p.reasons) if p.reasons else "Ready"
        rows.append([p.resolved_id, status, cat, reasons[:60]])

    print("\n=== Vision Test Farm Preflight Dry-Run ===")
    print(f"Host: {env['os']['node']} | Displays: {env['display_topology']['display_count']} | IsAdmin: {env['elevation']['is_admin']}")
    print_table(headers, rows)
    print(f"\nPlan Summary: Total: {len(plan)} | RUNNABLE: {counts.get('RUNNABLE', 0)} | SKIPPED: {counts.get('SKIPPED_CAPABILITY', 0)} | BLOCKED: {counts.get('BLOCKED_INTERVENTION', 0)} | INVALID: {counts.get('INVALID', 0)}\n")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    env = probe_environment(REPO_ROOT)
    catalogue_dir = HARNESS_DIR / "scenarios"
    resolver = ScenarioResolver(catalogue_dir, REPO_ROOT)

    tags = set(args.tags.split(",")) if args.tags else None
    plan = resolver.plan(
        env=env,
        pack=args.pack,
        tags=tags,
        category=args.category,
        scenario_id=args.scenario,
    )

    if not plan:
        print("No scenarios matched the given criteria.")
        return 0

    print(f"\n=== Vision Test Farm Execution Starting ({len(plan)} scenarios) ===")
    runner = ScenarioRunner(REPO_ROOT)
    results: List[Dict[str, Any]] = []

    for item in plan:
        sc = item.scenario
        rid = item.resolved_id
        print(f"-> Executing [{rid}] (preflight: {item.status})... ", end="", flush=True)

        res = runner.run_scenario(
            scenario=sc,
            env=env,
            preflight_status=item.status,
            preflight_reasons=item.reasons,
        )
        print(f"[{res.status}] in {round(res.duration_sec, 2)}s")
        results.append(res.to_dict())

    # Aggregate run results
    aggregator = Aggregator()
    agg_data = aggregator.aggregate_from_dicts(results)

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    pack_name = args.pack or "custom"
    out_dir = Path(args.out_dir) if args.out_dir else (REPO_ROOT / "lab" / "benchmarks" / "farm_aggregates" / f"{timestamp}__{pack_name}")
    json_path, md_path = aggregator.write_reports(agg_data, out_dir)

    print(f"\n=== Test Farm Run Complete ===")
    print(f"Aggregate JSON: {json_path}")
    print(f"Aggregate Markdown: {md_path}")
    counts = agg_data["counts"]
    print(f"Total: {counts['total']} | PASS: {counts['passed']} | FAIL: {counts['failed']} | SKIP: {counts['skipped']} | BLOCK: {counts['blocked']} | ERROR: {counts['errors']}\n")

    return 0 if counts["failed"] == 0 and counts["errors"] == 0 else 1


def cmd_safe_smoke(args: argparse.Namespace) -> int:
    """Convenience wrapper for running the safe smoke pack."""
    args.pack = "safe_smoke"
    args.tags = None
    args.category = None
    args.scenario = None
    args.out_dir = None
    return cmd_run(args)


def cmd_aggregate(args: argparse.Namespace) -> int:
    runs_dir = Path(args.runs_dir)
    if not runs_dir.is_dir():
        print(f"Error: Runs directory not found: {runs_dir}", file=sys.stderr)
        return 1

    subdirs = [p for p in runs_dir.glob("*") if p.is_dir()]
    aggregator = Aggregator()
    agg_data = aggregator.aggregate_from_run_dirs(subdirs)

    out_dir = Path(args.out_dir) if args.out_dir else runs_dir
    json_path, md_path = aggregator.write_reports(agg_data, out_dir)

    print(f"Aggregated {len(subdirs)} run directories.")
    print(f"Output: {json_path} and {md_path}")
    return 0


def cmd_swa_suite(args: argparse.Namespace) -> int:
    """Execute the mandatory SWA-01 to SWA-13 acceptance test suite."""
    from swa.run_swa import run_all_swa_tests
    return run_all_swa_tests()


def main() -> int:
    parser = argparse.ArgumentParser(description="Vision Test Farm CLI v0.1")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    p_list = subparsers.add_parser("list", help="List scenarios in catalogue")

    # dry-run
    p_dry = subparsers.add_parser("dry-run", help="Dry-run scenario resolution against environment")
    p_dry.add_argument("--pack", help="Filter by pack name (e.g. safe_smoke, unit, gated)")
    p_dry.add_argument("--category", help="Filter by category")
    p_dry.add_argument("--tags", help="Comma-separated tags")
    p_dry.add_argument("--scenario", help="Filter by scenario ID pattern")

    # run
    p_run = subparsers.add_parser("run", help="Execute scenarios")
    p_run.add_argument("--pack", help="Filter by pack name")
    p_run.add_argument("--category", help="Filter by category")
    p_run.add_argument("--tags", help="Comma-separated tags")
    p_run.add_argument("--scenario", help="Filter by scenario ID pattern")
    p_run.add_argument("--out-dir", help="Directory for aggregate reports")

    # safe-smoke
    p_smoke = subparsers.add_parser("safe-smoke", help="Execute canonical safe smoke pack")

    # aggregate
    p_agg = subparsers.add_parser("aggregate", help="Aggregate existing run directories")
    p_agg.add_argument("--runs-dir", required=True, help="Directory containing run subdirectories")
    p_agg.add_argument("--out-dir", help="Directory to write aggregate.json and AGGREGATE.md")

    # swa-suite
    p_swa = subparsers.add_parser("swa-suite", help="Execute mandatory SWA-01..13 test suite")

    args = parser.parse_args()

    if args.command == "list":
        return cmd_list(args)
    elif args.command == "dry-run":
        return cmd_dry_run(args)
    elif args.command == "run":
        return cmd_run(args)
    elif args.command == "safe-smoke":
        return cmd_safe_smoke(args)
    elif args.command == "aggregate":
        return cmd_aggregate(args)
    elif args.command == "swa-suite":
        return cmd_swa_suite(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
