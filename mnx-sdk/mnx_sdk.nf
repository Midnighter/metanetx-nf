#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.mnx_release = '4.2'
params.outdir = 'results'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process MNX_INFO {
    publishDir "${params.outdir}", mode:'link'

    output:
    path 'README.md'

    """
    mnx-sdk pull --version ${params.mnx_release} --no-compress . README.md
    """
}

process PULL_TABLES {
    publishDir "${params.outdir}/mnx-${params.mnx_release}", mode:'link'

    input:
    val names

    output:
    path '*.tsv.gz'

    """
    mnx-sdk pull --version ${params.mnx_release} . ${names.join(' ')}
    """
}

process TRANSFORM_TABLE {
    publishDir "${params.outdir}/mnx-${params.mnx_release}-processed", mode:'link'

    input:
    path table

    output:
    path "processed_${table}", emit: processed_table

    """
    mnx-sdk etl ${table.getSimpleName().replace('_', '-')} \
        "${table}" "processed_${table}"
    """
}

/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow mnx_sdk {
    take:
    table_names

    main:
    TRANSFORM_TABLE(table_names)

    emit:
    tables = TRANSFORM_TABLE.out.processed_table
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    log.info """
************************************************************

metanetx-sdk
============
MetaNetX Release: ${params.mnx_release}
Results Path: ${params.outdir}

************************************************************

"""

    main:
    Channel.fromList([
        "chem_prop.tsv",
        "chem_xref.tsv",
        "chem_depr.tsv",
        "comp_prop.tsv",
        "comp_xref.tsv",
        "comp_depr.tsv",
        "reac_prop.tsv",
        "reac_xref.tsv",
        "reac_depr.tsv",
    ]) \
    mnx_info()
    table_names.collect() \
    | pull_tables
}
