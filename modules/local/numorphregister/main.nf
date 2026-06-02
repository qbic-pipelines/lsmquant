process NUMORPHREGISTER {
    tag "$meta.id"
    label 'process_high_long'

    container "nf-core/numorph_analyze:1.0.0"

    input:
    tuple val(meta), path(resampled_directory), path(parameter_file)

    output:
    tuple val(meta), path("results/registered/")                 , emit: registered
    tuple val(meta), path("results/variables/")                  , emit: variables
    tuple val(meta), path("results/NM_variables.mat")             , emit: NM_variables

    tuple val("${task.process}"), val('numorphregister'), val('1.0.0'), emit: versions_numorph_analyze, topic: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p results/variables/
    mkdir -p results/resampled/
    mkdir -p results/registered/


    ln -sr ${resampled_directory} results/resampled

    #resolve symlinks and paths
    resampled_directory=\$(readlink -f ./results/resampled/)
    parameter_file=\$(readlink -f ${parameter_file})
    results_dir=\$(readlink -f ./results)

    numorph_analyze 'input_dir' \$resampled_directory 'output_dir' \$results_dir 'parameter_file' \$parameter_file 'sample_name' ${prefix} 'stage' 'register' 'NM_variables' '' 'use_processed_images' 'resampled'

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p results/registered
    mkdir -p results/variables

    touch results/variables/reg_params.mat
    touch results/variables/${prefix}_mask.mat
    touch results/NM_variables.mat
    touch results/registered/${prefix}_registered.tif

    """
}
