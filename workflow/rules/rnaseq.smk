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


# Rule: Align reads with HISAT2
rule hisat2_align:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}_R1.trimmed.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_R2.trimmed.fastq.gz",
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
