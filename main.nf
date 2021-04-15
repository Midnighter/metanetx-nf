#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.mnx_release = '4.2'
params.pubchem_identifiers = 'input/compound_additions.csv'
params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.tables = '*.tsv'
params.storage = 'storage'

include { mnx_sdk } from './mnx-sdk/mnx_sdk'
include { mnx_assets } from './mnx-assets/mnx_assets'
include { mnx_post } from './mnx-post/mnx_post'

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
MetaNetX Release: ${params.mnx_release}
PubChem Identifiers: ${params.pubchem_identifiers}
Chem-Informatics Backend: ${params.chem_backend}
SQLite Database: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}", checkIfExists: true)
    Channel.fromPath(params.tables, checkIfExists: true)
        .dump(tag: 'tables') \
    | mnx_sdk
    | mnx_assets
    mnx_post(mnx_assets.out.db, pubchem_identifiers)
}
