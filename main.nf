#!/usr/bin/env nextflow

params.outdir = 'results'
params.database = 'metanetx.sqlite'
params.mnx_release = '3.2'

log.info"""
************************************************************

metanetx-nf
===========
Results Path: ${params.outdir}
Database URI: ${params.database}
MetaNetX Release: ${params.mnx_release}

************************************************************

"""

table_names_ch = Channel.fromList([
    "chem_prop.tsv",
    "chem_xref.tsv",
    "comp_prop.tsv",
    "comp_xref.tsv",
    "reac_prop.tsv",
    "reac_xref.tsv",
])

process pullTables {
    publishDir "${params.outdir}/mnx-raw", mode:'link'

    input:
    val names from table_names_ch.collect()

    output:
    file '*.tsv.gz' into raw_tables_ch

    """
    mnx-sdk pull --version ${params.mnx_release} . ${names.join(' ')}
    """
}

process transformTables {
    publishDir "${params.outdir}/mnx-processed", mode:'link'

    input:
    file table from raw_tables_ch.flatten()

    output:
    file "processed_${table}" into processed_tables_ch

    """
    mnx-sdk etl ${table.getSimpleName().replace('_', '-')} \
        ${table} processed_${table}
    """
}

process pullRegistry {
    publishDir "${params.outdir}/registry", mode:'link'

    output:
    file "identifiers_org.json" into registry_ch

    """
    mnx-assets namespaces extract-registry identifiers_org.json
    """
}

process initDB {
    output:
    file "${params.database}" into init_ch

    """
    mnx-assets init --drop yes sqlite:///${params.database}
    """
}

processed_map_ch = processed_tables_ch
    .groupBy({ file ->
        def name = file.getName()
        def key = name[10..(name.size() - 8)]
        return key
    })
    .dump()

process etlNamespaces {
    input:
    val tables from processed_map_ch
    file registry from registry_ch
    file db from init_ch

    output:
    file "${db}" into namespaces_ch

    """
    mnx-assets namespaces reset sqlite:///${db}
    mnx-assets namespaces etl sqlite:///${db} \
        ${registry} \
        ${tables['chem_prop'].head()} \
        ${tables['chem_xref'].head()} \
        ${tables['comp_prop'].head()} \
        ${tables['comp_xref'].head()} \
        ${tables['reac_prop'].head()} \
        ${tables['reac_xref'].head()} \
    """
}

process etlCompartments {
    input:
    file db from namespaces_ch
    val tables from processed_map_ch

    output:
    file "${db}" into compartments_ch

    """
    mnx-assets compartments reset sqlite:///${db}
    mnx-assets compartments etl sqlite:///${db} \
        ${tables['comp_prop'].head()} \
        ${tables['comp_xref'].head()}
    """
}

process etlCompounds {
    input:
    file db from compartments_ch
    val tables from processed_map_ch

    output:
    file "${db}" into compounds_ch

    """
    mnx-assets compounds reset sqlite:///${db}
    mnx-assets compounds etl sqlite:///${db} \
        ${tables['chem_prop'].head()} \
        ${tables['chem_xref'].head()}
    """
}

process etlReactions {
    publishDir "${params.outdir}/registry", mode:'copy'

    input:
    file db from compounds_ch
    val tables from processed_map_ch

    output:
    file "${db}" into reactions_ch

    """
    mnx-assets reactions reset sqlite:///${db}
    mnx-assets reactions etl sqlite:///${db} \
        ${tables['reac_prop'].head()} \
        ${tables['reac_xref'].head()}
    """
}
