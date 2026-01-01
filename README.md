# Advanced RNA-seq Analysis Pipeline

![Docker Pulls](https://img.shields.io/docker/pulls/gynecoloji/rnaseq_pipeline)
![Docker Image Size](https://img.shields.io/docker/image-size/gynecoloji/rnaseq_pipeline)
![GitHub Stars](https://img.shields.io/github/stars/gynecoloji/Snakemake_RNA_seq_containerization?style=social)
![GitHub Forks](https://img.shields.io/github/forks/gynecoloji/Snakemake_RNA_seq_containerization?style=social)
![GitHub Issues](https://img.shields.io/github/issues/gynecoloji/Snakemake_RNA_seq_containerization)
![GitHub Last Commit](https://img.shields.io/github/last-commit/gynecoloji/Snakemake_RNA_seq_containerization)
![License](https://img.shields.io/github/license/gynecoloji/Snakemake_RNA_seq_containerization)

A comprehensive Snakemake workflow for RNA-seq data analysis that combines alignment-based quantification (HISAT2/featureCounts), alignment-free quantification (Salmon), and extensive quality control metrics in a single, easy-to-use pipeline.

**🐳 Now with Docker support for easy deployment!**

## 📚 Table of Contents

- [Overview](#overview)
- [Pipeline Components](#pipeline-components)
- [Workflow Diagram](#workflow-diagram)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Option 1: Docker (Recommended)](#option-1-docker-recommended)
  - [Option 2: Local Conda Installation](#option-2-local-conda-installation)
- [Usage](#usage)
  - [Docker Usage](#docker-usage)
  - [Local Usage](#local-usage)
- [Input Requirements](#input-requirements)
- [Output Description](#output-description)
- [Parameters](#parameters)
- [Conda Environments](#conda-environments)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Contact](#contact)

## 🔍 Overview

This pipeline integrates three complementary workflows for comprehensive RNA-seq analysis: (run them sequentially!)

1. **Core RNA-seq Processing**: Raw read QC, trimming, alignment, and gene-level quantification
2. **Advanced RNA-seq QC**: Multiple QC tools to evaluate alignment quality and RNA integrity
3. **Transcript Quantification**: Alignment-free transcript-level quantification with standard and decoy-aware indices

By combining these approaches, the pipeline delivers robust gene expression estimates while providing detailed quality metrics to ensure reliable results.

## 🧩 Pipeline Components

The workflow consists of three main component pipelines:

### 1. Core RNA-seq Processing

- **Quality Control**: FastQC for raw reads
- **Read Preprocessing**: Fastp for adapter trimming and quality filtering
- **Alignment**: HISAT2 for spliced read alignment to the reference genome (you can also use other aligners)
- **BAM Processing**: Samtools for filtering, sorting, and indexing
- **Expression Quantification**: featureCounts for gene-level counting
- **Results Summary**: MultiQC for aggregated quality reporting

### 2. Advanced RNA-seq QC

- **Fragment Size Analysis**: Picard CollectInsertSizeMetrics
- **Alignment QC**: Qualimap BAM QC for alignment quality metrics
- **RNA-seq Specific QC**: Qualimap RNA-seq for gene model coverage statistics
- **Transcript Analysis**: RSeQC for advanced RNA-seq QC metrics:
  - Read distribution across genomic features
  - GC content analysis
  - Transcript integrity number (TIN) calculation

### 3. Transcript Quantification

- **Alignment-free Quantification**: Salmon for direct transcript quantification
- **Multiple Index Support**:
  - Standard transcriptome index
  - Decoy-aware transcriptome index (reduces mapping bias)

## 📊 Workflow Diagram
![Workflow Plot](diagram.png)

## 🛠️ Requirements

### For Docker (Recommended)
- Docker ≥ 20.10
- Docker Compose ≥ 1.29
- 64GB+ RAM recommended
- 20+ CPU cores recommended for optimal performance

### For Local Installation
- Snakemake ≥ 7.0
- Conda (for environment management)
- 64GB+ RAM recommended
- 20+ CPU cores recommended for optimal performance

## 📥 Installation

### Option 1: Docker (Recommended)

**Step 1: Clone the repository**
```bash
git clone https://github.com/gynecoloji/SnakeMake_RNAseq.git
cd SnakeMake_RNAseq
```

**Step 2: Build the Docker image**
```bash
# Using Docker
docker build -t rnaseq-pipeline:latest .

# Or using Docker Compose (easier)
docker-compose build
```

That's it! All dependencies are included in the container.

### Option 2: Local Conda Installation

Clone the repository:

```bash
git clone https://github.com/gynecoloji/SnakeMake_RNAseq.git
cd SnakeMake_RNAseq
```

Create conda environments:

```bash
# Main snakemake environment
conda env create -f envs/snakemake.yaml

# QC tools environment
conda env create -f envs/qualimap.yaml

# RSeQC environment
conda env create -f envs/RSeQC.yaml

# Salmon environment
conda env create -f envs/salmon.yaml
```

## 🚀 Usage

### Docker Usage

**Quick Start with Docker Compose (Easiest)**

1. Place your FASTQ files in the `data/` directory
2. Place reference files in the `ref/` directory
3. Run the pipeline:

```bash
# Run all three pipelines sequentially
docker-compose up

# Or run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f
```

**Advanced Docker Usage**

```bash
# Run with Docker directly
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  -v $(pwd)/logs:/pipeline/logs \
  rnaseq-pipeline:latest

# Dry run (check what will be executed)
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  rnaseq-pipeline:latest --dry-run

# Run only core RNA-seq pipeline
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  rnaseq-pipeline:latest --pipeline rna --cores 10

# Run only QC analysis
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  rnaseq-pipeline:latest --pipeline qc

# Run only Salmon quantification
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  rnaseq-pipeline:latest --pipeline salmon

# Interactive shell for debugging
docker run --rm -it \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  rnaseq-pipeline:latest --shell

# Using docker-compose for specific pipelines
docker-compose run rnaseq-pipeline --pipeline rna --cores 15
docker-compose run rnaseq-pipeline --dry-run
docker-compose run rnaseq-pipeline --shell
```

**Optional: Jupyter Notebook for Analysis**

```bash
# Start Jupyter notebook server
docker-compose --profile jupyter up jupyter

# Access at: http://localhost:8888
# Token: rnaseq
```

### Local Usage

1. Place paired-end FASTQ files in the `data/` directory following the naming convention:
   - `{sample}_R1_001.fastq.gz`
   - `{sample}_R2_001.fastq.gz`

2. Configure reference paths in the Snakefile:
   - HISAT2 index: `ref/ENSEMBL/genome`
   - GTF annotation: `ref/Homo_sapiens.GRCh38.102.gtf`
   - Salmon indices: `ref/Salmon_index_Grch38` and `ref/Salmon_index_decoy_Grch38`
   - RSeQC bed file: `ref/ENSEMBL_hg38.bed`

3. Run the workflow:

```bash
# Activate snakemake environment
conda activate snakemake

# Dry run to verify
snakemake -n -s snakefile_RNA

# Run core RNA-seq pipeline with 20 cores
snakemake --use-conda --cores 20 -s snakefile_RNA -p

# Run QC pipeline
snakemake --use-conda --cores 20 -s snakefile_RNAQC -p

# Run Salmon pipeline
snakemake --use-conda --cores 20 -s snakefile_salmon -p
```

## 📁 Input Requirements

- **FASTQ files**: Paired-end reads with naming pattern `{sample}_R1_001.fastq.gz` and `{sample}_R2_001.fastq.gz`
- **Reference files**:
  - HISAT2 genome index
  - GTF gene annotation file (ENSEMBL format)
  - BED file for RSeQC tools
  - Salmon indices (standard and decoy-aware)

**Note**: When using Docker, mount these directories:
- `./data` → `/pipeline/data` (FASTQ files)
- `./ref` → `/pipeline/ref` (reference files)
- `./results` → `/pipeline/results` (output)
- `./logs` → `/pipeline/logs` (log files)

## 📊 Output Description

The pipeline generates organized outputs in the `results/` directory:

```
results/
├── fastqc/                # Raw read quality reports
├── trimmed/               # Trimmed reads and QC reports
├── hisat2/                # Alignment files and summaries
├── samtools/              # Processed BAM files and flagstat reports
├── featurecounts/         # Gene-level counts
├── picard/                # Insert size metrics and plots
├── qualimap_bamqc/        # General alignment QC
├── qualimap_rnaseq/       # RNA-specific QC
├── rseqc/                 # Advanced RNA-seq QC metrics
├── quants/                # Salmon standard index quantification
├── quants_decoy/          # Salmon decoy-aware quantification
└── multiqc_report.html    # Combined QC report
```

## ⚙️ Parameters

Key configurable parameters in the workflow:

- **HISAT2**:
  - Max fragment length: 3000bp
  - Mixed/discordant alignments: disabled

- **Samtools**:
  - Filtering: Properly paired reads (0x2) and primary alignments (-F 0x100)
  - Uniquely mapped: Only reads with NH:i:1 tag

- **featureCounts**:
  - Count paired reads (-p)
  - Feature type: exon
  - ID attribute: gene_id
  - Multi-mapping: count all (-M)
  - Strand-specificity: unstranded (-s 0)

- **Salmon**:
  - Library type: automatic (-l A)
  - Mapping validation: enabled (--validateMappings)

## 🧪 Conda Environments

The workflow uses four Conda environments:

1. **snakemake.yaml**: Core tools (FastQC, fastp, HISAT2, Samtools, featureCounts, MultiQC)
2. **qualimap.yaml**: Qualimap and Picard for alignment QC
3. **RSeQC.yaml**: RSeQC tools for RNA-specific QC
4. **salmon.yaml**: Salmon for transcript quantification

## 🔧 Troubleshooting

### Docker Issues

**Problem**: Container can't access data files
```bash
# Solution: Check volume mounts and file permissions
ls -la data/
docker run --rm -v $(pwd)/data:/pipeline/data rnaseq-pipeline:latest ls -la /pipeline/data
```

**Problem**: Out of memory
```bash
# Solution: Increase Docker memory limit in Docker Desktop settings
# Or reduce cores: --cores 10
```

**Problem**: Permission denied on results
```bash
# Solution: Fix ownership
sudo chown -R $USER:$USER results/ logs/
```

### Pipeline Issues

**Problem**: "No FASTQ files found"
- Ensure files follow naming pattern: `{sample}_R1_001.fastq.gz`
- Check they are in the correct directory

**Problem**: Reference files not found
- Update paths in Snakefiles
- Ensure reference files are in `ref/` directory

**Problem**: Conda environment conflicts
```bash
# Rebuild environments
conda env remove -n snakemake
conda env create -f envs/snakemake.yaml
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📧 Contact

For questions or feedback, please open an issue on the GitHub repository or contact the author.

---

**Pro Tips:**
- Use `--dry-run` first to check the workflow
- Monitor resource usage with `docker stats` or `htop`
- Check MultiQC report for overall quality assessment
- Use the interactive shell for debugging: `docker-compose run rnaseq-pipeline --shell`

Last updated: Dec 29th, 2025  
Created by: gynecoloji
