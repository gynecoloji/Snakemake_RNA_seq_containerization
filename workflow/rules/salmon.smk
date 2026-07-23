# Salmon transcript quantification (standard + decoy-aware). Consumes the core
# stage's trimmed reads. Ported from the former snakefile_salmon (unchanged).


rule salmon_all:
    input:
        expand(f"{RESULTS}/quants/{{sample}}_quant/quant.sf", sample=SAMPLES),
        expand(f"{RESULTS}/quants_decoy/{{sample}}_quant/quant.sf", sample=SAMPLES),


# Rule: Build the standard Salmon index from a transcriptome FASTA. The rule depends
# on the `info.json` sentinel Salmon writes, so an empty placeholder directory (only a
# .gitkeep) still triggers a build; a real pre-built index is reused as-is.
rule salmon_index:
    input:
        transcriptome=TRANSCRIPTOME_FASTA,
    output:
        f"{SALMON_INDEX}/info.json",
    log:
        f"{LOGS}/salmon_index/standard.log",
    params:
        index=SALMON_INDEX,
        kmer=SALMON_KMER,
    threads: config["threads"]["salmon"]
    conda:
        "../envs/salmon.yaml"
    shell:
        """
        mkdir -p {LOGS}/salmon_index
        salmon index -t {input.transcriptome} -i {params.index} -k {params.kmer} -p {threads} &> {log}
        """


# Rule: Build the decoy-aware Salmon index. decoys.txt = genome sequence names;
# gentrome = transcripts + genome (concatenated). Needs both FASTAs.
rule salmon_decoy_index:
    input:
        transcriptome=TRANSCRIPTOME_FASTA,
        genome=GENOME_FASTA,
    output:
        f"{SALMON_DECOY_INDEX}/info.json",
    log:
        f"{LOGS}/salmon_index/decoy.log",
    params:
        index=SALMON_DECOY_INDEX,
        kmer=SALMON_KMER,
        gentrome=f"{SALMON_DECOY_INDEX}.gentrome.fa",
        decoys=f"{SALMON_DECOY_INDEX}.decoys.txt",
    threads: config["threads"]["salmon"]
    conda:
        "../envs/salmon.yaml"
    shell:
        """
        mkdir -p $(dirname {params.gentrome}) {LOGS}/salmon_index
        grep '^>' {input.genome} | sed 's/^>//' | cut -d' ' -f1 > {params.decoys} 2> {log}
        cat {input.transcriptome} {input.genome} > {params.gentrome} 2>> {log}
        salmon index -t {params.gentrome} -d {params.decoys} -i {params.index} -k {params.kmer} -p {threads} &>> {log}
        rm -f {params.gentrome} {params.decoys}
        """


# Rule 1: Salmon quantification (standard index)
rule salmon_quant:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}_R1.trimmed.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_R2.trimmed.fastq.gz",
        index=f"{SALMON_INDEX}/info.json",
    output:
        f"{RESULTS}/quants/{{sample}}_quant/quant.sf",
    log:
        f"{LOGS}/salmon/{{sample}}_salmon.log",
    threads: config["threads"]["salmon"]
    params:
        index=SALMON_INDEX,
        lib_type=config["salmon"]["lib_type"],
        extra=config["salmon"]["extra"],
    conda:
        "../envs/salmon.yaml"
    shell:
        """
        mkdir -p {RESULTS}/quants {LOGS}/salmon
        salmon quant \
            -i {params.index} \
            -l {params.lib_type} \
            -1 {input.r1} \
            -2 {input.r2} \
            -p {threads} \
            {params.extra} \
            -o {RESULTS}/quants/{wildcards.sample}_quant > {log} 2>&1
        """


# Rule 2: Salmon quantification (decoy-aware index)
rule salmon_decoy_quant:
    input:
        r1=f"{RESULTS}/trimmed/{{sample}}_R1.trimmed.fastq.gz",
        r2=f"{RESULTS}/trimmed/{{sample}}_R2.trimmed.fastq.gz",
        index=f"{SALMON_DECOY_INDEX}/info.json",
    output:
        f"{RESULTS}/quants_decoy/{{sample}}_quant/quant.sf",
    log:
        f"{LOGS}/salmon/{{sample}}_salmon_decoy.log",
    threads: config["threads"]["salmon"]
    params:
        index=SALMON_DECOY_INDEX,
        lib_type=config["salmon"]["lib_type"],
        extra=config["salmon"]["extra"],
    conda:
        "../envs/salmon.yaml"
    shell:
        """
        mkdir -p {RESULTS}/quants_decoy {LOGS}/salmon
        salmon quant \
            -i {params.index} \
            -l {params.lib_type} \
            -1 {input.r1} \
            -2 {input.r2} \
            -p {threads} \
            {params.extra} \
            -o {RESULTS}/quants_decoy/{wildcards.sample}_quant > {log} 2>&1
        """
