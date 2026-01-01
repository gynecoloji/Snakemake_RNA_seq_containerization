# Advanced RNA-seq Analysis Pipeline

![Docker Pulls](https://img.shields.io/docker/pulls/gynecoloji/rnaseq_pipeline)
![Docker Image Size](https://img.shields.io/docker/image-size/gynecoloji/rnaseq_pipeline)
![GitHub Stars](https://img.shields.io/github/stars/gynecoloji/Snakemake_RNA_seq_containerization?style=social)
![License](https://img.shields.io/github/license/gynecoloji/Snakemake_RNA_seq_containerization)

**A production-ready, containerized Snakemake workflow for comprehensive RNA-seq analysis**

Integrates alignment-based quantification (HISAT2), alignment-free quantification (Salmon), and extensive quality control in a single reproducible pipeline. Fully containerized with Docker and Singularity support for seamless deployment on workstations, cloud, and HPC systems.

---

## 🚀 Quick Start
```bash
# Clone the repository
git clone https://github.com/gynecoloji/SnakeMake_RNAseq.git
cd SnakeMake_RNAseq

# Prepare your data
mkdir -p data ref
cp /path/to/fastq/*_R1_001.fastq.gz data/
cp /path/to/fastq/*_R2_001.fastq.gz data/
cp /path/to/references/* ref/

# Run with Docker (easiest)
docker-compose build
docker-compose up

# Or run with Singularity (HPC)
singularity pull rnaseq_pipeline.sif docker://gynecoloji/rnaseq-pipeline:latest
singularity exec -B $(pwd)/data:/pipeline/data rnaseq_pipeline.sif snakemake --cores 20
```

**Results:** Check `results/multiqc_report.html` for comprehensive QC summary.

---

## 📊 Overview

This pipeline provides **three complementary workflows** for robust RNA-seq analysis:

| Pipeline | Purpose | Key Tools | Output |
|----------|---------|-----------|--------|
| **Core RNA-seq** | Read processing & gene quantification | FastQC, fastp, HISAT2, featureCounts | Gene counts, alignments |
| **Advanced QC** | Deep quality assessment | Picard, Qualimap, RSeQC | QC metrics, TIN scores |
| **Salmon** | Transcript quantification | Salmon (standard + decoy) | Transcript abundances |

### Pipeline Workflow
```
Raw FASTQ files
    ↓
[FastQC] → Quality assessment
    ↓
[fastp] → Adapter trimming & filtering
    ↓
[HISAT2] → Spliced alignment to genome
    ↓
[Samtools] → BAM filtering & sorting
    ↓
[featureCounts] → Gene-level quantification
    ↓
[MultiQC] → Comprehensive report
    ↓
[Picard/Qualimap/RSeQC] → Advanced QC metrics
    ↓
[Salmon] → Transcript-level quantification
```

**Why three pipelines?**
- **Alignment-based** (HISAT2): Gold standard for gene counts
- **Alignment-free** (Salmon): Fast, accurate transcript quantification
- **Multi-tool QC**: Comprehensive quality validation from multiple perspectives

---

## ✨ Key Features

- ✅ **Fully Containerized** - Docker & Singularity support (no manual installation)
- ✅ **HPC Ready** - SLURM/PBS job scripts included
- ✅ **Reproducible** - All dependencies pinned in conda environments
- ✅ **Comprehensive QC** - 7+ QC tools integrated
- ✅ **Production Tested** - Handles paired-end RNA-seq at scale
- ✅ **Well Documented** - Detailed guides for every use case
- ✅ **Flexible** - Run individual pipelines or all together

---

## 📖 Documentation

**Getting Started:**
- 🐳 [**Docker Quick Reference**](DOCKER_QUICKREF.md) - Common commands & examples
- 🖥️ [**HPC/Singularity Guide**](SINGULARITY_HPC.md) - Complete cluster deployment guide
- 🛠️ [**Setup Guide**](SETUP_GUIDE.md) - Detailed installation & customization

**Understanding the Pipeline:**
- 📋 [**Input Requirements**](#input-requirements) - Data preparation checklist
- 📊 [**Output Structure**](#output-description) - What gets generated
- ⚙️ [**Parameters**](#parameters) - Configuration options

**Need Help?**
- 🐛 [**Troubleshooting**](#troubleshooting) - Common issues & solutions
- 💡 [**Best Practices**](#best-practices) - Tips for optimal results

---

## 📥 Installation

### Option 1: Docker (Recommended for Local/Cloud)

**Requirements:** Docker ≥ 20.10, Docker Compose ≥ 1.29
```bash
# Clone repository
git clone https://github.com/gynecoloji/Snakemake_RNA_seq_containerization.git
cd Snakemake_RNA_seq_containerization

# Build image (one-time setup)
docker-compose build

# Verify installation
docker-compose run rnaseq-pipeline --help
```

**Advantages:**
- ✅ Zero dependency installation
- ✅ Identical environment across systems
- ✅ Easy resource management

📖 **Full guide:** [DOCKER_QUICKREF.md](DOCKER_QUICKREF.md)

---

### Option 2: Singularity (Recommended for HPC)

**Requirements:** Singularity ≥ 3.x (usually pre-installed on HPC)
```bash
# On HPC cluster - load module
module load singularity

# Pull pre-built container
singularity pull rnaseq_pipeline.sif docker://gynecoloji/rnaseq_pipeline:latest

# Or build from local Docker image
docker save rnaseq_pipeline:latest | gzip > rnaseq_pipeline.tar.gz
# Transfer to HPC, then:
singularity build rnaseq_pipeline.sif docker-archive://rnaseq_pipeline.tar.gz
```

**Advantages:**
- ✅ No root access required
- ✅ Native HPC integration
- ✅ SLURM/PBS compatible

📖 **Full guide:** [SINGULARITY_HPC.md](SINGULARITY_HPC.md)

---

### Option 3: Local Conda (Advanced)

**Requirements:** Conda/Mamba, 64GB+ RAM
```bash
# Clone repository
git clone https://github.com/gynecoloji/Snakemake_RNA_seq_containerization.git
cd Snakemake_RNA_seq_containerization

# Create all environments
conda env create -f envs/snakemake.yaml
conda env create -f envs/qualimap.yaml
conda env create -f envs/RSeQC.yaml
conda env create -f envs/salmon.yaml

# Activate main environment
conda activate snakemake
```

**Use this if:** You need to modify tool versions or can't use containers

📖 **Full guide:** [SETUP_GUIDE.md](SETUP_GUIDE.md)

---

### Quick Comparison

| Method | Setup Time | Reproducibility | HPC Support | Flexibility |
|--------|------------|-----------------|-------------|-------------|
| **Docker** | ~10 min | ⭐⭐⭐ | ❌ | ⭐⭐ |
| **Singularity** | ~15 min | ⭐⭐⭐ | ✅ | ⭐⭐ |
| **Conda** | ~30 min | ⭐⭐ | ✅ | ⭐⭐⭐ |

---

## 🚀 Usage

### Docker Usage

**Run all three pipelines (recommended):**
```bash
# Using docker-compose (simplest)
docker-compose up

# Or with docker run
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  -v $(pwd)/logs:/pipeline/logs \
  rnaseq-pipeline:latest
```

**Run individual pipelines:**
```bash
# Core RNA-seq only
docker-compose run rnaseq_pipeline --pipeline rna --cores 10

# QC analysis only
docker-compose run rnaseq_pipeline --pipeline qc

# Salmon quantification only
docker-compose run rnaseq_pipeline --pipeline salmon

# Dry run (check workflow without executing)
docker-compose run rnaseq_pipeline --dry-run
```

**Interactive debugging:**
```bash
docker-compose run rnaseq_pipeline --shell
# Inside container:
conda activate snakemake
snakemake -n -s snakefile_RNA
```

---

### Singularity Usage (HPC)

**Interactive execution:**
```bash
singularity exec \
  -B $(pwd)/data:/pipeline/data \
  -B $(pwd)/ref:/pipeline/ref \
  -B $(pwd)/results:/pipeline/results \
  -B $(pwd)/logs:/pipeline/logs \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores 20 -s /pipeline/snakefile_RNA -p
```

**Submit to SLURM scheduler:**
```bash
#!/bin/bash
#SBATCH --job-name=rnaseq
#SBATCH --cpus-per-task=20
#SBATCH --mem=64G
#SBATCH --time=24:00:00

module load singularity

singularity exec \
  -B ${PWD}/data:/pipeline/data \
  -B ${PWD}/ref:/pipeline/ref \
  -B ${PWD}/results:/pipeline/results \
  rnaseq_pipeline.sif \
  snakemake --use-conda --cores ${SLURM_CPUS_PER_TASK} \
    -s /pipeline/snakefile_RNA -p
```

📖 **Complete HPC guide with job scripts:** [SINGULARITY_HPC.md](SINGULARITY_HPC.md)

---

### Local Conda Usage
```bash
# Activate environment
conda activate snakemake

# Run core pipeline
snakemake --use-conda --cores 20 -s snakefile_RNA -p

# Run QC pipeline
snakemake --use-conda --cores 20 -s snakefile_RNAQC -p

# Run Salmon pipeline
snakemake --use-conda --cores 20 -s snakefile_salmon -p

# Dry run first (recommended)
snakemake -n -s snakefile_RNA
```

---

### Common Options

| Flag | Description | Example |
|------|-------------|---------|
| `--pipeline rna\|qc\|salmon\|all` | Which pipeline to run | `--pipeline rna` |
| `--cores N` | Number of CPU cores | `--cores 10` |
| `--dry-run` | Show what will run | `--dry-run` |
| `--shell` | Interactive container shell | `--shell` |
| `-n` | Snakemake dry run | `snakemake -n` |
| `-p` | Print shell commands | `snakemake -p` |

---

## 📁 Input Requirements

### Required Data Structure
```
project/
├── data/                          # Your FASTQ files
│   ├── sample1_R1_001.fastq.gz   # ⚠️ Must follow this naming pattern
│   ├── sample1_R2_001.fastq.gz
│   ├── sample2_R1_001.fastq.gz
│   └── sample2_R2_001.fastq.gz
├── ref/                           # Reference files
│   ├── ENSEMBL/
│   │   └── genome.*.ht2          # HISAT2 index files
│   ├── Homo_sapiens.GRCh38.102.gtf
│   ├── ENSEMBL_hg38.bed          # For RSeQC
│   ├── Salmon_index_Grch38/      # Standard Salmon index
│   └── Salmon_index_decoy_Grch38/ # Decoy-aware Salmon index
├── results/                       # Auto-created, pipeline outputs
└── logs/                          # Auto-created, log files
```

### Naming Convention (Critical!)

**FASTQ files must match:** `{sample}_R1_001.fastq.gz` and `{sample}_R2_001.fastq.gz`

✅ **Good:**
- `Control1_R1_001.fastq.gz` / `Control1_R2_001.fastq.gz`
- `Treatment_A_R1_001.fastq.gz` / `Treatment_A_R2_001.fastq.gz`

❌ **Bad:**
- `sample_1.fastq.gz` / `sample_2.fastq.gz` (wrong pattern)
- `data_read1.fq.gz` / `data_read2.fq.gz` (wrong extension)

### Reference Files Checklist

- [ ] **HISAT2 index** - Built from your reference genome
- [ ] **GTF annotation** - Gene models (ENSEMBL/GENCODE)
- [ ] **BED file** - For RSeQC (can convert from GTF)
- [ ] **Salmon indices** - Transcriptome indices (standard + decoy)

📖 **How to prepare references:** See [SETUP_GUIDE.md](SETUP_GUIDE.md#reference-preparation)

---

## 📊 Output Description

### Directory Structure
```
results/
├── fastqc/raw/              # Raw read quality reports
│   ├── {sample}_R1_001_fastqc.html
│   └── {sample}_R2_001_fastqc.html
│
├── trimmed/                 # Trimmed reads & fastp reports
│   ├── {sample}_R1.trimmed.fastq.gz
│   ├── {sample}_R2.trimmed.fastq.gz
│   ├── {sample}_fastp.html
│   └── {sample}_fastp.json
│
├── hisat2/                  # Alignment files
│   ├── {sample}.sam
│   └── {sample}.sam.summary
│
├── samtools/                # Processed BAM files
│   ├── {sample}.sorted.filtered.bam
│   ├── {sample}.sorted.filtered.bam.bai
│   └── {sample}_summary.txt (flagstat)
│
├── featurecounts/           # Gene-level counts
│   └── featureCount.txt     # ⭐ Main count matrix
│
├── picard/                  # Fragment size metrics
│   ├── {sample}_insert_size_metrics.txt
│   └── {sample}_Histogram.pdf
│
├── qualimap_bamqc/          # Alignment QC
│   └── {sample}/
│       └── {sample}.pdf
│
├── qualimap_rnaseq/         # RNA-seq specific QC
│   └── {sample}/
│
├── rseqc/                   # Advanced RNA metrics
│   ├── {sample}_RD_summary.txt (read distribution)
│   ├── {sample}_GC_content.GC.xls
│   └── {sample}.sorted.filtered.tin.xls (transcript integrity)
│
├── quants/                  # Salmon standard quantification
│   └── {sample}_quant/
│       └── quant.sf         # ⭐ Transcript abundances
│
├── quants_decoy/            # Salmon decoy quantification
│   └── {sample}_quant/
│       └── quant.sf
│
├── multiqc_report.html      # 🎯 START HERE - Combined QC report
└── multiqc_data/            # Data behind MultiQC report
```

### Key Output Files

| File | Description | Use Case |
|------|-------------|----------|
| **multiqc_report.html** | 🎯 Aggregated QC from all tools | First check - overall quality |
| **featureCount.txt** | Gene-level count matrix | DESeq2, edgeR analysis |
| **quant.sf** | Transcript abundances (TPM) | Isoform analysis, sleuth |
| **{sample}.sorted.filtered.bam** | Aligned reads | IGV visualization |
| **{sample}.tin.xls** | Transcript integrity scores | RNA quality assessment |

### What to Check First

1. **MultiQC Report** - Overview of all samples
   - Open `results/multiqc_report.html` in browser
   - Check for failed samples, outliers

2. **Alignment Rates** - In MultiQC or HISAT2 summaries
   - Good: >80% aligned
   - Acceptable: 70-80%
   - Investigate: <70%

3. **Feature Counts** - Gene quantification
   - Located: `results/featurecounts/featureCount.txt`
   - Use for differential expression analysis

4. **Transcript Integrity** - RNA degradation check
   - Located: `results/rseqc/{sample}.sorted.filtered.tin.xls`
   - Good: TIN score >70
   - Degraded: TIN score <60

---

## 🏆 Contributing

Contributions are welcome! Please feel free to:

- 🐛 Report bugs or issues
- 💡 Suggest new features or improvements
- 📝 Improve documentation
- 🔧 Submit pull requests

**Before contributing:**
1. Check existing issues/PRs
2. Open an issue to discuss major changes
3. Follow existing code style
4. Update documentation as needed

---

## 📝 Citation

If you use this pipeline in your research, please cite:
```bibtex
@software{rnaseq_pipeline_2025,
  author = {gynecoloji},
  title = {Advanced RNA-seq Analysis Pipeline},
  year = {2025},
  url = {https://github.com/gynecoloji/Snakemake_RNA_seq_containerization},
  version = {1.0}
}
```

**Please also cite the tools used in the pipeline:**

- **Snakemake:** Mölder et al. (2021) https://doi.org/10.12688/f1000research.29032.2
- **HISAT2:** Kim et al. (2019) https://doi.org/10.1038/s41587-019-0201-4
- **Salmon:** Patro et al. (2017) https://doi.org/10.1038/nmeth.4197
- **FastQC:** https://www.bioinformatics.babraham.ac.uk/projects/fastqc/
- **fastp:** Chen et al. (2018) https://doi.org/10.1093/bioinformatics/bty560
- **featureCounts:** Liao et al. (2014) https://doi.org/10.1093/bioinformatics/btt656
- **MultiQC:** Ewels et al. (2016) https://doi.org/10.1093/bioinformatics/btw354
- **RSeQC:** Wang et al. (2012) https://doi.org/10.1093/bioinformatics/bts356
- **Qualimap:** Okonechnikov et al. (2016) https://doi.org/10.1093/bioinformatics/btv566

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

**Summary:**
- ✅ Commercial use allowed
- ✅ Modification allowed
- ✅ Distribution allowed
- ✅ Private use allowed
- ⚠️ No warranty provided
- ⚠️ No liability

---

## 📧 Contact & Support

**Author:** gynecoloji

**Get Help:**
- 🐛 **Bug Reports:** [Open an issue](https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/issues)
- 💬 **Questions:** [Start a discussion](https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/discussions)
- 📧 **Email:** [Contact via GitHub](https://github.com/gynecoloji)

**Community:**
- ⭐ Star this repo if you find it useful!
- 🔄 Fork it for your own modifications
- 📢 Share with colleagues

---

## 🙏 Acknowledgments

This pipeline integrates tools developed by the bioinformatics community. Special thanks to:

- The Snakemake team for the workflow framework
- All tool developers for their excellent software
- The Conda/Bioconda teams for package management
- Docker and Singularity communities for containerization support

---

## 📊 Pipeline Statistics

![Workflow](diagram.png)

- **Tools Integrated:** 10+
- **QC Metrics:** 20+
- **Containerization:** Docker + Singularity
- **Environments:** 4 isolated conda environments
- **Reproducibility:** All dependencies pinned

---

## 🚀 Quick Links

| Resource | Link |
|----------|------|
| 🏠 **Home** | [GitHub Repository](https://github.com/gynecoloji/Snakemake_RNA_seq_containerization) |
| 🐳 **Docker Hub** | [gynecoloji/rnaseq-pipeline](https://hub.docker.com/r/gynecoloji/rnaseq_pipeline) |
| 📖 **Documentation** | [Guides & Tutorials](#documentation) |
| 🐛 **Issues** | [Report Problems](https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/issues) |
| ⭐ **Star** | [Star this repo](https://github.com/gynecoloji/Snakemake_RNA_seq_containerization) |

---

## 📅 Version History

**v1.0** (January 2025)
- ✨ Initial release with Docker support
- ✨ Singularity/HPC integration
- ✨ Three integrated pipelines (RNA-seq, QC, Salmon)
- ✨ Comprehensive documentation
- ✨ Production-ready workflows

---

<div align="center">

**Built with ❤️ for the bioinformatics community**

Last updated: January 2025

[⬆ Back to Top](#advanced-rna-seq-analysis-pipeline)

</div>