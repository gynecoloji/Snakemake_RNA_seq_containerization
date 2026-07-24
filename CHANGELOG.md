# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.1](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.4.0...v1.4.1) (2026-07-24)


### Fixed

* make the Apptainer build work rootless (no /etc/subuid) ([d6ae52e](https://github.com/gynecoloji/snakemake_RNAseq/commit/d6ae52ebf9b206c82f4f21e8da9e597458fb1e04))
* mirror the rootless-apt sandbox fix into the Dockerfile ([e6e10ed](https://github.com/gynecoloji/snakemake_RNAseq/commit/e6e10edc67a2f683f3c49df6dd0f080e6d824023))

## [1.4.0](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.3.0...v1.4.0) (2026-07-23)


### Added

* add opt-in DESeq2 differential-expression + GO/KEGG enrichment stage ([2e0ce38](https://github.com/gynecoloji/snakemake_RNAseq/commit/2e0ce387e369fc71d77ffc37ab8c8500093c5526))
* add opt-in DESeq2 differential-expression + GO/KEGG enrichment stage ([9ffe263](https://github.com/gynecoloji/snakemake_RNAseq/commit/9ffe263cc6ac44f80568a5d92361a390ef36c41e))

## [1.3.0](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.2.1...v1.3.0) (2026-07-23)


### Added

* build the RSeQC gene-model BED from the GTF on demand ([c638e6f](https://github.com/gynecoloji/snakemake_RNAseq/commit/c638e6fea5074631bafeaf09297fcffab4205c88))
* GENCODE v36 reference support + on-demand RSeQC BED generation ([4eeaf38](https://github.com/gynecoloji/snakemake_RNAseq/commit/4eeaf38e04835093b0413e163c6cb52560ad8a17))


### Fixed

* point config at the GENCODE v36 GTF shipped in ref/ ([8da675d](https://github.com/gynecoloji/snakemake_RNAseq/commit/8da675dd4998eb16804739ede14b92e502fb7a9f))


### Documentation

* switch reference download links to GENCODE v36 to match the shipped GTF ([db92dd6](https://github.com/gynecoloji/snakemake_RNAseq/commit/db92dd6ce1b7a8581f0bdf4365ab0d7d509a056c))

## [1.2.1](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.2.0...v1.2.1) (2026-07-23)


### Documentation

* add Zenodo DOI badge and CITATION.cff identifier ([a37b981](https://github.com/gynecoloji/snakemake_RNAseq/commit/a37b9811ebf65e3caea14b1f800e2227b1df2302))
* note the align_chroms/keep_chroms chromosome filters in Configuration ([1860cc7](https://github.com/gynecoloji/snakemake_RNAseq/commit/1860cc7edba009fbdca813e05e2c4df8863170dd))

## [1.2.0](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.1.1...v1.2.0) (2026-07-23)


### Added

* add chromosome-selection filters for alignment ([a618af9](https://github.com/gynecoloji/snakemake_RNAseq/commit/a618af98126d70e4e720557e293556d8b2b470f4))
* add chromosome-selection filters for alignment ([fac6c56](https://github.com/gynecoloji/snakemake_RNAseq/commit/fac6c56f644651b0cd3b1ef73be299b78e309f6e))

## [1.1.1](https://github.com/gynecoloji/snakemake_RNAseq/compare/v1.1.0...v1.1.1) (2026-07-23)


### Documentation

* align README with the ATAC-seq template; tidy changelog, badges, and images ([e58f762](https://github.com/gynecoloji/snakemake_RNAseq/commit/e58f762cd8a7c7ef4e999bb1303682ee3f8287f3))
* apply the ATAC-seq-style README rewrite ([ea8f718](https://github.com/gynecoloji/snakemake_RNAseq/commit/ea8f7181b998af14437dbe469964c7830b4967d1))
* move diagram.png into images/ and drop rulegraph.svg ([00819bb](https://github.com/gynecoloji/snakemake_RNAseq/commit/00819bb9a97edc1e1a19f53d4ecfb7ba4ef31ec1))
* remove duplicate pipeline figure from README ([ddcb985](https://github.com/gynecoloji/snakemake_RNAseq/commit/ddcb985a0af2395d34fc6ad52ce275cb77e02272))
* rewrite README in the ATAC-seq template style; drop redundant guides ([aa8c95e](https://github.com/gynecoloji/snakemake_RNAseq/commit/aa8c95ef4725a6a361a4cb04588c334dfc901602))
* tidy changelog and refresh README badges ([a30f19c](https://github.com/gynecoloji/snakemake_RNAseq/commit/a30f19c8e0e07d9ade8d2d79be9ee8bc04672978))

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
