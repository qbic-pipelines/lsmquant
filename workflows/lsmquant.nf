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
include { VALIDATE_PARAMETERS    } from '../modules/local/validate_parameters'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



workflow LSMQUANT {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    ch_multiqc_files = Channel.empty()
    ch_versions = Channel.empty()


    // validate numorph specific parameters
    ch_parameter_file = samplesheet.map { meta, img_dir, parameter_file -> [meta, parameter_file] }
    schema_json = file("${projectDir}/assets/numorph_params_schema.json")
    VALIDATE_PARAMETERS(ch_parameter_file, schema_json)

    // branch input channel based on whether zip archive or directory
    samplesheet.branch { meta, img_directory, parameter_file ->
        zip_archive: img_directory[0].endsWith(".zip")
            return tuple(meta, img_directory, parameter_file)
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

    STAGEFILES (img_dir)
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

        def stitch_input = ch_samplesheet
                .map { meta, img_directory, parameter_file ->
                    [meta, img_directory, parameter_file, [],[]]
                }

        NUMORPHSTITCH (stitch_input)
        stitched_output = NUMORPHSTITCH.out.stitched

        // get all mat files
        def mat_files = NUMORPHSTITCH.out.variables_stitched
        .flatMap { meta, variables_dir ->
            variables_dir.listFiles()
                .findAll { it.name.endsWith('.mat') }
                .collect { matfile ->  [meta, matfile] }
        }

        MAT2JSON (mat_files, "stitch_only" )

    }

    // run single channel preprocessing by intensity and stitching
    if (params.stage == 'int_stitch') {

        NUMORPH_STITCH (ch_samplesheet)
        stitched_output = NUMORPH_STITCH.out.stitched

    }

    // run preprocessing with multi channel alignment and stitching
    if (params.stage == 'int_align_stitch') {

        NUMORPH_PREPROCESSING (ch_samplesheet)
        stitched_output= NUMORPH_PREPROCESSING.out.stitched

    }

    stitched_data = ch_samplesheet
            .join (stitched_output)
            .map { meta, img_directory, parameter_file, stitched_data ->
                [meta, stitched_data, parameter_file]
            }

    // run nuclei quantification
    if (params.nuclei_quantification) {

        model_file = file(params.model_file, checkIfExists: !params.model_file.startsWith('http'))
        NUMORPH3DUNET (stitched_data, model_file)

    }
    // run ara registration
    if (params.ara_registration) {

            ARAREGISTRATION (stitched_data)

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


    ch_versions = ch_versions.mix(UNZIP.out.versions)
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
    ch_multiqc_config        = channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? channel.fromPath(params.multiqc_config, checkIfExists: true) : channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ? channel.fromPath(params.multiqc_logo, checkIfExists: true) : channel.empty()

    summary_params      = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description
            ? file(params.multiqc_methods_description, checkIfExists: true)
            : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

    ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))

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
