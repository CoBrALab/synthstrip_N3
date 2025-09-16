# synthstrip_N3 -- A Human T1w Preprocessing Script

synthstrip_N3 is an MRI preprocessing pipeline, which at its core is intended
to correct inhomogeneites (aka bias fields) present in T1-weighted images.

There are two key implementation details which the core design is focused on

1. Implementing a `nu_correct` (aka N3) multi-scale variant similar to `N4BiasFieldCorrection` (aka ITKN4)
2. Iteratively refining the correction to the bias field by classifying the brain
tissue and focusing on the spatial intensity distribution within that tissue.

In addition, the following standardization steps are performed:

- Intensity range is rescaled 0-65535
- Intensity distribution is centered at 32767
- Intensity histogram is trimmed top and bottom 0.1%
- Head field-of-view is cropped/padded to match the FOV of the MNI ICBM model
- Image intensity outside the head is set to 0

As a side effect of the internal processes it uses to perform correction,
this pipeline also produces a number of secondary outputs suitable for use in
neuroimaging research:

- Registration (affine and non-linear transforms) to a model space (typically MNI ICBM 09c)
- Brain mask
- Brain tissue classification (GM/WM/CSF or GM/DEEPGM/WM/CSF)
- A denoised (via adaptive non-local means) version of the image
- Quality control images

## Dependencies

- minc-toolkit-v2 https://bic-mni.github.io/
- `antsRegistration_affine_SyN.sh` from https://github.com/CoBrALab/minc-toolkit-extras
- ANTs with MINC support enabled https://github.com/ANTsX/ANTs
- Priors (see below)
- imagemagick for a static QC image
- The webp package from google to get animated QC images: https://developers.google.com/speed/webp/download

## Usage

```bash
synthstrip_N3 Human T1w Preprocessing
Usage: ./synthstrip_N3.sh [-h|--help] [--distance <arg>] [--levels <arg>] [--cycles <arg>] [--iters <arg>] [--lambda <arg>] [--fwhm <arg>] [--stop <arg>] [--isostep <arg>] [--prior-config <arg>] [--lsq6-resample-type <arg>] [-c|--(no-)clobber] [-v|--(no-)verbose] [-d|--(no-)debug] <input> <output>
        <input>: Input MINC or NIFTI file
        <output>: Output MINC or NIFTI File
        -h, --help: Prints help
        --distance: Initial distance for correction (default: '400')
        --levels: Levels of correction with distance halving (default: '4')
        --cycles: Cycles of correction at each level (default: '3')
        --iters: Iterations of correction for each cycle (default: '50')
        --lambda: Spline regularization value (default: '2.0e-6')
        --fwhm: Intensity histogram smoothing fwhm (default: '0.1')
        --stop: Stopping criterion for N3 (default: '0.00001')
        --isostep: Isotropic resampling resolution in mm for N3 (default: '4')
        --prior-config: Config file to use for models and priors (default: 'mni_icbm152_nlin_sym_09c.cfg')
        --lsq6-resample-type: (Standalone) Type of resampling lsq6(rigid) output files undergo, can be "coordinates", "none", or a floating point value for the isotropic resolution in mni_icbm152_t1_tal_nlin_sym_09c space (default: 'none')
        -c, --clobber, --no-clobber: Overwrite files that already exist (off by default)
        -v, --verbose, --no-verbose: Run commands verbosely (off by default)
        -d, --debug, --no-debug: Show all internal commands and logic for debug (off by default)
```

## Getting Priors

This pipeline uses the priors available from the MNI at http://nist.mni.mcgill.ca/?page_id=714. The "ANTs" style priors
are modified versions of https://figshare.com/articles/ANTs_ANTsR_Brain_Templates/915436 to work with this pipeline
and available upon request.

## Adding your own priors

If you want to provide your own priors, the following files are required:
- `REGISTRATIONMODEL` - the t1-weighted image
- `REGISTRATIONBRAINMASK` - the brain mask
- `WMPRIOR` - a probability map of white matter
- `GMPRIOR` - a probability map of gray matter
- `CSFPRIOR` - a probability map of CSF
- (if your template is not in MNI space) `MNI_XFM`, an affine transform from your template to MNI ICBM NLIN SYM 09c space

Generate a config file defining these variables and provide it to the ``--prior-config`` option.

## Quality Control Outputs

`synthstrip_N3.sh` provides 3 quality control images, which provide feedback on the success of the following stages
- `<basename>.qc.bias.jpg`, alternating rows of the original image and the bias-corrected image
- `<basename>.qc.mask.classified.jpg`, alternating rows of the brain mask image and the classified image
- `<basename>.qc.bias.jpg`, alternating rows of the affine MNI outline image and the nlin MNI outline image

Additionally, `<basename>.qc.webp` an animated image which combined the static images together.

### Bias Field QC Example

![Bias Field QC Example](examples/example.qc.bias.jpg)

### Brain Mask and Classification QC Example

![Brain Mask and Classification QC Example](examples/example.mask.classified.jpg)

### Registration QC Example

![Registration QC Example](examples/example.qc.registration.jpg)
