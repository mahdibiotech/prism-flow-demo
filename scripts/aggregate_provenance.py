#!/usr/bin/env python3
# Aggregate JSON provenance events into a tabular execution trace.

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

COLUMNS = [
    "rule",
    "sample",
    "step",
    "status",
    "started_at",
    "finished_at",
    "runtime_seconds",
    "inputs",
    "outputs",
    "command",
    "software_environment",
    "git_commit",
    "host",
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--events-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    events = []
    for path in sorted(args.events_dir.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        payload["inputs"] = ";".join(payload.get("inputs", []))
        payload["outputs"] = ";".join(payload.get("outputs", []))
        events.append(payload)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        for event in events:
            writer.writerow({col: event.get(col, "") for col in COLUMNS})

    print(f"Aggregated {len(events)} provenance events into {args.output}")


if __name__ == "__main__":
    main()
