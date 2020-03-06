#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.mnx_release = '3.2'
params.outdir = 'results'
params.storage = 'storage'

log.info """
************************************************************

metanetx-sdk
============
MetaNetX Release: ${params.mnx_release}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process mnx_info {
    publishDir "${params.outdir}", mode:'link'

    output:
    path 'README.md'

    """
    mnx-sdk pull --version ${params.mnx_release} --no-compress . README.md
    """
}

process pull_tables {
    storeDir "${params.storage}"

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
    table_names

    main:
    mnx_info()
    table_names.collect() \
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
    | mnx_sdk
}
