# 🐳 Docker Setup Guide for SnakeMake RNA-seq Pipeline

## 📦 What Was Created

This professional Docker setup includes 6 files that will containerize your entire RNA-seq pipeline:

### 1. **Dockerfile** 
Main container definition that:
- Uses Miniconda3 as base image
- Installs all system dependencies (Java, build tools, etc.)
- Creates all 4 conda environments (snakemake, qualimap, RSeQC, salmon)
- Sets up the complete pipeline structure
- Optimized with multi-stage caching for faster builds

### 2. **docker-compose.yml**
Orchestration file that:
- Simplifies running the container with proper volume mounts
- Manages resource limits (20 CPUs, 64GB RAM by default)
- Provides environment variables for easy configuration
- Includes optional Jupyter notebook service for downstream analysis

### 3. **entrypoint.sh**
Smart entry script that:
- Accepts command-line arguments (--pipeline, --cores, --dry-run)
- Runs pipelines individually or all sequentially
- Provides colored, user-friendly output
- Validates data presence before running
- Handles errors gracefully with informative messages

### 4. **.dockerignore**
Build optimization file that:
- Excludes large data files from Docker image
- Prevents git history from being copied
- Removes build artifacts and cache files
- Keeps image size minimal (~2-3GB instead of 10GB+)

### 5. **README_Docker.md**
Comprehensive documentation with:
- Step-by-step installation instructions
- Docker and local usage comparisons
- Advanced usage examples
- Troubleshooting guide
- Best practices and pro tips

### 6. **DOCKER_QUICKREF.md**
Quick reference card with:
- Common commands cheat sheet
- Example workflows
- Resource management tips
- Directory structure guide

---

## 🚀 How to Deploy

### Step 1: Add Files to Your Repository

Copy all files from this setup to your GitHub repository root:

```bash
# Copy files to your repo (adjust path as needed)
cp Dockerfile docker-compose.yml entrypoint.sh .dockerignore /path/to/SnakeMake_RNAseq/
cp README_Docker.md /path/to/SnakeMake_RNAseq/
cp DOCKER_QUICKREF.md /path/to/SnakeMake_RNAseq/

# Make entrypoint executable
chmod +x /path/to/SnakeMake_RNAseq/entrypoint.sh
```

### Step 2: Update Your Repository

```bash
cd /path/to/SnakeMake_RNAseq
git add Dockerfile docker-compose.yml entrypoint.sh .dockerignore README_Docker.md DOCKER_QUICKREF.md
git commit -m "Add Docker support for easy deployment"
git push origin main
```

### Step 3: Optional - Replace Original README

```bash
# Backup original
mv README.md README_original.md

# Use Docker version
mv README_Docker.md README.md

git add README.md README_original.md
git commit -m "Update README with Docker instructions"
git push origin main
```

---

## 🎯 Usage Examples

### For End Users (Easiest)

```bash
# Clone your repo
git clone https://github.com/gynecoloji/SnakeMake_RNAseq.git
cd SnakeMake_RNAseq

# Prepare data
mkdir -p data ref
cp /your/fastq/files/*_R1_001.fastq.gz data/
cp /your/fastq/files/*_R2_001.fastq.gz data/
cp /your/references/* ref/

# Build and run
docker-compose build
docker-compose up
```

### For Developers

```bash
# Test dry run
docker-compose run rnaseq-pipeline --dry-run

# Run specific pipeline
docker-compose run rnaseq-pipeline --pipeline rna --cores 10

# Debug in shell
docker-compose run rnaseq-pipeline --shell
```

### For HPC/Cluster Users

```bash
# Build once
docker build -t rnaseq-pipeline:latest .

# Save as tar (for offline transfer)
docker save rnaseq-pipeline:latest | gzip > rnaseq-pipeline.tar.gz

# On cluster: Load image
docker load < rnaseq-pipeline.tar.gz

# Run with Slurm/PBS
docker run --rm \
  -v $PWD/data:/pipeline/data \
  -v $PWD/ref:/pipeline/ref \
  -v $PWD/results:/pipeline/results \
  --cpus=20 --memory=64g \
  rnaseq-pipeline:latest --cores 20
```

---

## 🎨 Customization Options

### Adjust Resource Limits

Edit `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '10'      # Change from 20 to 10
      memory: 32G     # Change from 64G to 32G
```

### Change Default Cores

Edit `docker-compose.yml`:

```yaml
environment:
  - THREADS=10           # Change from 20 to 10
  - SNAKEMAKE_CORES=10   # Change from 20 to 10
```

### Add Custom Reference Paths

Edit `Dockerfile` or mount additional volumes:

```yaml
volumes:
  - ./my_custom_refs:/pipeline/custom_refs
```

### Modify Pipeline Behavior

Edit the Snakefiles directly - they're mounted as volumes, so changes take effect immediately without rebuilding:

```yaml
volumes:
  - ./snakefile_RNA:/pipeline/snakefile_RNA
```

### Tune Pipeline Parameters via `config.yaml`

Most parameters (reference paths, per-rule threads, fastp/HISAT2/featureCounts/Salmon flags, Qualimap memory, library protocol) live in **`config.yaml`** at the repo root. Edit it once instead of touching the snakefiles:

```yaml
# config.yaml — examples
references:
  hisat2_index: "ref/mouse/genome"
  gtf:          "ref/Mus_musculus.GRCm39.110.gtf"

featurecounts:
  strandedness: 1            # 0 = unstranded, 1 = forward, 2 = reverse

threads:
  hisat2: 8                  # ↓ for low-RAM machines
```

**Override at runtime without editing the file:**

```bash
# Use a different config
snakemake --configfile my_config.yaml --cores 20 -s snakefile_RNA

# Override single key
snakemake --config references=hisat2_index=ref/mouse/genome --cores 20 -s snakefile_RNA

# Inside Docker — bind-mount your config over the baked-in default
docker run --rm \
  -v $(pwd)/data:/pipeline/data \
  -v $(pwd)/ref:/pipeline/ref \
  -v $(pwd)/config.yaml:/pipeline/config.yaml \
  rnaseq-pipeline:latest
```

See the full annotated reference in [`config.yaml`](config.yaml).

---

## 📊 Best Practices

### 1. **Data Organization**
```
project/
├── SnakeMake_RNAseq/    # Your cloned repo
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── ...
├── data/                 # Symlink or mount
├── ref/                  # Symlink or mount
└── results/             # Pipeline outputs
```

### 2. **Version Control**
- Tag Docker images with versions: `docker build -t rnaseq-pipeline:v1.0 .`
- Use semantic versioning for releases
- Keep changelog in README

### 3. **Performance**
- Use SSD for data/results directories
- Allocate sufficient RAM (minimum 32GB, recommended 64GB)
- Monitor with `docker stats` during runs

### 4. **Reproducibility**
- Pin all conda package versions in YAML files ✓ (already done)
- Document reference genome versions in README
- Include MD5 checksums for reference files

### 5. **Security**
- Don't include sensitive data in Docker image
- Use volumes for all data/results
- Run with user permissions (add to Dockerfile if needed)

---

## 🔍 Verification Checklist

Before pushing to GitHub:

- [ ] All 6 files are in repository root
- [ ] `entrypoint.sh` is executable (chmod +x)
- [ ] `.dockerignore` excludes large files
- [ ] `docker-compose.yml` has correct volume paths
- [ ] Documentation is clear and complete
- [ ] Example data paths are updated in README
- [ ] License file exists (MIT ✓)

Build test:
- [ ] `docker-compose build` completes successfully
- [ ] Image size is reasonable (<5GB)
- [ ] `docker run ... --help` shows correct help text
- [ ] Dry run works: `docker-compose run rnaseq-pipeline --dry-run`

---

## 📈 Next Steps

### 1. Add CI/CD (GitHub Actions)

Create `.github/workflows/docker.yml`:

```yaml
name: Build Docker Image

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Build Docker image
      run: docker build -t rnaseq-pipeline:latest .
    - name: Test help command
      run: docker run --rm rnaseq-pipeline:latest --help
```

### 2. Publish to Docker Hub

```bash
# Login
docker login

# Tag
docker tag rnaseq-pipeline:latest yourusername/rnaseq-pipeline:latest
docker tag rnaseq-pipeline:latest yourusername/rnaseq-pipeline:v1.0

# Push
docker push yourusername/rnaseq-pipeline:latest
docker push yourusername/rnaseq-pipeline:v1.0
```

Then users can simply:
```bash
docker pull yourusername/rnaseq-pipeline:latest
```

### 3. Add Example Dataset

Create a small test dataset for users to try:

```bash
mkdir -p test_data/
# Add small FASTQ files (e.g., 10K reads)
# Add mini reference files
```

### 4. Create Video Tutorial

Record a quick demo showing:
- How to clone and setup
- Running the pipeline
- Viewing results

---

## 🆘 Support

If users encounter issues:

1. Check DOCKER_QUICKREF.md for common solutions
2. Open GitHub issue with:
   - Docker version: `docker --version`
   - Error messages
   - System specs (RAM, CPU)

---

## ✅ Summary

Your pipeline is now professionally containerized with:
- ✅ Easy one-command deployment
- ✅ Reproducible environment
- ✅ Clear documentation
- ✅ Flexible configuration
- ✅ Production-ready setup

Users can now run your complex RNA-seq pipeline without installing any bioinformatics tools manually!

---

**Created**: Dec 29, 2025  
**Author**: gynecoloji  
**Docker Support**: Ready for production
