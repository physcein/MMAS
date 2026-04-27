# Release tag and Zenodo archive instructions

These instructions are tailored to the **current released repository state** centered on `MMAS_GUI.m`.

## Recommended release tag

For the first JOSS-facing archived release, use:

```text
v1.0.0
```

## What `v1.0.0` should mean in this repository

`v1.0.0` should archive the **exact code and documents described in the JOSS paper**, namely:

- `MMAS_GUI.m` as the released entry-point GUI
- the currently active `suppressionMAR(...)` behavior
- the current repository documentation
- `paper.md` and `paper.bib`

Because `MMAS_GUI.m` contains multiple commented alternative “take” variants, do one of the following before tagging:

### Option A: Release the current file as-is
If you do this, the paper should explicitly describe the **active** path only:
- polynomial interpolation
- `smoothdata(...,'movmean',7)`
- inverse Radon reconstruction
- `imgaussfilt(reconNew,0.6)`
- global soft-tissue blending

### Option B: Clean the file before release
If you prefer a cleaner JOSS release, remove inactive “take” variants and keep only the intended released implementation.

## Git workflow

Commit the release files:

```bash
git add .
git commit -m "Prepare JOSS release v1.0.0"
```

Create and push the tag:

```bash
git tag -a v1.0.0 -m "MMAS v1.0.0"
git push origin main
git push origin v1.0.0
```

## Create the GitHub release

In GitHub:
- open **Releases**
- draft a new release
- choose tag `v1.0.0`
- title it `MMAS v1.0.0`

Suggested release description:

```text
First JOSS-facing archived release of MMAS, a MATLAB GUI for modified metal artifact suppression in CT DICOM images. This release matches the software paper description and includes repository documentation, installation instructions, usage walkthrough, and JOSS manuscript files.
```

## Zenodo archiving

After linking Zenodo to GitHub and enabling the repository, Zenodo will archive the tagged GitHub release and mint a DOI.

You should then update `paper.bib` with the version DOI, for example:

```bibtex
@misc{mmas_gui,
  title = {MMAS\_GUI: MATLAB GUI for modified metal artifact suppression},
  author = {Lee, Tae Kyu},
  year = {2026},
  url = {https://github.com/physcein/MMAS},
  doi = {10.5281/zenodo.XXXXXXX}
}
```

## Final consistency check

Before JOSS submission, confirm that all of the following match exactly:

- GitHub repository state
- release tag `v1.0.0`
- GitHub release description
- Zenodo DOI archive
- `paper.md`
- `paper.bib`
- README description of the released algorithm
