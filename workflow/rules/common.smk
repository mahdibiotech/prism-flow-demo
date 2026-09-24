rule validate_metadata:
    input:
        samples=SAMPLE_SHEET,
        patients=PATIENT_SHEET
    output:
        report="results/metadata/validation.json"
    params:
        mode=MODE
    conda:
        "../envs/python.yaml"
    log:
        "logs/validate_metadata.log"
    benchmark:
        "benchmarks/validate_metadata.tsv"
    shell:
        r'''
        set -euo pipefail
        mkdir -p results/metadata provenance/events
        START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/validate_metadata.py \
          --samples {input.samples:q} \
          --patients {input.patients:q} \
          --mode {params.mode:q} \
          --output {output.report:q} > {log:q} 2>&1
        END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/write_provenance.py \
          --event provenance/events/validate_metadata.json \
          --rule validate_metadata --step metadata_validation --status success \
          --started "$START" --finished "$END" \
          --inputs {input.samples:q} {input.patients:q} \
          --outputs {output.report:q} \
          --command "python scripts/validate_metadata.py --mode {params.mode}" \
          --environment workflow/envs/python.yaml
        '''


rule aggregate_provenance:
    input:
        validation="results/metadata/validation.json",
        qc="results/qc/qc_gate.tsv",
        de="results/bulk/deseq2/results_full.tsv",
        report="results/report/prism_flow_report.html"
    output:
        "provenance/execution_trace.tsv"
    conda:
        "../envs/python.yaml"
    log:
        "logs/aggregate_provenance.log"
    shell:
        r'''
        set -euo pipefail
        python scripts/aggregate_provenance.py \
          --events-dir provenance/events \
          --output {output:q} > {log:q} 2>&1
        '''
