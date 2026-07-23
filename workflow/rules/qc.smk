# Advanced QC stage: Picard insert size, Qualimap bamqc + rnaseq, RSeQC
# (read distribution, GC, TIN). Consumes the core stage's filtered BAMs.
# Ported from the former snakefile_RNAQC (behaviour unchanged).


rule qc_all:
    input:
        expand(f"{RESULTS}/picard/{{sample}}_insert_size_metrics.txt", sample=SAMPLES),
        expand(f"{RESULTS}/picard/{{sample}}_final_insert_size.txt", sample=SAMPLES),
        expand(f"{RESULTS}/qualimap_bamqc/{{sample}}/{{sample}}.pdf", sample=SAMPLES),
        expand(f"{RESULTS}/samtools_byname/{{sample}}.sorted.byname.bam", sample=SAMPLES),
        expand(f"{RESULTS}/qualimap_rnaseq/{{sample}}", sample=SAMPLES),
        expand(f"{RESULTS}/rseqc/{{sample}}_RD_summary.txt", sample=SAMPLES),
        expand(f"{RESULTS}/rseqc/{{sample}}_GC_content.GC.xls", sample=SAMPLES),
        expand(f"{RESULTS}/rseqc/{{sample}}.sorted.filtered.tin.xls", sample=SAMPLES),


# Rule 1: Picard CollectInsertSizeMetrics + AWK extraction
rule picard_mean_fragment_length:
    input:
        bam=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
    output:
        metrics=f"{RESULTS}/picard/{{sample}}_insert_size_metrics.txt",
        final_metrics=f"{RESULTS}/picard/{{sample}}_final_insert_size.txt",
    log:
        f"{LOGS}/picard/{{sample}}_MeanFragmentLength.log",
    threads: config["threads"]["picard"]
    params:
        picard_jar=PICARD_JAR,
    conda:
        "../envs/qualimap.yaml"
    shell:
        """
        mkdir -p {RESULTS}/picard {LOGS}/picard
        java -jar {params.picard_jar} CollectInsertSizeMetrics \
            I={input.bam} \
            O={output.metrics} \
            H={RESULTS}/picard/{wildcards.sample}_Histogram.pdf \
            M=0.5 &> {log}

        awk 'NR==7,NR==8 {{print $0}}' {output.metrics} > {output.final_metrics}
        """


# Rule 2: Qualimap BAMQC
rule qualimap_bamqc:
    input:
        bam=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
    output:
        directory(f"{RESULTS}/qualimap_bamqc/{{sample}}"),
        pdf=f"{RESULTS}/qualimap_bamqc/{{sample}}/{{sample}}.pdf",
    log:
        f"{LOGS}/qualimap/{{sample}}_bamqc.log",
    threads: config["threads"]["qualimap_bamqc"]
    params:
        gtf=GTF,
        java_mem=JAVA_MEM,
        protocol=PROTOCOL,
    conda:
        "../envs/qualimap.yaml"
    shell:
        """
        mkdir -p {RESULTS}/qualimap_bamqc/{wildcards.sample} {LOGS}/qualimap
        qualimap bamqc \
            --java-mem-size={params.java_mem} \
            -bam {input.bam} \
            -c \
            --feature-file {params.gtf} \
            -outdir {RESULTS}/qualimap_bamqc/{wildcards.sample} \
            -os \
            -outfile {wildcards.sample}.pdf \
            -outformat PDF \
            --sequencing-protocol {params.protocol} \
            &> {log}
        """


# Rule 3: Samtools sort by name
rule samtools_sort_by_name:
    input:
        f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
    output:
        f"{RESULTS}/samtools_byname/{{sample}}.sorted.byname.bam",
    log:
        f"{LOGS}/samtools_byname/{{sample}}.log",
    threads: config["threads"]["samtools_byname"]
    conda:
        "../envs/snakemake.yaml"
    shell:
        """
        mkdir -p {RESULTS}/samtools_byname {LOGS}/samtools_byname
        samtools sort -n -@ {threads} -o {output} {input} &> {log}
        """


# Rule 4: Qualimap RNAseq QC
rule qualimap_rnaseq:
    input:
        bam=f"{RESULTS}/samtools_byname/{{sample}}.sorted.byname.bam",
    output:
        directory(f"{RESULTS}/qualimap_rnaseq/{{sample}}"),
    log:
        f"{LOGS}/qualimap/{{sample}}_rnaseq.log",
    threads: config["threads"]["qualimap_rnaseq"]
    params:
        gtf=GTF,
        java_mem=JAVA_MEM,
        protocol=PROTOCOL,
    conda:
        "../envs/qualimap.yaml"
    shell:
        """
        mkdir -p {RESULTS}/qualimap_rnaseq/{wildcards.sample} {LOGS}/qualimap
        qualimap rnaseq \
            --java-mem-size={params.java_mem} \
            -a uniquely-mapped-reads \
            -bam {input.bam} \
            -gtf {params.gtf} \
            -outdir {RESULTS}/qualimap_rnaseq/{wildcards.sample} \
            --sequencing-protocol {params.protocol} \
            --paired \
            --sorted \
            &> {log}
        """


# Build the RSeQC gene-model BED (BED12) from the GTF with UCSC tools, chr-prefixed to
# match the alignments. Only runs when the configured `bed` is absent; provide your own
# BED12 to skip it (the GTF is then not read for this step).
rule build_rseqc_bed:
    input:
        gtf=GTF,
    output:
        BED,
    log:
        f"{LOGS}/rseqc_bed/build.log",
    conda:
        "../envs/ucsc.yaml"
    shell:
        """
        mkdir -p $(dirname {output}) {LOGS}/rseqc_bed
        GP={output}.genePred
        gtfToGenePred -ignoreGroupsWithoutExons {input.gtf} "$GP" 2> {log}
        genePredToBed "$GP" {output} 2>> {log}
        rm -f "$GP"
        """


# RSeQC rules use a different conda environment (RSeQC)

# Rule 5: RSeQC Read distribution
rule rseqc_read_distribution:
    input:
        bam=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
        bed=BED,
    output:
        f"{RESULTS}/rseqc/{{sample}}_RD_summary.txt",
    log:
        f"{LOGS}/rseqc/{{sample}}_read_distribution.log",
    params:
        refbed=BED,
    threads: config["threads"]["rseqc"]
    conda:
        "../envs/RSeQC.yaml"
    shell:
        """
        mkdir -p {RESULTS}/rseqc {LOGS}/rseqc
        read_distribution.py -i {input.bam} -r {params.refbed} > {output} 2> {log}
        """


# Rule 6: RSeQC GC content
rule rseqc_gc_content:
    input:
        bam=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
    output:
        f"{RESULTS}/rseqc/{{sample}}_GC_content.GC.xls",
    log:
        f"{LOGS}/rseqc/{{sample}}_gc_content.log",
    threads: config["threads"]["rseqc"]
    conda:
        "../envs/RSeQC.yaml"
    shell:
        """
        mkdir -p {RESULTS}/rseqc {LOGS}/rseqc
        read_GC.py -i {input.bam} -o {RESULTS}/rseqc/{wildcards.sample}_GC_content &> {log}
        """


# Rule 7: RSeQC TIN (Transcript Integrity Number)
rule rseqc_tin:
    input:
        bam=f"{RESULTS}/samtools/{{sample}}.sorted.filtered.bam",
        bed=BED,
    output:
        f"{RESULTS}/rseqc/{{sample}}.sorted.filtered.tin.xls",
    log:
        f"{LOGS}/rseqc/{{sample}}_TIN.log",
    params:
        refbed=BED,
    threads: config["threads"]["rseqc"]
    conda:
        "../envs/RSeQC.yaml"
    shell:
        """
        mkdir -p {RESULTS}/rseqc {LOGS}/rseqc
        cd {RESULTS}/rseqc && tin.py -i ../../{input.bam} -r ../../{params.refbed} &> ../../{log}
        """
