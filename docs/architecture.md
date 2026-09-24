# Architecture notes

## Objective

PRISM-Flow separates **data processing** from the **platform contracts** that make processing reliable:

1. metadata contract;
2. workflow dependency graph;
3. QC contract;
4. provenance contract;
5. result/report contract.

This structure lets each omics modality evolve independently while preserving consistent operational behaviour.

## Result namespace

```text
results/<modality>/<stage>/...
results/qc/...
results/report/...
provenance/...
logs/...
benchmarks/...
```

## Multi-omics extension

A future modality rule file should expose at least:

- validated sample identifiers;
- primary processed artifacts;
- modality-specific QC metrics;
- PASS/WARN/FAIL state;
- provenance event;
- compact reportable summary.

Potential branches:

- **single-cell:** Cell Ranger/STARsolo → Scanpy/Seurat QC → embeddings/markers;
- **spatial:** platform-specific ingestion → QC → spatial expression objects;
- **WES/WGS:** alignment → duplicate handling → variant calling → annotation;
- **imaging:** image QC → feature extraction → indexed result manifest.

## Safety boundary

The repository is a research engineering demonstrator. Clinical deployment would require institutional governance, validated SOPs, access controls, audit requirements, data-protection review, software validation and modality-specific acceptance criteria.
