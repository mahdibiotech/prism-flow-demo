#!/usr/bin/env python3
# Generate a deterministic synthetic RNA-seq count matrix for workflow demonstration.

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np
import pandas as pd


def load_samples(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t", dtype=str).fillna("")
    if "sample_id" not in df or "condition" not in df:
        raise ValueError("samples file requires sample_id and condition columns")
    return df


def simulate(samples: pd.DataFrame, n_genes: int, seed: int) -> tuple[pd.DataFrame, pd.DataFrame]:
    rng = np.random.default_rng(seed)
    n = len(samples)

    # Gene-specific baseline means spanning low to high abundance.
    baseline = np.exp(rng.normal(np.log(60), 1.0, size=n_genes))
    dispersion = 0.20

    # Encode a known signal in 10% of genes, split between up/down regulation.
    n_de = max(10, int(n_genes * 0.10))
    de_genes = np.arange(n_de)
    half = n_de // 2
    fold_change = np.ones(n_genes)
    fold_change[de_genes[:half]] = 4.0
    fold_change[de_genes[half:]] = 0.25

    matrix = np.zeros((n_genes, n), dtype=int)
    for j, row in samples.reset_index(drop=True).iterrows():
        mu = baseline.copy()
        if row["condition"] == "tumor":
            mu *= fold_change

        # Negative binomial parameterisation: Var = mu + dispersion * mu^2.
        size = 1.0 / dispersion
        prob = size / (size + mu)
        matrix[:, j] = rng.negative_binomial(size, prob)

    gene_ids = [f"GENE_{i+1:04d}" for i in range(n_genes)]
    counts = pd.DataFrame(matrix, columns=samples["sample_id"].tolist())
    counts.insert(0, "gene_id", gene_ids)

    truth = pd.DataFrame(
        {
            "gene_id": gene_ids,
            "is_simulated_de": [i in set(de_genes) for i in range(n_genes)],
            "simulated_fold_change_tumor_vs_normal": fold_change,
        }
    )
    return counts, truth


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", required=True, type=Path)
    parser.add_argument("--counts", required=True, type=Path)
    parser.add_argument("--truth", required=True, type=Path)
    parser.add_argument("--genes", type=int, default=500)
    parser.add_argument("--seed", type=int, default=20260924)
    args = parser.parse_args()

    samples = load_samples(args.samples)
    counts, truth = simulate(samples, args.genes, args.seed)

    args.counts.parent.mkdir(parents=True, exist_ok=True)
    counts.to_csv(args.counts, sep="\t", index=False)
    truth.to_csv(args.truth, sep="\t", index=False)
    print(f"Wrote {len(counts)} genes x {len(samples)} samples to {args.counts}")


if __name__ == "__main__":
    main()
