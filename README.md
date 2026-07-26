# RNA-seq Analysis Pipeline

[![CI](https://github.com/gynecoloji/snakemake_RNAseq/actions/workflows/ci.yml/badge.svg)](https://github.com/gynecoloji/snakemake_RNAseq/actions/workflows/ci.yml)
[![DOI](https://zenodo.org/badge/1126053465.svg)](https://doi.org/10.5281/zenodo.21502827)
[![Release](https://img.shields.io/github/v/release/gynecoloji/snakemake_RNAseq?label=release)](https://github.com/gynecoloji/snakemake_RNAseq/releases)
[![Snakemake](https://img.shields.io/badge/snakemake-%E2%89%A58.0-brightgreen)](https://snakemake.github.io)
[![Docker Hub](https://img.shields.io/docker/pulls/gynecoloji/rnaseq-pipeline?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/gynecoloji/rnaseq-pipeline)
[![License: MIT](https://img.shields.io/github/license/gynecoloji/snakemake_RNAseq)](LICENSE)

A comprehensive Snakemake workflow for processing and analyzing paired-end RNA-seq
data from raw reads to a gene-level count matrix and transcript-level abundances,
with an extensive quality-control stage.

## Overview

This pipeline integrates three core components plus an opt-in downstream analysis:

1. **Core RNA-seq stage** (`rna_all` target) - Raw FASTQ → FastQC → fastp trimming →
   HISAT2 spliced alignment → SAMtools filtering/sorting → **featureCounts** gene-level
   quantification → an aggregated **MultiQC** report.
2. **Advanced QC stage** (`qc_all` target) - deeper per-sample quality metrics on the
   aligned reads: Picard insert-size, Qualimap `bamqc` + `rnaseq`, and RSeQC read
   distribution, GC content, and transcript integrity (TIN).
3. **Salmon stage** (`salmon_all` target) - alignment-free transcript quantification
   with both a standard and a decoy-aware index.
4. **Differential expression** (`deg_all` target, *opt-in*) - DESeq2 differential
   expression over the featureCounts matrix plus GO/KEGG enrichment (see
   [Differential Expression](#differential-expression-opt-in-r--deseq2)).
5. **Transcript-level DE** (`dte_all` target, *opt-in*) - edgeR **catchSalmon** on
   bootstrap-quantified Salmon transcripts (`txq_all`), dividing out read-to-transcript
   ambiguity so transcript-level FDR is controlled (legacy naive DESeq2 = `det_all`).

The three core stages live in a single standard-layout `workflow/Snakefile`: one
`snakemake --use-conda` run builds them in dependency order (unified DAG). Run a
subset with the `rna_all`, `qc_all`, or `salmon_all` targets; differential expression
is opt-in (`deg_all`, needs ≥2 conditions). The layout follows the
[Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog/)
conventions, so the workflow can be deployed into another project with
`snakedeploy deploy-workflow` (see [Deploying with snakedeploy](#deploying-with-snakedeploy)).

## Workflow Diagram

The Snakemake rule graph, rendered as a "tube map" with
[snakevision](https://github.com/OpenOmics/snakevision) (includes the opt-in `deg_all`
differential-expression stage):

![RNA-seq rule graph](images/rulegraph.svg)

Regenerate it after changing the rules:

```bash
pip install snakevision   # one-off — not one of the pipeline's conda envs

# Name the targets BEFORE --rulegraph (the flag takes an optional value and would
# otherwise swallow the first target). deg_all is added explicitly since it is not
# part of the default target.
snakemake -s workflow/Snakefile -c 1 -d .test all deg_all --forceall --rulegraph > rulegraph.dot
snakevision -s all rna_all qc_all salmon_all deg_all -o images/rulegraph.svg rulegraph.dot
```

## Features

- **Complete end-to-end processing** of paired-end RNA-seq data
- **Two quantification strategies** — alignment-based gene counts (HISAT2 +
  featureCounts) and alignment-free transcript abundances (Salmon, standard + decoy)
- **On-demand index building** — the HISAT2 and Salmon indexes are built automatically
  from source FASTAs when absent, or bring your own pre-built indexes
- **Comprehensive QC** — FastQC, fastp, MultiQC, Picard insert-size, Qualimap
  `bamqc`/`rnaseq`, and RSeQC (read distribution, GC content, transcript integrity)
- **Configurable filtering** — uniquely-mapped / properly-paired SAMtools filtering
  with tunable flags
- **Conda environment management** (one env per rule) plus a ready-to-run
  **Docker / Apptainer** image
- **Config-schema validation** on every run, and a `config/samples.csv` sample sheet

## Pipeline Components

### 1. Core RNA-seq stage (`rna_all` target)

**Processing steps:**
```
Raw FASTQ → FastQC → fastp
  → HISAT2 spliced alignment
  → SAMtools (properly-paired + uniquely-mapped filter → sort → index → flagstat)
  → featureCounts (gene-level count matrix)
  → MultiQC (aggregated report)
```

**Key features:**
- Quality assessment with FastQC; adapter trimming / quality filtering with fastp
- HISAT2 spliced alignment to the genome index
- Filtering to properly-paired, uniquely-mapped reads (`NH:i:1`), then coordinate
  sort + index; per-sample `flagstat`
- `featureCounts` (paired-end) → `results/featurecounts/featureCount.txt`
  (a genes × samples matrix, ready for DESeq2 / edgeR)
- MultiQC aggregates the FastQC, fastp, and alignment metrics

### 2. Advanced QC stage (`qc_all` target)

Run after the core stage (consumes its filtered BAMs):
- **Insert size** — Picard `CollectInsertSizeMetrics` (fragment-length distribution)
- **Alignment QC** — Qualimap `bamqc` (coverage, mapping quality, genomic origin)
- **RNA-seq QC** — Qualimap `rnaseq` (5′–3′ bias, exonic/intronic/intergenic rates)
  on a name-sorted BAM
- **RSeQC** — read distribution over gene features, GC content, and per-transcript
  integrity number (TIN)

### 3. Salmon stage (`salmon_all` target)

Alignment-free transcript quantification of the trimmed reads against:
- a **standard** Salmon index, and
- a **decoy-aware** index (transcriptome + genome decoys), which reduces spurious
  mapping of genomic reads.

Each writes `quant.sf` per sample (transcript TPM/counts), consumed by the
transcript-level differential-expression stage (`det_all`) below.

### 4. Differential expression (`deg_all` target, opt-in)

Downstream **DESeq2** differential expression over the `featureCounts` gene matrix,
run per non-reference condition level (vs the reference), plus **GO/KEGG**
over-representation on the up/down gene sets. Opt-in — see
[Differential Expression](#differential-expression-opt-in-r--deseq2).

### 5. Transcript-level differential expression (`dte_all` target, opt-in)

Differential **transcript** expression (DTE), done correctly for a high-multiplicity
annotation (GENCODE v36, 231k transcripts). Two opt-in steps:

1. **`txq_all`** — re-quantify with Salmon in bootstrap + bias-aware mode
   (`--numBootstraps 100 --gcBias --seqBias --posBias --rangeFactorizationBins 4`)
   against the decoy-aware index → `results/quants_boot/`.
2. **`dte_all`** — edgeR **`catchSalmon`**: estimates each transcript's
   read-to-transcript-ambiguity (RTA) overdispersion from the bootstraps and divides it
   out, restoring valid negative-binomial inference, then tests the same contrast as
   `deg_all` (glmQLF / TREAT effect-size floor). Emits `dte_results.tsv` (per-transcript
   `logFC` / `FDR` / `Overdispersion`), `significant.tsv`, a gene-level Simes roll-up, and
   MDS / BCV / MA / volcano plots under `results/transcript/dte/{contrast}/`.

```bash
snakemake --use-conda --cores 20 txq_all   # bootstrap quant (prerequisite)
snakemake --use-conda --cores 8  dte_all   # ★ the DTE deliverable
```

> Needs the **`r-transcript`** conda env (edgeR ≥ 4), so **rebuild the container** after
> pulling this (`docker build -t rnaseq-pipeline:latest .`, or
> `apptainer build --fakeroot rnaseq-pipeline.sif apptainer.def`). Best with ≥ 3
> replicates per group.

Why not plain DESeq2 on `NumReads`? Transcript counts carry RTA overdispersion that does
**not** follow the mean–variance trend empirical-Bayes shrinkage assumes, so per-transcript
FDR is not controlled. The older `det_all` target (naive `NumReads` → DESeq2,
`results/transcript_de_naive/`) is kept for continuity but should not be the reported result.

**Interpretation + report (`tx_report_all`, opt-in).** A DE transcript can be DE for two
reasons — its whole gene moved (*gene-driven*) or *it* shifted relative to its siblings
(*isoform-specific*) — and the distinction usually carries the biology. The report joins
each DTE hit to its gene-level DESeq2 result and a **DTU** flag (DRIMSeq → DEXSeq,
`dtu_dexseq_all`) and labels the class:

```bash
snakemake --use-conda --cores 8 dtu_dexseq_all   # DTU (DEXSeq) interpretation layer
snakemake --use-conda --cores 4 tx_report_all    # ★ annotated report (pulls DTE + gene-DGE + DTU)
```

`tx_report_all` builds the whole chain and writes `dte_annotated.tsv` (per transcript:
DTE `logFC`/`FDR`/`Overdispersion` × gene-DGE × DTU `dIF`, with an `isoform_specific` /
`gene_driven` / `gene_and_switch` class) plus `class_summary.tsv` under
`results/transcript/report/{contrast}/`.

## Requirements

- [Snakemake](https://snakemake.readthedocs.io/) ≥8.0
- [Conda](https://docs.conda.io/en/latest/) / [Mamba](https://github.com/mamba-org/mamba) (recommended)
- [Python](https://www.python.org/) ≥3.8
- UNIX-based system (Linux/macOS)

### Software Dependencies
(automatically installed via the per-rule conda environments):
- **FastQC** (raw-read quality control)
- **fastp** (adapter trimming / quality filtering)
- **HISAT2** (spliced alignment; also builds the genome index)
- **SAMtools** (BAM filtering, sorting, indexing, flagstat)
- **featureCounts / Subread** (gene-level quantification)
- **MultiQC** (aggregated QC report)
- **Picard** (insert-size metrics)
- **Qualimap** (`bamqc`, `rnaseq`)
- **RSeQC** (read distribution, GC content, TIN)
- **Salmon** (transcript quantification; also builds the Salmon indexes)

The per-rule environments under `workflow/envs/`
are created automatically on the first `--use-conda` run — you do not build them by hand.

### Reference Files (`ref/`)

Reference data is **not** shipped in the repo (it is `.gitignore`d). Provide the
files matching the `references:` paths in `config/config.yaml` under `ref/` before
running. For the HISAT2 and Salmon indexes you may supply **either** a pre-built
index **or** the source FASTA (the workflow builds the index for you when it is
absent — see [On-demand index building](#on-demand-index-building)).

```
ref/
├── ENSEMBL/genome.{1..8}.ht2          # HISAT2 index (prefix `genome`)   — or build from genome_fasta
├── genome.fa                          # genome FASTA   (source for the HISAT2 index + Salmon decoys)
├── transcripts.fa                     # transcriptome FASTA   (source for the Salmon indexes)
├── gencode.v36.annotation.gtf        # gene annotation (featureCounts, Qualimap)
├── gencode.v36.bed                    # 12-column BED of gene models (RSeQC)   — or build from the GTF
├── picard.jar                         # Picard (insert-size QC)
├── Salmon_index_Grch38/               # standard Salmon index      — or build from transcriptome_fasta
└── Salmon_index_decoy_Grch38/         # decoy-aware Salmon index    — or build from transcriptome_fasta + genome_fasta
```

Provide **either** an index **or** the source FASTA for each build step; only the
files required for the stage(s) you run need to be present. The defaults use
**GENCODE GRCh38, release 36**. Because GENCODE is `chr`-prefixed (`chr1 … chrM`),
the genome, transcriptome, and GTF must **all** be GENCODE — do not mix with ENSEMBL
(whose chromosomes are named `1 … MT`), or featureCounts/alignment will fail to match.

```bash
cd ref

# Genome FASTA (source for the HISAT2 index + Salmon decoys)  ->  ref/genome.fa
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_36/GRCh38.primary_assembly.genome.fa.gz
gunzip GRCh38.primary_assembly.genome.fa.gz && mv GRCh38.primary_assembly.genome.fa genome.fa

# Transcriptome FASTA (source for the Salmon indexes)  ->  ref/transcripts.fa
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_36/gencode.v36.transcripts.fa.gz
gunzip gencode.v36.transcripts.fa.gz && mv gencode.v36.transcripts.fa transcripts.fa

# Gene annotation GTF (featureCounts, Qualimap)  ->  ref/gencode.v36.annotation.gtf
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_36/gencode.v36.annotation.gtf.gz
gunzip gencode.v36.annotation.gtf.gz

# Picard (insert-size QC)  ->  ref/picard.jar
wget -O picard.jar https://github.com/broadinstitute/picard/releases/latest/download/picard.jar

cd ..
```

The RSeQC BED (`gencode.v36.bed`) is a 12-column gene-model BED. It is **built
automatically from the GTF** by the `build_rseqc_bed` rule (UCSC `gtfToGenePred` →
`genePredToBed`, in `workflow/envs/ucsc.yaml`), so it stays `chr`-prefixed and in sync
with your annotation — you only need `references.gtf` present. Provide your own BED12 at
`references.bed` to skip the build.

### On-demand index building

When a HISAT2 or Salmon index — or the RSeQC BED — is absent, the workflow builds it
from the source files and skips the build when a pre-built one is already present (in
that case the source files are never read):

| Rule | Builds from | Produces |
|---|---|---|
| `hisat2_build` | `references.genome_fasta` (+ GTF if `index.hisat2_splice_aware`) | `ref/ENSEMBL/genome.*.ht2` |
| `salmon_index` | `references.transcriptome_fasta` | `ref/Salmon_index_Grch38/` |
| `salmon_decoy_index` | `references.transcriptome_fasta` + `references.genome_fasta` | `ref/Salmon_index_decoy_Grch38/` |
| `build_rseqc_bed` | `references.gtf` | `references.bed` (RSeQC BED12) |

The default HISAT2 build is a plain genome index (~6 GB RAM); HISAT2 still finds
junctions de novo at run time. Set `index.hisat2_splice_aware: true` to build with
`--ss/--exon` extracted from the GTF (higher sensitivity to annotated junctions, but
~160 GB RAM for a human genome).

## Installation

```bash
# Clone the repository
git clone https://github.com/gynecoloji/snakemake_RNAseq.git
cd snakemake_RNAseq

# You need Snakemake + conda/mamba as the driver. The per-rule tool environments
# (workflow/envs/*.yaml) are created automatically on the first `--use-conda` run —
# you do not build them by hand.
mamba create -n rnaseq -c conda-forge -c bioconda snakemake-minimal pandas
conda activate rnaseq
```

> **No local install?** Skip all of the above and use the container image instead —
> see [Container Execution (Docker / Apptainer)](#container-execution-docker--apptainer).

## Configuration

All parameters live in `config/config.yaml`, which ships with working defaults and an
inline comment on each one. The [config schema](workflow/schemas/config.schema.yaml)
is the **single source of truth** for parameter types, defaults, and descriptions:
the workflow validates your config against it on every run (and fills in defaults for
anything you omit), and the
[Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog/?usage=gynecoloji/snakemake_RNAseq)
renders it as a parameter table. See [`config/README.md`](config/README.md) for the
sample sheet and reference-data details.

At minimum, point the reference-file paths at the files you provide:

```yaml
samples_table: "config/samples.csv"                     # sample sheet (sample_id[, condition])
references:
  hisat2_index:       "ref/ENSEMBL/genome"              # HISAT2 index prefix (or provide genome_fasta)
  gtf:                "ref/gencode.v36.annotation.gtf"   # gene annotation (GENCODE, chr-prefixed)
  bed:                "ref/gencode.v36.bed"              # RSeQC 12-column BED (auto-built from the GTF)
  salmon_index:       "ref/Salmon_index_Grch38"         # (or provide transcriptome_fasta)
  genome_fasta:       "ref/genome.fa"                    # source for building the HISAT2 index / decoys
  transcriptome_fasta:"ref/transcripts.fa"              # source for building the Salmon indexes
```

Common adjustments (see `config/config.yaml` for the full annotated file):
- **Strandedness** — `featurecounts.strandedness` (0 unstranded / 1 forward / 2 reverse)
  and `qualimap.protocol`.
- **Restrict chromosomes** — `index.align_chroms` subsets the genome when building the
  HISAT2 index (reads then align only to those chromosomes); `samtools_filter.keep_chroms`
  keeps, after alignment, only reads on the listed chromosomes. Empty = no filtering.
- **Per-rule threads** — the `threads:` section.
- **Low RAM** — lower `threads.*` and `qualimap.java_mem`.

## Data Preparation

### Input Files

Place paired-end FASTQ files in the `data/` directory following this naming
convention (the suffixes are set by `samples.r1_suffix` / `samples.r2_suffix`):

```
data/{sample}_R1_001.fastq.gz
data/{sample}_R2_001.fastq.gz
```

### Sample Information

List your samples in `config/samples.csv`:

```csv
sample_id,condition
Control_1,control
Control_2,control
Treatment_1,treatment
Treatment_2,treatment
```

`sample_id` is required (reads are read from `data/<sample_id>_R1_001.fastq.gz` /
`_R2_001.fastq.gz`); the optional `condition` column is informational and not consumed
by any rule.

## Running the Pipeline

The workflow is the standard-layout `workflow/Snakefile`. A single run builds all
three stages in dependency order (unified DAG); use the `rna_all` / `qc_all` /
`salmon_all` targets to run just one.

### Dry Run

```bash
# Check the whole workflow
snakemake -s workflow/Snakefile -n

# Or check a single stage
snakemake -s workflow/Snakefile -n rna_all
```

### Local Execution

```bash
# Run everything (core → QC → Salmon) in one dependency-ordered DAG
snakemake -s workflow/Snakefile --use-conda --cores 20

# Or run a single stage
snakemake -s workflow/Snakefile --use-conda --cores 20 rna_all      # core RNA-seq only
snakemake -s workflow/Snakefile --use-conda --cores 20 qc_all       # advanced QC only
snakemake -s workflow/Snakefile --use-conda --cores 20 salmon_all   # Salmon only
```

`qc_all` and `salmon_all` automatically build their core-stage prerequisites.

### Differential Expression (opt-in, R / DESeq2)

A downstream differential-expression + enrichment stage over the `featureCounts`
matrix. It is **not** part of the default target (it needs ≥2 levels in the
`condition` column of `config/samples.csv`); request it explicitly:

```bash
snakemake -s workflow/Snakefile --use-conda --cores 8 deg_all
```

One contrast is run per non-reference condition level (vs `deg.reference`), written to
`results/deg/<level>_vs_<reference>/`:

- **DESeq2** — `deseq2_results.tsv` (apeglm-shrunk log2FC), `significant.tsv`
  (padj < `deg.padj` and |log2FC| ≥ `deg.lfc`), `vst_counts.tsv`, and figures
  (`pca.png`, `sample_distances.png`, `dispersion.png`, `ma_plot.png`, `volcano.png`,
  `top_genes_heatmap.png`).
- **Enrichment** (`enrichment/`) — GO (`deg.go_ont`) and, if `deg.run_kegg`, KEGG
  over-representation on the up/down gene sets (`GO_<up|down>.tsv/.png`,
  `KEGG_<up|down>.tsv/.png`, `enrichment_summary.tsv`). GENCODE `gene_id`s are
  version-stripped and mapped to ENTREZ via `deg.orgdb` (`org.Hs.eg.db` by default).

Config lives under the `deg:` section (`condition_col`, `reference`, `padj`, `lfc`,
`top_genes`, `go_ont`, `run_kegg`, `orgdb`, `kegg_organism`). The stage runs in its own
`workflow/envs/r-deg.yaml` (DESeq2 + clusterProfiler), created automatically by
`--use-conda`. **KEGG needs network access at runtime** (it queries the KEGG API); it
is skipped gracefully (recorded as 0 terms) if unavailable.

### Container Execution (Docker / Apptainer)

One prebuilt image covers the whole workflow — you install nothing except Docker or
Apptainer. The image ships Snakemake + the pre-built per-rule conda envs (at
`/opt/wf-conda`) and its entrypoint is
`snakemake --use-conda --conda-frontend mamba --conda-prefix /opt/wf-conda`, so
anything after the image name goes straight to `snakemake`.

```bash
# Docker — the Docker Hub repo hosts a SIF (ORAS artifact), not a runnable Docker
# image, so build the Docker image locally from the Dockerfile:
docker compose build                          # → rnaseq-pipeline:latest

# Apptainer / Singularity (HPC) — pull the published SIF (ORAS) directly, or build it
# locally (apptainer build --fakeroot rnaseq-pipeline.sif apptainer.def):
apptainer pull rnaseq-pipeline.sif oras://docker.io/gynecoloji/rnaseq-pipeline:latest
```

Genomes/FASTQs are **not** baked into the image; you mount your project directory at
run time (see [`DOCKER.md`](DOCKER.md) for the exact `ref/` and `data/` files expected).

**Docker** — run from your project directory (which holds `workflow/`, `config/`,
`ref/`, `data/`):

```bash
docker run --rm -v "$(pwd)":/workflow -e HOME=/tmp --user "$(id -u):$(id -g)" \
    rnaseq-pipeline:latest -s workflow/Snakefile --cores 16
# or just one stage: append the rna_all / qc_all / salmon_all target
```

Convenience wrappers `docker compose` and `./run_pipeline.sh` are also provided:

```bash
./run_pipeline.sh --cores 16                     # everything
docker compose run --rm rnaseq --cores 16 rna_all
```

**Apptainer / Singularity (HPC)** — Apptainer auto-mounts `$HOME`, `/tmp`, and the
current directory, and runs as you (no `--user` needed). Load the module first if your
cluster uses one (`module load apptainer`):

```bash
# One-time: pull the published SIF (ORAS artifact) from Docker Hub
apptainer pull rnaseq-pipeline.sif oras://docker.io/gynecoloji/rnaseq-pipeline:latest

# Run from your project directory — the entrypoint IS snakemake, so just pass its args:
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 16            # everything
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 16 rna_all    # just one stage
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 1  -n         # dry run
```

On clusters without Docker you can also build the image natively from
[`apptainer.def`](apptainer.def): `apptainer build --fakeroot rnaseq-pipeline.sif apptainer.def`.
Notes: bind references living outside the project dir with `--bind`; if Apptainer
reports a read-only error writing to `/opt/wf-conda`, add `--writable-tmpfs`.

### Cluster Execution

For execution on a SLURM cluster (from your project directory, via the container):

```bash
#!/bin/bash
#SBATCH --cpus-per-task=20
#SBATCH --mem=64G
#SBATCH --time=24:00:00

module load apptainer   # or: module load singularity
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores ${SLURM_CPUS_PER_TASK} -p
```

Match `--cores` to your allocation (`${SLURM_CPUS_PER_TASK}`); Snakemake resumes from
where it stopped, so a timed-out job can simply be resubmitted.

## Deploying with snakedeploy

This repository follows the [Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog/)
standardized structure (`workflow/Snakefile`, `config/`, `workflow/rules|envs|schemas/`,
and `.snakemake-workflow-catalog.yml`), so it can be deployed into another project
without cloning it by hand:

```bash
pip install snakedeploy
# In an empty target project directory:
snakedeploy deploy-workflow https://github.com/gynecoloji/snakemake_RNAseq . --tag main
```

This writes `workflow/Snakefile` (which `module`-imports this workflow) and a
`config/` copy for you to edit. You can also import selected rules into your own
`Snakefile` with Snakemake's module system:

```python
module rnaseq:
    snakefile:
        github("gynecoloji/snakemake_RNAseq", path="workflow/Snakefile", tag="main")
    config:
        config

use rule * from rnaseq
```

Then supply your own `config/config.yaml`, `config/samples.csv`, and `ref/` reference
data (see [Configuration](#configuration)) and run with `snakemake --use-conda`.

## Pipeline Details

### 1. Quality Control and Preprocessing

- **FastQC** — quality assessment of raw reads.
- **fastp** — adapter trimming and quality filtering. Default flags
  (`--detect_adapter_for_pe -g -p`) auto-detect paired-end adapters, trim poly-G
  tails, and enable overrepresentation analysis; override with `fastp.extra` in
  `config/config.yaml`.

### 2. Alignment and Filtering

- **HISAT2** — spliced alignment to the genome index (default library params
  `-q --phred33 -X 3000 -I 0 --no-discordant --no-mixed`, via `hisat2.extra`).
- **SAMtools** — keep properly-paired reads (`-f 0x2`), drop secondary alignments
  (`-F 0x100`), and retain uniquely-mapped reads (`NH:i:1`); coordinate sort, index,
  and `flagstat`. All three filters are configurable under `samtools_filter`.

### 3. Gene-level Quantification

- **featureCounts** (Subread) — paired-end counting over the GTF
  (`-t exon -g gene_id`, `--countReadPairs -p -M`, strandedness from
  `featurecounts.strandedness`) → `results/featurecounts/featureCount.txt`.

### 4. Aggregated QC

- **MultiQC** — aggregates FastQC, fastp, and alignment metrics into
  `results/multiqc_report.html`.

### 5. Advanced QC (`qc_all` target)

- **Picard** `CollectInsertSizeMetrics` — fragment-length distribution + histogram.
- **Qualimap** `bamqc` (alignment QC) and `rnaseq` (RNA-seq-specific QC, on a
  name-sorted BAM); JVM heap from `qualimap.java_mem`, library from `qualimap.protocol`.
- **RSeQC** — `read_distribution.py` (feature distribution), `read_GC.py` (GC content),
  and `tin.py` (per-transcript integrity number).

### 6. Transcript Quantification (`salmon_all` target)

- **Salmon** `quant` against the standard and decoy-aware indexes
  (`-l A --validateMappings`, via `salmon.lib_type` / `salmon.extra`) →
  `results/quants/` and `results/quants_decoy/`.

## Output Files

The pipeline generates the following output directories:

```
results/
├── fastqc/raw/            # FastQC reports (raw reads)
├── trimmed/               # fastp-trimmed reads + HTML/JSON reports
├── hisat2/                # HISAT2 SAM + alignment summary
├── samtools/              # filtered/sorted BAM + index + flagstat summary
├── featurecounts/
│   └── featureCount.txt   # ⭐ gene-level count matrix (genes × samples)
├── picard/                # insert-size metrics + histogram
├── qualimap_bamqc/        # Qualimap alignment QC (per sample)
├── samtools_byname/       # name-sorted BAM (input to Qualimap rnaseq)
├── qualimap_rnaseq/       # Qualimap RNA-seq QC (per sample)
├── rseqc/                 # read distribution, GC content, TIN (per sample)
├── quants/                # Salmon standard quantification (quant.sf per sample)
├── quants_decoy/          # Salmon decoy-aware quantification (quant.sf per sample)
├── multiqc_report.html    # 🎯 aggregated QC report — start here
└── multiqc_data/          # data behind the MultiQC report
```

### Directory Structure
```
snakemake_RNAseq/                      # Snakemake Workflow Catalog layout
├── config/
│   ├── config.yaml         # workflow parameters
│   ├── samples.csv         # sample sheet (sample_id[, condition])
│   └── README.md           # configuration reference
├── workflow/
│   ├── Snakefile           # entry point (unified DAG; targets: rna_all, qc_all, salmon_all)
│   ├── rules/              # common.smk, rnaseq.smk, qc.smk, salmon.smk
│   ├── envs/               # per-rule conda environment files
│   └── schemas/            # config.schema.yaml (validated every run)
├── .snakemake-workflow-catalog.yml    # catalog metadata (enables snakedeploy)
├── data/                   # raw FASTQ files (you provide)
├── ref/                    # reference genome/annotation/indexes (you provide)
├── create_envs.smk         # build-time helper (pre-bakes the conda envs into the image)
├── Dockerfile, docker-compose.yml, apptainer.def, run_pipeline.sh, DOCKER.md
├── results/                # all pipeline outputs (detailed above)
└── logs/                   # per-rule logs
```

## Troubleshooting

### Common Issues

1. **Low alignment rate**
   - Check reference genome/index compatibility and version.
   - Verify adapter trimming in the fastp step; examine FastQC for quality issues.
   - Check for sample contamination or incorrect library prep.

2. **Low fraction of assigned reads (featureCounts)**
   - Usually a **strandedness** mismatch — set `featurecounts.strandedness`
     (0/1/2) to match your library, and `qualimap.protocol` accordingly.
   - Confirm the GTF matches the genome build the index was made against.

3. **High duplication rate**
   - Indicates low library complexity; may need more input RNA or fewer PCR cycles.
   - Check the FastQC / fastp duplication estimates.

4. **Low TIN / 3′ bias (RSeQC / Qualimap rnaseq)**
   - Suggests RNA degradation; check RIN and consider a 3′-bias-aware analysis.

5. **Out-of-memory during index build or Qualimap**
   - The splice-aware HISAT2 build needs ~160 GB RAM — use the default plain index,
     or build on a high-memory node. Lower `qualimap.java_mem` for large BAMs.

### Performance Optimization
- Adjust thread counts (`threads:` in `config/config.yaml`) to your resources.
- Use fast/SSD storage for `data/`, `ref/`, and `results/` when possible.
- HISAT2 alignment and Salmon quantification are the heavy steps.

### Log Files

Per-rule logs are stored under `logs/` (e.g. `logs/fastqc/`, `logs/fastp/`,
`logs/hisat2/`, `logs/samtools/`, `logs/featurecounts/`, `logs/multiqc/`,
`logs/picard/`, `logs/qualimap/`, `logs/rseqc/`, `logs/salmon/`,
`logs/hisat2_build/`, `logs/salmon_index/`).

## Citation

If you use this workflow in your research, please cite it. Use the **"Cite this
repository"** button on the GitHub repository page (generated from
[`CITATION.cff`](CITATION.cff)).

**Please also cite the individual tools used:**
- **Snakemake**: Mölder, F. et al. (2021). Sustainable data analysis with Snakemake. F1000Research, 10, 33.
- **HISAT2**: Kim, D. et al. (2019). Graph-based genome alignment and genotyping with HISAT2 and HISAT-genotype. Nature Biotechnology, 37, 907-915.
- **Salmon**: Patro, R. et al. (2017). Salmon provides fast and bias-aware quantification of transcript expression. Nature Methods, 14, 417-419.
- **featureCounts (Subread)**: Liao, Y. et al. (2014). featureCounts: an efficient general purpose program for assigning sequence reads to genomic features. Bioinformatics, 30(7), 923-930.
- **FastQC**: Andrews, S. (2010). FastQC: a quality control tool for high throughput sequence data.
- **fastp**: Chen, S. et al. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics, 34(17), i884-i890.
- **MultiQC**: Ewels, P. et al. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics, 32(19), 3047-3048.
- **RSeQC**: Wang, L. et al. (2012). RSeQC: quality control of RNA-seq experiments. Bioinformatics, 28(16), 2184-2185.
- **Qualimap**: Okonechnikov, K. et al. (2016). Qualimap 2: advanced multi-sample quality control for high-throughput sequencing data. Bioinformatics, 32(2), 292-294.
- **SAMtools**: Li, H. et al. (2009). The Sequence Alignment/Map format and SAMtools. Bioinformatics, 25(16), 2078-2079.
- **Picard**: Broad Institute. Picard Toolkit. http://broadinstitute.github.io/picard/

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

**Author**: gynecoloji  
**Project Repository**: [https://github.com/gynecoloji/snakemake_RNAseq](https://github.com/gynecoloji/snakemake_RNAseq)

For questions, issues, or feature requests, please:
1. Check the existing [Issues](https://github.com/gynecoloji/snakemake_RNAseq/issues) on GitHub
2. Submit a new issue with detailed information about your problem
3. Include relevant log files and system information for troubleshooting

## Acknowledgments

This pipeline integrates tools developed by the bioinformatics community. Special
thanks to the Snakemake team, the Bioconda/Conda-Forge maintainers, and the
developers of all the integrated tools.

---

**Note**: This pipeline ships with defaults for human genome analysis (GRCh38, GENCODE
release 36) but can be adapted for other organisms/releases by updating the reference
files and parameters in `config/config.yaml`.
