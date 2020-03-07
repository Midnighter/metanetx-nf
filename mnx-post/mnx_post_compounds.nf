#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.chem_backend = 'rdkit'
params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

log.info """
************************************************************

metanetx-post-compounds
=======================
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

    input:
    path db

    output:
    path 'kegg_compounds.json'

    """
    mnx-post compounds kegg extract sqlite:///${db}
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

    main:
    kegg_extract(database)
    kegg_transform(kegg_extract.out)
    kegg_load(database, kegg_transform.out)
    structures_etl(kegg_load.out.db)

    emit:
    db = kegg_load.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    main:
    Channel.fromPath("${params.outdir}/${params.database}") \
    | compounds
}
