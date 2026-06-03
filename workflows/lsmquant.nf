/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { NUMORPH_PREPROCESSING  } from '../subworkflows/local/numorph_preprocessing'
include { ARAREGISTRATION        } from '../subworkflows/local/araregistration'
include { NUMORPH_STITCH         } from '../subworkflows/local/numorph_stitch'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_lsmquant_pipeline'
include { MAT2JSON               } from '../modules/local/mat2json'
include { NUMORPH3DUNET          } from '../modules/local/numorph3dunet'
include { UNZIP                  } from '../modules/nf-core/unzip'
include { STAGEFILES             } from '../modules/local/stagefiles'
include { MULTIQC                } from '../modules/nf-core/multiqc'
include { NUMORPHSTITCH          } from '../modules/local/numorphstitch'
include { CONVERSIONCZITIF       } from '../modules/local/conversionczitif'  

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



workflow LSMQUANT {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // branch input channel based on whether zip archive or directory
    samplesheet.branch { meta, img_directory, parameter_file , conversion_file->
        zip_archive: img_directory[0].endsWith(".zip")
            return tuple(meta, img_directory, parameter_file)
        conversion:  conversion_file
            return tuple(meta, conversion_file, parameter_file)
        directory: true
            return tuple(meta, img_directory, parameter_file)
        
    }
    .set { samplesheet_split }


    // if zip archive then unzip first
    samplesheet_split.zip_archive
        .map { meta, zip, parameter_file ->
            tuple(meta, zip)
        }
        .set { zip_archive }

    UNZIP (zip_archive)
    ch_versions = ch_versions.mix(UNZIP.out.versions)
    unzipped_output = UNZIP.out.unzipped_archive
    // join unzipped output with  parameter file
    unzipped_output
        .join(samplesheet_split.zip_archive)
        .map { meta, unzipped, zip, parameter_file ->
            tuple(meta, unzipped, parameter_file)
        }
        .set { ch_unzipped }

    // if directory then stage files
    samplesheet_split.directory
        .map { meta, img_directory, parameter_file ->
            tuple(meta, img_directory)
        }
        .set { img_dir }

    // if conversion
    samplesheet_split.conversion{
        def ch_images = Channel.fromPath(params.input_conversion, checkIfExists: true)
                                 .splitCsv(header:true)
                                 .map { row ->
                                        def meta = [:]
                                        meta.id = row.sample
                                        def image = file(row.image_path)
                                        def tile_position =row.tile_position
                                        def group = row.group
                                        def markers = row.markers
                                        def slicenumber = row.slicenumber
                                        return [meta, image,tile_position,markers,group,slicenumber]
                                    }
                                    .set{image_ch}  
        CONVERSIONCZITIF(ch_images).set{ img_dir}

    STAGEFILES (img_dir)
    ch_versions = ch_versions.mix(STAGEFILES.out.versions)
    staged_images = STAGEFILES.out.raw_files

    staged_images
        .join(samplesheet_split.directory)
        .map { meta, staged, raw_img_directory, parameter_file ->
            tuple(meta, staged, parameter_file)
        }
        .set { ch_stagedfiles }

    // combine unzipped and staged files channels
    ch_samplesheet = Channel.empty()
    ch_samplesheet = ch_unzipped.mix(ch_stagedfiles)


    // run only stitching
    if (params.stage == 'stitch_only') {
        // create empty channels for intensity adjustment outputs
        empty_adj_params_mat = samplesheet.map {[]}
        empty_path_table_mat = samplesheet.map {[]}
        empty_thresholds_mat = samplesheet.map {[]}
        empty_NM_variables = samplesheet.map {[]}
        empty_align_table_mat = samplesheet.map {[]}
        empty_z_displacement_align_mat = samplesheet.map {[]}


          NUMORPHSTITCH (
            ch_samplesheet,
            empty_align_table_mat,
            empty_z_displacement_align_mat,
            empty_path_table_mat,
            empty_thresholds_mat,
            empty_adj_params_mat,
            empty_NM_variables
        )
      //  ch_versions = ch_versions.mix(NUMORPHSTITCH.out.versions)

      //  def stitched_output = NUMORPHSTITCH.out.stitched

    //    stitched_output
    //        .join(samplesheet)
    //        .map { meta, stitched, raw_img_directory, parameter_file ->
    //            tuple(meta, stitched, parameter_file)
    //        }
     //       .set { stitched_data }


        }


        if  (params.conversion_czi_tif==false){
        NUMORPHSTITCH (
            ch_samplesheet,
            empty_align_table_mat,
            empty_z_displacement_align_mat,
            empty_path_table_mat,
            empty_thresholds_mat,
            empty_adj_params_mat,
            empty_NM_variables
        )
        ch_versions = ch_versions.mix(NUMORPHSTITCH.out.versions)

        def stitched_output = NUMORPHSTITCH.out.stitched

        stitched_output
            .join(samplesheet)
            .map { meta, stitched, raw_img_directory, parameter_file ->
                tuple(meta, stitched, parameter_file)
            }
            .set { stitched_data }
    }}

    // run single channel preprocessing by intensity and stitching
    if (params.stage == 'int_stitch') {
        NUMORPH_STITCH (ch_samplesheet)
        ch_versions = ch_versions.mix(NUMORPH_STITCH.out.versions)

        def stitched_output = NUMORPH_STITCH.out.stitched

        stitched_output
            .join(samplesheet)
            .map { meta, stitched, raw_img_directory, parameter_file ->
                tuple(meta, stitched, parameter_file)
            }
            .set { stitched_data }
    }

    // run preprocessing with multi channel alignment and stitching
    if (params.stage == 'int_align_stitch') {
        NUMORPH_PREPROCESSING (ch_samplesheet)
        ch_versions = ch_versions.mix(NUMORPH_PREPROCESSING.out.versions)

        def stitched_output = NUMORPH_PREPROCESSING.out.stitched

        stitched_output
            .join(samplesheet)
            .map { meta, stitched, raw_img_directory, parameter_file ->
                tuple(meta, stitched, parameter_file)
            }
            .set { stitched_data }
    }

    // run nuclei quantification
    if (params.nuclei_quantification) {
        model_file = Channel.fromPath(params.model_file, checkIfExists: !params.model_file.startsWith('http'))
        NUMORPH3DUNET (stitched_data, model_file)
        ch_versions = ch_versions.mix(NUMORPH3DUNET.out.versions)
    }
    // run ara registration
    if (params.ara_registration) {
            ARAREGISTRATION (stitched_data)
            ch_versions = ch_versions.mix(ARAREGISTRATION.out.versions)
        }


    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'lsmquant_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

     //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )
    multiqc_report = MULTIQC.out.report.toList()

    emit:
    multiqc_report          // channel: final MultiQC report
    ch_collated_versions    // channel: collated software versions in YAML file

}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
