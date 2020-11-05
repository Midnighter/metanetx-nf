#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/* ############################################################################
 * Default parameter values.
 * ############################################################################
 */

params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process PULL_REGISTRY {
    storeDir params.storage
    errorStrategy 'retry'
    maxRetries 3

    output:
    path result, emit: registry

    script:
    result = 'identifiers_org.json'
    """
    mnx-assets namespaces extract-registry ${result}
    """
}

process INIT_DB {
    input:
    val database

    output:
    path database, emit: db

    """
    mnx-assets init --drop yes "sqlite:///${database}"
    """
}

process ETL_NAMESPACES {
    input:
    path db
    val tables
    path registry

    output:
    path result, emit: db

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-assets namespaces etl "sqlite:///${result}" \
        ${registry} \
        ${tables['chem_prop']} \
        ${tables['chem_xref']} \
        ${tables['comp_prop']} \
        ${tables['comp_xref']} \
        ${tables['reac_prop']} \
        ${tables['reac_xref']}
    """
}

process ETL_COMPARTMENTS {
    input:
    path db
    val tables

    output:
    path result, emit: db

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-assets compartments etl "sqlite:///${result}" \
        ${tables['comp_prop']} \
        ${tables['comp_xref']} \
        ${tables['comp_depr']}
    """
}

process ETL_COMPOUNDS {
    input:
    path db
    val tables

    output:
    path result, emit: db

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-assets compounds etl "sqlite:///${result}" \
        ${tables['chem_prop']} \
        ${tables['chem_xref']} \
        ${tables['chem_depr']}
    """
}

process ETL_REACTIONS {
    publishDir params.outdir, mode:'link'

    input:
    path db
    val tables

    output:
    path result, emit: db

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-assets reactions etl "sqlite:///${result}" \
        ${tables['reac_prop']} \
        ${tables['reac_xref']} \
        ${tables['reac_depr']}
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
    PULL_REGISTRY()
    INIT_DB(params.database)

    grouped_tables = processed_tables
        .reduce( [:] ) { map, file ->
         map[file.getSimpleName().minus('processed_')] = file; return map }

    ETL_NAMESPACES(
        INIT_DB.out.db,
        grouped_tables,
        PULL_REGISTRY.out.registry
    )
    ETL_COMPARTMENTS(ETL_NAMESPACES.out.db, grouped_tables)
    ETL_COMPOUNDS(ETL_COMPARTMENTS.out.db, grouped_tables)
    ETL_REACTIONS(ETL_COMPOUNDS.out.db, grouped_tables)

    emit:
    db = ETL_REACTIONS.out.db
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    log.info """
************************************************************

metanetx-assets
===============
Database URI: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

    main:
    Channel.fromPath("${params.outdir}/mnx-processed/processed_*.tsv.gz") \
    | mnx_assets
}
