# Catalog test case (`.test/`)

Lets the Snakemake Workflow Catalog render the workflow's rule graph via:

    snakemake -s workflow/Snakefile -c 1 -d .test --forceall --rulegraph

`--rulegraph` resolves only the rule dependency graph — no rule runs — so the
reads here are empty 0-byte placeholders and the reference files (HISAT2 index,
GTF, BED, Salmon indexes, picard.jar) are not needed for it (they are rule
`params`, not declared inputs). This is not an end-to-end integration test.
