process CONVERSIONCZITIF {
    label 'process_low'

    container '/home/tatiana/2025_11_Irene/lsmquant/conversion.sif'

    input:
    tuple  val(meta), path(image) ,val(tile_position), val(marker), val(group_val), val(slice_number)

    output:
    path("converted/*.tif"), emit: converted_folder

    script:
    def args = task.ext.args ?: ''
    """
    conversion_czi_tif.py --czi_filepath $image --position $tile_position --markers $marker --group $group_val --max_z_number $slice_number --n_cores  $task.cpus  --outdir "converted" $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
    
    stub:
    """
    mkdir -p converted
    touch converted/test.tif
    
    """
}
