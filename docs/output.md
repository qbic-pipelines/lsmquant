# nf-core/lsmquant: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarizes results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [NumorphIntensity](#numorphintensity) - Measures intensity parameters for illumination correction
- [NumorphAlign](#numorphalign) - Performs 2D rigid or 3D non-linear channel alignment
- [NumorphStitch](#numoprhstitch) - Performs 2D iterative stitching of image tiles
- [NumorphResample](#numorphresample) - Generate downsampled images
- [NumorphRegister](#numorphregister) - Performs registration to the Allen Reference Atlas (ARA)
- [Numorph3DUnet](#numorph3dunet) - Performs cell-nuclei segmentation and quantification
- [Mat2JSON](#mat2json) - Converts `.mat`files to JSON
- [MultiQC](#MultiQC) Aggregate report describing workflow run and tools used from the whole pipeline.
- [Pipeline information](#pipeline-information) - Reports the metrics generated during the workflow execution

### StageFiles

This process stages the image files from the input directory to the pipeline's work directory. This step is necessary to avoid duplication of input data in the work directory, as the processes **NumorphIntensity**, **NumorphAlign**, and **NumorphStitch** require the same input data.

### NumorphIntensity

<details markdown="1">
<summary>Output files</summary>

- `Sample_id/intensity/results`
  - `NM_variables.mat`: Contains input and calculated parameters
  - `samples/`
    - `[channel]_x_y_z.tif`: Image comparing raw and adjusted image tiles for respective channel. Example for each tile of the middle z slice
    - `flatfield_*.png`: Flatfield correction heatmap for each channel
    - `tile_adj_*.png`: Heatmap of tile positions displaying illumination correction factor for each tile
    - `y_adj_*.png`: Intensity correction factors along the Y-axis (using intensity profiles specifically for the LaVision Ultramicroscope II)
  - `variables/`
    - `adj_params.mat`: Correction parameters
    - `thresholds.mat`: Intensity thresholds per channel
    - `path_table.mat`: Image information table

</details>

**NumorphIntensity** calculates intensity thresholds and performs intensity adjustments in the y dimension and between image tile stacks on raw images. The process includes the MATLAB implementation of [BaSiC](https://github.com/marrlab/BaSiC) for shading correction.

### NumorphAlign

<details markdown="1">
<summary>Output files</summary>

- `Sample_id/alignment/results`
  - `NM_variables.mat`: Contains input and calculated parameters
  - `samples/`
    - `Sample_id_*_full.tif`: Aligned image for each channel
  - `variables/`
    - `alignment_table.mat`: Alignment table
    - `z_displacement_align.mat`: Z displacement matrix for given channels to the reference
    - `path_table.mat`: Image information table

</details>

**NumorphAlign** performs rigid or non-rigid alignment of channels to a reference (nuclei) channel and determines z displacement per tile for each channel.

### NumorphStitch

<details markdown="1">
<summary>Output files</summary>

- `Sample_id/stitching/results`
  - `NM_variables.mat`: Contains input and calculated parameters
  - `stitched/`
    - `Sample_id_*_stitched.tif`: Stitched images per z slice
  - `variables/`
    - `adj_params.mat`: Correction parameters
    - `thresholds.mat`: Intensity thresholds per channel
    - `path_table.mat`: Image information table
    - `stitch_tforms.mat`: Stitching information
    - `adjusted_z.mat`: Adjusted z positions for each tile
    - `z_disp_matrix.mat`: Z displacement for adjacent tiles
    - `z_displacement_align.mat`: Z displacement matrix for given channels to the reference

</details>

**NumorphStitch** performs 2D iterative stitching.

### NumorphResample

<details markdown="1">
<summary>Output files</summary>

- `Sample_id/resampled/results`
  - `NM_variables.mat`: Contains input and calculated parameters
  - `Sample_id_*.nii`: Downsampled image

</details>

**NumorphResample** downsamples the image resolution to match the Allen Reference Atlas resolution before registration.

### NumorphRegister

<details markdown="1">
<summary>Output files</summary>

- `Sample_id/results`:
  - `NM_variables.mat`: Contains input and calculated parameters
  - `registered/*_MOV_*.nii`: Moving image from registration
  - `registered/*_REF_*.nii`: Reference image from registration
  - `variables/reg_params.mat`: Registration parameters
  </details>

**NumorphRegister** performs image registration to the Allen Reference Atlas.

### Numorph3DUnet

<details markdown="1">
<summary>Output files</summary>

- `Sample_id/3DUnet/`
  - `Sample_id_counts.csv`
  - `Sample_id.csv`

</details>

**Numorph3DUnet** performs cell-nuclei segmentation and quantification from the nuclear channel.

### Mat2JSON

<details markdown="1">
<summary>Output files</summary>

- `process/sampleID`
  - `*.json|*.csv`: Converted mat file
  </details>

  **Mat2JSON** converts a given `.mat`file into a `CSV` if the data is stored as a table data structure or a `JSON` for other nested data structures.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.

</details>

[**MultiQC**](http://multiqc.info) collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
