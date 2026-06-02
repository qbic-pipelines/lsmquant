process NUMORPHALIGN {
    tag "$meta.id"
    label 'process_high_long'


    container "nf-core/numorph_preprocessing:1.0.0"

    input:
    tuple val(meta), path(img_directory),  path(parameter_file), path(variables), path(NM_variable)


    output:
    tuple val(meta), path("./results/samples/alignment/")                     , emit: samples_alignment
    tuple val(meta), path("./results/variables/")                             , emit: variables_alignment
    tuple val(meta), path("./results/NM_variables.mat")                       , emit: NM_variable

    tuple val("${task.process}"), val('numorph_align'), val('1.0.0'), emit: versions_numorph_align, topic: versions



    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    # create output directories needed by the tool
    mkdir -p ./results/samples/



    # symlink input files to variables directory
    cp -rL ${variables} ./results

    # resolve symlinks and paths for matlab tool
    img_dir=\$(readlink -f ${img_directory})
    parameter_file=\$(readlink -f ${parameter_file})
    results_dir=\$(readlink -f ./results)
    NM_variables=\$(readlink -f ${NM_variable})

    numorph_preprocessing 'input_dir' \$img_dir 'output_dir' \$results_dir 'parameter_file' \$parameter_file 'sample_name' ${meta.id} 'stage' 'align' 'NM_variables' \$NM_variables

    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p results/samples/alignment
    mkdir -p results/variables

    touch results/variables/path_table.mat
    touch results/variables/alignment_table.mat
    touch results/variables/z_displacement_align.mat
    touch results/NM_variables.mat
    touch results/samples/alignment/${meta.id}_full.tif

    """
}
