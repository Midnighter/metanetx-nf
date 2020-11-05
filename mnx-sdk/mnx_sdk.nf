#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/* ############################################################################
 * Default parameter values.
 * ############################################################################
 */

params.mnx_release = '4.1'
params.outdir = 'results'
params.storage = 'storage'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process MNX_INFO {
    publishDir params.outdir, mode: 'link'

    output:
    path 'README.md'

    """
    mnx-sdk pull --version ${params.mnx_release} --no-compress . README.md
    """
}

process PULL_TABLE {
    storeDir params.storage
    errorStrategy 'retry'
    maxRetries 3

    input:
    val name

    output:
    path result, emit: table

    script:
    result = "${name}.gz"
    """
    mnx-sdk pull --version ${params.mnx_release} . ${name}
    """
}

process TRANSFORM_TABLE {
    publishDir "${params.outdir}/mnx-processed", mode: 'link'

    input:
    path table

    output:
    path result, emit: processed_table

    script:
    command = table.getSimpleName().replace('_', '-')
    result = "processed_${table}"
    """
    mnx-sdk etl ${command} ${table} ${result}
    """
}

/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow MNX_SDK {
    take:
    table_names

    main:
    MNX_INFO()
    PULL_TABLE(table_names) | TRANSFORM_TABLE

    emit:
    table = TRANSFORM_TABLE.out.processed_table
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
Permanent Cache: ${params.storage}

************************************************************

"""

    main:
    Channel.fromList([
        "chem_depr.tsv",
        "chem_prop.tsv",
        "chem_xref.tsv",
        "comp_depr.tsv",
        "comp_prop.tsv",
        "comp_xref.tsv",
        "reac_depr.tsv",
        "reac_prop.tsv",
        "reac_xref.tsv",
    ]) \
    | MNX_SDK
}
