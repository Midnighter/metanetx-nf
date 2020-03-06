#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.outdir = 'results'
params.database = "sqlite:///metanetx.sqlite"

log.info """
************************************************************

metanetx-assets
===============
Results Path: ${params.outdir}
Database URI: ${params.database}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process pull_registry {
    publishDir "${params.outdir}/registry", mode:'link'

    output:
    path 'identifiers_org.json'

    """
    mnx-assets namespaces extract-registry identifiers_org.json
    """
}

process init_db {
    output:
    path "${params.database.minus('sqlite:///')}"

    """
    mnx-assets init --drop yes ${params.database}
    """
}

process group_tables {
    input:
    val tables

    output:
    val grouped

    exec:
    grouped = tables.groupBy({ file -> file.getSimpleName().minus('processed_') })
}

process etl_namespaces {
    input:
    path db
    val tables
    path registry

    output:
    path db

    """
    mnx-assets namespaces reset ${params.database}
    mnx-assets namespaces etl ${params.database} \
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
    mnx-assets compartments reset ${params.database}
    mnx-assets compartments etl ${params.database} \
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
    mnx-assets compounds reset ${params.database}
    mnx-assets compounds etl ${params.database} \
        ${tables['chem_prop'].head()} \
        ${tables['chem_xref'].head()}
    """
}

process etl_reactions {
    publishDir "${params.outdir}", mode:'copy'

    input:
    path db
    val tables

    output:
    path db

    """
    mnx-assets reactions reset ${params.database}
    mnx-assets reactions etl ${params.database} \
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
