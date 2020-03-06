#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

log.info """
************************************************************

metanetx-assets
===============
Database URI: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process pull_registry {
    storeDir "${params.storage}"

    output:
    path 'identifiers_org.json'

    """
    mnx-assets namespaces extract-registry identifiers_org.json
    """
}

process init_db {
    output:
    path "${params.database}"

    """
    mnx-assets init --drop yes sqlite:///${params.database}
    """
}

process etl_namespaces {
    input:
    path db
    val tables
    path registry

    output:
    path db

    """
    mnx-assets namespaces reset sqlite:///${db}
    mnx-assets namespaces etl sqlite:///${db} \
        ${registry} \
        ${tables['chem_prop'].head()} \
        ${tables['chem_xref'].head()} \
        ${tables['comp_prop'].head()} \
        ${tables['comp_xref'].head()} \
        ${tables['reac_prop'].head()} \
        ${tables['reac_xref'].head()}
    """
}

process etl_compartments {
    input:
    path db
    val tables

    output:
    path db

    """
    mnx-assets compartments reset sqlite:///${db}
    mnx-assets compartments etl sqlite:///${db} \
        ${tables['comp_prop'].head()} \
        ${tables['comp_xref'].head()}
    """
}

process etl_compounds {
    input:
    path db
    val tables

    output:
    path db

    """
    mnx-assets compounds reset sqlite:///${db}
    mnx-assets compounds etl sqlite:///${db} \
        ${tables['chem_prop'].head()} \
        ${tables['chem_xref'].head()}
    """
}

process etl_reactions {
    publishDir "${params.outdir}", mode:'link'

    input:
    path db
    val tables

    output:
    path db

    """
    mnx-assets reactions reset sqlite:///${db}
    mnx-assets reactions etl sqlite:///${db} \
        ${tables['reac_prop'].head()} \
        ${tables['reac_xref'].head()}
    """
}

/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

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
