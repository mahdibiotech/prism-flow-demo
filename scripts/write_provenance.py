#!/usr/bin/env python3
# Write one atomic provenance event for a completed workflow step.

from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def git_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return "unavailable"


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", required=True, type=Path)
    parser.add_argument("--rule", required=True)
    parser.add_argument("--step", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--started", required=True)
    parser.add_argument("--finished", required=True)
    parser.add_argument("--inputs", nargs="*", default=[])
    parser.add_argument("--outputs", nargs="*", default=[])
    parser.add_argument("--command", default="")
    parser.add_argument("--environment", default="")
    parser.add_argument("--sample", default="")
    args = parser.parse_args()

    started = parse_time(args.started)
    finished = parse_time(args.finished)
    payload = {
        "rule": args.rule,
        "sample": args.sample,
        "step": args.step,
        "status": args.status,
        "started_at": args.started,
        "finished_at": args.finished,
        "runtime_seconds": max(0.0, (finished - started).total_seconds()),
        "inputs": args.inputs,
        "outputs": args.outputs,
        "command": args.command,
        "software_environment": args.environment,
        "git_commit": git_commit(),
        "host": os.environ.get("HOSTNAME", "unknown"),
    }

    args.event.parent.mkdir(parents=True, exist_ok=True)
    tmp = args.event.with_suffix(args.event.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    tmp.replace(args.event)


if __name__ == "__main__":
    main()
