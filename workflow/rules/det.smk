# Transcript-level differential expression from Salmon.
#
# Assembles per-transcript count (NumReads) + TPM matrices from Salmon quant.sf
# and runs DESeq2 (apeglm-shrunk) for the same contrast as the gene-level `deg`
# stage, for both the plain and decoy-aware Salmon quants. Opt-in target `det_all`.

import os

# NOTE: superseded by transcript_de.smk (edgeR catchSalmon, DTE). Kept for continuity;
# its NumReads->DESeq2 test does not control transcript-level FDR (RTA overdispersion),
# so its output is written under transcript_de_naive/ and should not be the reported result.
DET_DIR = f"{RESULTS}/transcript_de_naive"
TX_DE_SCRIPT = os.path.join(workflow.basedir, "scripts", "salmon_tx_de.R")

# quant-source label -> salmon output root (produced by rules salmon_quant / salmon_decoy_quant)
QUANT_ROOTS = {
    "salmon":       f"{RESULTS}/quants",
    "salmon_decoy": f"{RESULTS}/quants_decoy",
}
DET_SOURCES = config.get("transcript_de", {}).get("quant_sources", list(QUANT_ROOTS))
DET_MIN_COUNT = config.get("transcript_de", {}).get("min_count", 10)


rule det_all:
    input:
        expand(f"{DET_DIR}/{{qt}}/significant.tsv", qt=DET_SOURCES),


rule det:
    input:
        quants=lambda wc: expand(f"{QUANT_ROOTS[wc.qt]}/{{sample}}_quant/quant.sf",
                                  sample=SAMPLES),
        samples=config["samples_table"],
    output:
        counts=f"{DET_DIR}/{{qt}}/transcript_counts.tsv",
        tpm=f"{DET_DIR}/{{qt}}/transcript_tpm.tsv",
        results=f"{DET_DIR}/{{qt}}/transcript_de_results.tsv",
        significant=f"{DET_DIR}/{{qt}}/significant.tsv",
    params:
        script=TX_DE_SCRIPT,
        quant_root=lambda wc: QUANT_ROOTS[wc.qt],
        outdir=lambda wc: f"{DET_DIR}/{wc.qt}",
        condition_col=DEG_CONDITION_COL,
        reference=DEG_REFERENCE,
        padj=DEG_PADJ,
        lfc=DEG_LFC,
        top_n=DEG_TOP_GENES,
        min_count=DET_MIN_COUNT,
    log:
        f"{LOGS}/transcript_de/{{qt}}.log",
    conda:
        "../envs/r-deg.yaml"
    wildcard_constraints:
        qt="|".join(QUANT_ROOTS),
    shell:
        "Rscript {params.script} "
        "quant_root={params.quant_root} samples={input.samples} "
        "outdir={params.outdir} condition_col={params.condition_col} "
        "reference={params.reference} padj={params.padj} lfc={params.lfc} "
        "top_n={params.top_n} min_count={params.min_count} &> {log}"
