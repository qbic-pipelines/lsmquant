# nf-core/lsmquant: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.x.x -

### `Fixed``

- [Issue#71](https://github.com/nf-core/lsmquant/issues/71):
  - adding test_gpu profile to run test with GPU
  - update test profile to run without gpu
  - update documentation (README + usage) for both profiles

## 1.0.3 - Excited Squid Patch

### `Added`

- [PR#72](https://github.com/nf-core/lsmquant/pull/75) remove local module numorph3dunet and include the updated nf-core/module numorph_3dunet

## 1.0.2 - Excited Squid Patch

### `Added`

- [PR#62](https://github.com/nf-core/lsmquant/pull/62) - Template update
- zenodo DOI to cite all versions
- new metromap (smaller nf-core logo, fix typo)
- [PR#69](https://github.com/nf-core/lsmquant/pull/69) - Fix to prevent stitching from starting twice when “NM_variables” is specified

## 1.0.1 - Excited Squid Patch

### `Fixed`

- [PR#57](https://github.com/nf-core/lsmquant/pull/57) - Fix input declaration of the model file for the module: `numorph3dunet` to be reused for all inputs.
- remove conda batch from readme, the pipeline does not support conda.
- set matlab cache directory in numorph_stitch to fix concurrency issues when running multiple samples.

## v1.0.0 - Excited Squid

Initial release of nf-core/lsmquant, created with the [nf-core](https://nf-co.re/) template.

### `Added`

The main functionalities of the NuMorph toolbox are added up until the nuclei quantification via a 3DUnet.

local Modules:

- numorphintensity
- numorphalign
- numorphstitch
- numorphresample
- numorphregister
- numorph3dunet
- mat2json
- stagefiles

nf-core Modules:

- multiqc
- unzip

local subworkflows:

- numorphpreprocessing:
  - numorphintensity
  - numorphalign
  - numorphstitch
  - mat2json
- ara-registration
  - numorphresample
  - numorphregister
  - mat2json

### `Fixed`

### `Dependencies`

Custom numorph container `numorphpreprocessing`, `numorphanalyze`, `mat2json`, and `numorph3dunet`are on the nf-core quay io repository. Compiled matlab application [numorph_preprocessing](https://github.com/CaroAMN/numorph_preprocessing), [mat2json](https://github.com/CaroAMN/mat2json) and the source code for the [3Dunet](https://github.com/CaroAMN/numorph_3dunet) python package are public repositories. The source code of the tools are found here [NuMorph_dev](https://github.com/CaroAMN/Numorph_dev/tree/main)

### `Deprecated`
