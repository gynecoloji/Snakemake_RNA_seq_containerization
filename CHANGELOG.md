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
