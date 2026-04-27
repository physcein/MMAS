---
title: "MMAS_GUI: a MATLAB graphical interface for modified metal artifact suppression in CT images"
tags:
  - MATLAB
  - computed tomography
  - metal artifact reduction
  - radiotherapy
  - medical imaging
authors:
  - name: "Tae Kyu Lee"
    affiliation: 1
    orcid: ""
affiliations:
  - name: "Indiana University Health Arnett, Lafayette, Indiana, USA"
    index: 1
date: 2026-04-26
bibliography: paper.bib
---

# Summary

MMAS_GUI is a MATLAB-based graphical user interface for modified metal artifact suppression (MMAS) in computed tomography (CT) images affected by high-density implants such as hip prostheses. The maintained source repository is hosted at `https://github.com/physcein/MMAS`. The software packages a previously developed research workflow into a user-facing application that loads DICOM CT series, browses slices, selects a slice range for processing, applies a sinogram-based suppression pipeline, and exports corrected DICOM images. Because the core algorithm is concentrated in one processing function, the software can also be used as a platform for additional metal artifact reduction research, including alternative interpolation, masking, denoising, and reconstruction strategies. The implemented workflow follows a sequence of metal segmentation, forward projection, metal-only sinogram subtraction, interpolation and filtering within the affected sinogram trace, inverse Radon reconstruction, and restoration of preserved image regions such as bone and metal [@wei2004; @supp_mmas].

The software was motivated by radiotherapy planning problems in which bright shadows, dark shadows, streaks, and unrealistic CT numbers near metal can degrade contouring accuracy and dose computation [@spadea2013; @manuscript_mmas]. Although commercial scanners and treatment-planning workflows may provide proprietary artifact reduction, they typically do not expose the intermediate masks, sinograms, and reconstruction choices needed for transparent research evaluation. MMAS_GUI therefore provides a practical, inspectable implementation for medical physicists, imaging scientists, and radiation oncology researchers who need to experiment with artifact-suppression strategies, compare corrected and uncorrected datasets, and export reproducible outputs for downstream analysis.

# Statement of need

Metal artifacts remain a persistent challenge in CT-based radiotherapy planning and image analysis. In prostate radiotherapy, femoral prostheses can create shadows and streaks that distort local CT numbers and complicate segmentation of targets and organs at risk [@manuscript_mmas]. Because photon and proton dose algorithms both depend on underlying electron-density information, these distortions can propagate to treatment-planning errors. This is especially relevant for proton therapy, where range errors caused by dark-shadow artifacts can alter target coverage and conformity [@manuscript_mmas].

A large body of prior work has addressed metal artifact reduction through projection replacement, interpolation, normalization, and tissue- or prior-based correction strategies [@veldkamp2010; @wei2004; @bal2006; @meyer2010fsmar; @meyer2010nmar]. However, researchers still need accessible software that is easy to inspect, adapt, and use in domain-specific workflows such as radiotherapy planning studies. MMAS_GUI addresses that need by translating a sinogram-based suppression workflow into a standalone GUI with explicit support for DICOM import, slice-range selection, visual comparison of original and corrected images, and DICOM export of corrected data [@supp_mmas]. The intended users are researchers who need a transparent baseline method rather than a closed production implementation.

# State of the field

Projection-completion approaches remain a common family of solutions for CT metal artifact reduction. Veldkamp et al. described segmentation and interpolation in sinograms for suppression of metal-corrupted projection data [@veldkamp2010]. Wei et al. described high-density artifact suppression in the presence of bone, which directly motivates the base MAS workflow adapted in MMAS_GUI [@wei2004]. Bal and Spies proposed tissue-class modeling and adaptive prefiltering [@bal2006], while Meyer et al. introduced both frequency split metal artifact reduction and normalized metal artifact reduction (NMAR) as influential reference methods [@meyer2010fsmar; @meyer2010nmar].

MMAS_GUI does not attempt to replace those broader method families or claim superior performance to vendor implementations. Instead, its contribution is software-oriented: it operationalizes a modified MAS workflow as an inspectable research tool. Compared with the surrounding literature, the package emphasizes (1) transparent intermediate representations such as the original sinogram, metal-only sinogram, subtracted sinogram, and reconstructed corrected image, (2) direct applicability to DICOM CT data used in radiotherapy studies, and (3) an interface that enables users without extensive MATLAB programming experience to process a selected slice range and visually compare the resulting image sets [@supp_mmas]. That “build versus contribute” justification is important: the value here is not merely another interpolation routine, but a reusable platform for controlled experimentation, education, and workflow translation.

# Software design

`MMAS_GUI` is a MATLAB graphical user interface that packages a slice-based modified metal artifact suppression workflow for CT DICOM data. The current release loads a folder of DICOM CT slices, converts stored values to Hounsfield units when rescale tags are available, displays original and corrected slices side by side, supports slice browsing with a slider or mouse wheel, allows the user to process either the current slice or a selected range of slices, and exports corrected images back to DICOM with a `MAR_` filename prefix. The software is organized around a persistent GUI state structure and a single core processing function, `suppressionMAR(...)`.

The released workflow follows the same overall sequence described in the supplementary document: generation of `sinogramori` from the original CT slice, metal segmentation, generation of `sinogrammetal` from the metal-only image, subtraction to form `sinogramsub`, interpolation and smoothing in sinogram space, inverse-Radon reconstruction, and restoration of preserved structures such as metal and bone. In the currently uploaded `MMAS_GUI.m`, the active implementation uses metal thresholding, preserved bone masking, metal-only sinogram subtraction, a polynomial-interpolation path in sinogram space, moving-average smoothing of projection profiles, inverse Radon reconstruction, post-reconstruction Gaussian filtering, and final blending into non-bone/non-metal soft tissue.

This release should therefore be described as a research GUI for transparent experimentation with sinogram-domain metal artifact suppression rather than as a finalized production-grade MAR package. One of its main software contributions is that it exposes a complete, editable workflow that can be used for additional metal artifact reduction research. Because the algorithmic logic is concentrated in `suppressionMAR(...)`, users can replace or extend interpolation rules, trace masks, denoising filters, region-of-interest write-back policies, or reconstruction strategies without rewriting the GUI and DICOM-handling workflow. In that sense, `MMAS_GUI` is both a standalone suppression tool and a baseline platform for developing additional metal artifact reduction methods.

# Research impact statement

MMAS_GUI was developed in the context of a radiotherapy study evaluating the dosimetric effect of metal artifacts and their suppression on IMRT and IMPT prostate plans. In that study, treatment plans generated on original and MMAS-corrected CT images showed that IMRT metrics changed only minimally on average, whereas IMPT plans were more sensitive to artifact-driven CT-number errors, with larger changes in target coverage metrics and a statistically significant decrease in conformity index in the artifact-affected comparison [@manuscript_mmas]. Those findings provide direct evidence that the software addresses a meaningful research problem rather than a one-off visualization task.

The software also has broader near-term significance. Because it exposes intermediate masks, sinograms, and corrected image volumes, MMAS_GUI can be used to generate benchmark datasets for comparing artifact-reduction policies, to prototype additional metal artifact reduction steps layered on top of the baseline workflow, and to support educational demonstrations of how sinogram-domain correction changes reconstructed CT appearance [@supp_mmas]. In radiotherapy contexts, those capabilities are relevant for studies of contouring robustness, density override strategies, proton range uncertainty, and evaluation of whether more advanced MAR should be added to an imaging workflow before planning. The package is therefore positioned as a reusable research instrument for methodological comparison, not just as an implementation artifact from a single publication.

# AI usage disclosure

Generative AI was used to help draft and organize this software paper and to assist with code documentation during preparation of this submission draft. The authors are responsible for reviewing, revising, and validating the final manuscript text, software description, and repository materials before submission.

# References
