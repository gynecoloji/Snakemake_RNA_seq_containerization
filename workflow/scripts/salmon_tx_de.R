#!/usr/bin/env Rscript
# Transcript-level count matrix + differential expression from Salmon quant.sf files.
#
# Reads per-sample Salmon quant.sf (GENCODE transcriptome), assembles transcript
# count (NumReads) and TPM matrices, then runs DESeq2 on the rounded estimated
# counts (low-count filtered) for one two-group contrast, with apeglm LFC shrinkage.
#
# Deliberately uses base R + DESeq2 only (no tximport), so it runs in the existing
# container. At the transcript level the tximport average-length offset matters far
# less than at gene level; NumReads-based DESeq2 is a sound, common approach for DTE.
#
# Usage (key=value args; runnable standalone or from a Snakemake `shell:` rule):
#   Rscript salmon_tx_de.R \
#       quant_root=results/quants_decoy samples=config/samples.csv \
#       outdir=results/transcript_de/salmon_decoy \
#       condition_col=condition reference=control [level=NICD3] \
#       padj=0.05 lfc=1 top_n=30 min_count=10 [quant_suffix=_quant]

suppressPackageStartupMessages({
  library(DESeq2)
})

## ---- args -------------------------------------------------------------------
argv <- commandArgs(trailingOnly = TRUE)
kv <- list()
for (a in argv) {
  if (!grepl("=", a)) next
  k <- sub("=.*$", "", a); v <- sub("^[^=]*=", "", a); kv[[k]] <- v
}
getarg <- function(name, default = NULL, required = FALSE) {
  if (!is.null(kv[[name]]) && nzchar(kv[[name]])) return(kv[[name]])
  if (required) stop(sprintf("missing required arg: %s", name))
  default
}

quant_root   <- getarg("quant_root", required = TRUE)
samples_csv  <- getarg("samples",    required = TRUE)
outdir       <- getarg("outdir",     required = TRUE)
cond_col     <- getarg("condition_col", "condition")
reference    <- getarg("reference",  required = TRUE)
level_arg    <- getarg("level", NA)
padj_cut     <- as.numeric(getarg("padj", "0.05"))
lfc_cut      <- as.numeric(getarg("lfc", "1"))
top_n        <- as.integer(getarg("top_n", "30"))
min_count    <- as.numeric(getarg("min_count", "10"))
quant_suffix <- getarg("quant_suffix", "_quant")

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(outdir, "plots"), showWarnings = FALSE)
message(sprintf("[salmon_tx_de] quant_root=%s  outdir=%s  ref=%s", quant_root, outdir, reference))

## ---- sample sheet -----------------------------------------------------------
samples <- read.csv(samples_csv, stringsAsFactors = FALSE)
# accept sample_id/sample and condition_col
id_col <- if ("sample_id" %in% names(samples)) "sample_id" else names(samples)[1]
if (!cond_col %in% names(samples)) stop(sprintf("condition column '%s' not in %s", cond_col, samples_csv))
sample_ids <- samples[[id_col]]
conditions <- samples[[cond_col]]
if (!(reference %in% conditions)) stop(sprintf("reference '%s' not present in %s", reference, cond_col))

# level = the non-reference group of the contrast
if (is.na(level_arg)) {
  others <- setdiff(unique(conditions), reference)
  if (length(others) != 1)
    stop(sprintf("condition has levels {%s}; pass level=<group> to pick the contrast",
                 paste(unique(conditions), collapse = ", ")))
  level_arg <- others
}
message(sprintf("[salmon_tx_de] contrast: %s_vs_%s  (n=%d samples)", level_arg, reference, length(sample_ids)))

## ---- read quant.sf ----------------------------------------------------------
quant_files <- file.path(quant_root, paste0(sample_ids, quant_suffix), "quant.sf")
missing <- quant_files[!file.exists(quant_files)]
if (length(missing)) stop("missing quant.sf:\n  ", paste(missing, collapse = "\n  "))

reads_list <- vector("list", length(sample_ids))
tpm_list   <- vector("list", length(sample_ids))
names(reads_list) <- names(tpm_list) <- sample_ids
tx_names <- NULL
for (i in seq_along(sample_ids)) {
  q <- read.delim(quant_files[i], stringsAsFactors = FALSE,
                  colClasses = c(Name = "character", Length = "integer",
                                 EffectiveLength = "numeric", TPM = "numeric",
                                 NumReads = "numeric"))
  reads_list[[i]] <- setNames(q$NumReads, q$Name)
  tpm_list[[i]]   <- setNames(q$TPM, q$Name)
  if (is.null(tx_names)) tx_names <- q$Name
  message(sprintf("  read %-16s %d transcripts", sample_ids[i], nrow(q)))
}

# assemble matrices by Name (robust to any ordering differences)
counts <- vapply(reads_list, function(v) v[tx_names], numeric(length(tx_names)))
tpm    <- vapply(tpm_list,   function(v) v[tx_names], numeric(length(tx_names)))
rownames(counts) <- rownames(tpm) <- tx_names
colnames(counts) <- colnames(tpm) <- sample_ids

## ---- annotation from GENCODE pipe-delimited Name ----------------------------
# ENST|ENSG|OTTHUMG|OTTHUMT|tx_name|gene_symbol|length|biotype|
f <- strsplit(tx_names, "|", fixed = TRUE)
pick <- function(idx) vapply(f, function(x) if (length(x) >= idx) x[idx] else NA_character_, character(1))
tx_info <- data.frame(
  transcript_id = pick(1),
  gene_id       = pick(2),
  transcript    = pick(5),
  gene_symbol   = pick(6),
  biotype       = pick(8),
  row.names     = tx_names,
  stringsAsFactors = FALSE
)

## ---- write full count + TPM matrices ---------------------------------------
mat_out <- function(mat, path) {
  df <- data.frame(transcript_id = tx_info$transcript_id,
                   gene_symbol   = tx_info$gene_symbol,
                   biotype       = tx_info$biotype,
                   mat, check.names = FALSE, row.names = NULL)
  write.table(df, path, sep = "\t", quote = FALSE, row.names = FALSE)
}
mat_out(round(counts, 3), file.path(outdir, "transcript_counts.tsv"))
mat_out(round(tpm, 4),    file.path(outdir, "transcript_tpm.tsv"))
message(sprintf("[salmon_tx_de] wrote count + TPM matrices (%d transcripts)", nrow(counts)))

## ---- filter low-count transcripts ------------------------------------------
keep <- rowSums(round(counts)) >= min_count
message(sprintf("[salmon_tx_de] expressed transcripts (rowSum>=%g): %d of %d",
                min_count, sum(keep), length(keep)))
cts <- round(counts[keep, , drop = FALSE])
mode(cts) <- "integer"

## ---- DESeq2 -----------------------------------------------------------------
coldata <- data.frame(row.names = sample_ids,
                      condition = factor(conditions, levels = c(reference,
                                          setdiff(unique(conditions), reference))))
dds <- DESeqDataSetFromMatrix(cts, coldata, design = ~ condition)
dds <- DESeq(dds)
coef <- paste0("condition_", level_arg, "_vs_", reference)
if (!coef %in% resultsNames(dds))
  stop(sprintf("coef '%s' not in resultsNames: %s", coef, paste(resultsNames(dds), collapse = ", ")))
res <- lfcShrink(dds, coef = coef, type = "apeglm")
res <- as.data.frame(res)
res$transcript_id <- tx_info[rownames(res), "transcript_id"]
res$gene_symbol   <- tx_info[rownames(res), "gene_symbol"]
res$biotype       <- tx_info[rownames(res), "biotype"]
res <- res[order(res$padj), ]
res <- res[, c("transcript_id", "gene_symbol", "biotype",
               "baseMean", "log2FoldChange", "lfcSE", "pvalue", "padj")]

write.table(res, file.path(outdir, "transcript_de_results.tsv"),
            sep = "\t", quote = FALSE, row.names = FALSE)
sig <- res[!is.na(res$padj) & res$padj < padj_cut & abs(res$log2FoldChange) > lfc_cut, ]
write.table(sig, file.path(outdir, "significant.tsv"),
            sep = "\t", quote = FALSE, row.names = FALSE)
message(sprintf("[salmon_tx_de] DE done: %d significant (padj<%g & |log2FC|>%g)",
                nrow(sig), padj_cut, lfc_cut))

## ---- transform for PCA / heatmap -------------------------------------------
vsd <- tryCatch(
  if (nrow(cts) >= 1000) vst(dds, blind = FALSE) else varianceStabilizingTransformation(dds, blind = FALSE),
  error = function(e) { message("  vst failed (", conditionMessage(e), "); using rlog-free normTransform"); normTransform(dds) }
)

## ---- plots (never let a plotting error kill the tables) --------------------
png_plot <- function(path, expr, w = 1600, h = 1300) {
  tryCatch({ png(path, width = w, height = h, res = 200); on.exit(dev.off()); eval.parent(expr) },
           error = function(e) message("  plot skipped (", basename(path), "): ", conditionMessage(e)))
}
pd <- file.path(outdir, "plots")

png_plot(file.path(pd, "pca.png"), quote({
  suppressPackageStartupMessages(library(ggplot2))
  p <- plotPCA(vsd, intgroup = "condition") + theme_bw() +
       ggtitle(sprintf("Transcript-level PCA (%s)", basename(outdir)))
  print(p)
}))

png_plot(file.path(pd, "sample_distances.png"), quote({
  suppressPackageStartupMessages(library(pheatmap))
  d <- as.matrix(dist(t(assay(vsd))))
  pheatmap(d, clustering_distance_rows = as.dist(d),
           clustering_distance_cols = as.dist(d), main = "Sample distances (VST)")
}))

png_plot(file.path(pd, "ma_plot.png"), quote({
  DESeq2::plotMA(dds, ylim = c(-5, 5), main = sprintf("MA: %s_vs_%s", level_arg, reference))
}))

png_plot(file.path(pd, "volcano.png"), quote({
  suppressPackageStartupMessages(library(ggplot2))
  v <- res
  v$sig <- !is.na(v$padj) & v$padj < padj_cut & abs(v$log2FoldChange) > lfc_cut
  print(ggplot(v, aes(log2FoldChange, -log10(pmax(padj, 1e-300)), color = sig)) +
        geom_point(alpha = 0.5, size = 0.7) +
        scale_color_manual(values = c(`FALSE` = "grey70", `TRUE` = "firebrick")) +
        geom_vline(xintercept = c(-lfc_cut, lfc_cut), linetype = 2) +
        geom_hline(yintercept = -log10(padj_cut), linetype = 2) +
        labs(x = "log2 fold change", y = "-log10 padj",
             title = sprintf("Transcript volcano: %s_vs_%s", level_arg, reference)) +
        theme_bw() + theme(legend.position = "none"))
}))

png_plot(file.path(pd, "top_transcripts_heatmap.png"), quote({
  suppressPackageStartupMessages(library(pheatmap))
  top <- head(rownames(res[!is.na(res$padj), ]), top_n)
  top <- top[top %in% rownames(assay(vsd))]
  if (length(top) >= 2) {
    m <- assay(vsd)[top, , drop = FALSE]
    lab <- tx_info[top, "transcript"]; lab[is.na(lab)] <- top[is.na(lab)]
    rownames(m) <- lab
    pheatmap(m, scale = "row", show_rownames = TRUE,
             annotation_col = data.frame(condition = coldata$condition, row.names = rownames(coldata)),
             main = sprintf("Top %d transcripts by padj", length(top)))
  }
}))

message(sprintf("[salmon_tx_de] complete -> %s", outdir))
