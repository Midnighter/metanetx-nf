#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.outdir = 'results'
params.pubchem_identifiers = 'input/compound_additions.csv'

include reactions from './mnx_post_reactions'
include compounds from './mnx_post_compounds'

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
    pubchem_identifiers

    main:
    bigg_info()
    kegg_info()
    reactions(database)
    compounds(reactions.out, pubchem_identifiers)

    emit:
    db = compounds.out.db
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    log.info """
************************************************************

metanetx-post
=============
PubChem Identifiers: ${params.pubchem_identifiers}
Results Path: ${params.outdir}

************************************************************

"""

    main:
    db = Channel.fromPath("${params.outdir}/${params.database}")
    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}", checkIfExists: true)
    mnx_post(db, pubchem_identifiers)
}
