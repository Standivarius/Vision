"""
Vision Test Farm Schema & Validation (v0.1)

Defines the scenario schema, validation rules, and variant expansion logic.
All scenarios and evidence bundles follow this versioned, human-readable format.
"""

from __future__ import annotations

import copy
import hashlib
import json
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional, Tuple

SCHEMA_VERSION = "0.1"

VALID_CATEGORIES = {
    "unit_replay",
    "lifecycle",
    "zoom_return",
    "pointer",
    "caret",
    "focus",
    "arbitration",
    "geometry",
    "rendering",
    "browser",
    "stress",
    "synthetic",
    "future_gated",
}

VALID_FIXTURE_TYPES = {
    "powershell",
    "process",
    "ctest",
    "python",
    "synthetic",
}

VALID_ASSERTION_TYPES = {
    "exit_code",
    "telemetry_present",
    "telemetry_metric",
    "file_exists",
    "regex_match",
    "log_event",
    "custom",
}

VALID_OPS = {"eq", "ne", "lt", "lte", "gt", "gte", "contains", "not_contains", "regex"}


class SchemaValidationError(Exception):
    def __init__(self, errors: List[str]):
        self.errors = errors
        super().__init__("; ".join(errors))


def canonical_json_bytes(obj: Any) -> bytes:
    """Return deterministic UTF-8 bytes for canonical JSON hashing."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def compute_scenario_hash(scenario_dict: Dict[str, Any]) -> str:
    """Compute deterministic SHA-256 hash of a scenario specification."""
    return hashlib.sha256(canonical_json_bytes(scenario_dict)).hexdigest()


def validate_scenario(data: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Validate scenario dictionary against schema v0.1 rules.
    Returns (is_valid, list_of_error_messages).
    """
    errors: List[str] = []

    if not isinstance(data, dict):
        return False, ["Scenario data must be a dictionary"]

    # Required top-level fields
    required_fields = ["schema_version", "id", "version", "title", "category", "fixture", "assertions"]
    for f in required_fields:
        if f not in data or data[f] is None:
            errors.append(f"Missing required field: '{f}'")

    if errors:
        return False, errors

    # Schema version
    if str(data.get("schema_version")) != SCHEMA_VERSION:
        errors.append(f"Unsupported schema_version: '{data.get('schema_version')}'; expected '{SCHEMA_VERSION}'")

    # ID format
    sid = data.get("id")
    if not isinstance(sid, str) or not sid.strip():
        errors.append("Field 'id' must be a non-empty string")
    elif any(c in sid for c in " \t\r\n@/\\:"):
        errors.append(f"Field 'id' contains invalid characters: '{sid}'")

    # Version format
    ver = data.get("version")
    if not isinstance(ver, str) or not ver.strip():
        errors.append("Field 'version' must be a non-empty string")

    # Category validation
    cat = data.get("category")
    if cat not in VALID_CATEGORIES:
        errors.append(f"Invalid category: '{cat}'; must be one of {sorted(VALID_CATEGORIES)}")

    # Fixture validation
    fixture = data.get("fixture")
    if not isinstance(fixture, dict):
        errors.append("Field 'fixture' must be a dictionary")
    else:
        ftype = fixture.get("type")
        if ftype not in VALID_FIXTURE_TYPES:
            errors.append(f"Invalid fixture type: '{ftype}'; must be one of {sorted(VALID_FIXTURE_TYPES)}")
        entrypoint = fixture.get("entrypoint")
        if not entrypoint or not isinstance(entrypoint, str):
            errors.append("Fixture must provide non-empty 'entrypoint' string")

    # Assertions validation
    assertions = data.get("assertions")
    if not isinstance(assertions, list):
        errors.append("Field 'assertions' must be a list")
    elif len(assertions) == 0:
        errors.append("Scenario must declare at least one assertion")
    else:
        seen_assertion_ids = set()
        for i, a in enumerate(assertions):
            if not isinstance(a, dict):
                errors.append(f"Assertion[{i}] must be a dictionary")
                continue
            aid = a.get("id")
            if not aid or not isinstance(aid, str):
                errors.append(f"Assertion[{i}] must have non-empty 'id'")
            elif aid in seen_assertion_ids:
                errors.append(f"Duplicate assertion id '{aid}' in scenario '{sid}'")
            else:
                seen_assertion_ids.add(aid)

            atype = a.get("type")
            if atype not in VALID_ASSERTION_TYPES:
                errors.append(f"Assertion '{aid}' has invalid type: '{atype}'; must be one of {sorted(VALID_ASSERTION_TYPES)}")

            op = a.get("op")
            if op not in VALID_OPS:
                errors.append(f"Assertion '{aid}' has invalid op: '{op}'; must be one of {sorted(VALID_OPS)}")

    # Capabilities validation (if present)
    caps = data.get("capabilities_required")
    if caps is not None and not isinstance(caps, dict):
        errors.append("Field 'capabilities_required' must be a dictionary if present")

    # Flags validation (if present)
    flags = data.get("flags")
    if flags is not None and not isinstance(flags, dict):
        errors.append("Field 'flags' must be a dictionary if present")

    # Variants validation (if present)
    variants = data.get("variants")
    if variants is not None:
        if not isinstance(variants, list):
            errors.append("Field 'variants' must be a list if present")
        else:
            seen_variant_ids = set()
            for j, v in enumerate(variants):
                if not isinstance(v, dict):
                    errors.append(f"Variant[{j}] must be a dictionary")
                    continue
                vid = v.get("id")
                if not vid or not isinstance(vid, str):
                    errors.append(f"Variant[{j}] must have non-empty 'id'")
                elif vid in seen_variant_ids:
                    errors.append(f"Duplicate variant id '{vid}' in scenario '{sid}'")
                else:
                    seen_variant_ids.add(vid)

    return len(errors) == 0, errors


def expand_scenario_variants(scenario_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Expand a scenario containing 'variants' into multiple resolved scenario dicts.
    Each variant produces a stable compound ID: <base_id>@<variant_id>.
    If no variants are declared, returns a single-item list with the base scenario.
    """
    valid, errors = validate_scenario(scenario_data)
    if not valid:
        raise SchemaValidationError(errors)

    variants = scenario_data.get("variants")
    if not variants:
        base_copy = copy.deepcopy(scenario_data)
        base_copy["resolved_id"] = base_copy["id"]
        base_copy["scenario_hash"] = compute_scenario_hash(base_copy)
        return [base_copy]

    expanded: List[Dict[str, Any]] = []
    base_id = scenario_data["id"]

    for var in variants:
        variant_id = var["id"]
        compound_id = f"{base_id}@{variant_id}"
        resolved = copy.deepcopy(scenario_data)
        # Remove top-level variants list from resolved scenario
        resolved.pop("variants", None)

        # Merge variant overrides
        resolved["resolved_id"] = compound_id
        resolved["variant_id"] = variant_id
        if "title" in var:
            resolved["title"] = f"{scenario_data['title']} ({var['title']})"
        else:
            resolved["title"] = f"{scenario_data['title']} [{variant_id}]"

        # Merge args
        if "args" in var:
            fixture = copy.deepcopy(resolved.get("fixture", {}))
            fixture["args"] = var["args"]
            resolved["fixture"] = fixture

        # Merge initial_settings
        if "initial_settings" in var:
            settings = copy.deepcopy(resolved.get("initial_settings", {}))
            settings.update(var["initial_settings"])
            resolved["initial_settings"] = settings

        # Merge flags
        if "flags" in var:
            flags = copy.deepcopy(resolved.get("flags", {}))
            flags.update(var["flags"])
            resolved["flags"] = flags

        # Compute stable hash
        resolved["scenario_hash"] = compute_scenario_hash(resolved)
        expanded.append(resolved)

    return expanded
