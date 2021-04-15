#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.database = 'metanetx.sqlite'
params.outdir = 'results'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process PULL_REGISTRY {
    output:
    path 'identifiers_org.json'

    """
    mnx-assets namespaces extract-registry identifiers_org.json
    """
}

process INIT_DB {
    output:
    path "${params.database}", emit: db

    """
    mnx-assets init --drop yes "sqlite:///${params.database}"
    """
}

process ETL_NAMESPACES {
    input:
    path db
    val tables_list
    path registry

    output:
    path "${db.getName()}", emit: db

    script:
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-assets namespaces etl "sqlite:///${db.getName()}" \
        ${registry} ${tables_list.join(' ')}
    """
}

process ETL_COMPARTMENTS {
    input:
    path db
    path comp_prop
    path comp_xref
    path comp_depr

    output:
    path "${db.getName()}", emit: db

    script:
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-assets compartments etl "sqlite:///${db.getName()}" \
        "${comp_prop}" \
        "${comp_xref}" \
        "${comp_depr}"
    """
}

process ETL_COMPOUNDS {
    input:
    path db
    path chem_prop
    path chem_xref
    path chem_depr

    output:
    path "${db.getName()}", emit: db

    script:
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-assets compounds etl "sqlite:///${db.getName()}" \
        "${chem_prop}" \
        "${chem_xref}" \
        "${chem_depr}"
    """
}

process ETL_REACTIONS {
    publishDir "${params.outdir}", mode:'link'

    input:
    path db
    path reac_prop
    path reac_xref
    path reac_depr

    output:
    path "${db.getName()}", emit: db

    script:
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-assets reactions etl "sqlite:///${db.getName()}" \
        "${reac_prop}" \
        "${reac_xref}" \
        "${reac_depr}"
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
    def tables = processed_tables.branch({
        chem_prop: it.name =~ /chem_prop/
        chem_xref: it.name =~ /chem_xref/
        chem_depr: it.name =~ /chem_depr/
        comp_prop: it.name =~ /comp_prop/
        comp_xref: it.name =~ /comp_xref/
        comp_depr: it.name =~ /comp_depr/
        reac_prop: it.name =~ /reac_prop/
        reac_xref: it.name =~ /reac_xref/
        reac_depr: it.name =~ /reac_depr/
    })

    PULL_REGISTRY()
    INIT_DB()
    ETL_NAMESPACES(
        INIT_DB.out,
        processed_tables
            .filter({ it.getSimpleName() =~ /prop|xref/ })
            .collect(),
        PULL_REGISTRY.out
    )
    ETL_COMPARTMENTS(
        ETL_NAMESPACES.out,
        tables.comp_prop,
        tables.comp_xref,
        tables.comp_depr
    )
    ETL_COMPOUNDS(
        ETL_COMPARTMENTS.out,
        tables.chem_prop,
        tables.chem_xref,
        tables.chem_depr

    )
    ETL_REACTIONS(
        ETL_COMPOUNDS.out,
        tables.reac_prop,
        tables.reac_xref,
        tables.reac_depr
    )

    emit:
    db = ETL_REACTIONS.out
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

************************************************************

"""

    main:
    Channel.fromPath("${params.outdir}/mnx-processed/processed_*.tsv.gz") \
    | mnx_assets
}
