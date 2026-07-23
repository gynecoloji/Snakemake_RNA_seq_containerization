# Downstream differential expression (DESeq2) + GO/KEGG enrichment. OPT-IN stage:
# not part of the default `all` target (it needs >=2 levels in the samples.csv
# condition column). Request it explicitly:
#
#   snakemake --use-conda --cores 8 deg_all
#
# One contrast is run per non-reference condition level (vs deg.reference), written
# to results/deg/<level>_vs_<reference>/.


rule deg_all:
    input:
        expand(f"{DEG_DIR}/{{contrast}}/deseq2_results.tsv", contrast=DEG_CONTRASTS),
        expand(
            f"{DEG_DIR}/{{contrast}}/enrichment/enrichment_summary.tsv",
            contrast=DEG_CONTRASTS,
        ),


# DESeq2 differential expression for one contrast: results table, significant
# subset, VST counts, and PCA / sample-distance / dispersion / MA / volcano /
# top-gene-heatmap figures.
rule deg:
    input:
        counts=f"{RESULTS}/featurecounts/featureCount.txt",
        samples=config["samples_table"],
    output:
        results=f"{DEG_DIR}/{{contrast}}/deseq2_results.tsv",
        significant=f"{DEG_DIR}/{{contrast}}/significant.tsv",
        vst=f"{DEG_DIR}/{{contrast}}/vst_counts.tsv",
        pca=f"{DEG_DIR}/{{contrast}}/pca.png",
        ma=f"{DEG_DIR}/{{contrast}}/ma_plot.png",
        volcano=f"{DEG_DIR}/{{contrast}}/volcano.png",
        heatmap=f"{DEG_DIR}/{{contrast}}/top_genes_heatmap.png",
    log:
        f"{LOGS}/deg/{{contrast}}.log",
    params:
        condition_col=DEG_CONDITION_COL,
        level=lambda w: DEG_CONTRAST_LEVEL[w.contrast],
        reference=DEG_REFERENCE,
        padj=DEG_PADJ,
        lfc=DEG_LFC,
        top_genes=DEG_TOP_GENES,
        outdir=lambda w: f"{DEG_DIR}/{w.contrast}",
    conda:
        "../envs/r-deg.yaml"
    script:
        "../scripts/deg.R"


# GO + KEGG over-representation on the up/down DE genes of one contrast.
rule deg_enrich:
    input:
        res=f"{DEG_DIR}/{{contrast}}/deseq2_results.tsv",
    output:
        summary=f"{DEG_DIR}/{{contrast}}/enrichment/enrichment_summary.tsv",
    log:
        f"{LOGS}/deg/{{contrast}}_enrich.log",
    params:
        orgdb=DEG_ORGDB,
        go_ont=DEG_GO_ONT,
        run_kegg=DEG_RUN_KEGG,
        kegg_organism=DEG_KEGG_ORG,
        padj=DEG_PADJ,
        lfc=DEG_LFC,
        outdir=lambda w: f"{DEG_DIR}/{w.contrast}/enrichment",
    conda:
        "../envs/r-deg.yaml"
    script:
        "../scripts/deg_enrich.R"
