# RNA-seq Snakemake workflow container.
#
# The workflow runs one conda env PER RULE (workflow/envs/*.yaml). This image
# ships Snakemake + the pre-built per-rule conda envs and runs --use-conda.
# Large genomes/FASTQs are NOT baked in — mount your project at runtime
# (see docker-compose.yml / run_pipeline.sh / DOCKER.md).

# For a fully reproducible build, pin the base, e.g. FROM condaforge/miniforge3:24.11.3-2
FROM condaforge/miniforge3:latest

LABEL org.opencontainers.image.title="rnaseq-snakemake"
LABEL org.opencontainers.image.description="RNA-seq (HISAT2 + QC + Salmon) Snakemake workflow, --use-conda"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    WF_CONDA_PREFIX=/opt/wf-conda

# Disable apt's privilege-dropping sandbox so the image also builds under a rootless
# engine (e.g. podman without /etc/subuid), mirroring apptainer.def. No-op under root
# docker (apt would run as root anyway).
RUN printf 'APT::Sandbox::User "root";\n' > /etc/apt/apt.conf.d/01-no-sandbox && \
    apt-get update && apt-get install -y --no-install-recommends \
        git procps ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# FLEXIBLE channel priority (the env YAMLs are fully-pinned exports spanning
# conda-forge/bioconda/defaults); best-effort accept the Anaconda defaults ToS.
RUN conda config --system --set channel_priority flexible && \
    ( conda tos accept --override-channels \
        --channel https://repo.anaconda.com/pkgs/main \
        --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true )

# Snakemake driver in its OWN env (miniforge base pins Python 3.13; snakemake
# needs <3.13). pandas is imported by common.smk at parse time.
RUN mamba create -y -n driver -c conda-forge -c bioconda \
        python=3.12 snakemake-minimal pandas && \
    mamba clean -afy
ENV PATH=/opt/conda/envs/driver/bin:$PATH

WORKDIR /workflow

# Pre-build the per-rule envs BEFORE copying workflow code (cache-friendly).
COPY workflow/envs/ ./workflow/envs/
COPY create_envs.smk ./
RUN snakemake -s create_envs.smk --use-conda --conda-create-envs-only \
        --conda-frontend mamba --conda-prefix "${WF_CONDA_PREFIX}" --cores 1 && \
    mamba clean -afy && \
    rm -rf build .snakemake

COPY workflow/ ./workflow/
COPY config/ ./config/
COPY tests/ ./tests/

ENTRYPOINT ["snakemake", "--use-conda", "--conda-frontend", "mamba", "--conda-prefix", "/opt/wf-conda"]
CMD ["-s", "workflow/Snakefile", "--cores", "4"]
