# Setup Guide

A practical walkthrough for getting the RNA-seq workflow running. For the full
parameter reference see [`config/README.md`](config/README.md); for container
details see [`DOCKER.md`](DOCKER.md) and [`SINGULARITY_HPC.md`](SINGULARITY_HPC.md).

## 1. Repository layout

```
snakemake_RNAseq/
├── config/
│   ├── config.yaml        # all parameters (validated against the schema)
│   ├── samples.csv        # sample sheet (sample_id[, condition])
│   └── README.md
├── workflow/
│   ├── Snakefile          # entry point (unified DAG; targets rna_all/qc_all/salmon_all)
│   ├── rules/             # common.smk, rnaseq.smk, qc.smk, salmon.smk
│   ├── envs/              # 4 per-rule conda envs
│   └── schemas/config.schema.yaml
├── data/                  # your FASTQ files (you provide)
├── ref/                   # reference genomes/indexes/annotations (you provide)
├── Dockerfile, docker-compose.yml, apptainer.def, run_pipeline.sh
└── results/, logs/        # created at runtime
```

## 2. Prepare inputs

1. **Reads** — place paired-end FASTQ files in `data/`, named
   `{sample_id}_R1_001.fastq.gz` / `{sample_id}_R2_001.fastq.gz`.
2. **Sample sheet** — list each `sample_id` in `config/samples.csv` (one row per
   sample; an optional `condition` column is informational).
3. **References** — put the files referenced in `config/config.yaml`'s
   `references:` section under `ref/` (HISAT2 index, GTF, RSeQC BED, `picard.jar`,
   and the two Salmon indexes). See the top-level [README](README.md#-input-requirements)
   for exact files and how to obtain them. Only the references for the stage(s)
   you run need to be present.
4. **Config** — edit `config/config.yaml` (organism metadata, reference paths,
   per-rule threads, tool flags). It ships with working GRCh38 defaults.

## 3. Choose how to run

### Option A — Docker (local / cloud)

```bash
docker compose build                       # one-time (pre-bakes the conda envs)
docker compose run --rm rnaseq -n          # dry run: check the DAG
docker compose run --rm rnaseq --cores 20  # everything (core → QC → Salmon)
```

Run a single stage by appending its target, e.g.
`docker compose run --rm rnaseq --cores 10 rna_all`. See [DOCKER.md](DOCKER.md).

### Option B — Apptainer / Singularity (HPC)

```bash
apptainer pull rnaseq-pipeline.sif docker://gynecoloji/rnaseq_pipeline:latest
# or build natively:  apptainer build --fakeroot rnaseq-pipeline.sif apptainer.def
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 20
```

See [SINGULARITY_HPC.md](SINGULARITY_HPC.md) for SLURM job scripts.

### Option C — Local conda

```bash
mamba create -n rnaseq -c conda-forge -c bioconda snakemake pandas
conda activate rnaseq
snakemake --use-conda -s workflow/Snakefile --cores 20        # everything
snakemake --use-conda -s workflow/Snakefile --cores 20 qc_all # one stage
```

The four per-rule tool environments under `workflow/envs/` are created
automatically on the first `--use-conda` run.

## 4. Targets

| Target | Builds |
|---|---|
| *(default)* | core RNA-seq → advanced QC → Salmon, in one dependency-ordered DAG |
| `rna_all` | FastQC → fastp → HISAT2 → samtools → featureCounts → MultiQC |
| `qc_all` | Picard, Qualimap (bamqc + rnaseq), RSeQC (read distribution, GC, TIN) |
| `salmon_all` | Salmon standard + decoy-aware quantification |

`qc_all` and `salmon_all` automatically build their core-stage prerequisites.

## 5. Results

Outputs land in `results/` (per-rule logs in `logs/`). Start with
`results/multiqc_report.html`; the gene count matrix is
`results/featurecounts/featureCount.txt` and Salmon abundances are under
`results/quants/` and `results/quants_decoy/`. See the
[README output section](README.md#-output-description) for the full layout.

## 6. Customization

- **Parameters** — edit `config/config.yaml`; it is validated against
  `workflow/schemas/config.schema.yaml` on every run (fail-fast on bad values,
  defaults filled for anything omitted).
- **Different organism** — point the `references:` paths and `genome:` metadata at
  your files; set `featurecounts.strandedness` and `qualimap.protocol` for your
  library.
- **Low-RAM machine** — lower the `threads:` values and `qualimap.java_mem`.
- **Custom config at runtime** — `snakemake --configfile my.yaml -s workflow/Snakefile`.

## 7. Publishing the image (maintainers)

```bash
docker build -t gynecoloji/rnaseq_pipeline:latest .
docker push gynecoloji/rnaseq_pipeline:latest
```

CI (`.github/workflows/ci.yml`) validates the config and builds the DAG on every
push; releases are automated via release-please (see [CONTRIBUTING.md](CONTRIBUTING.md)).
