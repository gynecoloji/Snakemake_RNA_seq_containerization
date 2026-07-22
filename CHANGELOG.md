# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-22

Restructures the project into the [Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog/)
standardized `workflow/` + `config/` layout and consolidates the three
snakefiles into a single unified-DAG entry point, so the pipeline can be
deployed with `snakedeploy deploy-workflow` or imported via Snakemake's
`module` / `use rule` system. The scientific steps are unchanged.

### Added

- `workflow/Snakefile` — single entry point; a unified DAG builds the core
  RNA-seq stage, advanced QC, and Salmon quantification in dependency order.
  Run subsets with the `rna_all` / `qc_all` / `salmon_all` targets.
- `config/samples.csv` sample sheet and `samples_table` config key (sample
  discovery moved from `glob_wildcards`).
- `workflow/schemas/config.schema.yaml` — config validated on every run.
- `.snakemake-workflow-catalog.yml`, `.test/` fixture, and `images/rulegraph.svg`.
- `apptainer.def` native Apptainer build; `create_envs.smk` env pre-bake helper.
- CI (`.github/workflows/ci.yml`), release-please automation, `CITATION.cff`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`.

### Changed

- Restructured into the catalog layout: `envs/` → `workflow/envs/`;
  `config.yaml` → `config/config.yaml`; `snakefile_RNA` / `snakefile_RNAQC` /
  `snakefile_salmon` rule bodies → `workflow/rules/{rnaseq,qc,salmon}.smk` with a
  shared `common.smk`. Every rule now declares a `conda:` env.
- Docker image rebuilt on `condaforge/miniforge3` with the 4 per-rule conda envs
  pre-baked at `/opt/wf-conda` and a `snakemake` ENTRYPOINT; `docker-compose.yml`
  and the new `run_pipeline.sh` target `-s workflow/Snakefile`.
- `DOCKER.md` replaces `DOCKER_QUICKREF.md`; `README.md` updated with badges,
  the new targets, and a snakedeploy section.

### Removed

- Root `snakefile_RNA` / `snakefile_RNAQC` / `snakefile_salmon`, `entrypoint.sh`
  (superseded by `workflow/Snakefile` + the stage targets), and stale
  `snakemake_CLT` / `directory_tree` artifacts.

### Migration notes

- **Breaking:** `-s snakefile_RNA` (etc.) and the container's `--pipeline` flag no
  longer exist. Use `snakemake --use-conda -s workflow/Snakefile` with an optional
  `rna_all` / `qc_all` / `salmon_all` target. Configuration moved to `config/`.

[Unreleased]: https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/gynecoloji/Snakemake_RNA_seq_containerization/releases/tag/v1.0.0
