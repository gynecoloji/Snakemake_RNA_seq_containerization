# Configuration

This workflow is configured through two files in this directory:

- `config.yaml` — all workflow parameters (nested by section)
- `samples.csv` — the sample sheet

plus reference data you place under `ref/` (see the top-level `README.md`).

## Sample sheet (`config/samples.csv`)

CSV with one row per sample:

| column      | required | description                                                                      |
|-------------|----------|----------------------------------------------------------------------------------|
| `sample_id` | yes      | Sample name. Reads must be `data/<sample_id>_R1_001.fastq.gz` / `_R2_001.fastq.gz`. |
| `condition` | no       | Free-text label (informational; not consumed by any rule).                       |

The `_R1_001.fastq.gz` / `_R2_001.fastq.gz` suffixes are set by `samples.r1_suffix`
/ `samples.r2_suffix` in `config.yaml`.

## Parameters (`config/config.yaml`)

Every parameter — type, default, description — is defined in the config schema,
[`workflow/schemas/config.schema.yaml`](../workflow/schemas/config.schema.yaml).
The workflow validates `config.yaml` against it on every run (and fills in
defaults for anything omitted), and the Snakemake Workflow Catalog renders it as
a parameter table. `config.yaml` ships with working defaults and an inline
comment on each parameter.

## Reference data

Genomes, indexes and large annotations are not tracked in git. Place them under
`ref/` matching the `references:` paths in `config.yaml`. See the top-level
`README.md` (Reference Files) for exact files and how to obtain them.

The HISAT2 and Salmon indexes are **built automatically** when absent: provide a
genome FASTA (`references.genome_fasta`) and a transcriptome FASTA
(`references.transcriptome_fasta`), and the `hisat2_build` / `salmon_index` /
`salmon_decoy_index` rules create them on the first run. Drop in a pre-built index
instead and the build is skipped (the source FASTAs are then never read).
Index-build options live under the `index:` section (`hisat2_splice_aware`,
`salmon_kmer`).

## Chromosome selection

Two optional filters restrict which chromosomes are used, both off by default (an
empty list means no filtering):

- `index.align_chroms` — restrict the genome to these chromosomes when **building** the
  HISAT2 index, so reads only ever align to them (only affects the auto-built index).
- `samtools_filter.keep_chroms` — **after** alignment, keep only reads whose chromosome
  is in this list (works with any index — bring-your-own or auto-built).

Chromosome names must match your reference (ENSEMBL: `1 2 … X Y MT`; UCSC: `chr1 …`).
