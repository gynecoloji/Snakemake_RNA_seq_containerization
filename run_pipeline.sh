#!/usr/bin/env bash
# Build (once) and run the RNA-seq Snakemake workflow in Docker.
#
# The workflow is the standard-layout workflow/Snakefile: a single run builds the
# core stage, advanced QC, and Salmon quantification (unified DAG). Pass extra
# snakemake args (cores, a target, -n, ...) through to the container.
#
# Usage:
#   ./run_pipeline.sh                     # everything, 4 cores
#   ./run_pipeline.sh --cores 16          # everything, 16 cores
#   ./run_pipeline.sh --cores 16 rna_all  # core stage only
#   ./run_pipeline.sh --cores 16 qc_all   # advanced QC only
#   ./run_pipeline.sh --cores 16 salmon_all  # Salmon only
#   ./run_pipeline.sh -n                  # dry run
#
# The current directory (code + ref/ genomes + data/ FASTQs) is mounted at
# /workflow; results/ are written back here. Pre-built conda envs live in the
# image at /opt/wf-conda and are reused via --conda-prefix. The image ENTRYPOINT
# runs `snakemake --use-conda ...`.
set -euo pipefail

IMAGE="rnaseq-pipeline:latest"

if [ "$#" -eq 0 ]; then set -- --cores 4; fi   # default snakemake args

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo ">> Building $IMAGE (first time only; pre-builds the conda envs)..."
    docker build -t "$IMAGE" .
fi

echo ">> snakemake -s workflow/Snakefile $*"
docker run --rm \
    -v "$(pwd)":/workflow \
    -e HOME=/tmp \
    --user "$(id -u):$(id -g)" \
    "$IMAGE" -s workflow/Snakefile "$@"
