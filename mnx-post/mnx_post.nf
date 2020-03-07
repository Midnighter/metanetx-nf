#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.outdir = 'results'

include reactions from './mnx_post_reactions'
include compounds from './mnx_post_compounds'

log.info """
************************************************************

metanetx-post
=============
Results Path: ${params.outdir}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process bigg_info {
    publishDir "${params.outdir}", mode:'link'

    output:
    path 'bigg_info.json'

    """
    mnx-post bigg-info
    """
}

process kegg_info {
    publishDir "${params.outdir}", mode:'link'

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

workflow mnx_post {
    take:
    database

    main:
    bigg_info()
    kegg_info()
    reactions(database)
    compounds(reactions.out)

    emit:
    db = compounds.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    main:
    Channel.fromPath("${params.outdir}/${params.database}") \
    | mnx_assets
}
