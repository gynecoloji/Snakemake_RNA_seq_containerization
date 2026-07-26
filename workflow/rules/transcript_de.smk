# Transcript-level differential EXPRESSION (DTE) — statistically-correct successor
# to the naive det.smk. Pipeline:
#   T1  salmon_boot_quant : bootstrap + bias-aware Salmon quant (decoy index only)
#   T0  tx2gene           : transcript->gene map keyed on Salmon's own Name column
#   T2  dte_catchsalmon   : edgeR catchSalmon — divides out per-transcript
#                           read-to-transcript-ambiguity (RTA) overdispersion before
#                           NB inference, restoring valid FDR control at transcript level
#
# Why this replaces det.smk: NumReads->DESeq2 (det.smk) ignores RTA overdispersion,
# which does not follow the abundance-dependent mean-variance trend empirical-Bayes
# shrinkage assumes, so transcript-level FDR is not controlled. catchSalmon estimates
# that overdispersion from the Salmon bootstraps and divides it out (catchsalmon2024).
#
# Opt-in. Needs >=2 levels in the samples.csv condition column and, for trustworthy
# statistics, >=3 replicates/group. Uses the decoy-aware index only (§0.4).

TXCFG      = config.get("transcript_de", {})
TXQ_DIR    = f"{RESULTS}/quants_boot"          # T1 bootstrap quants (separate from det.smk quants)
TX_DIR     = f"{RESULTS}/transcript"
TX2GENE    = f"{RESULTS}/reference/tx2gene.tsv"

TX_NBOOT   = TXCFG.get("num_bootstraps", 100)
TX_INFER   = TXCFG.get("inference", "bootstrap")   # bootstrap (T2) | gibbs (T5 swish)
TX_LIBTYPE = config["salmon"]["lib_type"]          # inherited; no strandedness handling here
TX_COVARS  = TXCFG.get("covariates", []) or []


# ---------------------------------------------------------------------------
# T1 · bootstrap + bias-aware quantification  (prerequisite for catchSalmon)
# ---------------------------------------------------------------------------
rule txq_all:
    input:
        expand(f"{TXQ_DIR}/{{sample}}_quant/quant.sf", sample=SAMPLES),


rule salmon_boot_quant:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}_R1.trimmed.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_R2.trimmed.fastq.gz",
        index=f"{SALMON_DECOY_INDEX}/info.json",
    output:
        quant=f"{TXQ_DIR}/{{sample}}_quant/quant.sf",
        meta=f"{TXQ_DIR}/{{sample}}_quant/aux_info/meta_info.json",
    params:
        index=SALMON_DECOY_INDEX,
        outdir=lambda w: f"{TXQ_DIR}/{w.sample}_quant",
        libtype=TX_LIBTYPE,
        infer=("--numGibbsSamples" if TX_INFER == "gibbs" else "--numBootstraps"),
        nboot=TX_NBOOT,
        thin=("--thinningFactor 16" if TX_INFER == "gibbs" else ""),
    threads: config["threads"]["salmon"]
    log:
        f"{LOGS}/transcript/salmon_boot_{{sample}}.log",
    conda:
        "../envs/salmon.yaml"
    shell:
        """
        mkdir -p {params.outdir} $(dirname {log})
        salmon quant \
            -i {params.index} -l {params.libtype} -p {threads} \
            -1 {input.r1} -2 {input.r2} -o {params.outdir} \
            --validateMappings --seqBias --gcBias --posBias \
            --rangeFactorizationBins 4 \
            {params.infer} {params.nboot} {params.thin} \
            > {log} 2>&1
        """


# ---------------------------------------------------------------------------
# T0 · tx2gene keyed on Salmon's full pipe-delimited Name (see Finding 3)
# ---------------------------------------------------------------------------
# GENCODE pipe fields: 1=ENST.v 2=ENSG.v ... 6=symbol 8=tx_biotype. Deriving the
# map from quant.sf itself makes keys match the count matrix rownames by construction.
rule tx2gene:
    input:
        quant=f"{TXQ_DIR}/{SAMPLES[0]}_quant/quant.sf",
    output:
        TX2GENE,
    log:
        f"{LOGS}/transcript/tx2gene.log",
    conda:
        "../envs/snakemake.yaml"
    shell:
        r"""
        mkdir -p $(dirname {output}) $(dirname {log})
        awk -F'\t' 'BEGIN{{OFS="\t"; print "TXNAME","TXID","GENEID","GENESYMBOL","BIOTYPE"}}
             NR>1 {{
               n=split($1, f, "|");
               if (n>=6) print $1, f[1], f[2], f[6], (n>=8 ? f[8] : "");
               else      print $1, $1, "",   "",   ""      # non-GENCODE header: passthrough
             }}' {input.quant} > {output} 2> {log}
        echo "blank GENEID rows: $(awk -F'\t' 'NR>1 && $3==\"\"' {output} | wc -l)" >> {log}
        """


# ---------------------------------------------------------------------------
# T2 · DTE via edgeR catchSalmon  (the primary deliverable)
# ---------------------------------------------------------------------------
rule dte_all:
    input:
        expand(f"{TX_DIR}/dte/{{contrast}}/dte_results.tsv", contrast=DEG_CONTRASTS),


rule dte_catchsalmon:
    input:
        quants=expand(f"{TXQ_DIR}/{{sample}}_quant/quant.sf", sample=SAMPLES),
        samples=config["samples_table"],
        tx2gene=TX2GENE,
    output:
        results=f"{TX_DIR}/dte/{{contrast}}/dte_results.tsv",
        significant=f"{TX_DIR}/dte/{{contrast}}/significant.tsv",
        gene_simes=f"{TX_DIR}/dte/{{contrast}}/gene_level_simes.tsv",
        overdisp=f"{TX_DIR}/dte/{{contrast}}/overdispersion.tsv",
        counts=f"{TX_DIR}/dte/{{contrast}}/divided_counts.tsv",
        mds=f"{TX_DIR}/dte/{{contrast}}/qc_mds.png",
        bcv=f"{TX_DIR}/dte/{{contrast}}/qc_bcv.png",
        md=f"{TX_DIR}/dte/{{contrast}}/ma_plot.png",
        volcano=f"{TX_DIR}/dte/{{contrast}}/volcano.png",
    params:
        quant_root=TXQ_DIR,
        condition_col=DEG_CONDITION_COL,
        level=lambda w: DEG_CONTRAST_LEVEL[w.contrast],
        reference=DEG_REFERENCE,
        covariates=TX_COVARS,
        padj=DEG_PADJ,
        lfc=TXCFG.get("dte_lfc", 1.0),
        outdir=lambda w: f"{TX_DIR}/dte/{w.contrast}",
    threads: 4
    log:
        f"{LOGS}/transcript/dte_{{contrast}}.log",
    conda:
        "../envs/r-transcript.yaml"
    script:
        "../scripts/tx_dte_edger.R"
