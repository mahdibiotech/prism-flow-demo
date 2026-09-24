#!/usr/bin/env python3
# Validate sample/patient metadata before workflow execution.

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

REQUIRED_SAMPLE_COLUMNS = {
    "sample_id",
    "patient_id",
    "condition",
    "modality",
    "sample_type",
    "fastq_r1",
    "fastq_r2",
}
REQUIRED_PATIENT_COLUMNS = {"patient_id"}
ALLOWED_MODALITIES = {"bulk_rnaseq", "scrnaseq", "spatial", "wgs", "wes", "imaging"}


def read_tsv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None:
            raise ValueError(f"No header found in {path}")
        return reader.fieldnames, list(reader)


def validate(samples_path: Path, patients_path: Path, mode: str) -> dict:
    errors: list[str] = []
    warnings: list[str] = []

    sample_fields, samples = read_tsv(samples_path)
    patient_fields, patients = read_tsv(patients_path)

    missing = REQUIRED_SAMPLE_COLUMNS - set(sample_fields)
    if missing:
        errors.append(f"Missing sample columns: {', '.join(sorted(missing))}")

    missing_pat = REQUIRED_PATIENT_COLUMNS - set(patient_fields)
    if missing_pat:
        errors.append(f"Missing patient columns: {', '.join(sorted(missing_pat))}")

    sample_ids = [r.get("sample_id", "").strip() for r in samples]
    patient_ids = [r.get("patient_id", "").strip() for r in patients]
    patient_set = set(patient_ids)

    duplicates = sorted({x for x in sample_ids if x and sample_ids.count(x) > 1})
    if duplicates:
        errors.append(f"Duplicate sample_id values: {', '.join(duplicates)}")

    pduplicates = sorted({x for x in patient_ids if x and patient_ids.count(x) > 1})
    if pduplicates:
        errors.append(f"Duplicate patient_id values: {', '.join(pduplicates)}")

    if any(not sid for sid in sample_ids):
        errors.append("Blank sample_id found")

    conditions = set()
    modalities = set()

    for i, row in enumerate(samples, start=2):
        sid = row.get("sample_id", "").strip() or f"row_{i}"
        pid = row.get("patient_id", "").strip()
        condition = row.get("condition", "").strip()
        modality = row.get("modality", "").strip()

        if not pid:
            errors.append(f"{sid}: missing patient_id")
        elif pid not in patient_set:
            errors.append(f"{sid}: patient_id {pid!r} not found in patient table")

        if not condition:
            errors.append(f"{sid}: missing condition")
        else:
            conditions.add(condition)

        if modality not in ALLOWED_MODALITIES:
            errors.append(
                f"{sid}: unknown modality {modality!r}; allowed={sorted(ALLOWED_MODALITIES)}"
            )
        else:
            modalities.add(modality)

        if mode == "fastq" and modality == "bulk_rnaseq":
            for col in ("fastq_r1", "fastq_r2"):
                raw = row.get(col, "").strip()
                if not raw:
                    errors.append(f"{sid}: {col} is required in fastq mode")
                elif not Path(raw).exists():
                    errors.append(f"{sid}: {col} does not exist: {raw}")

    if len(conditions) < 2:
        warnings.append("Fewer than two analysis conditions were found")

    if any(m != "bulk_rnaseq" for m in modalities):
        warnings.append(
            "This repository currently executes the bulk_rnaseq reference modality only; "
            "other modalities are architecture placeholders."
        )

    result = {
        "status": "PASS" if not errors else "FAIL",
        "mode": mode,
        "sample_count": len(samples),
        "patient_count": len(patients),
        "conditions": sorted(conditions),
        "modalities": sorted(modalities),
        "errors": errors,
        "warnings": warnings,
    }
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", required=True, type=Path)
    parser.add_argument("--patients", required=True, type=Path)
    parser.add_argument("--mode", required=True, choices=["demo", "fastq"])
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    result = validate(args.samples, args.patients, args.mode)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    if result["errors"]:
        for msg in result["errors"]:
            print(f"ERROR: {msg}")
        return 2

    print(
        f"Metadata validation PASS: {result['sample_count']} samples, "
        f"{result['patient_count']} patients"
    )
    for msg in result["warnings"]:
        print(f"WARNING: {msg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
