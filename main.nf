#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/* ############################################################################
 * Default parameter values.
 * ############################################################################
 */

params.email = null
params.mnx_release = '4.1'
params.pubchem_identifiers = 'input/compound_additions.csv'
params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

/* ############################################################################
 * Include modules.
 * ############################################################################
 */

include { MNX_SDK } from './mnx-sdk/mnx_sdk'
include { MNX_ASSETS } from './mnx-assets/mnx_assets'
include { MNX_POST } from './mnx-post/mnx_post'

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    log.info """
************************************************************

metanetx-nf
===========
E-Mail: ${params.email}
MetaNetX Release: ${params.mnx_release}
PubChem Identifiers: ${params.pubchem_identifiers}
Chem-Informatics Backend: ${params.chem_backend}
SQLite Database: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}", checkIfExists: true)
    Channel.fromList([
        "chem_prop.tsv",
        "chem_xref.tsv",
        "comp_prop.tsv",
        "comp_xref.tsv",
        "reac_prop.tsv",
        "reac_xref.tsv",
    ]) \
    | MNX_SDK \
    | MNX_ASSETS
    MNX_POST(MNX_ASSETS.out.db, pubchem_identifiers)
}
