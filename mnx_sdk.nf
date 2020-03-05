#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.outdir = 'results'
params.mnx_release = '3.2'

log.info """
************************************************************

metanetx-sdk
============
Results Path: ${params.outdir}
MetaNetX Release: ${params.mnx_release}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */
process pull_tables {
    publishDir "${params.outdir}/mnx-raw", mode:'link'

    input:
    val names

    output:
    path '*.tsv.gz'

    """
    mnx-sdk pull --version ${params.mnx_release} . ${names.join(' ')}
    """
}

process transform_table {
    publishDir "${params.outdir}/mnx-processed", mode:'link'

    input:
    path table

    output:
    path "processed_${table}", emit: processed_table

    """
    mnx-sdk etl ${table.getSimpleName().replace('_', '-')} \
        ${table} processed_${table}
    """
}

/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */
workflow mnx_sdk {
    take:
    names

    main:
    names.collect() \
    | pull_tables \
    | flatten() \
    | transform_table

    emit:
    tables = transform_table.out.processed_table
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */
workflow {
    main:
    Channel.fromList([
        "chem_prop.tsv",
        "chem_xref.tsv",
        "comp_prop.tsv",
        "comp_xref.tsv",
        "reac_prop.tsv",
        "reac_xref.tsv",
    ]) \
    | collect \
    | mnx_sdk

    emit:
    tables = mnx_sdk.out.tables
}
