COUNTS = "results/bulk/counts/gene_counts.tsv"

if MODE == "demo":
    rule generate_demo_counts:
        input:
            validation="results/metadata/validation.json",
            samples=SAMPLE_SHEET
        output:
            counts=COUNTS,
            truth="results/bulk/counts/simulation_truth.tsv"
        params:
            genes=config["analysis"]["demo_genes"],
            seed=config["analysis"]["seed"]
        conda:
            "../envs/python.yaml"
        log:
            "logs/generate_demo_counts.log"
        benchmark:
            "benchmarks/generate_demo_counts.tsv"
        shell:
            r'''
            set -euo pipefail
            mkdir -p results/bulk/counts provenance/events
            START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            python scripts/generate_demo_data.py \
              --samples {input.samples:q} \
              --counts {output.counts:q} \
              --truth {output.truth:q} \
              --genes {params.genes} \
              --seed {params.seed} > {log:q} 2>&1
            END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            python scripts/write_provenance.py \
              --event provenance/events/generate_demo_counts.json \
              --rule generate_demo_counts --step synthetic_demo_generation --status success \
              --started "$START" --finished "$END" \
              --inputs {input.samples:q} \
              --outputs {output.counts:q} {output.truth:q} \
              --command "python scripts/generate_demo_data.py --genes {params.genes} --seed {params.seed}" \
              --environment workflow/envs/python.yaml
            '''

else:
    rule fastqc_raw:
        input:
            r1=lambda wc: SAMPLE_BY_ID[wc.sample]["fastq_r1"],
            r2=lambda wc: SAMPLE_BY_ID[wc.sample]["fastq_r2"]
        output:
            html1="results/qc/fastqc/{sample}_R1_fastqc.html",
            zip1="results/qc/fastqc/{sample}_R1_fastqc.zip",
            html2="results/qc/fastqc/{sample}_R2_fastqc.html",
            zip2="results/qc/fastqc/{sample}_R2_fastqc.zip"
        conda:
            "../envs/fastqc.yaml"
        threads: 2
        log:
            "logs/fastqc/{sample}.log"
        shell:
            r'''
            set -euo pipefail
            mkdir -p results/qc/fastqc logs/fastqc provenance/events
            fastqc --threads {threads} --outdir results/qc/fastqc \
              {input.r1:q} {input.r2:q} > {log:q} 2>&1
            '''

    rule trim_galore:
        input:
            r1=lambda wc: SAMPLE_BY_ID[wc.sample]["fastq_r1"],
            r2=lambda wc: SAMPLE_BY_ID[wc.sample]["fastq_r2"],
            qc1="results/qc/fastqc/{sample}_R1_fastqc.html",
            qc2="results/qc/fastqc/{sample}_R2_fastqc.html"
        output:
            r1="results/bulk/trimmed/{sample}_R1_val_1.fq.gz",
            r2="results/bulk/trimmed/{sample}_R2_val_2.fq.gz"
        conda:
            "../envs/trim_galore.yaml"
        log:
            "logs/trim/{sample}.log"
        benchmark:
            "benchmarks/trim_{sample}.tsv"
        shell:
            r'''
            set -euo pipefail
            mkdir -p results/bulk/trimmed logs/trim
            trim_galore --paired --gzip --output_dir results/bulk/trimmed \
              {input.r1:q} {input.r2:q} > {log:q} 2>&1
            '''

    rule salmon_quant:
        input:
            r1="results/bulk/trimmed/{sample}_R1_val_1.fq.gz",
            r2="results/bulk/trimmed/{sample}_R2_val_2.fq.gz"
        output:
            quant="results/bulk/salmon/{sample}/quant.sf",
            meta="results/bulk/salmon/{sample}/aux_info/meta_info.json"
        params:
            index=config["reference"]["salmon_index"],
            outdir=lambda wc: f"results/bulk/salmon/{wc.sample}"
        threads: config["resources"]["salmon_threads"]
        conda:
            "../envs/salmon.yaml"
        log:
            "logs/salmon/{sample}.log"
        benchmark:
            "benchmarks/salmon_{sample}.tsv"
        shell:
            r'''
            set -euo pipefail
            mkdir -p {params.outdir:q} logs/salmon
            salmon quant -i {params.index:q} -l A \
              -1 {input.r1:q} -2 {input.r2:q} \
              --validateMappings --gcBias --seqBias \
              -p {threads} -o {params.outdir:q} > {log:q} 2>&1
            '''

    rule tximport_counts:
        input:
            validation="results/metadata/validation.json",
            quants=expand("results/bulk/salmon/{sample}/quant.sf", sample=SAMPLES),
            samples=SAMPLE_SHEET,
            tx2gene=config["reference"]["tx2gene"]
        output:
            counts=COUNTS
        conda:
            "../envs/deseq2.yaml"
        log:
            "logs/tximport.log"
        benchmark:
            "benchmarks/tximport.tsv"
        shell:
            r'''
            set -euo pipefail
            mkdir -p results/bulk/counts provenance/events
            START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            Rscript scripts/tximport_counts.R \
              {input.samples:q} {input.tx2gene:q} results/bulk/salmon {output.counts:q} \
              > {log:q} 2>&1
            END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            python scripts/write_provenance.py \
              --event provenance/events/tximport_counts.json \
              --rule tximport_counts --step transcript_to_gene_import --status success \
              --started "$START" --finished "$END" \
              --inputs {input.samples:q} {input.tx2gene:q} \
              --outputs {output.counts:q} \
              --command "Rscript scripts/tximport_counts.R" \
              --environment workflow/envs/deseq2.yaml
            '''


rule count_qc:
    input:
        counts=COUNTS,
        validation="results/metadata/validation.json"
    output:
        "results/qc/sample_qc.tsv"
    conda:
        "../envs/python.yaml"
    log:
        "logs/count_qc.log"
    benchmark:
        "benchmarks/count_qc.tsv"
    shell:
        r'''
        set -euo pipefail
        mkdir -p results/qc provenance/events
        START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/count_qc.py --counts {input.counts:q} --output {output:q} > {log:q} 2>&1
        END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/write_provenance.py \
          --event provenance/events/count_qc.json \
          --rule count_qc --step count_matrix_qc --status success \
          --started "$START" --finished "$END" \
          --inputs {input.counts:q} --outputs {output:q} \
          --command "python scripts/count_qc.py" --environment workflow/envs/python.yaml
        '''


rule qc_gate:
    input:
        qc="results/qc/sample_qc.tsv"
    output:
        tsv="results/qc/qc_gate.tsv",
        json="results/qc/qc_gate_summary.json"
    params:
        fail_lib=config["qc"]["min_library_size_fail"],
        warn_lib=config["qc"]["min_library_size_warn"],
        fail_genes=config["qc"]["min_detected_genes_fail"],
        warn_genes=config["qc"]["min_detected_genes_warn"],
        warn_zero=config["qc"]["max_zero_fraction_warn"]
    conda:
        "../envs/python.yaml"
    log:
        "logs/qc_gate.log"
    benchmark:
        "benchmarks/qc_gate.tsv"
    shell:
        r'''
        set -euo pipefail
        START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/qc_gate.py \
          --input {input.qc:q} --output {output.tsv:q} --summary {output.json:q} \
          --fail-library {params.fail_lib} --warn-library {params.warn_lib} \
          --fail-genes {params.fail_genes} --warn-genes {params.warn_genes} \
          --warn-zero-fraction {params.warn_zero} > {log:q} 2>&1
        END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/write_provenance.py \
          --event provenance/events/qc_gate.json \
          --rule qc_gate --step quality_gate --status success \
          --started "$START" --finished "$END" \
          --inputs {input.qc:q} --outputs {output.tsv:q} {output.json:q} \
          --command "python scripts/qc_gate.py" --environment workflow/envs/python.yaml
        '''


rule deseq2:
    input:
        counts=COUNTS,
        samples=SAMPLE_SHEET,
        gate="results/qc/qc_gate.tsv"
    output:
        full="results/bulk/deseq2/results_full.tsv",
        sig="results/bulk/deseq2/results_significant.tsv",
        norm="results/bulk/deseq2/normalized_counts.tsv",
        pca="results/bulk/deseq2/pca.png",
        volcano="results/bulk/deseq2/volcano.png",
        session="results/bulk/deseq2/sessionInfo.txt"
    params:
        design=config["analysis"]["design_column"],
        ref=config["analysis"]["reference_level"],
        contrast=config["analysis"]["contrast_level"],
        alpha=config["analysis"]["alpha"],
        lfc=config["analysis"]["min_abs_log2fc"]
    conda:
        "../envs/deseq2.yaml"
    log:
        "logs/deseq2.log"
    benchmark:
        "benchmarks/deseq2.tsv"
    shell:
        r'''
        set -euo pipefail
        mkdir -p results/bulk/deseq2 provenance/events
        START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        Rscript scripts/run_deseq2.R \
          {input.counts:q} {input.samples:q} {input.gate:q} \
          {params.design:q} {params.ref:q} {params.contrast:q} \
          {params.alpha} {params.lfc} results/bulk/deseq2 \
          > {log:q} 2>&1
        END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        python scripts/write_provenance.py \
          --event provenance/events/deseq2.json \
          --rule deseq2 --step differential_expression --status success \
          --started "$START" --finished "$END" \
          --inputs {input.counts:q} {input.samples:q} {input.gate:q} \
          --outputs {output.full:q} {output.sig:q} {output.norm:q} {output.pca:q} {output.volcano:q} \
          --command "Rscript scripts/run_deseq2.R {params.design} {params.ref} {params.contrast}" \
          --environment workflow/envs/deseq2.yaml
        '''
