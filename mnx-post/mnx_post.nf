#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/* ############################################################################
 * Default parameter values.
 * ############################################################################
 */

params.email = null
params.pubchem_identifiers = 'input/compound_additions.csv'
params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

/* ############################################################################
 * Include modules.
 * ############################################################################
 */

include { REACTIONS } from './mnx_post_reactions'
include { COMPOUNDS } from './mnx_post_compounds'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process BIGG_INFO {
    publishDir params.outdir, mode:'link'

    output:
    path 'bigg_info.json'

    """
    mnx-post bigg-info
    """
}

process KEGG_INFO {
    publishDir params.outdir, mode:'link'

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

workflow MNX_POST {
    take:
    database
    pubchem_identifiers

    main:
    BIGG_INFO()
    KEGG_INFO()
    REACTIONS(database)
    COMPOUNDS(REACTIONS.out, pubchem_identifiers)

    emit:
    db = COMPOUNDS.out.db
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
E-Mail: ${params.email}
PubChem Identifiers: ${params.pubchem_identifiers}
Chem-Informatics Backend: ${params.chem_backend}
SQLite Database: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

    main:
    db = Channel.fromPath("${params.outdir}/${params.database}")
    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}", checkIfExists: true)
    MNX_POST(db, pubchem_identifiers)
}
