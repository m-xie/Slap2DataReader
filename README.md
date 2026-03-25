# Slap2DataReader

Cross-platform MATLAB reader for SLAP2 binary data files (`.dat` + `.meta`).

On **Windows 64-bit**, the reader automatically uses the bundled
`MexFetchImageData` MEX binary for fast C++ I/O (matching the original `slap2`
repo). On **Linux** and **macOS** (or when the MEX binary is not available), it
falls back to a pure-MATLAB `memmapfile` implementation — no compilation
required.

Compatible with MATLAB R2019b+. The package structure mirrors the original
`slap2` repo exactly — usage is unchanged.

## Setup

Add the repository root to your MATLAB path:

```matlab
addpath('path/to/Slap2DataReader');
```

## Quick start

```matlab
% Open a recording (multi-cycle .dat files are discovered automatically)
sdf = slap2.Slap2DataFile('path/to/recording.dat');

% Reconstruct a single frame (channel 1, centred at line 5000, kernel width 100)
[img, imgNonNorm, freshness] = sdf.getImage(1, 5000, 100);

% Reconstruct multiple frames
times = 1000:500:20000;
[imgs, counts] = sdf.getImages(1, times, 100);

% Access underlying data objects
sdf.hMultiDataFiles.header
sdf.hMultiDataFiles.getLineData(lineIndices, cycleIndices, channelIdx)
sdf.hMultiDataFiles.getLineHeader(lineIdx, cycleIdx)
```

## Package structure

```
+slap2/
  @Slap2DataFile/           Thin wrapper (identical to original slap2 repo)
    Slap2DataFile.m
    getImageBatched.m
    getImages.m
  +gui/+refstack/
    ReferenceStack.m        Load/save/compute reference stack TIFFs
  +constants/
    fastz.m                 Z-position rounding constants
  +util/
    MultiDataFiles.m        Multi-cycle file aggregator (dynamicprops)
    @DataFile/              Single .dat file reader
      DataFile.m
      getLineData.m         MEX when available, memmapfile fallback
      getLineHeader.m
      loadFileHeader.m
      loadParsePlan.m
      parseLineHeader.m
      private/
        loadFileHeaderV2.m
        MexFetchImageData.mexw64  (Windows 64-bit MEX binary)
+most/
  +util/
    writeTiff.m             TIFF writer (from ScanImage most library)
```

## Reference stacks

Load a pre-computed reference stack TIFF:

```matlab
rs = slap2.gui.refstack.ReferenceStack.loadTif('path/to/recording-REFERENCE.tif');

rs.data       % {chIdx, zIdx} cell array of image planes
rs.channels   % channel indices
rs.zs         % z-positions (single)
```

`loadTif` expects a pre-computed SLAP2 ReferenceStack TIFF (files with
`SLAP2ReferenceStackFileVersion` or `sourceTifFile` in their metadata).
TIFF reading uses the ScanImage `ScanImageTiffReader` MEX when available,
falling back to MATLAB's built-in `Tiff` class otherwise.

## Metadata format auto-detection

Data files produced by different branches of the `slap2` acquisition software
use different metadata layouts inside the `.meta` file. This reader
automatically detects the format on load:

| Format | Branch | Detection | Key traits |
|--------|--------|-----------|------------|
| **ParsePlan** | `master` | `AcquisitionContainer.ParsePlan` present | Per-line structs with zero-based `sliceIdx` |
| **AcquisitionPlan** | `fastZFeedbackExperiment3` | `AcquisitionContainer.AcquisitionPlan` present (no `ParsePlan`) | `activeZs` (1-based), `superPixelIDs` (Dependent property; computed from `activeSuperPixels` when absent) |

No user action is required — `loadParsePlan` inspects the loaded metadata and
dispatches to the correct parser. All downstream functions (`getImage`,
`getImages`, etc.) work identically regardless of which format was detected.

## What changed from the original `slap2` repo

| Area | Original | This repo |
|------|----------|-----------|
| Binary I/O | `MexFetchImageData` (C++ MEX) | `MexFetchImageData` on Win64; `memmapfile` fallback elsewhere |
| Compilation | Requires C++17 compiler | Pre-compiled `.mexw64` bundled; no compiler needed |
| Platform | Windows only (MEX binary) | Windows (MEX), Linux, macOS (memmapfile) |
| Metadata formats | Branch-specific | Auto-detects `ParsePlan` (master) and `AcquisitionPlan` (fastZFeedbackExperiment3) |
| `getTimeSeries` | Broken in original (undefined variables, unpopulated `metaData`) | Removed |

Everything else — class names, package namespaces, property names, method
signatures, `dynamicprops` wiring — is preserved so that existing code using
`slap2.Slap2DataFile` works without modification.
