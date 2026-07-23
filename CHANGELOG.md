# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.0.0...v1.1.0) (2026-07-23)


### Added

* build HISAT2 and Salmon indexes on demand from FASTA ([4e05ad3](https://github.com/gynecoloji/snakemake_RNAseq/commit/4e05ad370aeb4895c4864617b97651ba4ad398de))
* container parity (miniforge3 + pre-baked envs + Apptainer); drop entrypoint dispatcher ([21ee93a](https://github.com/gynecoloji/snakemake_RNAseq/commit/21ee93a841e771165bb01890f0030784fb58d515))


### Changed

* add advanced-QC stage (qc_all) to the unified DAG ([943e171](https://github.com/gynecoloji/snakemake_RNAseq/commit/943e171289e887df0817603762350e9125a0d1d8))
* add Salmon stage (salmon_all) and rule-graph image ([0889919](https://github.com/gynecoloji/snakemake_RNAseq/commit/0889919b45402ad940ce6285d103169058e53fba))
* add unified workflow/ layout with core RNA-seq stage ([2758053](https://github.com/gynecoloji/snakemake_RNAseq/commit/2758053dc5a6d0adb4e285bef18ccd158232efd7))
* move config to config/ and add sample sheet + schema ([2772a6c](https://github.com/gynecoloji/snakemake_RNAseq/commit/2772a6ccd3197d9290bc8705483a4e5bc0a398da))


### Documentation

* add citation, changelog, contributing, code of conduct; refresh git metadata ([3a81272](https://github.com/gynecoloji/snakemake_RNAseq/commit/3a81272017b67a380b644ad1ff9f639f96019cbc))
* update README + guides for the unified workflow layout ([032ccee](https://github.com/gynecoloji/snakemake_RNAseq/commit/032ccee91ede918e57d626e0862266d07e84c1ab))
* use canonical repo name gynecoloji/snakemake_RNAseq ([54eb7cb](https://github.com/gynecoloji/snakemake_RNAseq/commit/54eb7cb60fcf9979fca9dd62f67e6c463877b748))

## [Unreleased]

### Added

- On-demand index building: `hisat2_build`, `salmon_index`, and
  `salmon_decoy_index` rules build the HISAT2 and Salmon (standard + decoy-aware)
  indexes from `references.genome_fasta` / `references.transcriptome_fasta` when
  the indexes are absent, and are skipped when a pre-built index is present. Adds
  an `index:` config section (`hisat2_splice_aware`, `salmon_kmer`).

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

[Unreleased]: https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/gynecoloji/snakemake_RNAseq/releases/tag/v1.0.0
