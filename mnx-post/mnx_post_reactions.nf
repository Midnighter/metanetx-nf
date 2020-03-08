#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.database = 'metanetx.sqlite'
params.outdir = 'results'
params.storage = 'storage'

log.info """
************************************************************

metanetx-post-reactions
=======================
SQLite Database: ${params.database}
Results Path: ${params.outdir}
Permanent Cache: ${params.storage}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process bigg_extract {
    storeDir "${params.storage}"

    output:
    path 'bigg_universal_reactions.json'

    """
    mnx-post reactions bigg extract
    """
}

process bigg_transform {
    input:
    path universal_reactions

    output:
    path 'bigg_reaction_names.json'

    """
    mnx-post reactions bigg transform ${universal_reactions}
    """
}

process bigg_load {
    input:
    path db
    path reaction_names

    output:
    path db

    """
    mnx-post reactions bigg load sqlite:///${db} ${reaction_names}
    """
}

process expasy_extract {
    storeDir "${params.storage}"

    output:
    path 'enzyme.rdf'

    """
    mnx-post reactions expasy extract ${params.email}
    """
}

process expasy_transform {
    input:
    path enzymes

    output:
    path 'expasy_reaction_names.json', emit: names
    path 'expasy_replacements.json', emit: replacements

    """
    mnx-post reactions expasy transform ${enzymes}
    """
}

process expasy_load {
    input:
    path db
    path enzyme_names
    path enzyme_replacements

    output:
    path db

    """
    mnx-post reactions expasy load sqlite:///${db} \
        ${enzyme_names} ${enzyme_replacements}
    """
}

process kegg_extract {
    storeDir "${params.storage}"

    output:
    path 'kegg_reactions.json'

    """
    mnx-post reactions kegg extract
    """
}

process kegg_transform {
    input:
    path reactions

    output:
    path 'kegg_reaction_names.json'

    """
    mnx-post reactions kegg transform ${reactions}
    """
}

process kegg_load {
    input:
    path db
    path reaction_names

    output:
    path db

    """
    mnx-post reactions kegg load sqlite:///${db} ${reaction_names}
    """
}

process seed_extract {
    storeDir "${params.storage}"

    output:
    path 'seed_reactions.json'

    """
    mnx-post reactions seed extract
    """
}

process seed_transform {
    input:
    path reactions

    output:
    path 'seed_reaction_names.json'

    """
    mnx-post reactions seed transform ${reactions}
    """
}

process seed_load {
    publishDir "${params.outdir}", mode:'link'

    input:
    path db
    path reaction_names

    output:
    path db

    """
    mnx-post reactions seed load sqlite:///${db} ${reaction_names}
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
    bigg_extract()
    bigg_transform(bigg_extract.out)
    bigg_load(database, bigg_transform.out)
    expasy_extract()
    expasy_transform(expasy_extract.out)
    expasy_load(
        bigg_load.out,
        expasy_transform.out.names,
        expasy_transform.out.replacements
    )
    kegg_extract()
    kegg_transform(kegg_extract.out)
    kegg_load(expasy_load.out, kegg_transform.out)
    seed_extract()
    seed_transform(seed_extract.out)
    seed_load(kegg_load.out, seed_transform.out)

    emit:
    db = seed_load.out
}

/* ############################################################################
 * Define an implicit workflow that only runs when this is the main nextflow
 * pipeline called.
 * ############################################################################
 */

workflow {
    main:
    Channel.fromPath("${params.outdir}/${params.database}") \
    | reactions
}
