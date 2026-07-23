#!/usr/bin/env bash
# Build (once) and run the RNA-seq Snakemake workflow with Apptainer.
#
# Usage:
#   ./run_pipeline.sh                     # everything, 4 cores
#   ./run_pipeline.sh --cores 16          # everything, 16 cores
#   ./run_pipeline.sh --cores 16 rna_all  # core stage only
#   ./run_pipeline.sh --cores 8  deg_all  # opt-in DEG + enrichment
#   ./run_pipeline.sh -n                  # dry run
#
# Runs from the current directory (Apptainer auto-mounts the CWD, $HOME, and /tmp). The
# image runscript is `snakemake --use-conda --conda-frontend mamba --conda-prefix
# /opt/wf-conda`, so anything you pass here goes straight to snakemake. The pre-built
# conda envs live in the image at /opt/wf-conda and are reused via --conda-prefix.
set -euo pipefail

SIF="rnaseq-pipeline.sif"

if [ "$#" -eq 0 ]; then set -- --cores 4; fi   # default snakemake args

if [ ! -f "$SIF" ]; then
    echo ">> Building $SIF (first time only; pre-builds the conda envs — heavy, best as a batch job)..."
    apptainer build --fakeroot "$SIF" apptainer.def
fi

echo ">> apptainer run $SIF -s workflow/Snakefile $*"
apptainer run "$SIF" -s workflow/Snakefile "$@"
