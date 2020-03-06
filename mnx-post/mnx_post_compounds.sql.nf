#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.chem_backend = 'rdkit'
params.outdir = 'results'
params.database = 'sqlite:///metanetx.sqlite'
params.kegg = "${params.outdir}/kegg"

log.info """
************************************************************

metanetx-post-compounds
=======================
Chem-Informatics Backend: ${params.chem_backend}
Database URI: ${params.database}
Results Path: ${params.outdir}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process kegg_extract {
    publishDir "${params.kegg}", mode:'link'

    input:
    path db

    output:
    path 'kegg_compounds.json'

    """
    mnx-post compounds kegg extract ${params.database}
    """
}

process kegg_transform {
    publishDir "${params.kegg}", mode:'link'

    input:
    path compounds

    output:
    path 'kegg_inchi.json'

    """
    mnx-post compounds kegg transform --backend=${params.chem_backend} ${compounds}
    """
}

process kegg_load {
    publishDir "${params.kegg}", mode:'link'

    input:
    path db
    path inchis

    output:
    path db
    path 'kegg_inchi_conflicts.json'

    """
    mnx-post compounds kegg load ${params.database} ${inchis}
    """
}

process structures_etl {
    input:
    path db

    output:
    path db

    """
    mnx-post compounds structures etl --backend=${params.chem_backend} ${params.database}
    """
}


/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow kegg_inchis {
    take:
    path database

    main:
    kegg_extract(database)
    kegg_transform(kegg_extract.out)
    kegg_load(database, kegg_transform.out)

    emit:
    db = kegg_load.out
}

workflow augment_structures {
    take:
    path database

    main:
    structures_etl(database)

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
    Channel.fromPath("${params.outdir}/${params.database.minus('sqlite:///')}") \
    | kegg_inchis \
    | augment_structures
}
