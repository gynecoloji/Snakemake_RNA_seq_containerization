# Build-time helper: pre-create the per-rule conda envs (workflow/envs/*.yaml)
# so they are baked into the image and reused at runtime via --conda-prefix.
# Used only by apptainer.def:
#   snakemake -s create_envs.smk --use-conda --conda-create-envs-only \
#       --conda-frontend mamba --conda-prefix /opt/wf-conda --cores 1

ENVS = ["snakemake", "qualimap", "RSeQC", "salmon", "ucsc", "r-deg"]


rule all:
    input:
        expand("build/conda_env_{env}.ready", env=ENVS),


rule create_env:
    output:
        "build/conda_env_{env}.ready",
    conda:
        "workflow/envs/{env}.yaml"
    shell:
        "touch {output}"
