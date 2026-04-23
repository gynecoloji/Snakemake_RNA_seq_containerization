# Use Miniconda3 as base image
FROM continuumio/miniconda3:latest

# IMPORTANT: Use bash instead of sh
SHELL ["/bin/bash", "-c"]

# Set metadata
LABEL maintainer="gynecoloji"
LABEL description="Docker image for Advanced RNA-seq Analysis Pipeline"
LABEL version="1.0"

# Set working directory
WORKDIR /pipeline

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    curl \
    default-jdk \
    libz-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy environment files first (for better caching)
COPY envs/ /pipeline/envs/

# Create conda environments
RUN conda env create -f /pipeline/envs/snakemake.yaml && \
    conda env create -f /pipeline/envs/qualimap.yaml && \
    conda env create -f /pipeline/envs/RSeQC.yaml && \
    conda env create -f /pipeline/envs/salmon.yaml && \
    conda clean -a -y

# Initialize conda and set default environment
RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda init bash && \
    echo "conda activate snakemake" >> ~/.bashrc

# Add snakemake environment to PATH (so it works with --no-home)
ENV PATH="/opt/conda/envs/snakemake/bin:$PATH"

# Copy the entire pipeline
COPY . /pipeline/

# Create necessary directories
RUN mkdir -p /pipeline/data \
    /pipeline/results \
    /pipeline/logs \
    /pipeline/ref

# Make entrypoint script executable
RUN chmod +x /pipeline/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/pipeline/entrypoint.sh"]

# Default command
CMD ["--help"]