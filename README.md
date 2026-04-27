# MMAS

Modified Metal Artifact Suppression (MMAS) for CT images with a MATLAB GUI.

## Repository

GitHub repository: `https://github.com/physcein/MMAS`

Maintainer: **Tae Kyu Lee, PhD**  
Affiliation: **Indiana University Health Arnett, Lafayette, Indiana, USA**

## What this repository currently releases

The current release centers on **`MMAS_GUI.m`**, a MATLAB graphical user interface for slice-based, sinogram-domain metal artifact suppression on CT DICOM data.

This release currently provides:

- loading of CT DICOM folders
- slice browsing with a slider or mouse wheel
- selection of **From/To** slice indices for batch processing
- display of **Original**, **Corrected**, and **Difference** images
- saving corrected DICOM slices with a `MAR_` filename prefix
- an editable core algorithm in `suppressionMAR(...)`

## Current released algorithmic behavior

The currently released `MMAS_GUI.m` implements the following active processing path:

1. convert DICOM data to HU when rescale tags are available
2. segment metal using a high-density threshold (`work >= 2000`)
3. create a metal-only image
4. compute:
   - `sinogramori` from the original CT slice
   - `sinogrammetal` from the metal-only image
   - `sinogramsub = sinogramori - sinogrammetal`
5. identify the metal trace in sinogram space
6. apply **polynomial interpolation** across the trace region
7. apply `smoothdata(...,'movmean',7)` projection cleanup
8. reconstruct with inverse Radon transform
9. apply `imgaussfilt(reconNew, 0.6)`
10. restore preserved metal and bone pixels
11. blend the corrected image back into all non-bone/non-metal soft tissue

This is the behavior the current JOSS draft now describes.

## Intended use

This repository is intended for:

- research on CT metal artifact suppression
- radiotherapy image-processing studies
- transparent experimentation with sinogram-domain correction
- development of **additional metal artifact reduction** methods on top of the current workflow

Examples of additional MAR research that can build on this release include:

- changing interpolation from polynomial to linear
- restricting write-back to a region of interest
- replacing Gaussian smoothing with noise filtering
- changing the metal trace mask in sinogram space
- adding prior-image or hybrid MAR strategies

## Limitations of the current release

The current `MMAS_GUI.m` is a research code release and should not be described as a finalized clinical product.

Known limitations of the current release include:

- multiple commented alternative `suppressionMAR(...)` “take” variants remain in the file
- the **active** path is still the earlier polynomial-interpolation implementation
- correction is blended back globally into soft tissue, which may accentuate bright/dark streaks in some cases
- the code has not been validated for clinical use

## Requirements

- MATLAB R2021b or newer recommended
- Image Processing Toolbox
- DICOM CT dataset for testing

## Files

- `MMAS_GUI.m` — main released MATLAB GUI
- `LICENSE` — open-source software license
- `README.md` — project overview
- `INSTALL.md` — installation and environment setup
- `USAGE_WALKTHROUGH.md` — exact walkthrough for the current release
- `RELEASE_AND_ZENODO.md` — release-tag and Zenodo instructions
- `paper.md`, `paper.bib` — JOSS software paper files

## Suggested first JOSS-facing release tag

- `v1.0.0`

## JOSS note

Before JOSS submission, create an archived Zenodo release that matches the exact GitHub tag described in `paper.bib`.

## License

This repository uses the MIT License.
