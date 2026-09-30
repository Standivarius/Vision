"""
Vision Test Farm Result Aggregator & Failure Signature Clustering (v0.1)

In-gests multiple run bundles, clusters failure signatures, manages the human-review
queue, handles interrupted runs, and produces aggregate.json and AGGREGATE.md.
"""

from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class FailureCluster:
    signature: str
    failure_class: str
    count: int = 0
    scenarios: List[str] = field(default_factory=list)
    run_dirs: List[str] = field(default_factory=list)
    messages: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "signature": self.signature,
            "failure_class": self.failure_class,
            "count": self.count,
            "scenarios": self.scenarios,
            "run_dirs": self.run_dirs,
            "sample_message": self.messages[0] if self.messages else "",
        }


@dataclass
class ReviewQueueItem:
    scenario_id: str
    resolved_id: str
    status: str
    reason: str
    run_dir: str
    summary_path: Optional[str]
    stdout_path: Optional[str]
    stderr_path: Optional[str]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "scenario_id": self.scenario_id,
            "resolved_id": self.resolved_id,
            "status": self.status,
            "reason": self.reason,
            "run_dir": self.run_dir,
            "summary_path": self.summary_path,
            "stdout_path": self.stdout_path,
            "stderr_path": self.stderr_path,
        }


class Aggregator:
    """Aggregates test farm runs into structured statistics and human-review queues."""

    def __init__(self, run_dirs: Optional[List[Path]] = None):
        self.run_dirs = run_dirs or []

    def aggregate_from_dicts(self, results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Aggregate results directly from in-memory run result dictionaries."""
        counts = {
            "total": len(results),
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "blocked": 0,
            "errors": 0,
            "incomplete": 0,
        }
        categories: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        failure_clusters: Dict[str, FailureCluster] = {}
        review_queue: List[ReviewQueueItem] = []

        for r in results:
            status = r.get("status", "UNKNOWN").upper()
            cat = r.get("category", "unclassified")
            sid = r.get("scenario_id", "unknown")
            rid = r.get("resolved_id", sid)
            run_dir_str = r.get("run_dir", "")
            run_dir = Path(run_dir_str) if run_dir_str else None

            # SWA-12 Interrupted check
            if status in ("INTERRUPTED", "INCOMPLETE"):
                counts["incomplete"] += 1
                categories[cat]["incomplete"] += 1
                review_queue.append(
                    ReviewQueueItem(
                        scenario_id=sid,
                        resolved_id=rid,
                        status="INCOMPLETE",
                        reason="Run bundle was interrupted before normal completion",
                        run_dir=run_dir_str,
                        summary_path=str(run_dir / "SUMMARY.md") if run_dir and (run_dir / "SUMMARY.md").exists() else None,
                        stdout_path=str(run_dir / "stdout.log") if run_dir and (run_dir / "stdout.log").exists() else None,
                        stderr_path=str(run_dir / "stderr.log") if run_dir and (run_dir / "stderr.log").exists() else None,
                    )
                )
                continue

            if status == "PASS":
                counts["passed"] += 1
                categories[cat]["passed"] += 1
                # Check if visual_review was requested
                if r.get("failure_class") == "HUMAN_REVIEW_REQUIRED":
                    review_queue.append(
                        ReviewQueueItem(
                            scenario_id=sid,
                            resolved_id=rid,
                            status="PASS",
                            reason="Visual review requested by scenario flags",
                            run_dir=run_dir_str,
                            summary_path=str(run_dir / "SUMMARY.md") if run_dir and (run_dir / "SUMMARY.md").exists() else None,
                            stdout_path=str(run_dir / "stdout.log") if run_dir and (run_dir / "stdout.log").exists() else None,
                            stderr_path=str(run_dir / "stderr.log") if run_dir and (run_dir / "stderr.log").exists() else None,
                        )
                    )
            elif status == "FAIL":
                counts["failed"] += 1
                categories[cat]["failed"] += 1
                sig = r.get("failure_signature") or f"{rid}::GENERIC::FAIL"
                fclass = r.get("failure_class") or "VISION_REGRESSION"
                msg = r.get("failure_message", "")

                if sig not in failure_clusters:
                    failure_clusters[sig] = FailureCluster(signature=sig, failure_class=fclass)
                fc = failure_clusters[sig]
                fc.count += 1
                fc.scenarios.append(rid)
                fc.run_dirs.append(run_dir_str)
                if msg:
                    fc.messages.append(msg)

                review_queue.append(
                    ReviewQueueItem(
                        scenario_id=sid,
                        resolved_id=rid,
                        status="FAIL",
                        reason=msg or f"Failure signature: {sig}",
                        run_dir=run_dir_str,
                        summary_path=str(run_dir / "SUMMARY.md") if run_dir and (run_dir / "SUMMARY.md").exists() else None,
                        stdout_path=str(run_dir / "stdout.log") if run_dir and (run_dir / "stdout.log").exists() else None,
                        stderr_path=str(run_dir / "stderr.log") if run_dir and (run_dir / "stderr.log").exists() else None,
                    )
                )
            elif status == "SKIP":
                counts["skipped"] += 1
                categories[cat]["skipped"] += 1
            elif status == "BLOCK":
                counts["blocked"] += 1
                categories[cat]["blocked"] += 1
                review_queue.append(
                    ReviewQueueItem(
                        scenario_id=sid,
                        resolved_id=rid,
                        status="BLOCK",
                        reason=r.get("failure_message", "Blocked intervention or capability"),
                        run_dir=run_dir_str,
                        summary_path=str(run_dir / "SUMMARY.md") if run_dir and (run_dir / "SUMMARY.md").exists() else None,
                        stdout_path=str(run_dir / "stdout.log") if run_dir and (run_dir / "stdout.log").exists() else None,
                        stderr_path=str(run_dir / "stderr.log") if run_dir and (run_dir / "stderr.log").exists() else None,
                    )
                )
            elif status == "ERROR":
                counts["errors"] += 1
                categories[cat]["errors"] += 1
                review_queue.append(
                    ReviewQueueItem(
                        scenario_id=sid,
                        resolved_id=rid,
                        status="ERROR",
                        reason=r.get("failure_message", "Harness execution error"),
                        run_dir=run_dir_str,
                        summary_path=str(run_dir / "SUMMARY.md") if run_dir and (run_dir / "SUMMARY.md").exists() else None,
                        stdout_path=str(run_dir / "stdout.log") if run_dir and (run_dir / "stdout.log").exists() else None,
                        stderr_path=str(run_dir / "stderr.log") if run_dir and (run_dir / "stderr.log").exists() else None,
                    )
                )

        cluster_list = [fc.to_dict() for fc in sorted(failure_clusters.values(), key=lambda c: c.count, reverse=True)]
        review_list = [rq.to_dict() for rq in review_queue]

        # Convert categories to regular dict
        cat_dict = {k: dict(v) for k, v in categories.items()}

        return {
            "counts": counts,
            "categories": cat_dict,
            "failure_clusters": cluster_list,
            "human_review_queue": review_list,
            "runs": results,
        }

    def aggregate_from_run_dirs(self, run_dirs: Optional[List[Path]] = None) -> Dict[str, Any]:
        """Load result.json from each run directory and aggregate."""
        dirs = run_dirs if run_dirs is not None else self.run_dirs
        results: List[Dict[str, Any]] = []

        for d in dirs:
            if not d.is_dir():
                continue
            res_file = d / "result.json"
            if not res_file.is_file():
                # Incomplete run directory without result.json
                results.append({
                    "run_dir": str(d),
                    "status": "INCOMPLETE",
                    "scenario_id": d.name,
                    "resolved_id": d.name,
                    "failure_message": "result.json missing from run directory",
                })
                continue

            try:
                with open(res_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                data["run_dir"] = str(d)
                results.append(data)
            except Exception as e:
                results.append({
                    "run_dir": str(d),
                    "status": "INCOMPLETE",
                    "scenario_id": d.name,
                    "resolved_id": d.name,
                    "failure_message": f"result.json corrupted or unreadable: {e}",
                })

        return self.aggregate_from_dicts(results)

    def write_reports(self, aggregate_data: Dict[str, Any], output_dir: Path) -> Tuple[Path, Path]:
        """Write aggregate.json and AGGREGATE.md."""
        output_dir.mkdir(parents=True, exist_ok=True)
        json_path = output_dir / "aggregate.json"
        md_path = output_dir / "AGGREGATE.md"

        with open(json_path, "w", encoding="utf-8") as jf:
            json.dump(aggregate_data, jf, indent=2)

        counts = aggregate_data["counts"]
        md_lines = [
            "# Vision Test Farm Aggregate Report",
            "",
            "## Overall Outcomes",
            "",
            f"- **Total Scenarios:** {counts['total']}",
            f"- **Passed:** {counts['passed']}",
            f"- **Failed:** {counts['failed']}",
            f"- **Skipped (Capability):** {counts['skipped']}",
            f"- **Blocked (Intervention):** {counts['blocked']}",
            f"- **Errors:** {counts['errors']}",
            f"- **Incomplete / Interrupted:** {counts['incomplete']}",
            "",
            "## Category Breakdown",
            "",
            "| Category | Total | Pass | Fail | Skip | Block | Error | Incomplete |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
        ]

        for cat, c in sorted(aggregate_data["categories"].items()):
            tot = sum(c.values())
            md_lines.append(
                f"| {cat} | {tot} | {c.get('passed',0)} | {c.get('failed',0)} | "
                f"{c.get('skipped',0)} | {c.get('blocked',0)} | {c.get('errors',0)} | {c.get('incomplete',0)} |"
            )

        md_lines.extend([
            "",
            "## Failure Clusters",
            "",
        ])
        clusters = aggregate_data.get("failure_clusters", [])
        if not clusters:
            md_lines.append("*(No failures detected)*\n")
        else:
            md_lines.extend([
                "| Failure Signature | Class | Count | Sample Message |",
                "|---|---|---:|---|",
            ])
            for fc in clusters:
                md_lines.append(f"| `{fc['signature']}` | `{fc['failure_class']}` | {fc['count']} | {fc['sample_message']} |")
            md_lines.append("")

        md_lines.extend([
            "## Human Review Queue",
            "",
        ])
        rq = aggregate_data.get("human_review_queue", [])
        if not rq:
            md_lines.append("*(Human review queue is empty)*\n")
        else:
            md_lines.extend([
                "| Scenario | Status | Reason | Run Directory | Evidence Links |",
                "|---|---|---|---|---|",
            ])
            for item in rq:
                links = []
                if item.get("summary_path"):
                    links.append(f"[SUMMARY]({item['summary_path']})")
                if item.get("stdout_path"):
                    links.append(f"[stdout]({item['stdout_path']})")
                if item.get("stderr_path"):
                    links.append(f"[stderr]({item['stderr_path']})")
                link_str = " \\| ".join(links) if links else "None"
                md_lines.append(f"| `{item['resolved_id']}` | **{item['status']}** | {item['reason']} | `{item['run_dir']}` | {link_str} |")
            md_lines.append("")

        with open(md_path, "w", encoding="utf-8") as mf:
            mf.write("\n".join(md_lines) + "\n")

        return json_path, md_path
