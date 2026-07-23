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


# Constrain {sample} to the sheet so no stray files are matched.
wildcard_constraints:
    sample="|".join(re.escape(s) for s in SAMPLES) if SAMPLES else "a^",
