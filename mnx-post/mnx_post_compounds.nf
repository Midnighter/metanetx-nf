#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/* ############################################################################
 * Default parameter values.
 * ############################################################################
 */

params.pubchem_identifiers = 'input/compound_additions.csv'
params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process KEGG_EXTRACT {
    storeDir params.storage

    output:
    path 'kegg_compounds.json'

    """
    mnx-post compounds kegg extract
    """
}

process KEGG_TRANSFORM {
    input:
    path compounds

    output:
    path 'kegg_inchi.json'

    """
    mnx-post compounds kegg transform --backend=${params.chem_backend} ${compounds}
    """
}

process KEGG_LOAD {
    publishDir params.outdir, mode:'link', glob: '*.json'

    input:
    path db
    path inchis

    output:
    path result, emit: db
    path 'kegg_inchi_conflicts.json'

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-post compounds kegg load sqlite:///${result} ${inchis}
    """
}

process PUBCHEM_EXTRACT {
    storeDir params.storage

    input:
    path identifiers

    output:
    path 'pubchem_properties.json'
    path 'pubchem_synonyms.json'

    """
    mnx-post compounds pubchem extract ${identifiers}
    """
}

process PUBCHEM_TRANSFORM {
    input:
    path properties
    path synonyms

    output:
    path 'pubchem_compounds.json'

    """
    mnx-post compounds pubchem transform ${properties} ${synonyms}
    """
}

process PUBCHEM_LOAD {
    publishDir params.outdir, mode:'link', glob: '*.json'

    input:
    path db
    path compounds

    output:
    path result, emit: db

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-post compounds pubchem load sqlite:///${result} ${compounds}
    """
}

process STRUCTURES_ETL {
    publishDir params.outdir, mode:'link'

    input:
    path db

    output:
    path result, emit: db

    script:
    result = db.getName()
    // We copy the SQLite database in order to improve the ability to resume a pipeline.
    """
    cp --remove-destination "\$(realpath -e ${db})" "${result}"
    mnx-post compounds structures etl --backend=${params.chem_backend} \
        sqlite:///${result}
    """
}


/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow COMPOUNDS {
    take:
    database
    pubchem_identifiers

    main:
    KEGG_EXTRACT()
    KEGG_TRANSFORM(KEGG_EXTRACT.out)
    KEGG_LOAD(database, KEGG_TRANSFORM.out)
    PUBCHEM_EXTRACT(pubchem_identifiers)
    PUBCHEM_TRANSFORM(PUBCHEM_EXTRACT.out)
    PUBCHEM_LOAD(KEGG_LOAD.out.db, PUBCHEM_TRANSFORM.out)
    STRUCTURES_ETL(PUBCHEM_LOAD.out.db)

    emit:
    db = STRUCTURES_ETL.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
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

    main:
    db = Channel.fromPath("${params.outdir}/${params.database}")
    pubchem_identifiers = Channel.fromPath("${params.pubchem_identifiers}", checkIfExists: true)
    COMPOUNDS(db, pubchem_identifiers)
}
