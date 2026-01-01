#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CORES=${SNAKEMAKE_CORES:-20}
PIPELINE="all"
DRY_RUN=false

# Help function
show_help() {
    cat << EOF
${GREEN}Advanced RNA-seq Analysis Pipeline - Docker Version${NC}

Usage: docker run [docker-options] rnaseq-pipeline:latest [options]

Options:
    --help              Show this help message
    --dry-run           Perform a dry run (don't execute, just show what would run)
    --cores N           Number of cores to use (default: 20)
    --pipeline PIPE     Which pipeline to run: rna, qc, salmon, or all (default: all)
    --shell             Start an interactive shell instead of running pipeline
    
Pipeline Options:
    rna                 Run core RNA-seq processing (snakefile_RNA)
    qc                  Run advanced QC analysis (snakefile_RNAQC)
    salmon              Run Salmon quantification (snakefile_salmon)
    all                 Run all three pipelines sequentially (default)

Examples:
    # Run full pipeline with 20 cores
    docker run --rm -v \$(pwd)/data:/pipeline/data rnaseq-pipeline:latest
    
    # Dry run to check workflow
    docker run --rm -v \$(pwd)/data:/pipeline/data rnaseq-pipeline:latest --dry-run
    
    # Run only core RNA-seq pipeline with 10 cores
    docker run --rm -v \$(pwd)/data:/pipeline/data rnaseq-pipeline:latest --pipeline rna --cores 10
    
    # Start interactive shell
    docker run --rm -it -v \$(pwd)/data:/pipeline/data rnaseq-pipeline:latest --shell

Using docker-compose:
    # Build and run full pipeline
    docker-compose up
    
    # Run with custom command
    docker-compose run rnaseq-pipeline --pipeline rna --cores 10
    
    # Interactive shell
    docker-compose run rnaseq-pipeline --shell

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --pipeline)
            PIPELINE="$2"
            shift 2
            ;;
        --shell)
            echo -e "${GREEN}Starting interactive shell...${NC}"
            exec /bin/bash
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Activate conda base environment
source /opt/conda/etc/profile.d/conda.sh

# Check if data directory has files
if [ -z "$(ls -A /pipeline/data/*.fastq.gz 2>/dev/null)" ]; then
    echo -e "${YELLOW}Warning: No FASTQ files found in /pipeline/data/${NC}"
    echo -e "${YELLOW}Please mount your data directory with FASTQ files${NC}"
    echo -e "${YELLOW}Example: docker run -v /path/to/your/data:/pipeline/data rnaseq-pipeline:latest${NC}"
fi

# Function to run snakemake
run_snakemake() {
    local snakefile=$1
    local description=$2
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Running: $description${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN MODE - No actual execution${NC}"
        conda run -n snakemake snakemake -n -s "$snakefile" -p
    else
        conda run -n snakemake snakemake --use-conda --cores "$CORES" -s "$snakefile" -p
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $description completed successfully${NC}"
    else
        echo -e "${RED}✗ $description failed${NC}"
        exit 1
    fi
}

# Run pipeline based on selection
echo -e "${GREEN}Starting RNA-seq Pipeline with $CORES cores${NC}"
echo -e "${GREEN}Pipeline mode: $PIPELINE${NC}"

case $PIPELINE in
    rna)
        run_snakemake "snakefile_RNA" "Core RNA-seq Processing"
        ;;
    qc)
        run_snakemake "snakefile_RNAQC" "Advanced RNA-seq QC"
        ;;
    salmon)
        run_snakemake "snakefile_salmon" "Salmon Quantification"
        ;;
    all)
        run_snakemake "snakefile_RNA" "Core RNA-seq Processing"
        run_snakemake "snakefile_RNAQC" "Advanced RNA-seq QC"
        run_snakemake "snakefile_salmon" "Salmon Quantification"
        ;;
    *)
        echo -e "${RED}Unknown pipeline: $PIPELINE${NC}"
        echo -e "${YELLOW}Valid options: rna, qc, salmon, all${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All pipelines completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Results are available in: /pipeline/results${NC}"
