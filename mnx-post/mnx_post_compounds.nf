#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.pubchem_identifiers = 'input/compound_additions.csv'
params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

log.info """
************************************************************

metanetx-post-compounds
=======================
PubChem Identifiers: ${params.pubchem_identifiers}
Chem-Informatics Backend: ${params.chem_backend}
SQLite Database: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process kegg_extract {
    storeDir "${params.storage}"

    output:
    path 'kegg_compounds.json'

    """
    mnx-post compounds kegg extract
    """
}

process kegg_transform {
    input:
    path compounds

    output:
    path 'kegg_inchi.json'

    """
    mnx-post compounds kegg transform --backend=${params.chem_backend} ${compounds}
    """
}

process kegg_load {
    publishDir "${params.outdir}", mode:'link', glob: '*.json'

    input:
    path db
    path inchis

    output:
    path db, emit: db
    path 'kegg_inchi_conflicts.json'

    """
    mnx-post compounds kegg load sqlite:///${db} ${inchis}
    """
}

process pubchem_extract {
    storeDir "${params.storage}"

    input:
    path identifiers

    output:
    path 'pubchem_properties.json'
    path 'pubchem_synonyms.json'

    """
    mnx-post compounds pubchem extract ${identifiers}
    """
}

process pubchem_transform {
    input:
    path properties
    path synonyms

    output:
    path 'pubchem_compounds.json'

    """
    mnx-post compounds pubchem transform ${properties} ${synonyms}
    """
}

process pubchem_load {
    publishDir "${params.outdir}", mode:'link', glob: '*.json'

    input:
    path db
    path compounds

    output:
    path db, emit: db

    """
    mnx-post compounds pubchem load sqlite:///${db} ${compounds}
    """
}

process structures_etl {
    publishDir "${params.outdir}", mode:'link'

    input:
    path db

    output:
    path db

    """
    mnx-post compounds structures etl --backend=${params.chem_backend} \
        sqlite:///${db}
    """
}


/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow compounds {
    take:
    database
    pubchem_identifiers

    main:
    kegg_extract()
    kegg_transform(kegg_extract.out)
    kegg_load(database, kegg_transform.out)
    pubchem_extract(pubchem_identifiers)
    pubchem_transform(pubchem_extract.out)
    pubchem_load(kegg_load.out.db, pubchem_transform.out)
    structures_etl(pubchem_load.out.db)

    emit:
    db = structures_etl.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    main:
    db = Channel.fromPath("${params.outdir}/${params.database}")
    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}")
    compounds(db, pubchem_identifiers)
}
