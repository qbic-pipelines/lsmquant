process NUMORPHSTITCH {
    tag "$meta.id"
    label 'process_high_long'

    container "nf-core/numorph_preprocessing:1.0.0"

    input:
    tuple val(meta), path(img_directory), path(parameter_file), path(variables), path(NM_variable)

    output:
    tuple val(meta),  path("results/stitched/")                              , emit: stitched
    tuple val(meta),  path("results/variables/")                             , emit: variables_stitched
    tuple val(meta),  path("results/NM_variables.mat")                       , emit: NM_variable

    tuple val("${task.process}"), val('numorph_stitch'), val('1.0.0'), emit: versions_numorph_stitch, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def NM_var = NM_variable ? NM_variable : ''
    def variables_input = variables ? variables : ''
    """
    export MCR_CACHE_ROOT=\${PWD}/.mcrCache

    # create output directories needed by the tool
    mkdir -p ./results/stitched/

    # symlink input files to variables directory if variables input is provided
    if [ -n "${variables_input}" ]; then
        cp -rL ${variables_input} ./results
    fi
        mkdir -p ./results/variables/

    img_dir=\$(readlink -f ${img_directory})
    parameter_file=\$(readlink -f ${parameter_file})
    results_dir=\$(readlink -f ./results)

    # if NM_variable  exist provide it as input to the tool
    if [ -n "${NM_var}" ]; then
        NM_variables=\$(readlink -f ${NM_var})
        numorph_preprocessing 'input_dir' \$img_dir 'output_dir' \$results_dir 'parameter_file' \$parameter_file 'sample_name' ${meta.id} 'stage' 'stitch' 'NM_variables' \$NM_variables
    fi

    numorph_preprocessing 'input_dir' \$img_dir 'output_dir' \$results_dir 'parameter_file' \$parameter_file 'sample_name' ${meta.id} 'stage' 'stitch'

    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p results/stitched
    mkdir -p results/variables

    touch results/variables/z_dips_matrix.mat
    touch results/variables/stitch_tforms.mat
    touch results/variables/path_table.mat
    touch results/variables/adjusted_z.mat
    touch results/NM_variables.mat
    touch results/stitched/${meta.id}_stitched.tif

    """
}
