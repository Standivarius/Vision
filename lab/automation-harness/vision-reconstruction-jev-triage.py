"""Small optional Jev triage adapter. Dry-run by default. Never sends binary/code."""
import argparse
import json
import os
import re
import time
import urllib.request
from pathlib import Path

SAFE = re.compile(r"^[a-zA-Z0-9 _.,:/#()?+-]{1,130}$")
ENDPOINT = "https://api.typesafe.ai/v1/systemone"
CATEGORIES = {
    "render_capture": "Graphics capture, GPU render, composition or presentation",
    "accessibility_tracking": "UI Automation, caret, pointer, focus or movement evidence",
    "topology_roles": "Monitor identity, topology, recovery or source/destination ownership",
    "configuration_ui": "Settings, application windows, preferences and help UI",
    "other": "Unknown, unrelated, or not enough information",
}
RELEVANCE = [
    "No apparent relation to the investigation",
    "Weak contextual clue",
    "Plausibly related but indirect",
    "Relevant function or mechanism clue",
    "Directly decisive evidence for the investigated mechanism",
]


def safe_string(x):
    if not isinstance(x, str) or not SAFE.fullmatch(x):
        raise ValueError("Only short safe identifiers/metadata are permitted")
    return x


def create_payload(input_data):
    question = safe_string(input_data["question"])
    candidates = input_data["candidates"]
    if not 1 <= len(candidates) <= 8:
        raise ValueError("Provide 1 to 8 bounded candidates")
    state = {"investigation": question, "candidates": []}
    questions = {}
    for index, candidate in enumerate(candidates):
        identifier = safe_string(candidate["id"])
        signals = [safe_string(s) for s in candidate["signals"]]
        if len(signals) > 8:
            raise ValueError("At most 8 concise signals per candidate")
        state["candidates"].append({"id": identifier, "signals": signals})
        prefix = "c" + str(index)
        questions[prefix + "_area"] = {
            "type": "choice",
            "instructions": "Choose the best technical domain for candidate "
                            + identifier + " using only the provided metadata.",
            "criteria": CATEGORIES,
        }
        questions[prefix + "_relevance"] = {
            "type": "score",
            "instructions": "Score how strongly " + identifier +
                            " supports this investigation; avoid over-claiming.",
            "criteria": RELEVANCE,
        }
    return {
        "model": "jev-latest",
        "state": state,
        "questions": questions,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--live", action="store_true",
                        help="Explicitly allow transmission of metadata to official Jev API")
    args = parser.parse_args()
    payload = create_payload(json.loads(Path(args.input).read_text(encoding="utf-8-sig")))
    out = {"mode": "dry_run", "sent": False,
           "question_count": len(payload["questions"]),
           "candidate_count": len(payload["state"]["candidates"]),
           "payload": payload}
    if args.live:
        key = os.environ.get("JEV_API_KEY")
        if not key:
            raise SystemExit("JEV_API_KEY not configured; no network request sent")
        data = json.dumps(payload, separators=(",", ":")).encode()
        req = urllib.request.Request(ENDPOINT, data=data, method="POST",
                                     headers={"Authorization": "Bearer " + key,
                                              "Content-Type": "application/json"})
        start = time.perf_counter()
        with urllib.request.urlopen(req, timeout=35) as response:
            answer = json.load(response)
        out = {"mode": "live", "sent": True,
               "elapsed_seconds": round(time.perf_counter() - start, 3),
               "answer": answer}
    Path(args.output).write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(json.dumps({"mode": out["mode"], "sent": out["sent"],
                      "candidate_count": len(payload["state"]["candidates"])}))


if __name__ == "__main__":
    main()