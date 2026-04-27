# Usage walkthrough

This walkthrough is written for the **current released** `MMAS_GUI.m`.

## Start the GUI

```matlab
cd('path_to_MMAS_repository')
MMAS_GUI
```

## Step 1. Load a CT DICOM folder

Click **Load DICOM Folder** and choose a folder containing one CT series.

The software will:
- read DICOM metadata
- sort slices
- convert to Hounsfield units if rescale tags are available
- display the first slice in the **Original** panel

## Step 2. Browse the CT dataset

Use:
- the **Slice** slider
- the mouse wheel

Review the artifact-affected region before processing.

## Step 3. Choose a slice range

Enter values in:
- **From idx**
- **To idx**

These define the slice range for batch processing.

## Step 4. Review current GUI parameters

The current release exposes:

- **Metal threshold (HU)**  
  The active algorithm currently uses a high-density metal threshold and the released code path uses `work >= 2000`.

- **Blend 0-1**  
  Controls how strongly the corrected image is blended back into non-bone/non-metal soft tissue.

- **Display WL / WW**  
  Display settings only.

- **Template**  
  Preset display windows.

## Step 5. Process the images

To process one slice:
- click **Process Current**

To process multiple slices:
- click **Process Range**

## Step 6. What the current algorithm does

The active release path in `suppressionMAR(...)` currently:

1. builds `sinogramori`
2. segments metal
3. builds `sinogrammetal`
4. computes `sinogramsub = sinogramori - sinogrammetal`
5. applies **polynomial interpolation** in the trace region
6. applies `smoothdata(...,'movmean',7)`
7. reconstructs with inverse Radon transform
8. applies `imgaussfilt(reconNew,0.6)`
9. restores preserved metal and bone
10. blends corrected values into all non-bone/non-metal soft tissue

## Step 7. Review results

The GUI shows:
- **Original**
- **Corrected**
- **Difference**

When evaluating the result, check for:
- reduction of metal-related dark and bright artifacts
- preservation of anatomy away from the implant
- absence of new non-original structures

## Step 8. Save corrected DICOM files

Use:
- **Save Current**
- **Save Range**

The current release writes corrected DICOM files using a `MAR_` prefix.

## Using this release for additional metal artifact reduction

The most important extension point is:

```matlab
suppressionMAR(...)
```

That function can be modified to test additional MAR strategies, such as:
- linear instead of polynomial interpolation
- local ROI write-back
- Wiener or bilateral filtering instead of Gaussian smoothing
- modified sinogram trace masks
- hybrid or prior-image-based artifact reduction
