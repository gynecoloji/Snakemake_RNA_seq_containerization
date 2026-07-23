# GO + KEGG over-representation for the up/down DE genes of one contrast, using
# clusterProfiler + an organism OrgDb. GENCODE gene ids (ENSG with a version suffix)
# are stripped and mapped to ENTREZ. Driven by the Snakemake `script:` directive.
#
# enrichKEGG downloads from the KEGG API at runtime; it degrades gracefully (skipped,
# recorded as 0 terms) if no network is available.

log <- file(snakemake@log[[1]], open = "wt")
sink(log, type = "message")
sink(log, type = "output")

suppressMessages({
  library(clusterProfiler)
  library(enrichplot)
  library(ggplot2)
})
orgdb_name <- snakemake@params[["orgdb"]]
suppressMessages(library(orgdb_name, character.only = TRUE))
orgdb <- get(orgdb_name)

res_file <- snakemake@input[["res"]]
outdir <- snakemake@params[["outdir"]]
go_ont <- snakemake@params[["go_ont"]]
run_kegg <- isTRUE(as.logical(snakemake@params[["run_kegg"]]))
kegg_org <- snakemake@params[["kegg_organism"]]
padj_thr <- as.numeric(snakemake@params[["padj"]])
lfc_thr <- as.numeric(snakemake@params[["lfc"]])
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

res <- read.delim(res_file, check.names = FALSE)
res$ensembl <- sub("\\..*$", "", res$gene_id)  # strip GENCODE version suffix

map <- tryCatch(
  bitr(unique(res$ensembl), fromType = "ENSEMBL", toType = "ENTREZID", OrgDb = orgdb),
  error = function(e) data.frame(ENSEMBL = character(), ENTREZID = character())
)
res <- merge(res, map, by.x = "ensembl", by.y = "ENSEMBL")
universe <- unique(res$ENTREZID)

pick <- function(up) {
  keep <- !is.na(res$padj) & res$padj < padj_thr &
    (if (up) res$log2FoldChange >= lfc_thr else res$log2FoldChange <= -lfc_thr)
  unique(res$ENTREZID[keep])
}
sets <- list(up = pick(TRUE), down = pick(FALSE))

summary_rows <- list()
add_summary <- function(db, direction, n) {
  summary_rows[[paste(db, direction)]] <<-
    data.frame(database = db, direction = direction, n_terms = n, stringsAsFactors = FALSE)
}

for (direction in names(sets)) {
  genes <- sets[[direction]]
  message(direction, ": ", length(genes), " mapped DE genes")
  if (length(genes) < 5) {
    add_summary("GO", direction, 0)
    if (run_kegg) add_summary("KEGG", direction, 0)
    next
  }

  ego <- tryCatch(
    enrichGO(genes, OrgDb = orgdb, keyType = "ENTREZID", ont = go_ont,
             universe = universe, pAdjustMethod = "BH", qvalueCutoff = 0.2,
             readable = TRUE),
    error = function(e) { message("enrichGO failed: ", conditionMessage(e)); NULL }
  )
  n_go <- if (!is.null(ego)) nrow(as.data.frame(ego)) else 0
  add_summary("GO", direction, n_go)
  if (n_go > 0) {
    write.table(as.data.frame(ego), file.path(outdir, paste0("GO_", direction, ".tsv")),
                sep = "\t", quote = FALSE, row.names = FALSE)
    ggsave(file.path(outdir, paste0("GO_", direction, ".png")),
           dotplot(ego, showCategory = 20) + ggtitle(paste("GO —", direction)),
           width = 8, height = 7, dpi = 150)
  }

  if (run_kegg) {
    ek <- tryCatch(
      enrichKEGG(genes, organism = kegg_org, universe = universe,
                 pAdjustMethod = "BH", qvalueCutoff = 0.2),
      error = function(e) { message("enrichKEGG failed (needs network?): ",
                                    conditionMessage(e)); NULL }
    )
    n_kegg <- if (!is.null(ek)) nrow(as.data.frame(ek)) else 0
    add_summary("KEGG", direction, n_kegg)
    if (n_kegg > 0) {
      write.table(as.data.frame(ek), file.path(outdir, paste0("KEGG_", direction, ".tsv")),
                  sep = "\t", quote = FALSE, row.names = FALSE)
      ggsave(file.path(outdir, paste0("KEGG_", direction, ".png")),
             dotplot(ek, showCategory = 20) + ggtitle(paste("KEGG —", direction)),
             width = 8, height = 7, dpi = 150)
    }
  }
}

summ <- if (length(summary_rows)) {
  do.call(rbind, summary_rows)
} else {
  data.frame(database = character(), direction = character(), n_terms = integer())
}
write.table(summ, file.path(outdir, "enrichment_summary.tsv"),
            sep = "\t", quote = FALSE, row.names = FALSE)
message("deg_enrich.R done")
