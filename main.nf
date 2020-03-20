#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.pubchem_identifiers = 'input/compound_additions.csv'

include mnx_sdk from './mnx-sdk/mnx_sdk'
include mnx_assets from './mnx-assets/mnx_assets'
include mnx_post from './mnx-post/mnx_post'

log.info """
************************************************************

metanetx-nf
===========
PubChem Identifiers: ${params.pubchem_identifiers}

************************************************************

"""

workflow {
    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}")
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
