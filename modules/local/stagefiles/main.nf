
process STAGEFILES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "nf-core/ubuntu:22.04"

    input:
    tuple val(meta), path(file_directory) // directory containing files

    output:
    tuple val(meta), path("${meta.id}_raw/*")  , emit: raw_files
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # This is a stageing module
    # The purpose is to stage files from a directory into the working directory once
    # preventing copying of files multiple times
    # It is a workaround for nf-core/lsmquant
    # In nf-core/lsmquant the first 3 modules need the same raw image directory as input
    # This process will stage the data into the workdir and then it will be symlinked

    mkdir -p ${prefix}_raw
    ln -sr ${file_directory} ${prefix}_raw/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stagefiles: 1.0.0
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stagefiles: 1.0.0
    END_VERSIONS
    """
}
