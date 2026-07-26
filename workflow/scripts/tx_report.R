# Annotated DTE report (T8) — the final transcript-analysis output.
# Joins, per contrast: T2 DTE (logFC/FDR/Overdispersion) x gene-level DESeq2 DGE
# x T4 DTU (gene q-value + per-transcript dIF), and assigns an interpretation class
# that says WHY a transcript is DE: gene-driven vs isoform-specific (see design doc 1.4).
log <- file(snakemake@log[[1]], open = "wt"); sink(log, type = "message"); sink(log, type = "output")

dte      <- read.delim(snakemake@input[["dte"]], stringsAsFactors = FALSE)
dtu_gene <- read.delim(snakemake@input[["dtu_gene"]], stringsAsFactors = FALSE)
frac     <- read.delim(snakemake@input[["fractions"]], stringsAsFactors = FALSE)
gene_dge <- read.delim(snakemake@input[["gene_dge"]], stringsAsFactors = FALSE)
padj_thr <- as.numeric(snakemake@params[["padj"]])
dif_cut  <- as.numeric(snakemake@params[["dif_cutoff"]])
outdir   <- snakemake@params[["outdir"]]; dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

ann <- dte  # one row per transcript; already carries GeneID, Symbol, logFC, FDR, Overdispersion

# Gene IDs can differ only by trailing .version between sources; match on the
# stripped ID so a version bump can't silently break the join.
strip <- function(x) sub("\\.[0-9]+$", "", x)
ann_g <- strip(ann$GeneID)

gi <- match(ann_g, strip(gene_dge$gene_id))
ann$gene_log2FC <- gene_dge$log2FoldChange[gi]
ann$gene_padj   <- gene_dge$padj[gi]

di <- match(ann_g, strip(dtu_gene$GeneID))
ann$dtu_qval <- dtu_gene$dtu_qval[di]

fi <- match(ann$transcript_name, frac$feature_id)
ann$dIF <- frac$dIF[fi]

## ---- significance flags ----------------------------------------------------
ann$dte_sig  <- !is.na(ann$FDR)       & ann$FDR       < padj_thr
ann$gene_sig <- !is.na(ann$gene_padj) & ann$gene_padj < padj_thr
ann$dtu_sig  <- !is.na(ann$dtu_qval)  & ann$dtu_qval  < padj_thr &
                !is.na(ann$dIF)       & abs(ann$dIF)  >= dif_cut

## ---- interpretation class (design doc 1.4) --------------------------------
ann$class <- with(ann, ifelse(
  dte_sig & !gene_sig &  dtu_sig, "isoform_specific",
  ifelse(dte_sig &  gene_sig & !dtu_sig, "gene_driven",
  ifelse(dte_sig &  gene_sig &  dtu_sig, "gene_and_switch",
  ifelse(dte_sig & !gene_sig & !dtu_sig, "transcript_only_unclassified", "not_DTE")))))

# order: DTE hits first, by FDR
ann <- ann[order(!ann$dte_sig, ann$FDR), ]
write.table(ann, snakemake@output[["annotated"]], sep = "\t", quote = FALSE, row.names = FALSE)

## ---- headline: class counts over the DTE-significant set -------------------
classes <- c("isoform_specific", "gene_driven", "gene_and_switch", "transcript_only_unclassified")
cls <- factor(ann$class[ann$dte_sig], levels = classes)
summary_df <- data.frame(class = classes, n = as.integer(table(cls)))
write.table(summary_df, snakemake@output[["summary"]], sep = "\t", quote = FALSE, row.names = FALSE)

message("DTE-significant transcripts: ", sum(ann$dte_sig))
for (i in seq_len(nrow(summary_df)))
  message(sprintf("  %-30s %d", summary_df$class[i], summary_df$n[i]))
message("gene-DGE join rate: ", round(mean(!is.na(ann$gene_padj)) * 100), "%  ",
        "| DTU join rate: ", round(mean(!is.na(ann$dtu_qval)) * 100), "%")
