#!/usr/bin/env nextflow

params.outdir = 'results'
params.database = 'metanetx.sqlite'
params.sdk_version = '0.3.2'
params.mnx_release = '3.2'

table_names_ch = Channel.from([
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
    val list from table_names_ch.collect()

    output:
    file '*.tsv.gz' into raw_tables_ch

    shell:
    """
    mnx-sdk pull --version !{params.mnx_release} . !{list.join(' ')}
    """
}

process transformTables {
    publishDir "${params.outdir}/mnx-processed", mode:'link'

    input:
    file table from raw_tables_ch.flatten()

    output:
    file "processed_${table}"
    val true into transform_ch

    """
    mnx-sdk etl ${table.getSimpleName().replace('_', '-')} \
        ${table} processed_${table}
    """
}

process pullRegistry {
    publishDir "${params.outdir}/registry", mode:'link'
    
    output:
    file "identifiers_org.json"
    val true into registry_ch

    """
    mnx-assets extract-registry identifiers_org.json
    """
}

process initDB {
    publishDir "${params.outdir}", mode:'copy', overwrite: true

    output:
    file "${params.database}"
    val true into init_ch
    
    """
    mnx-assets init --drop yes sqlite:///${params.database}
    """
}

process etlNamespaces {

    input:
    val transform_done from transform_ch
    val registry_done from registry_ch
    val init_done from init_ch

    output:
    val true into namespaces_ch
    
    """
    mnx-assets namespaces etl sqlite:///${params.outdir}/${params.database} \
        ${params.outdir}/identifiers_org.json \
        ${params.outdir}/processed_chem_prop.tsv.gz \
        ${params.outdir}/processed_chem_xref.tsv.gz \
        ${params.outdir}/processed_comp_prop.tsv.gz \
        ${params.outdir}/processed_comp_xref.tsv.gz \
        ${params.outdir}/processed_reac_prop.tsv.gz \
        ${params.outdir}/processed_reac_xref.tsv.gz
    """
}

