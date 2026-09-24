#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(DESeq2)
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(tibble)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 9) {
  stop(paste(
    "Usage: run_deseq2.R counts.tsv samples.tsv qc_gate.tsv",
    "design_column reference_level contrast_level alpha min_abs_log2fc outdir"
  ))
}

counts_path <- args[[1]]
samples_path <- args[[2]]
qc_path <- args[[3]]
design_col <- args[[4]]
reference_level <- args[[5]]
contrast_level <- args[[6]]
alpha <- as.numeric(args[[7]])
min_abs_lfc <- as.numeric(args[[8]])
outdir <- args[[9]]

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

counts_df <- read_tsv(counts_path, show_col_types = FALSE)
samples <- read_tsv(samples_path, show_col_types = FALSE)
qc <- read_tsv(qc_path, show_col_types = FALSE)

if (!"gene_id" %in% names(counts_df)) stop("counts.tsv must contain gene_id")
if (!design_col %in% names(samples)) stop(paste("Missing design column:", design_col))

keep_samples <- qc %>% filter(qc_status != "FAIL") %>% pull(sample_id)
samples <- samples %>% filter(sample_id %in% keep_samples)
if (nrow(samples) < 4) stop("Fewer than four non-FAIL samples remain; refusing DE analysis")

missing_counts <- setdiff(samples$sample_id, names(counts_df))
if (length(missing_counts) > 0) stop(paste("Samples absent from counts:", paste(missing_counts, collapse=", ")))

count_mat <- as.matrix(counts_df[, samples$sample_id])
rownames(count_mat) <- counts_df$gene_id
storage.mode(count_mat) <- "integer"

samples[[design_col]] <- factor(samples[[design_col]])
if (!reference_level %in% levels(samples[[design_col]])) stop("Reference level absent from metadata")
if (!contrast_level %in% levels(samples[[design_col]])) stop("Contrast level absent from metadata")
samples[[design_col]] <- relevel(samples[[design_col]], ref = reference_level)

coldata <- as.data.frame(samples)
rownames(coldata) <- coldata$sample_id

dds <- DESeqDataSetFromMatrix(
  countData = count_mat,
  colData = coldata,
  design = as.formula(paste0("~", design_col))
)
dds <- dds[rowSums(counts(dds)) >= 10, ]
dds <- DESeq(dds, quiet = TRUE)

res <- results(dds, contrast = c(design_col, contrast_level, reference_level), alpha = alpha)
res_df <- as.data.frame(res) %>% rownames_to_column("gene_id") %>% arrange(padj)
write_tsv(res_df, file.path(outdir, "results_full.tsv"))

sig <- res_df %>%
  filter(!is.na(padj), padj <= alpha, !is.na(log2FoldChange), abs(log2FoldChange) >= min_abs_lfc)
write_tsv(sig, file.path(outdir, "results_significant.tsv"))

norm <- counts(dds, normalized = TRUE) %>% as.data.frame() %>% rownames_to_column("gene_id")
write_tsv(norm, file.path(outdir, "normalized_counts.tsv"))

vsd <- vst(dds, blind = FALSE)
pca_df <- plotPCA(vsd, intgroup = design_col, returnData = TRUE)
percent_var <- round(100 * attr(pca_df, "percentVar"))

p1 <- ggplot(pca_df, aes(x = PC1, y = PC2, label = name)) +
  geom_point(aes_string(color = design_col), size = 3) +
  geom_text(vjust = -0.8, size = 3, show.legend = FALSE) +
  xlab(paste0("PC1: ", percent_var[1], "% variance")) +
  ylab(paste0("PC2: ", percent_var[2], "% variance")) +
  theme_bw() +
  ggtitle("PCA — variance stabilised counts")
ggsave(file.path(outdir, "pca.png"), p1, width = 7, height = 5, dpi = 160)

volcano <- res_df %>%
  mutate(
    neglog10padj = -log10(pmax(padj, .Machine$double.xmin)),
    significant = !is.na(padj) & padj <= alpha & abs(log2FoldChange) >= min_abs_lfc
  )

p2 <- ggplot(volcano, aes(x = log2FoldChange, y = neglog10padj)) +
  geom_point(aes(color = significant), alpha = 0.65, size = 1.4) +
  geom_vline(xintercept = c(-min_abs_lfc, min_abs_lfc), linetype = "dashed") +
  geom_hline(yintercept = -log10(alpha), linetype = "dashed") +
  theme_bw() +
  labs(
    title = paste0("Volcano — ", contrast_level, " vs ", reference_level),
    x = "log2 fold change",
    y = "-log10 adjusted p-value"
  )
ggsave(file.path(outdir, "volcano.png"), p2, width = 7, height = 5, dpi = 160)

sink(file.path(outdir, "sessionInfo.txt"))
print(sessionInfo())
sink()

message("DESeq2 completed: ", nrow(res_df), " tested genes; ", nrow(sig), " significant genes")
