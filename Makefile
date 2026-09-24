SHELL := /bin/bash
SNAKEFILE := workflow/Snakefile

.PHONY: demo dryrun test clean graph

demo:
	snakemake --snakefile $(SNAKEFILE) --cores 2 --use-conda --printshellcmds

dryrun:
	snakemake --snakefile $(SNAKEFILE) --cores 1 --use-conda --dry-run --printshellcmds

test:
	python -m unittest discover -s tests -v

graph:
	snakemake --snakefile $(SNAKEFILE) --dag | dot -Tpng > docs/dag.png

clean:
	rm -rf results/* provenance/events provenance/execution_trace.tsv logs benchmarks .snakemake
