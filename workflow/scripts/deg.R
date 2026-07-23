# DESeq2 differential expression + exploratory plots for one contrast
# (<level> vs <reference>). Driven by the Snakemake `script:` directive, so it reads
# its inputs/params from the injected `snakemake` object.

log <- file(snakemake@log[[1]], open = "wt")
sink(log, type = "message")
sink(log, type = "output")

suppressMessages({
  library(DESeq2)
  library(ggplot2)
  library(pheatmap)
  library(RColorBrewer)
})

counts_file <- snakemake@input[["counts"]]
samples_file <- snakemake@input[["samples"]]
cond_col <- snakemake@params[["condition_col"]]
level <- snakemake@params[["level"]]
reference <- snakemake@params[["reference"]]
padj_thr <- as.numeric(snakemake@params[["padj"]])
lfc_thr <- as.numeric(snakemake@params[["lfc"]])
top_n <- as.integer(snakemake@params[["top_genes"]])
outdir <- snakemake@params[["outdir"]]
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# ---- featureCounts matrix -> integer counts keyed by sample_id ----
fc <- read.delim(counts_file, comment.char = "#", check.names = FALSE)
rownames(fc) <- fc[["Geneid"]]
cnt <- fc[, 7:ncol(fc), drop = FALSE]  # cols 1-6 are Geneid/Chr/Start/End/Strand/Length
colnames(cnt) <- sub("\\.sorted\\.filtered\\.bam$", "", basename(colnames(cnt)))
mat <- as.matrix(cnt)
mode(mat) <- "integer"

# ---- sample sheet -> colData (aligned to the matrix columns) ----
samples <- read.csv(samples_file, stringsAsFactors = FALSE)
rownames(samples) <- samples[["sample_id"]]
missing <- setdiff(colnames(mat), rownames(samples))
if (length(missing)) {
  stop("count columns not found in samples.csv: ", paste(missing, collapse = ", "))
}
samples <- samples[colnames(mat), , drop = FALSE]
cond <- relevel(factor(samples[[cond_col]]), ref = reference)
coldata <- data.frame(condition = cond, row.names = colnames(mat))

# ---- DESeq2 ----
dds <- DESeqDataSetFromMatrix(countData = mat, colData = coldata, design = ~condition)
dds <- dds[rowSums(counts(dds)) >= 10, ]
dds <- DESeq(dds)

coef <- paste0("condition_", level, "_vs_", reference)
if (!coef %in% resultsNames(dds)) {
  stop("contrast coefficient '", coef, "' not in resultsNames(): ",
       paste(resultsNames(dds), collapse = ", "))
}
res <- lfcShrink(dds, coef = coef, type = "apeglm")

resdf <- as.data.frame(res)
resdf <- data.frame(gene_id = rownames(resdf), resdf, row.names = NULL, check.names = FALSE)
resdf <- resdf[order(resdf$padj), ]
write.table(resdf, file.path(outdir, "deseq2_results.tsv"),
            sep = "\t", quote = FALSE, row.names = FALSE)

sig <- subset(resdf, !is.na(padj) & padj < padj_thr & abs(log2FoldChange) >= lfc_thr)
write.table(sig, file.path(outdir, "significant.tsv"),
            sep = "\t", quote = FALSE, row.names = FALSE)

# ---- VST-normalized counts ----
vsd <- tryCatch(vst(dds, blind = FALSE),
                error = function(e) varianceStabilizingTransformation(dds, blind = FALSE))
vm <- assay(vsd)
write.table(data.frame(gene_id = rownames(vm), vm, check.names = FALSE),
            file.path(outdir, "vst_counts.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

# ---- exploratory + result plots ----
ggsave(file.path(outdir, "pca.png"),
       plotPCA(vsd, intgroup = "condition") + theme_bw(),
       width = 6, height = 5, dpi = 150)

dists <- dist(t(vm))
png(file.path(outdir, "sample_distances.png"), width = 1000, height = 850, res = 150)
pheatmap(as.matrix(dists), clustering_distance_rows = dists,
         clustering_distance_cols = dists,
         col = colorRampPalette(rev(brewer.pal(9, "Blues")))(255))
dev.off()

png(file.path(outdir, "dispersion.png"), width = 950, height = 750, res = 150)
plotDispEsts(dds)
dev.off()

png(file.path(outdir, "ma_plot.png"), width = 950, height = 750, res = 150)
DESeq2::plotMA(res, ylim = c(-5, 5))
dev.off()

resdf$significant <- with(resdf, !is.na(padj) & padj < padj_thr & abs(log2FoldChange) >= lfc_thr)
volcano <- ggplot(resdf, aes(log2FoldChange, -log10(padj))) +
  geom_point(aes(colour = significant), alpha = 0.5, size = 0.8) +
  scale_colour_manual(values = c(`FALSE` = "grey70", `TRUE` = "firebrick")) +
  geom_vline(xintercept = c(-lfc_thr, lfc_thr), linetype = "dashed") +
  geom_hline(yintercept = -log10(padj_thr), linetype = "dashed") +
  theme_bw() +
  labs(title = paste(level, "vs", reference), colour = "significant")
ggsave(file.path(outdir, "volcano.png"), volcano, width = 6, height = 5, dpi = 150)

top <- head(resdf$gene_id[order(resdf$padj)], top_n)
top <- top[top %in% rownames(vm)]
png(file.path(outdir, "top_genes_heatmap.png"), width = 950, height = 1050, res = 150)
if (length(top) >= 2) {
  pheatmap(vm[top, , drop = FALSE], scale = "row", annotation_col = coldata,
           show_rownames = TRUE, fontsize_row = 6)
} else {
  plot.new()
  text(0.5, 0.5, "not enough genes for heatmap")
}
dev.off()

message("deg.R done: ", level, " vs ", reference)
