# Running RNA-seq Pipeline on HPC with Singularity

A complete guide for running the containerized RNA-seq analysis pipeline on High-Performance Computing (HPC) clusters using Singularity.

## 📋 Table of Contents

- [Why Singularity for HPC?](#why-singularity-for-hpc)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Converting Docker to Singularity](#converting-docker-to-singularity)
- [Running the Pipeline](#running-the-pipeline)
- [Job Scheduler Scripts](#job-scheduler-scripts)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)

---

## 🎯 Why Singularity for HPC?

Singularity is designed specifically for HPC environments:

| Feature | Docker | Singularity |
|---------|--------|-------------|
| **Root access required** | Yes | No ✅ |
| **User permissions** | Runs as root | Runs as user ✅ |
| **MPI support** | Limited | Native ✅ |
| **GPU support** | Complex | Simple ✅ |
| **Security** | Risky for shared systems | Safe for multi-user ✅ |
| **HPC scheduler integration** | Difficult | Easy ✅ |

**Bottom line**: Singularity containers run **without root privileges** and maintain user identity, making them ideal for shared HPC systems.

---

## 🚀 Quick Start

```bash
# 1. Load Singularity module (on HPC)
module load singularity

# 2. Pull the container
singularity pull rnaseq_pipeline.sif docker://yourusername/rnaseq-pipeline:latest

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

Most HPC clusters have Singularity pre-installed:

```bash
# Check available versions (if singularity not available, try module spider singularity)
module avail singularity

# Load Singularity
module load singularity

# Verify installation
singularity --version
# Expected: singularity version 3.x.x or newer
```

### Option 2: Request Installation

If Singularity is not available, contact your HPC administrator:

```
Subject: Singularity Installation Request

Dear HPC Support,

Could you please install Singularity (https://sylabs.io/singularity/) 
on the cluster? It's needed for containerized bioinformatics workflows.

Thank you!
```

---

## 🔄 Converting Docker to Singularity

### Method 1: Pull from Docker Hub (Easiest)

```bash
# Pull and convert in one step
singularity pull rnaseq_pipeline.sif docker://gynecoloji/rnaseq-pipeline:latest

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

### 2. **Set Singularity Cache Directory**

```bash
# Add to your job script or ~/.bashrc
export SINGULARITY_CACHEDIR=/scratch/$USER/singularity_cache
mkdir -p $SINGULARITY_CACHEDIR
```

This prevents filling your home directory with cached files.

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
- [ ] Load Singularity module
- [ ] Pull/build Singularity image
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
3. Check Singularity documentation: https://sylabs.io/docs/

**Pipeline issues:**
1. GitHub Issues: https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/issues
2. Check log files in `logs/` directory
3. Run with `--verbose` flag for debug info

---

**Last Updated**: January 2026  
**Author**: gynecoloji  
**License**: MIT
