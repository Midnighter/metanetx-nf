#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.outdir = 'results'
params.database = "sqlite:///metanetx.sqlite"
params.bigg = "${params.outdir}/bigg"
params.kegg = "${params.outdir}/kegg"

log.info """
************************************************************

metanetx-post
=============
Database URI: ${params.database}
Results Path: ${params.outdir}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process bigg_info {
    publishDir "${params.bigg}", mode:'link'

    output:
    path 'bigg_info.json'

    """
    mnx-post bigg-info
    """
}

process kegg_info {
    publishDir "${params.kegg}", mode:'link'

    output:
    path 'kegg_info.txt'

    """
    mnx-post kegg-info
    """
}

/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow reaction_names {
    main:
    bigg_info()
    kegg_info()
}

workflow mnx_assets {
    take:
    processed_tables

    main:
    pull_registry()
    init_db()
    grouped_tables = processed_tables.groupBy({ file ->
        file.getSimpleName().minus('processed_')
    })
    etl_namespaces(
        init_db.out,
        grouped_tables,
        pull_registry.out
    )
    etl_compartments(etl_namespaces.out, grouped_tables)
    etl_compounds(etl_compartments.out, grouped_tables)
    etl_reactions(etl_compounds.out, grouped_tables)

    emit:
    db = etl_reactions.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    main:
    Channel.fromPath("${params.outdir}/mnx-processed/processed_*.tsv.gz") \
    | mnx_assets
}
