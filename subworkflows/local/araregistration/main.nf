
include { NUMORPH_RESAMPLE       } from '../../../modules/nf-core/numorph/resample'
include { NUMORPHREGISTER        } from '../../../modules/local/numorphregister'
include { MAT2JSON               } from '../../../modules/nf-core/mat2json'
include { softwareVersionsToYAML } from '../../../subworkflows/nf-core/utils_nfcore_pipeline/'

workflow ARAREGISTRATION {

    take:

    stitched_data // channel: [ val(meta), path(images), path(parameters.csv)  ]
    main:

    ch_versions = Channel.empty()
    sample_meta = stitched_data.map { meta, img_dir, params -> meta }

    NUMORPH_RESAMPLE (stitched_data)

    def resampled_data = stitched_data
        .join(NUMORPH_RESAMPLE.out.resampled)
        .map { meta, stitched_img_directory, parameter_file, resampled ->
            [meta, resampled, parameter_file]
        }


    NUMORPHREGISTER (resampled_data)

    def mat_files = NUMORPHREGISTER.out.variables
        .flatMap { meta, variables_dir ->
            variables_dir.listFiles()
                .findAll { it.name.endsWith('.mat') }
                .collect { matfile ->  [meta, matfile] }
        }
        .mix(NUMORPHREGISTER.out.NM_variables)

    MAT2JSON (mat_files, "registration")


    emit:

    variables    = NUMORPHREGISTER.out.variables            // channel: variables
    registered   = NUMORPHREGISTER.out.registered           // channel: registered
    NM_variable  = NUMORPHREGISTER.out.NM_variables         // channel: NM_variables

}
