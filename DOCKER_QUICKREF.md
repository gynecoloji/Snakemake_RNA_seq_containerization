# 🐳 Docker Quick Reference - RNA-seq Pipeline

## Build & Setup

```bash
# Clone repository
git clone https://github.com/gynecoloji/SnakeMake_RNAseq.git
cd SnakeMake_RNAseq

# Build image
docker-compose build

# Or with Docker
docker build -t rnaseq-pipeline:latest .
```

## Running the Pipeline

### Using Docker Compose (Easiest)

```bash
# Run all pipelines
docker-compose up

# Run specific pipeline
docker-compose run rnaseq-pipeline --pipeline rna
docker-compose run rnaseq-pipeline --pipeline qc
docker-compose run rnaseq-pipeline --pipeline salmon

# Dry run
docker-compose run rnaseq-pipeline --dry-run

# Custom cores
docker-compose run rnaseq-pipeline --cores 15

# Interactive shell
docker-compose run rnaseq-pipeline --shell
```

### Using Docker Directly

```bash
# Full pipeline
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  -v $(pwd)/logs:/pipeline/logs \
  rnaseq-pipeline:latest

# Specific pipeline with options
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  rnaseq-pipeline:latest --pipeline rna --cores 10

# Override the baked-in config.yaml at runtime
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/results:/pipeline/results \
  -v $(pwd)/config.yaml:/pipeline/config.yaml \
  rnaseq-pipeline:latest

# Help
docker run --rm rnaseq-pipeline:latest --help
```

## Common Commands

```bash
# View running containers
docker ps

# View logs
docker-compose logs -f

# Stop containers
docker-compose down

# Remove everything (including volumes)
docker-compose down -v

# Check resource usage
docker stats

# Clean up
docker system prune -a
```

## Directory Structure

```
SnakeMake_RNAseq/
├── config.yaml              # All tunable parameters (mountable)
├── data/                    # Mount: Your FASTQ files here
│   ├── sample1_R1_001.fastq.gz
│   └── sample1_R2_001.fastq.gz
├── ref/                     # Mount: Reference files
│   ├── ENSEMBL/
│   ├── Homo_sapiens.GRCh38.102.gtf
│   └── Salmon_index_Grch38/
├── results/                 # Mount: Pipeline outputs
└── logs/                    # Mount: Log files
```

## Configuration

All tunable parameters live in **`config.yaml`** (reference paths, per-rule threads, fastp/HISAT2/featureCounts/Salmon flags, Qualimap protocol). Edit it directly, or override at runtime:

```bash
# Bind-mount your custom config over the baked-in default
docker run --rm \
  -v $(pwd)/config.yaml:/pipeline/config.yaml \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  rnaseq-pipeline:latest
```

See README.md → **Configuration** for the full key reference.

## Pipeline Options

| Option | Description | Default |
|--------|-------------|---------|
| `--pipeline` | Which pipeline: rna, qc, salmon, all | all |
| `--cores` | Number of CPU cores | 20 |
| `--dry-run` | Show what will run without executing | false |
| `--shell` | Start interactive bash shell | - |
| `--help` | Show help message | - |

## Troubleshooting

```bash
# Check if data is mounted correctly
docker run --rm -v $(pwd)/data:/pipeline/data rnaseq-pipeline:latest ls -la /pipeline/data

# Fix file permissions
sudo chown -R $USER:$USER results/ logs/

# Rebuild image
docker-compose build --no-cache

# Interactive debugging
docker-compose run rnaseq-pipeline --shell
# Inside container:
conda activate snakemake
snakemake -n -s snakefile_RNA
```

## Resource Management

```bash
# Set custom resources in docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '10'
      memory: 32G

# Or via Docker
docker run --cpus=10 --memory=32g ...
```

## Tips

- Always run `--dry-run` first to check workflow
- Monitor with `docker stats` in another terminal
- Use `docker-compose` for easier management
- Check `results/multiqc_report.html` for QC summary
- Reference files should be prepared beforehand

## Example Workflow

```bash
# 1. Prepare your data
mkdir -p data ref results logs
cp /path/to/samples/*_R1_001.fastq.gz data/
cp /path/to/samples/*_R2_001.fastq.gz data/

# 2. Add reference files
cp /path/to/references/* ref/

# 3. Dry run to check
docker-compose run rnaseq-pipeline --dry-run

# 4. Run pipeline
docker-compose up

# 5. Check results
firefox results/multiqc_report.html
```

## Pipeline Stages

1. **RNA** (snakefile_RNA): FastQC → fastp → HISAT2 → samtools → featureCounts → MultiQC
2. **QC** (snakefile_RNAQC): Picard → Qualimap → RSeQC
3. **Salmon** (snakefile_salmon): Transcript quantification with standard & decoy indices

---
For detailed documentation, see README.md
