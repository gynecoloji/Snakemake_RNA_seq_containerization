# Running RNA-seq Pipeline on HPC with Singularity / Apptainer

A complete guide for running the containerized RNA-seq analysis pipeline on High-Performance Computing (HPC) clusters using **Singularity** or **Apptainer**.

## 🔁 Singularity vs. Apptainer

[Apptainer](https://apptainer.org/) is the community-maintained fork of Singularity (moved under the Linux Foundation in 2021) and has become the default on many HPC systems. From a user perspective the two are interchangeable:

- **Identical CLI** — every `singularity <subcommand>` in this guide works as `apptainer <subcommand>` (e.g. `apptainer pull`, `apptainer exec`, `apptainer build`).
- **Same image format (`.sif`)** — images built with one tool run under the other without conversion.
- **Same bind-mount flags** — `-B`, `--bind`, `SINGULARITYENV_*` / `APPTAINERENV_*`, etc.
- **Compatibility shim** — most Apptainer installations provide a `singularity` symlink pointing at `apptainer`, so the commands in this guide usually work unchanged.

**Which one do I have?** Run `which singularity` and `which apptainer`, or check `module avail singularity apptainer`. If only Apptainer is available and no `singularity` shim exists, add `alias singularity=apptainer` to your `~/.bashrc`, or mentally substitute `apptainer` wherever this guide says `singularity`.

Throughout this guide we use `singularity` for brevity; unless explicitly noted otherwise, every command is equally valid with `apptainer`.

## 📋 Table of Contents

- [Why Singularity/Apptainer for HPC?](#why-singularity-for-hpc)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Converting Docker to Singularity](#converting-docker-to-singularity)
- [Running the Pipeline](#running-the-pipeline)
- [Job Scheduler Scripts](#job-scheduler-scripts)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)

---

## 🎯 Why Singularity/Apptainer for HPC?

Singularity and Apptainer are both designed specifically for HPC environments:

| Feature | Docker | Singularity / Apptainer |
|---------|--------|-------------------------|
| **Root access required** | Yes | No ✅ |
| **User permissions** | Runs as root | Runs as user ✅ |
| **MPI support** | Limited | Native ✅ |
| **GPU support** | Complex | Simple ✅ |
| **Security** | Risky for shared systems | Safe for multi-user ✅ |
| **HPC scheduler integration** | Difficult | Easy ✅ |

**Bottom line**: Singularity/Apptainer containers run **without root privileges** and maintain user identity, making them ideal for shared HPC systems.

---

## 🚀 Quick Start

```bash
# 1. Load Singularity or Apptainer module (whichever your HPC provides)
module load singularity   # or: module load apptainer

# 2. Pull the container (use `apptainer pull` if that's what your cluster has)
singularity pull rnaseq_pipeline.sif docker://gynecoloji/rnaseq_pipeline:latest

# 3. Run the pipeline
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores 20 -s /pipeline/snakefile_RNA -p
```

---

## 📥 Installation

### Option 1: Using Module System (Recommended)

Most HPC clusters have Singularity or Apptainer pre-installed. Check for either:

```bash
# Check for available module names (try both — clusters vary)
module avail singularity
module avail apptainer
# Also useful if neither shows up immediately:
module spider singularity
module spider apptainer

# Load whichever your cluster provides
module load singularity   # or: module load apptainer

# Verify installation
singularity --version     # Expected: singularity version 3.x.x or newer
# -- or --
apptainer --version       # Expected: apptainer version 1.x.x or newer
```

Both tools accept the same subcommands; this guide uses `singularity` consistently.

### Option 2: Request Installation

If neither Singularity nor Apptainer is available, contact your HPC administrator:

```
Subject: Singularity / Apptainer Installation Request

Dear HPC Support,

Could you please install Apptainer (https://apptainer.org/) — the
community-maintained successor to Singularity — or Singularity CE
(https://sylabs.io/singularity/) on the cluster? Either is needed
for containerized bioinformatics workflows.

Thank you!
```

---

## 🔄 Converting Docker to Singularity

### Method 1: Pull from Docker Hub (Easiest)

```bash
# Pull and convert in one step
singularity pull rnaseq_pipeline.sif docker://gynecoloji/rnaseq_pipeline:latest

# This creates: rnaseq_pipeline.sif (~2.5 GB)
```

**Advantages:**
- ✅ Simple one-line command
- ✅ Automatic conversion
- ✅ No Docker required on HPC

### Method 2: Build from Local Docker Image

If you have Docker access on a local machine:

```bash
# On your local machine with Docker:
docker save rnaseq-pipeline:latest | gzip > rnaseq_pipeline.tar.gz

# Transfer to HPC:
scp rnaseq_pipeline.tar.gz username@hpc-cluster:~/

# On HPC, convert to Singularity:
singularity build rnaseq_pipeline.sif docker-archive://rnaseq_pipeline.tar.gz
```

### Method 3: Build from Dockerfile

```bash
# On HPC (requires sudo - usually not available):
sudo singularity build rnaseq_pipeline.sif docker://continuumio/miniconda3:latest

# Better: Use Singularity remote builder
singularity build --remote rnaseq_pipeline.sif Dockerfile
```

### Verify the Container

```bash
# Check image info
singularity inspect rnaseq_pipeline.sif

# Test help command
singularity run rnaseq_pipeline.sif --help

# Interactive shell
singularity shell rnaseq_pipeline.sif
```

---

## 🏃 Running the Pipeline

### Basic Execution

```bash
# Core RNA-seq pipeline
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores 20 -s /pipeline/snakefile_RNA -p
```

### Understanding Bind Mounts (`-B`)

```bash
-B HOST_PATH:CONTAINER_PATH[:OPTIONS]
```

**Examples:**
```bash
# Read-write mount (default)
-B $(pwd)/data:/pipeline/data

# Read-only mount
-B $(pwd)/ref:/pipeline/ref:ro

# Multiple mounts
-B $(pwd)/data:/pipeline/data,$(pwd)/ref:/pipeline/ref
```

### Override `config.yaml` at runtime

The image ships with a default `/pipeline/config.yaml`, but on HPC you usually want **your** paths and thread counts. Bind-mount your edited copy over the default — no rebuild required:

```bash
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  -B $(pwd)/config.yaml:/pipeline/config.yaml:ro \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores ${SLURM_CPUS_PER_TASK} -s /pipeline/snakefile_RNA -p
```

Or pass an out-of-tree config explicitly:

```bash
snakemake --use-conda --configfile /pipeline/data/my_hpc_config.yaml \
          --cores ${SLURM_CPUS_PER_TASK} -s /pipeline/snakefile_RNA -p
```

See README.md → **Configuration** for the full list of tunable keys.

### Running Individual Pipelines

**Core RNA-seq processing:**
```bash
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores 20 -s /pipeline/snakefile_RNA -p
```

**Advanced QC:**
```bash
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores 20 -s /pipeline/snakefile_RNAQC -p
```

**Salmon quantification:**
```bash
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores 20 -s /pipeline/snakefile_salmon -p
```

### Dry Run (Recommended First Step)

```bash
# Check what will run without executing
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  rnaseq_pipeline.sif \
  snakemake -n -s /pipeline/snakefile_RNA
```

---

## 📜 Job Scheduler Scripts

### SLURM

**Full pipeline (all three workflows):**

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq_full
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --partition=standard

# Load Singularity
module load singularity

# Set project directory
PROJECT_DIR=$(pwd)

echo "========================================="
echo "Starting RNA-seq Pipeline"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Cores: $SLURM_CPUS_PER_TASK"
echo "========================================="

# Pipeline 1: Core RNA-seq
echo "Running Core RNA-seq Processing..."
singularity exec \
  -B ${PROJECT_DIR}/data:/pipeline/data \
  -B ${PROJECT_DIR}/ref:/pipeline/ref \
  -B ${PROJECT_DIR}/results:/pipeline/results \
  -B ${PROJECT_DIR}/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores ${SLURM_CPUS_PER_TASK} \
    -s /pipeline/snakefile_RNA -p

# Pipeline 2: Advanced QC
echo "Running Advanced QC..."
singularity exec \
  -B ${PROJECT_DIR}/data:/pipeline/data \
  -B ${PROJECT_DIR}/ref:/pipeline/ref \
  -B ${PROJECT_DIR}/results:/pipeline/results \
  -B ${PROJECT_DIR}/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores ${SLURM_CPUS_PER_TASK} \
    -s /pipeline/snakefile_RNAQC -p

# Pipeline 3: Salmon quantification
echo "Running Salmon Quantification..."
singularity exec \
  -B ${PROJECT_DIR}/data:/pipeline/data \
  -B ${PROJECT_DIR}/ref:/pipeline/ref \
  -B ${PROJECT_DIR}/results:/pipeline/results \
  -B ${PROJECT_DIR}/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores ${SLURM_CPUS_PER_TASK} \
    -s /pipeline/snakefile_salmon -p

echo "========================================="
echo "Pipeline completed successfully!"
echo "Results in: ${PROJECT_DIR}/results/"
echo "========================================="
```

**Submit:**
```bash
sbatch run_rnaseq.sh
```

**Single pipeline (e.g., just core RNA-seq):**

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq_core
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=standard

module load singularity

singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores ${SLURM_CPUS_PER_TASK} \
    -s /pipeline/snakefile_RNA -p
```

---

## 🎯 Best Practices

### 1. **Use Scratch/Fast Storage**

```bash
# Copy data to fast scratch space
SCRATCH=/scratch/$USER/$SLURM_JOB_ID
mkdir -p $SCRATCH

# Copy input data
cp -r data/ ref/ $SCRATCH/

# Run pipeline on scratch
cd $SCRATCH
singularity exec ... snakemake ...

# Copy results back
cp -r results/ logs/ $HOME/project/
```

### 2. **Set Singularity/Apptainer Cache Directory**

```bash
# Singularity: add to your job script or ~/.bashrc
export SINGULARITY_CACHEDIR=/scratch/$USER/singularity_cache
mkdir -p $SINGULARITY_CACHEDIR

# Apptainer uses its own env var (set both if your cluster provides both tools):
export APPTAINER_CACHEDIR=/scratch/$USER/apptainer_cache
mkdir -p $APPTAINER_CACHEDIR
```

This prevents filling your home directory with cached layer files.

### 3. **Use Absolute Paths**

```bash
# GOOD - Absolute paths
-B /home/user/project/data:/pipeline/data

# RISKY - Relative paths (can fail if cd changes)
-B ./data:/pipeline/data
```

### 4. **Resource Allocation**

```bash
# Match Snakemake cores to SLURM allocation
snakemake --cores ${SLURM_CPUS_PER_TASK}

# Not hardcoded!
snakemake --cores 20  # Bad if you requested 10 cores
```

### 5. **Email Notifications**

```bash
# Add to SLURM script
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=your.email@university.edu
```

### 6. **Checkpoint and Resume**

Snakemake automatically resumes from where it stopped:

```bash
# If job times out, just resubmit - it will continue!
sbatch run_rnaseq.sh  # Picks up where it left off
```

---

## 📊 Monitoring Jobs

### SLURM

```bash
# Check job status
squeue -u $USER

# Detailed job info
scontrol show job <jobid>

# Job efficiency (after completion)
seff <jobid>

# Real-time resource usage
ssh <compute-node>
htop
```

### Check Progress

```bash
# Watch log files
tail -f slurm-*.out

# Count completed files
ls results/samtools/*.bam | wc -l

# Check specific pipeline log
tail -f logs/hisat2/*.log
```

---

## 📁 Directory Structure for HPC

```
/home/username/rnaseq_project/
├── rnaseq_pipeline.sif          # Singularity image
├── run_rnaseq.sh                # SLURM script
├── data/                        # Input FASTQ files
├── ref/                         # Reference genomes
├── results/                     # Pipeline outputs
├── logs/                        # Log files
└── scripts/                     # Helper scripts

/scratch/username/
└── rnaseq_tmp_$JOBID/          # Temporary working directory
```

---

## ✅ HPC Workflow Checklist

**Before submission:**
- [ ] Load Singularity or Apptainer module
- [ ] Pull/build `.sif` image
- [ ] Verify data is accessible and sample name nomenclature (it should match the pattern indicated in snakemake file: {sample_name}_R1_001.fastq.gz)
- [ ] Check reference files exist
- [ ] Test with dry run (`-n`)
- [ ] Set appropriate time/memory limits
- [ ] Configure email notifications

**During run:**
- [ ] Monitor job queue status
- [ ] Check log files for errors
- [ ] Monitor resource usage
- [ ] Watch for completion

**After completion:**
- [ ] Check exit status
- [ ] Verify all outputs created
- [ ] Review MultiQC report
- [ ] Copy results from scratch
- [ ] Clean up temporary files

---

## 🆘 Getting Help

**HPC-specific issues:**
1. Check cluster documentation
2. Contact your HPC support team
3. Check the relevant docs:
   - Apptainer: https://apptainer.org/docs/
   - Singularity CE (Sylabs): https://sylabs.io/docs/

**Pipeline issues:**
1. GitHub Issues: https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/issues
2. Check log files in `logs/` directory
3. Run with `--verbose` flag for debug info

---

**Last Updated**: January 2026  
**Author**: gynecoloji  
**License**: MIT
