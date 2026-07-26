# Differential transcript USAGE (DTU) — interpretation layer for the DTE report (T8),
# NOT the primary deliverable. DRIMSeq filtering -> DEXSeq test on dtuScaledTPM counts.
# countsFromAbundance="dtuScaledTPM" is mandatory HERE (and only here): it keeps
# within-gene isoform proportions unbiased, which is what DTU tests.
log <- file(snakemake@log[[1]], open = "wt"); sink(log, type = "message"); sink(log, type = "output")
suppressMessages({ library(tximport); library(DRIMSeq); library(DEXSeq) })

samples   <- read.csv(snakemake@input[["samples"]], stringsAsFactors = FALSE)
cond_col  <- snakemake@params[["condition_col"]]
level     <- snakemake@params[["level"]]
reference <- snakemake@params[["reference"]]
covars    <- unlist(snakemake@params[["covariates"]])
outdir    <- snakemake@params[["outdir"]]; dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
mfe <- as.numeric(snakemake@params[["min_feature_expr"]])
mfp <- as.numeric(snakemake@params[["min_feature_prop"]])
mge <- as.numeric(snakemake@params[["min_gene_expr"]])

# Subset to the two levels of THIS contrast (mirrors deg.R / tx_dte_edger.R).
samples   <- samples[samples[[cond_col]] %in% c(level, reference), , drop = FALSE]
condition <- factor(samples[[cond_col]], levels = c(reference, level))
files <- file.path(snakemake@params[["quant_root"]], paste0(samples$sample_id, "_quant"), "quant.sf")
names(files) <- samples$sample_id
stopifnot(all(file.exists(files)))
message("DTU contrast: ", level, " vs ", reference, "  n = ", paste(table(condition), collapse = " / "))

t2g <- read.delim(snakemake@input[["tx2gene"]], stringsAsFactors = FALSE)

## ---- import as dtuScaledTPM (proportions unbiased) -------------------------
# dtuScaledTPM scales within-gene, so tximport needs the tx->gene map (keys = Salmon Name).
txi <- tximport(files, type = "salmon", txOut = TRUE, countsFromAbundance = "dtuScaledTPM",
                tx2gene = t2g[, c("TXNAME", "GENEID")])
cts <- txi$counts[rowSums(txi$counts) > 0, , drop = FALSE]
gid <- t2g$GENEID[match(rownames(cts), t2g$TXNAME)]
ok  <- !is.na(gid) & gid != ""
cts <- cts[ok, , drop = FALSE]; gid <- gid[ok]
cdf <- data.frame(gene_id = gid, feature_id = rownames(cts), cts, check.names = FALSE)

samps <- data.frame(sample_id = samples$sample_id, condition = condition)
d <- dmDSdata(counts = cdf, samples = samps)

## ---- DRIMSeq filter (the proportion filter does most of the work) ----------
n <- nrow(samps); n.small <- min(table(samps$condition))
d <- dmFilter(d, min_samps_feature_expr = n.small, min_feature_expr = mfe,
                 min_samps_feature_prop = n.small, min_feature_prop = mfp,
                 min_samps_gene_expr    = n,       min_gene_expr    = mge)
cd <- counts(d)
message("after dmFilter: ", nrow(cd), " transcripts / ", length(unique(cd$gene_id)), " genes")

## ---- DEXSeq: covariates as :exon interactions; `sample` saturates main effects ----
cov_terms  <- if (length(covars)) paste0(" + ", paste0(covars, ":exon", collapse = " + ")) else ""
sampleData <- data.frame(condition = samps$condition, row.names = as.character(samps$sample_id))
for (cv in covars) sampleData[[cv]] <- samples[[cv]][match(rownames(sampleData), samples$sample_id)]
countData <- round(as.matrix(cd[, as.character(samps$sample_id)]))

dxd <- DEXSeqDataSet(countData = countData, sampleData = sampleData,
                     design = as.formula(paste0("~ sample + exon", cov_terms, " + condition:exon")),
                     featureID = cd$feature_id, groupID = cd$gene_id)
dxd <- estimateSizeFactors(dxd)
dxd <- estimateDispersions(dxd, quiet = TRUE)
dxd <- testForDEU(dxd, reducedModel = as.formula(paste0("~ sample + exon", cov_terms)))
dxr <- DEXSeqResults(dxd, independentFiltering = FALSE)   # dmFilter already filtered

## ---- per-gene DTU q-value --------------------------------------------------
gq_vec <- perGeneQValue(dxr)
gq <- data.frame(GeneID = names(gq_vec), dtu_qval = as.numeric(gq_vec),
                 Symbol = t2g$GENESYMBOL[match(names(gq_vec), t2g$GENEID)])
write.table(gq[order(gq$dtu_qval), c("GeneID", "Symbol", "dtu_qval")],
            snakemake@output[["gene"]], sep = "\t", quote = FALSE, row.names = FALSE)

## ---- observed isoform fractions -> dIF (level - reference) -----------------
cnt <- as.matrix(cd[, as.character(samps$sample_id)]); rownames(cnt) <- cd$feature_id
gtot <- rowsum(cnt, cd$gene_id)
prop <- cnt / gtot[match(cd$gene_id, rownames(gtot)), , drop = FALSE]
ref_ids <- as.character(samps$sample_id[samps$condition == reference])
lvl_ids <- as.character(samps$sample_id[samps$condition == level])
frac <- data.frame(feature_id    = cd$feature_id,
                   TranscriptID  = t2g$TXID[match(cd$feature_id, t2g$TXNAME)],
                   GeneID        = cd$gene_id,
                   Symbol        = t2g$GENESYMBOL[match(cd$feature_id, t2g$TXNAME)],
                   mean_prop_ref   = rowMeans(prop[, ref_ids, drop = FALSE]),
                   mean_prop_level = rowMeans(prop[, lvl_ids, drop = FALSE]),
                   dIF = rowMeans(prop[, lvl_ids, drop = FALSE]) - rowMeans(prop[, ref_ids, drop = FALSE]))
write.table(frac[order(-abs(frac$dIF)), ], snakemake@output[["fractions"]],
            sep = "\t", quote = FALSE, row.names = FALSE)
message("DTU done: genes tested ", nrow(gq), "; DTU genes q<0.05: ", sum(gq$dtu_qval < 0.05, na.rm = TRUE))
