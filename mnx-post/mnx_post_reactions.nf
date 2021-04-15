#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process BIGG_EXTRACT {
    storeDir params.storage

    output:
    path 'bigg_universal_reactions.json'

    """
    mnx-post reactions bigg extract
    """
}

process BIGG_TRANSFORM {
    input:
    path universal_reactions

    output:
    path 'bigg_reaction_names.json'

    """
    mnx-post reactions bigg transform "${universal_reactions}"
    """
}

process BIGG_LOAD {
    input:
    path db
    path reaction_names

    output:
    path "${db.getName()}", emit: db

    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-post reactions bigg load "sqlite:///${db.getName()}" "${reaction_names}"
    """
}

process EXPASY_EXTRACT {
    storeDir params.storage

    output:
    path 'enzyme.rdf'

    """
    mnx-post reactions expasy extract ${params.email}
    """
}

process EXPASY_TRANSFORM {
    input:
    path enzymes

    output:
    path 'expasy_reaction_names.json', emit: names
    path 'expasy_replacements.json', emit: replacements

    """
    mnx-post reactions expasy transform "${enzymes}"
    """
}

process EXPASY_LOAD {
    input:
    path db
    path enzyme_names
    path enzyme_replacements

    output:
    path "${db.getName()}", emit: db

    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-post reactions expasy load "sqlite:///${db.getName()}" \
        "${enzyme_names}" "${enzyme_replacements}"
    """
}

process KEGG_EXTRACT {
    storeDir params.storage

    output:
    path 'kegg_reactions.json'

    """
    mnx-post reactions kegg extract --rate-limit=5
    """
}

process KEGG_TRANSFORM {
    input:
    path reactions

    output:
    path 'kegg_reaction_names.json'

    """
    mnx-post reactions kegg transform "${reactions}"
    """
}

process KEGG_LOAD {
    input:
    path db
    path reaction_names

    output:
    path "${db.getName()}", emit: db

    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-post reactions kegg load "sqlite:///${db.getName()}" "${reaction_names}"
    """
}

process SEED_EXTRACT {
    storeDir params.storage

    output:
    path 'seed_reactions.json'

    """
    mnx-post reactions seed extract
    """
}

process SEED_TRANSFORM {
    input:
    path reactions

    output:
    path 'seed_reaction_names.json'

    """
    mnx-post reactions seed transform "${reactions}"
    """
}

process SEED_LOAD {
    publishDir params.outdir, mode:'link'

    input:
    path db
    path reaction_names

    output:
    path "${db.getName()}", emit: db

    """
    cp --remove-destination "\$(realpath -e '${db}')" "${db.getName()}"
    mnx-post reactions seed load "sqlite:///${db.getName()}" "${reaction_names}"
    """
}


/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow reactions {
    take:
    database

    main:
    BIGG_EXTRACT()
    BIGG_TRANSFORM(BIGG_EXTRACT.out)
    BIGG_LOAD(database, BIGG_TRANSFORM.out)
    EXPASY_EXTRACT()
    EXPASY_TRANSFORM(EXPASY_EXTRACT.out)
    EXPASY_LOAD(
        BIGG_LOAD.out,
        EXPASY_TRANSFORM.out.names,
        EXPASY_TRANSFORM.out.replacements
    )
    KEGG_EXTRACT()
    KEGG_TRANSFORM(KEGG_EXTRACT.out)
    KEGG_LOAD(EXPASY_LOAD.out, KEGG_TRANSFORM.out)
    SEED_EXTRACT()
    SEED_TRANSFORM(SEED_EXTRACT.out)
    SEED_LOAD(KEGG_LOAD.out, SEED_TRANSFORM.out)

    emit:
    db = SEED_LOAD.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    log.info """
************************************************************

metanetx-post-reactions
=======================
SQLite Database: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

    main:
    Channel.fromPath("${params.outdir}/${params.database}") \
    | reactions
}
