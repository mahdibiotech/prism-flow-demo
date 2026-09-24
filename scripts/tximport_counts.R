#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(tximport)
  library(readr)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4) {
  stop("Usage: tximport_counts.R samples.tsv tx2gene.tsv salmon_dir output.tsv")
}

samples_path <- args[[1]]
tx2gene_path <- args[[2]]
salmon_dir <- args[[3]]
out_path <- args[[4]]

samples <- read_tsv(samples_path, show_col_types = FALSE)
tx2gene <- read_tsv(tx2gene_path, show_col_types = FALSE)
if (ncol(tx2gene) < 2) stop("tx2gene requires at least two columns: transcript_id, gene_id")
colnames(tx2gene)[1:2] <- c("TXNAME", "GENEID")

files <- file.path(salmon_dir, samples$sample_id, "quant.sf")
names(files) <- samples$sample_id
missing <- files[!file.exists(files)]
if (length(missing) > 0) stop(paste("Missing Salmon quant files:", paste(missing, collapse = ", ")))

txi <- tximport(files, type = "salmon", tx2gene = tx2gene[, 1:2], countsFromAbundance = "lengthScaledTPM")
counts <- round(txi$counts)
out <- data.frame(gene_id = rownames(counts), counts, check.names = FALSE)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
write_tsv(out, out_path)
