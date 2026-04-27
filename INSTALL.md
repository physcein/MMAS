# Installation instructions

These instructions are tailored to the **current released file**: `MMAS_GUI.m`.

## 1. Clone or download the repository

Using Git:

```bash
git clone https://github.com/physcein/MMAS.git
cd MMAS
```

Or download the repository ZIP from GitHub and extract it.

## 2. MATLAB requirements

Recommended environment:

- MATLAB R2021b or newer
- Image Processing Toolbox

The current release uses MATLAB functions including:

- `dicominfo`
- `dicomread`
- `dicomwrite`
- `radon`
- `iradon`
- `bwareaopen`
- `imfill`
- `smoothdata`
- `imgaussfilt`

## 3. Add the repository to the MATLAB path

In MATLAB:

```matlab
cd('path_to_MMAS_repository')
addpath(genpath(pwd))
savepath
```

If `savepath` is not allowed on your system, the code will still run for the current MATLAB session after `addpath(genpath(pwd))`.

## 4. Launch the released GUI

```matlab
MMAS_GUI
```

## 5. Input data expectations

Prepare a folder containing one CT DICOM image series.

The current GUI expects:
- CT image slices in DICOM format
- one series per selected folder
- readable DICOM metadata for sorting slices

## 6. Output behavior

The current release saves corrected slices as DICOM files with a `MAR_` prefix.

## 7. Important validation note

This software is a research implementation. Validate the processed image set before using it for any downstream dosimetric or image-analysis study.
