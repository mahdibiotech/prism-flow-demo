#!/usr/bin/env python3
# Compute simple count-matrix quality metrics per sample.

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


def calculate_qc(counts: pd.DataFrame) -> pd.DataFrame:
    if "gene_id" not in counts.columns:
        raise ValueError("Count matrix must contain a gene_id column")

    data = counts.drop(columns=["gene_id"])
    if data.empty:
        raise ValueError("No sample columns found in count matrix")
    if (data < 0).any().any():
        raise ValueError("Negative counts are not allowed")

    rows = []
    for sample_id in data.columns:
        values = data[sample_id]
        rows.append(
            {
                "sample_id": sample_id,
                "library_size": int(values.sum()),
                "detected_genes": int((values > 0).sum()),
                "zero_fraction": float((values == 0).mean()),
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--counts", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    counts = pd.read_csv(args.counts, sep="\t")
    qc = calculate_qc(counts)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    qc.to_csv(args.output, sep="\t", index=False, float_format="%.6f")
    print(qc.to_string(index=False))


if __name__ == "__main__":
    main()
