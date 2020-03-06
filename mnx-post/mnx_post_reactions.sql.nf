#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.outdir = 'results'
params.database = 'sqlite:///metanetx.sqlite'
params.bigg = "${params.outdir}/bigg"
params.expasy = "${params.outdir}/expasy"
params.kegg = "${params.outdir}/kegg"
params.seed = "${params.outdir}/seed"

log.info """
************************************************************

metanetx-post-reactions
=======================
Database URI: ${params.database}
Results Path: ${params.outdir}

************************************************************

"""

/* ############################################################################
 * Define workflow processes.
 * ############################################################################
 */

process bigg_extract {
    publishDir "${params.bigg}", mode:'link'

    output:
    path 'bigg_universal_reactions.json'

    """
    mnx-post reactions bigg extract
    """
}

process bigg_transform {
    publishDir "${params.bigg}", mode:'link'

    input:
    path universal_reactions

    output:
    path 'bigg_reaction_names.json'

    """
    mnx-post reactions bigg transform ${universal_reactions}
    """
}

process bigg_load {
    publishDir "${params.bigg}", mode:'link'

    input:
    path db
    path reaction_names

    output:
    path db

    """
    mnx-post reactions bigg load ${params.database} ${reaction_names}
    """
}

process expasy_extract {
    publishDir "${params.expasy}", mode:'link'

    output:
    path 'enzyme.rdf'

    """
    mnx-post reactions expasy extract ${params.email}
    """
}

process expasy_transform {
    publishDir "${params.expasy}", mode:'link'

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
    publishDir "${params.expasy}", mode:'link'

    input:
    path db
    path enzyme_names
    path enzyme_replacements

    output:
    path db

    """
    mnx-post reactions expasy load ${params.database} ${enzyme_names} \
        ${enzyme_replacements}
    """
}

process kegg_extract {
    publishDir "${params.kegg}", mode:'link'

    input:
    path db

    output:
    path 'kegg_reactions.json'

    """
    mnx-post reactions kegg extract ${params.database}
    """
}

process kegg_transform {
    publishDir "${params.kegg}", mode:'link'

    input:
    path reactions

    output:
    path 'kegg_reaction_names.json'

    """
    mnx-post reactions kegg transform ${reactions}
    """
}

process kegg_load {
    publishDir "${params.kegg}", mode:'link'

    input:
    path db
    path reaction_names

    output:
    path db

    """
    mnx-post reactions kegg load ${params.database} ${reaction_names}
    """
}

process seed_extract {
    publishDir "${params.seed}", mode:'link'

    output:
    path 'seed_reactions.json'

    """
    mnx-post reactions seed extract
    """
}

process seed_transform {
    publishDir "${params.seed}", mode:'link'

    input:
    path reactions

    output:
    path 'seed_reaction_names.json'

    """
    mnx-post reactions seed transform ${reactions}
    """
}

process seed_load {
    publishDir "${params.seed}", mode:'link'

    input:
    path db
    path reaction_names

    output:
    path db

    """
    mnx-post reactions seed load ${params.database} ${reaction_names}
    """
}


/* ############################################################################
 * Define named workflows to be included elsewhere.
 * ############################################################################
 */

workflow bigg_names {
    take:
    path database

    main:
    bigg_info()
    bigg_extract()
    bigg_transform(bigg_extract.out)
    bigg_load(database, bigg_transform.out)

    emit:
    db = bigg_load.out
}

workflow expasy_names {
    take:
    path database

    main:
    expasy_extract()
    expasy_transform(expasy_extract.out)
    expasy_load(database, expasy_transform.names, expasy_transform.replacements)

    emit:
    db = expasy_load.out
}

workflow kegg_names {
    take:
    path database

    main:
    kegg_info()
    kegg_extract(database)
    kegg_transform(kegg_extract.out)
    kegg_load(database, kegg_transform.out)

    emit:
    db = kegg_load.out
}

workflow seed_names {
    take:
    path database

    main:
    seed_extract()
    seed_transform(seed_extract.out)
    seed_load(database, seed_transform.out)

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
    expasy_extract()
}
