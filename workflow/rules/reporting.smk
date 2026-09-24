rule render_report:
    input:
        validation="results/metadata/validation.json",
        qc="results/qc/qc_gate.tsv",
        qc_summary="results/qc/qc_gate_summary.json",
        de="results/bulk/deseq2/results_full.tsv",
        sig="results/bulk/deseq2/results_significant.tsv",
        pca="results/bulk/deseq2/pca.png",
        volcano="results/bulk/deseq2/volcano.png"

    output:
        "results/report/prism_flow_report.html"

    conda:
        "../envs/report.yaml"

    log:
        "logs/report.log"

    benchmark:
        "benchmarks/report.tsv"

    shell:
        r'''
        set -euo pipefail

        mkdir -p results/report provenance/events

        START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        ROOT=$(pwd)

        (
          cd workflow/report

          PRISM_FLOW_ROOT="$ROOT" quarto render report.qmd \
            --output prism_flow_report.html

        ) > {log:q} 2>&1

        mv workflow/report/prism_flow_report.html \
           results/report/prism_flow_report.html

        rm -rf workflow/report/report_files

        END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

        python scripts/write_provenance.py \
          --event provenance/events/render_report.json \
          --rule render_report \
          --step reporting \
          --status success \
          --started "$START" \
          --finished "$END" \
          --inputs \
            {input.validation:q} \
            {input.qc:q} \
            {input.de:q} \
          --outputs \
            {output:q} \
          --command "quarto render workflow/report/report.qmd" \
          --environment workflow/envs/report.yaml
        '''
