# Differential transcript EXPRESSION via edgeR, after dividing out
# read-to-transcript-ambiguity (RTA) overdispersion estimated from Salmon bootstraps.
# Invoked by rule dte_catchsalmon (transcript_de.smk) via the Snakemake `script:` directive.
log <- file(snakemake@log[[1]], open = "wt"); sink(log, type = "message"); sink(log, type = "output")
suppressMessages({ library(edgeR); library(ggplot2) })

samples   <- read.csv(snakemake@input[["samples"]], stringsAsFactors = FALSE)
cond_col  <- snakemake@params[["condition_col"]]
level     <- snakemake@params[["level"]]
reference <- snakemake@params[["reference"]]
covars    <- unlist(snakemake@params[["covariates"]])
padj_thr  <- as.numeric(snakemake@params[["padj"]])
lfc_thr   <- as.numeric(snakemake@params[["lfc"]])
outdir    <- snakemake@params[["outdir"]]
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# Subset to the two levels of THIS contrast (mirrors deg.R).
samples <- samples[samples[[cond_col]] %in% c(level, reference), , drop = FALSE]
paths   <- file.path(snakemake@params[["quant_root"]], paste0(samples$sample_id, "_quant"))
stopifnot(all(file.exists(file.path(paths, "quant.sf"))))
grp <- factor(samples[[cond_col]], levels = c(reference, level))
message("contrast: ", level, " vs ", reference, "  n = ", paste(table(grp), collapse = " / "))

## ---- 1. quantify uncertainty, then divide it out ---------------------------
catch <- catchSalmon(paths)
colnames(catch$counts) <- samples$sample_id
scaled <- catch$counts / catch$annotation$Overdispersion

od <- catch$annotation$Overdispersion
message(sprintf("RTA overdispersion: median %.2f  IQR %.2f-%.2f  max %.1f",
                median(od), quantile(od, .25), quantile(od, .75), max(od)))

## ---- 2. annotate (keys are Salmon's full pipe Name; see Finding 3) ---------
t2g <- read.delim(snakemake@input[["tx2gene"]], stringsAsFactors = FALSE)
ann <- catch$annotation
idx <- match(rownames(ann), t2g$TXNAME)
if (all(is.na(idx))) stop("tx2gene keys do not match quant.sf rownames -- see Finding 3")
ann$TranscriptID <- t2g$TXID[idx]; ann$GeneID <- t2g$GENEID[idx]
ann$Symbol       <- t2g$GENESYMBOL[idx]; ann$Biotype <- t2g$BIOTYPE[idx]

## ---- 3. standard edgeR, now valid -----------------------------------------
y <- DGEList(counts = scaled, genes = ann, group = grp)
keep <- filterByExpr(y, group = grp)
message("transcripts kept by filterByExpr: ", sum(keep), " / ", length(keep))
y <- y[keep, , keep.lib.sizes = FALSE]
y <- normLibSizes(y)

# Covariates first, condition last -> coef = ncol(design) is always the contrast.
dat    <- data.frame(grp = grp, samples[, covars, drop = FALSE])
design <- model.matrix(as.formula(paste("~", paste(c(covars, "grp"), collapse = " + "))), data = dat)

y   <- estimateDisp(y, design, robust = TRUE)
fit <- glmQLFit(y, design, robust = TRUE)

# TREAT tests |log2FC| > threshold rather than != 0 -- an effect-size floor
# inside the inference rather than a post-hoc filter. (Braced so `else` parses
# from a file: `res <- if (...) A` is otherwise complete at the newline.)
res <- if (lfc_thr > 0) {
  glmTreat(fit, coef = ncol(design), lfc = lfc_thr)
} else {
  glmQLFTest(fit, coef = ncol(design))
}

tt <- topTags(res, n = Inf)$table
tt <- data.frame(transcript_name = rownames(tt), tt, row.names = NULL)

## ---- 4. outputs ------------------------------------------------------------
write.table(tt, snakemake@output[["results"]], sep = "\t", quote = FALSE, row.names = FALSE)
sig <- tt[tt$FDR < padj_thr, , drop = FALSE]
message("significant transcripts (FDR < ", padj_thr, "): ", nrow(sig))
write.table(sig, snakemake@output[["significant"]], sep = "\t", quote = FALSE, row.names = FALSE)

# Optional gene-level roll-up: "which genes have >=1 DE transcript", Simes-adjusted.
# Use this ONLY when making gene-level statements; the transcript FDR above is the
# correct error rate for transcript-level claims (see section 1.1 of the design doc).
simes <- do.call(rbind, lapply(split(tt, tt$GeneID), function(g) {
  p <- sort(g$PValue); n <- length(p)
  data.frame(GeneID = g$GeneID[1], Symbol = g$Symbol[1], n_transcripts = n,
             simes_p = min(p * n / seq_len(n)),
             top_transcript = g$TranscriptID[which.min(g$PValue)],
             top_logFC = g$logFC[which.min(g$PValue)])
}))
simes$simes_FDR <- p.adjust(simes$simes_p, method = "BH")
write.table(simes[order(simes$simes_p), ], snakemake@output[["gene_simes"]],
            sep = "\t", quote = FALSE, row.names = FALSE)

write.table(data.frame(transcript_name = rownames(catch$annotation),
                       transcript_id = t2g$TXID[match(rownames(catch$annotation), t2g$TXNAME)],
                       overdispersion = od, length = catch$annotation$Length),
            snakemake@output[["overdisp"]], sep = "\t", quote = FALSE, row.names = FALSE)
write.table(data.frame(transcript_name = rownames(y$counts), cpm(y, log = TRUE)),
            snakemake@output[["counts"]], sep = "\t", quote = FALSE, row.names = FALSE)

png(snakemake@output[["mds"]], 900, 800); plotMDS(y, col = as.integer(grp), labels = colnames(y)); dev.off()
png(snakemake@output[["bcv"]], 900, 800); plotBCV(y); dev.off()
png(snakemake@output[["md"]],  900, 800); plotMD(res); abline(h = c(-lfc_thr, lfc_thr), col = "blue"); dev.off()

tt$sig <- tt$FDR < padj_thr
p <- ggplot(tt, aes(logFC, -log10(PValue), colour = sig)) +
  geom_point(size = .6, alpha = .5) +
  scale_colour_manual(values = c(`FALSE` = "grey70", `TRUE` = "firebrick")) +
  labs(x = "log2 fold change", y = "-log10 P", title = paste(level, "vs", reference)) +
  theme_bw()
ggsave(snakemake@output[["volcano"]], p, width = 7, height = 6, dpi = 150)
