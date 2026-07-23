# Running the RNA-seq workflow with Docker

The pipeline uses **one conda environment per rule** (`workflow/envs/*.yaml`) so
tools with incompatible dependency stacks stay isolated. The image therefore
ships **Snakemake + the pre-built per-rule conda envs** (`snakemake`, `qualimap`,
`RSeQC`, `salmon`) and runs Snakemake with `--use-conda`.

Large reference genomes/indexes and FASTQs are **not** baked into the image — you
mount your project directory at run time.

## 1. What you need on the host (in `ref/` and `data/`)

The container reads these from the mounted project directory:

| Path | What |
|---|---|
| `data/{sample}_R1_001.fastq.gz`, `_R2_001.fastq.gz` | your paired-end reads |
| `ref/ENSEMBL/genome.*.ht2` | HISAT2 index (prefix `genome`) |
| `ref/Homo_sapiens.GRCh38.102.gtf` | GTF annotation |
| `ref/ENSEMBL_hg38.bed` | RSeQC 12-column BED |
| `ref/picard.jar` | Picard (insert-size QC) |
| `ref/Salmon_index_Grch38/`, `ref/Salmon_index_decoy_Grch38/` | Salmon indexes |
| `config/config.yaml`, `config/samples.csv` | config + sample sheet (tracked in the repo) |

Only the references for the stage(s) you run need to be present (see the
top-level `README.md`). List your samples in `config/samples.csv`.

## 2. Build the image (once)

```bash
docker compose build
# or:  docker build -t rnaseq-pipeline:latest .
```

This pre-builds the conda envs into the image (a few GB). Expect a long first
build. For a reproducible image, pin the base tag in the `Dockerfile`
(`FROM condaforge/miniforge3:<version>`).

### No Docker? Build the `.sif` natively with Apptainer

On HPC you usually have Apptainer but not Docker. [`apptainer.def`](apptainer.def)
mirrors the Dockerfile, so you can build the image directly:

```bash
module load apptainer                     # if your cluster uses modules
cd /path/to/snakemake_RNAseq              # must run from the repo root (%files context)
apptainer build --fakeroot rnaseq-pipeline.sif apptainer.def
```

Because this is a long, memory-hungry build, run it as a batch job rather than on
a login node, and point Apptainer's scratch at a large filesystem:

```bash
export APPTAINER_TMPDIR=/big/scratch/apptainer_tmp
export APPTAINER_CACHEDIR=/big/scratch/apptainer_cache
```

## 3. Run

A single run builds the core stage, advanced QC, and Salmon quantification in
dependency order (unified DAG). Using the helper script (recommended):

```bash
./run_pipeline.sh -n                        # dry run: check the DAG first
./run_pipeline.sh --cores 16                # everything
./run_pipeline.sh --cores 16 rna_all        # core RNA-seq only
./run_pipeline.sh --cores 16 qc_all         # advanced QC only
./run_pipeline.sh --cores 16 salmon_all     # Salmon only
```

Or with docker compose (the image entrypoint sets `-s workflow/Snakefile`; run
from the project root):

```bash
docker compose run --rm rnaseq -n
docker compose run --rm rnaseq --cores 16
docker compose run --rm rnaseq --cores 16 rna_all
```

Or a raw `docker run` (mount the project; reuse the baked envs):

```bash
docker run --rm -v "$(pwd)":/workflow -e HOME=/tmp --user "$(id -u):$(id -g)" \
    rnaseq-pipeline:latest -s workflow/Snakefile --cores 16
```

Everything after the image name is passed straight to `snakemake` (the image's
entrypoint already sets `--use-conda --conda-frontend mamba --conda-prefix
/opt/wf-conda`).

**Targets:** the default target runs core → QC → Salmon in one DAG. Use `rna_all`
for just the core stage, `qc_all` for the advanced-QC stage (it consumes the core
stage's BAMs), and `salmon_all` for Salmon quantification.

## 4. Notes & troubleshooting

- **Outputs ownership:** the run script / compose run as your host UID/GID
  (`--user`) so `results/` isn't root-owned. For compose, export `DOCKER_UID`/
  `DOCKER_GID` if the defaults (1000:1000) aren't you.
- **`defaults` channel ToS:** the env YAMLs list the Anaconda `defaults` channel.
  The Dockerfile best-effort-accepts its ToS; if an env solve still fails on
  `defaults`, either accept it (`conda tos accept …`) or drop `- defaults` from
  the affected `workflow/envs/*.yaml`.
- **Cores:** pass `--cores N` to match the host; the HISAT2 alignment and Salmon
  quantification are the heavy steps. Qualimap memory is set by `qualimap.java_mem`
  in `config/config.yaml`.
```
