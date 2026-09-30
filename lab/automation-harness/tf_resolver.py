"""
Vision Test Farm Scenario Resolver & Preflight Planner (v0.1)

Loads scenario definitions from the catalogue, expands variants, checks schema validity,
and preflights each scenario against the probed environment into:
- RUNNABLE
- SKIPPED_CAPABILITY
- BLOCKED_INTERVENTION
- INVALID
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from tf_schema import (
    validate_scenario,
    expand_scenario_variants,
    compute_scenario_hash,
    SchemaValidationError,
)


@dataclass
class PreflightDecision:
    scenario: Dict[str, Any]
    status: str  # "RUNNABLE", "SKIPPED_CAPABILITY", "BLOCKED_INTERVENTION", "INVALID"
    reasons: List[str] = field(default_factory=list)

    @property
    def resolved_id(self) -> str:
        return self.scenario.get("resolved_id", self.scenario.get("id", "unknown"))

    def to_dict(self) -> Dict[str, Any]:
        return {
            "resolved_id": self.resolved_id,
            "status": self.status,
            "reasons": self.reasons,
            "scenario": self.scenario,
        }


def preflight_scenario(scenario: Dict[str, Any], env: Dict[str, Any]) -> PreflightDecision:
    """Preflight a single resolved scenario against the environment."""
    # First check schema validity
    valid, errors = validate_scenario(scenario)
    if not valid:
        return PreflightDecision(scenario=scenario, status="INVALID", reasons=errors)

    caps = scenario.get("capabilities_required", {})
    flags = scenario.get("flags", {})

    reasons: List[str] = []

    # Check blocked intervention / privileged flags
    is_admin = env.get("elevation", {}).get("is_admin", False)
    if flags.get("not_yet_automatable", False):
        return PreflightDecision(
            scenario=scenario,
            status="BLOCKED_INTERVENTION",
            reasons=["Scenario marked 'not_yet_automatable'"],
        )
    if flags.get("destructive", False):
        return PreflightDecision(
            scenario=scenario,
            status="BLOCKED_INTERVENTION",
            reasons=["Scenario marked 'destructive'"],
        )
    if flags.get("privileged", False) and not is_admin:
        return PreflightDecision(
            scenario=scenario,
            status="BLOCKED_INTERVENTION",
            reasons=["Scenario requires administrator privileges, but process is non-elevated"],
        )
    if caps.get("requires_admin", False) and not is_admin:
        return PreflightDecision(
            scenario=scenario,
            status="BLOCKED_INTERVENTION",
            reasons=["Scenario requires administrator elevation, current session is non-elevated"],
        )

    # Check capability skips
    display_count = env.get("display_topology", {}).get("display_count", 0)
    min_displays = caps.get("min_displays", 1)
    if display_count < min_displays:
        reasons.append(f"Requires at least {min_displays} displays, found {display_count}")

    exact_displays = caps.get("exact_displays")
    if exact_displays is not None and display_count != exact_displays:
        reasons.append(f"Requires exactly {exact_displays} displays, found {display_count}")

    if caps.get("requires_physical_console", False):
        is_console = env.get("session", {}).get("is_console_session", False)
        if not is_console:
            reasons.append("Requires active physical console session")

    if caps.get("requires_installed_product", False):
        installed_exists = env.get("vision_binaries", {}).get("installed_executable", {}).get("exists", False)
        if not installed_exists:
            reasons.append("Requires installed Vision public alpha package")

    if caps.get("requires_dev_binary", False):
        dev_exists = env.get("vision_binaries", {}).get("dev_executable", {}).get("exists", False)
        if not dev_exists:
            reasons.append("Requires built dev binary: app/build/Release/visual_app.exe")

    if reasons:
        return PreflightDecision(scenario=scenario, status="SKIPPED_CAPABILITY", reasons=reasons)

    return PreflightDecision(scenario=scenario, status="RUNNABLE", reasons=["All required capabilities present"])


class ScenarioResolver:
    """Discovers scenarios, expands variants, and generates preflight execution plans."""

    def __init__(self, catalogue_dir: Path, repo_root: Optional[Path] = None):
        self.catalogue_dir = catalogue_dir
        self.repo_root = repo_root or catalogue_dir.parent.parent

    def load_all_scenarios(self) -> List[Dict[str, Any]]:
        """Load and expand all scenario definitions from JSON files in catalogue_dir."""
        all_resolved: List[Dict[str, Any]] = []
        if not self.catalogue_dir.is_dir():
            return []

        for p in sorted(self.catalogue_dir.glob("*.json")):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                expanded = expand_scenario_variants(data)
                all_resolved.extend(expanded)
            except Exception as e:
                # Malformed scenario file produces an INVALID stub
                stub = {
                    "schema_version": "0.1",
                    "id": p.stem,
                    "resolved_id": p.stem,
                    "version": "0.0",
                    "title": f"Invalid scenario in {p.name}",
                    "category": "future_gated",
                    "fixture": {"type": "synthetic", "entrypoint": "invalid"},
                    "assertions": [{"id": "schema", "type": "exit_code", "op": "eq", "expected": 0}],
                    "_load_error": str(e),
                }
                all_resolved.append(stub)
        return all_resolved

    def plan(
        self,
        env: Dict[str, Any],
        scenarios: Optional[List[Dict[str, Any]]] = None,
        pack: Optional[str] = None,
        tags: Optional[Set[str]] = None,
        category: Optional[str] = None,
        scenario_id: Optional[str] = None,
    ) -> List[PreflightDecision]:
        """Produce filtered, preflighted execution plan."""
        items = scenarios if scenarios is not None else self.load_all_scenarios()
        planned: List[PreflightDecision] = []

        for sc in items:
            sid = sc.get("resolved_id", sc.get("id", ""))
            sc_tags = set(sc.get("tags", []))
            sc_cat = sc.get("category", "")

            # Filter by ID
            if scenario_id and scenario_id not in sid:
                continue

            # Filter by category
            if category and sc_cat != category:
                continue

            # Filter by tags
            if tags and not tags.intersection(sc_tags):
                continue

            # Filter by predefined packs
            if pack == "safe_smoke":
                if "safe_smoke" not in sc_tags:
                    continue
            elif pack == "unit":
                if sc_cat != "unit_replay":
                    continue
            elif pack == "gated":
                if sc_cat != "future_gated":
                    continue

            # Run preflight
            decision = preflight_scenario(sc, env)
            planned.append(decision)

        return planned
