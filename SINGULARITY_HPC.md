# Running the RNA-seq Pipeline on HPC with Apptainer / Singularity

A guide for running the containerized RNA-seq workflow on High-Performance
Computing (HPC) clusters using **Apptainer** (or **Singularity**).

## 🔁 Singularity vs. Apptainer

[Apptainer](https://apptainer.org/) is the community-maintained fork of
Singularity (Linux Foundation, 2021) and is the default on many HPC systems. The
two are interchangeable:

- **Identical CLI** — every `apptainer <subcommand>` works as `singularity <subcommand>`
  (`pull`, `run`, `exec`, `build`, `--bind`, …).
- **Same image format (`.sif`)** — images built with one tool run under the other.
- **Compatibility shim** — most Apptainer installs also provide a `singularity`
  symlink.

**Which do I have?** `which apptainer singularity`, or `module avail apptainer singularity`.
This guide uses `apptainer`; substitute `singularity` if that is what your cluster
provides.

## 🎯 Why Apptainer/Singularity for HPC?

| Feature | Docker | Apptainer / Singularity |
|---------|--------|-------------------------|
| **Root required** | Yes | No ✅ |
| **Runs as** | root | you (your UID) ✅ |
| **Auto-mounts `$HOME`, `/tmp`, CWD** | No | Yes ✅ |
| **HPC scheduler integration** | Difficult | Easy ✅ |

Because Apptainer auto-mounts the current directory and runs as you, running
**from your project directory** needs no bind flags and no `--user` — outputs are
written back as you.

## 📦 Get the image

The image ships Snakemake + the 4 pre-built per-rule conda envs (at
`/opt/wf-conda`) and runs `snakemake --use-conda`. Its runscript already sets
`--conda-frontend mamba --conda-prefix /opt/wf-conda`, so everything after the
image name is passed to Snakemake.

**Option 1 — pull the published Docker image and convert (easiest):**
```bash
module load apptainer                      # if your cluster uses modules
apptainer pull rnaseq-pipeline.sif docker://gynecoloji/rnaseq_pipeline:latest
```

**Option 2 — build natively from `apptainer.def` (no Docker needed):**
```bash
cd /path/to/snakemake_RNAseq               # must run from the repo root (%files context)
apptainer build --fakeroot rnaseq-pipeline.sif apptainer.def
```

This is a long, memory-hungry build (it solves and pre-bakes the conda envs). Run
it as a batch job, not on a login node, and point Apptainer's scratch at a large
filesystem:
```bash
export APPTAINER_TMPDIR=/big/scratch/apptainer_tmp
export APPTAINER_CACHEDIR=/big/scratch/apptainer_cache
```

## 🏃 Running the pipeline

Run **from your project directory** (the one holding `workflow/`, `config/`,
`ref/`, `data/`). Apptainer auto-mounts it, so no bind flags are needed:

```bash
# Dry run first (check the DAG + validate config)
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile -n

# Everything (core stage → advanced QC → Salmon) in one dependency-ordered DAG
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 20

# A single stage — append the target
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 20 rna_all
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 20 qc_all
apptainer run rnaseq-pipeline.sif -s workflow/Snakefile --cores 20 salmon_all
```

`apptainer exec` also works if you prefer to spell out the Snakemake call:
```bash
apptainer exec rnaseq-pipeline.sif \
  snakemake --use-conda --conda-frontend mamba --conda-prefix /opt/wf-conda \
  -s workflow/Snakefile --cores 20
```

**References outside the project directory?** If `ref/` genomes live on scratch,
bind them in and point `config/config.yaml` at the bound paths:
```bash
apptainer run --bind /scratch/genomes:/scratch/genomes \
  rnaseq-pipeline.sif -s workflow/Snakefile --cores 20
```

**Read-only conda prefix error?** Add `--writable-tmpfs` to the `apptainer run` /
`exec` command.

## 📜 SLURM job scripts

**Everything in one job (the unified DAG runs all three stages in order):**

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --partition=standard

module load apptainer   # or: module load singularity

# Run from the project directory (Apptainer auto-mounts it)
apptainer run rnaseq-pipeline.sif \
  -s workflow/Snakefile --cores ${SLURM_CPUS_PER_TASK} -p

echo "Done. Results in $(pwd)/results/"
```

Submit with `sbatch run_rnaseq.sh`.

**Just one stage** — append the target to the `apptainer run` line, e.g.
`-s workflow/Snakefile --cores ${SLURM_CPUS_PER_TASK} rna_all -p`.

## 🎯 Best practices

- **Match cores to the allocation:** `--cores ${SLURM_CPUS_PER_TASK}` (not a
  hardcoded number).
- **Use fast scratch** for `data/`, `ref/`, and `results/` when available.
- **Set the Apptainer cache dir** so `$HOME` doesn't fill with layers:
  ```bash
  export APPTAINER_CACHEDIR=/scratch/$USER/apptainer_cache
  mkdir -p "$APPTAINER_CACHEDIR"
  ```
- **Resume for free:** Snakemake continues from where it stopped — if a job times
  out, just resubmit.
- **Email notifications:** `#SBATCH --mail-type=BEGIN,END,FAIL` /
  `#SBATCH --mail-user=you@example.edu`.

## 📊 Monitoring

```bash
squeue -u $USER                 # job status
seff <jobid>                    # efficiency after completion
tail -f slurm-*.out             # driver output
tail -f logs/hisat2/*.log       # per-rule logs
ls results/samtools/*.bam | wc -l   # progress
```

## ✅ Checklist

**Before submission:**
- [ ] Load the `apptainer` (or `singularity`) module
- [ ] Pull/build `rnaseq-pipeline.sif`
- [ ] Reads in `data/` named `{sample_id}_R1_001.fastq.gz` / `_R2_001.fastq.gz`
- [ ] Samples listed in `config/samples.csv`; reference paths set in `config/config.yaml`
- [ ] Dry run passes (`-s workflow/Snakefile -n`)
- [ ] Time/memory limits set

**After completion:**
- [ ] Check exit status and `results/multiqc_report.html`
- [ ] Copy results back from scratch if used

## 🆘 Getting help

- Apptainer docs: https://apptainer.org/docs/ · Singularity CE: https://sylabs.io/docs/
- Pipeline issues: https://github.com/gynecoloji/snakemake_RNAseq/issues
  (include the `snakemake` command, the relevant `logs/`, and your Snakemake version)

---

**License**: MIT
