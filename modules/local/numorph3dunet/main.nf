process NUMORPH3DUNET {
    tag "$meta.id"
    label 'process_gpu'

    container "nf-core/numorph-3dunet:1.0.0"

    input:
    tuple val(meta), path(img_directory), path(parameter_file)
    path(model_file)

    output:
    tuple val(meta), path ("${prefix}/")              , emit: cellcounts

    tuple val("${task.process}"), val('numorph-3dunet'), val('1.0.0'), emit: versions_numorph_3dunet, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    source /opt/conda/etc/profile.d/conda.sh
    conda activate 3dunet

    echo "Checking GPU access:"
    nvidia-smi

    mkdir -p ${prefix}
    img_dir=\$(readlink -f ${img_directory})



    numorph_3dunet.predict \\
        -i \$img_dir \\
        -o ${prefix} \\
        --model_file ${model_file} \\
        --sample_id ${prefix} \\
        $args

    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p ${prefix}
    touch ${prefix}/${prefix}.csv
    touch ${prefix}/${prefix}_counts.csv

    """
}
