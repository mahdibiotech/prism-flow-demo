#!/usr/bin/env python3
# Assign PASS/WARN/FAIL state from configurable count-level QC thresholds.

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd


def classify(row, args) -> tuple[str, str]:
    fail = []
    warn = []

    if row.library_size < args.fail_library:
        fail.append(f"library_size<{args.fail_library}")
    elif row.library_size < args.warn_library:
        warn.append(f"library_size<{args.warn_library}")

    if row.detected_genes < args.fail_genes:
        fail.append(f"detected_genes<{args.fail_genes}")
    elif row.detected_genes < args.warn_genes:
        warn.append(f"detected_genes<{args.warn_genes}")

    if row.zero_fraction > args.warn_zero_fraction:
        warn.append(f"zero_fraction>{args.warn_zero_fraction}")

    if fail:
        return "FAIL", ";".join(fail + warn)
    if warn:
        return "WARN", ";".join(warn)
    return "PASS", "all_thresholds_met"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--fail-library", required=True, type=int)
    parser.add_argument("--warn-library", required=True, type=int)
    parser.add_argument("--fail-genes", required=True, type=int)
    parser.add_argument("--warn-genes", required=True, type=int)
    parser.add_argument("--warn-zero-fraction", required=True, type=float)
    args = parser.parse_args()

    df = pd.read_csv(args.input, sep="\t")
    states = df.apply(lambda row: classify(row, args), axis=1)
    df["qc_status"] = [x[0] for x in states]
    df["qc_reasons"] = [x[1] for x in states]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.output, sep="\t", index=False, float_format="%.6f")

    counts = df["qc_status"].value_counts().to_dict()
    summary = {
        "samples": int(len(df)),
        "PASS": int(counts.get("PASS", 0)),
        "WARN": int(counts.get("WARN", 0)),
        "FAIL": int(counts.get("FAIL", 0)),
    }
    args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(df.to_string(index=False))


if __name__ == "__main__":
    main()
