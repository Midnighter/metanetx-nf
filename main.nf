#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.mnx_release = '3.2'
params.pubchem_identifiers = 'input/compound_additions.csv'
params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

include mnx_sdk from './mnx-sdk/mnx_sdk'
include mnx_assets from './mnx-assets/mnx_assets'
include mnx_post from './mnx-post/mnx_post'

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
    Channel.fromList([
        "chem_prop.tsv",
        "chem_xref.tsv",
        "comp_prop.tsv",
        "comp_xref.tsv",
        "reac_prop.tsv",
        "reac_xref.tsv",
    ]) \
    | mnx_sdk \
    | mnx_assets
    mnx_post(mnx_assets.out.db, pubchem_identifiers)
}
