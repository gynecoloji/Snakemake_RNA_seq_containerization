# Core RNA-seq stage: FastQC → fastp → HISAT2 → samtools → featureCounts → MultiQC.
# Ported from the former snakefile_RNA (behaviour unchanged); every rule now
# declares conda: ../envs/snakemake.yaml so a single --use-conda run works.


rule rna_all:
    input:
        f"{RESULTS}/featurecounts/featureCount.txt",
        f"{RESULTS}/multiqc_report.html",


# Rule: FastQC on raw reads
rule fastqc_raw:
    input:
        r1=f"{DATA}/{{sample}}{R1_SUFFIX}",
        r2=f"{DATA}/{{sample}}{R2_SUFFIX}",
    output:
        html_r1=f"{RESULTS}/fastqc/raw/{{sample}}_R1_001_fastqc.html",
        html_r2=f"{RESULTS}/fastqc/raw/{{sample}}_R2_001_fastqc.html",
    log:
        f"{LOGS}/fastqc/{{sample}}.log",
    threads: config["threads"]["fastqc"]
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {RESULTS}/fastqc/raw {LOGS}/fastqc
        fastqc -t {threads} -o {RESULTS}/fastqc/raw {input.r1} {input.r2} &> {log}
        """


# Rule: Trim reads with fastp
rule fastp_trim:
    input:
        r1=f"{DATA}/{{sample}}{R1_SUFFIX}",
        r2=f"{DATA}/{{sample}}{R2_SUFFIX}",
    output:
        r1_trimmed=f"{RESULTS}/trimmed/{{sample}}_R1.trimmed.fastq.gz",
        r2_trimmed=f"{RESULTS}/trimmed/{{sample}}_R2.trimmed.fastq.gz",
        html=f"{RESULTS}/trimmed/{{sample}}_fastp.html",
        json=f"{RESULTS}/trimmed/{{sample}}_fastp.json",
    log:
        f"{LOGS}/fastp/{{sample}}.log",
    threads: config["threads"]["fastp"]
    params:
        extra=config["fastp"]["extra"],
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {RESULTS}/trimmed {LOGS}/fastp
        fastp -i {input.r1} -I {input.r2} \
              -o {output.r1_trimmed} -O {output.r2_trimmed} \
              --html {output.html} --json {output.json} \
              --thread {threads} \
              {params.extra} \
              &> {log}
        """


# Rule: Build the HISAT2 index from a genome FASTA. Only runs when the index files
# are absent; if you provide a pre-built index, Snakemake skips this rule (and never
# reads genome_fasta). Plain genome index by default; set index.hisat2_splice_aware
# to build with --ss/--exon from the GTF (needs ~160 GB RAM for human).
rule hisat2_build:
    input:
        genome=GENOME_FASTA,
        gtf=GTF if HISAT2_SPLICE_AWARE else [],
    output:
        multiext(
            HISAT2_INDEX,
            ".1.ht2", ".2.ht2", ".3.ht2", ".4.ht2",
            ".5.ht2", ".6.ht2", ".7.ht2", ".8.ht2",
        ),
    log:
        f"{LOGS}/hisat2_build/build.log",
    params:
        prefix=HISAT2_INDEX,
        splice_aware=HISAT2_SPLICE_AWARE,
        align_chroms=" ".join(ALIGN_CHROMS),
    threads: config["threads"]["hisat2"]
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p $(dirname {params.prefix}) {LOGS}/hisat2_build
        GENOME={input.genome}
        # Optional: restrict the genome to the requested chromosomes before building.
        if [ -n "{params.align_chroms}" ]; then
            SUBSET={params.prefix}.align_subset.fa
            samtools faidx {input.genome} {params.align_chroms} > "$SUBSET" 2> {log}
            GENOME="$SUBSET"
        fi
        if [ "{params.splice_aware}" = "True" ]; then
            SS={params.prefix}.ss.tsv
            EXON={params.prefix}.exon.tsv
            hisat2_extract_splice_sites.py {input.gtf} > "$SS" 2>> {log}
            hisat2_extract_exons.py {input.gtf} > "$EXON" 2>> {log}
            hisat2-build -p {threads} --ss "$SS" --exon "$EXON" "$GENOME" {params.prefix} >> {log} 2>&1
            rm -f "$SS" "$EXON"
        else
            hisat2-build -p {threads} "$GENOME" {params.prefix} >> {log} 2>&1
        fi
        if [ -n "{params.align_chroms}" ]; then rm -f "$SUBSET"; fi
        """


# Rule: Align reads with HISAT2
rule hisat2_align:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}_R1.trimmed.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_R2.trimmed.fastq.gz",
        index=multiext(
            HISAT2_INDEX,
            ".1.ht2", ".2.ht2", ".3.ht2", ".4.ht2",
            ".5.ht2", ".6.ht2", ".7.ht2", ".8.ht2",
        ),
    output:
        sam=f"{RESULTS}/hisat2/{{sample}}.sam",
        summary=f"{RESULTS}/hisat2/{{sample}}.sam.summary",
    log:
        f"{LOGS}/hisat2/{{sample}}.log",
    params:
        index=HISAT2_INDEX,
        extra=config["hisat2"]["extra"],
    threads: config["threads"]["hisat2"]
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {RESULTS}/hisat2 {LOGS}/hisat2
        hisat2 -x {params.index} -1 {input.r1} -2 {input.r2} \
               -S {output.sam} \
               --summary-file {output.summary} \
               -p {threads} \
               {params.extra} \
               &> {log}
        """


# Rule: Filter, sort, index BAM and generate flagstat
rule samtools_sort_filter_index:
    input:
        f"{RESULTS}/hisat2/{{sample}}.sam",
    output:
        bam=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
        bai=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam.bai",
        flagstat=f"{RESULTS}/samtools/{{sample}}_summary.txt",
    log:
        f"{LOGS}/samtools/{{sample}}.log",
    threads: config["threads"]["samtools"]
    params:
        require=config["samtools_filter"]["require_flags"],
        exclude=config["samtools_filter"]["exclude_flags"],
        unique_tag=config["samtools_filter"]["unique_tag"],
        keep_chroms=",".join(KEEP_CHROMS),
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {RESULTS}/samtools {LOGS}/samtools
        TMP={RESULTS}/samtools/tmp_{wildcards.sample}.sam
        if [ -n "{params.unique_tag}" ]; then
            samtools view -@ {threads} -f {params.require} -F {params.exclude} -hS {input} \
                | grep "{params.unique_tag}\\|^@" > $TMP
        else
            samtools view -@ {threads} -f {params.require} -F {params.exclude} -hS {input} > $TMP
        fi
        # Optional: keep only reads whose RNAME (chromosome) is in the configured set.
        if [ -n "{params.keep_chroms}" ]; then
            awk -v keep="{params.keep_chroms}" 'BEGIN{{n=split(keep,a,","); for(i=1;i<=n;i++) K[a[i]]=1}} /^@/{{print; next}} ($3 in K)' $TMP > $TMP.chr && mv $TMP.chr $TMP
        fi
        samtools view -@ {threads} -bhS $TMP | \
            samtools sort -@ {threads} -O bam -o {output.bam}
        samtools index -@ {threads} {output.bam} {output.bai}
        samtools flagstat {output.bam} > {output.flagstat}
        rm $TMP
        """


# Rule: Quantify with FeatureCounts
rule featurecount:
    input:
        expand(f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam", sample=SAMPLES),
    output:
        f"{RESULTS}/featurecounts/featureCount.txt",
    log:
        f"{LOGS}/featurecounts/featurecount.log",
    params:
        gtf=GTF,
        feature=config["featurecounts"]["feature_type"],
        attr=config["featurecounts"]["attribute"],
        strand=config["featurecounts"]["strandedness"],
        extra=config["featurecounts"]["extra"],
    threads: config["threads"]["featurecounts"]
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {RESULTS}/featurecounts {LOGS}/featurecounts
        featureCounts -T {threads} {params.extra} \
                      -a {params.gtf} -F GTF \
                      -t {params.feature} -g {params.attr} -s {params.strand} \
                      -o {output} {input} &> {log}
        """


# Rule: Summarize everything with MultiQC
rule multiqc:
    input:
        expand(f"{RESULTS}/trimmed/{{sample}}_fastp.json", sample=SAMPLES),
        expand(f"{RESULTS}/fastqc/raw/{{sample}}_R1_001_fastqc.html", sample=SAMPLES),
        expand(f"{RESULTS}/fastqc/raw/{{sample}}_R2_001_fastqc.html", sample=SAMPLES),
        expand(f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam.bai", sample=SAMPLES),
    output:
        f"{RESULTS}/multiqc_report.html",
    log:
        f"{LOGS}/multiqc/multiqc.log",
    threads: config["threads"]["multiqc"]
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {LOGS}/multiqc
        multiqc -f {RESULTS}/ -o {RESULTS}/ &> {log}
        """
