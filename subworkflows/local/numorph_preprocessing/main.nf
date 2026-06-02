
include { NUMORPH_INTENSITY                    } from '../../../modules/nf-core/numorph/intensity'
include { NUMORPHALIGN                         } from '../../../modules/local/numorphalign/'
include { NUMORPHSTITCH                        } from '../../../modules/local/numorphstitch/'
include { MAT2JSON                             } from '../../../modules/nf-core/mat2json/'

workflow NUMORPH_PREPROCESSING {

    take:
    samplesheet  // channel: [ val(meta), path(img_directory), path(parameter_file) ]

    main:


    NUMORPH_INTENSITY (samplesheet)


    def align_input = samplesheet
        .join(NUMORPH_INTENSITY.out.variables)
        .join(NUMORPH_INTENSITY.out.NM_variable)

    NUMORPHALIGN (align_input)

    def stitch_input = samplesheet
        .join(NUMORPHALIGN.out.variables_alignment)
        .join(NUMORPHALIGN.out.NM_variable)

    NUMORPHSTITCH (stitch_input)

    def mat_files = NUMORPHSTITCH.out.variables_stitched
        .flatMap { meta, variables_dir ->
            variables_dir.listFiles()
                .findAll { it.name.endsWith('.mat') }
                .collect { matfile ->  [meta, matfile] }
        }

    MAT2JSON (mat_files, "preprocessing" )

    emit:

    variables                 = NUMORPHSTITCH.out.variables_stitched
    stitched                  = NUMORPHSTITCH.out.stitched
    NM_variable               = NUMORPHSTITCH.out.NM_variable

}
