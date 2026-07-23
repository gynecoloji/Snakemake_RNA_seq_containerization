# Shared setup for the RNA-seq (rnaseq.smk), QC (qc.smk) and Salmon (salmon.smk)
# rule files: config validation, the sample table, config-derived shortcuts and
# output-directory constants. Included first by workflow/Snakefile.

import re
import pandas as pd
from snakemake.utils import validate

# ── Config validation (also fills defaults) ─────────────────────────────
# Path is relative to this file (workflow/rules/).
validate(config, "../schemas/config.schema.yaml")

# ── Samples (from the sample sheet) ─────────────────────────────────────
samples_df = pd.read_csv(config["samples_table"])
SAMPLES = samples_df["sample_id"].astype(str).tolist()

# ── Config shortcuts ────────────────────────────────────────────────────
DATA = config["paths"]["data_dir"]
RESULTS = config["paths"]["results_dir"]
LOGS = config["paths"]["logs_dir"]

R1_SUFFIX = config["samples"]["r1_suffix"]
R2_SUFFIX = config["samples"]["r2_suffix"]

HISAT2_INDEX = config["references"]["hisat2_index"]
GTF = config["references"]["gtf"]
BED = config["references"]["bed"]
PICARD_JAR = config["references"]["picard_jar"]
SALMON_INDEX = config["references"]["salmon_index"]
SALMON_DECOY_INDEX = config["references"]["salmon_decoy_index"]

# Source FASTAs + build options for the on-demand index-building rules.
GENOME_FASTA = config["references"].get("genome_fasta", "ref/genome.fa")
TRANSCRIPTOME_FASTA = config["references"].get("transcriptome_fasta", "ref/transcripts.fa")
HISAT2_SPLICE_AWARE = config.get("index", {}).get("hisat2_splice_aware", False)
SALMON_KMER = config.get("index", {}).get("salmon_kmer", 31)
ALIGN_CHROMS = config.get("index", {}).get("align_chroms", []) or []
KEEP_CHROMS = config.get("samtools_filter", {}).get("keep_chroms", []) or []

JAVA_MEM = config["qualimap"]["java_mem"]
PROTOCOL = config["qualimap"]["protocol"]

# ── Differential expression (opt-in stage; see rules/deg.smk) ────────────
DEG_DIR = f"{RESULTS}/deg"
DEG_CFG = config.get("deg", {})
DEG_CONDITION_COL = DEG_CFG.get("condition_col", "condition")
DEG_REFERENCE = str(DEG_CFG.get("reference", ""))
DEG_PADJ = DEG_CFG.get("padj", 0.05)
DEG_LFC = DEG_CFG.get("lfc", 1.0)
DEG_TOP_GENES = DEG_CFG.get("top_genes", 30)
DEG_ORGDB = DEG_CFG.get("orgdb", "org.Hs.eg.db")
DEG_GO_ONT = DEG_CFG.get("go_ont", "ALL")
DEG_RUN_KEGG = DEG_CFG.get("run_kegg", True)
DEG_KEGG_ORG = DEG_CFG.get("kegg_organism", "hsa")

# One contrast per non-reference condition level (each vs DEG_REFERENCE).
if DEG_CONDITION_COL in samples_df.columns:
    _deg_levels = [
        lvl
        for lvl in dict.fromkeys(samples_df[DEG_CONDITION_COL].astype(str))
        if lvl != DEG_REFERENCE
    ]
else:
    _deg_levels = []
DEG_CONTRAST_LEVEL = {f"{lvl}_vs_{DEG_REFERENCE}": lvl for lvl in _deg_levels}
DEG_CONTRASTS = list(DEG_CONTRAST_LEVEL.keys())


# Constrain wildcards to known values so no stray files are matched.
wildcard_constraints:
    sample="|".join(re.escape(s) for s in SAMPLES) if SAMPLES else "a^",
    contrast="|".join(re.escape(c) for c in DEG_CONTRASTS) if DEG_CONTRASTS else "a^",
