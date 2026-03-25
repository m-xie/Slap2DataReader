# Slap2DataFile

Cross-platform MATLAB reader for SLAP2 binary data files (`.dat` + `.meta`).

This is a **standalone, pure-MATLAB** implementation that does not require MEX
compilation. It is compatible with **Windows, Linux, and macOS** (MATLAB R2019b+).

The package structure mirrors the original `slap2` repo exactly — usage is
unchanged.

## Setup

Add the repository root to your MATLAB path:

```matlab
addpath('path/to/Slap2DataFile');
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
    getTimeSeries.m
  +util/
    MultiDataFiles.m        Multi-cycle file aggregator (dynamicprops)
    @DataFile/              Single .dat file reader
      DataFile.m
      getLineData.m         Pure MATLAB replacement for MexFetchImageData
      getLineHeader.m
      loadFileHeader.m
      loadParsePlan.m
      parseLineHeader.m
      private/
        loadFileHeaderV2.m
```

## What changed from the original `slap2` repo

| Area | Original | This repo |
|------|----------|-----------|
| Binary I/O | `MexFetchImageData` (C++ MEX) | `memmapfile` + MATLAB indexing |
| Compilation | Requires C++17 compiler | None — pure MATLAB |
| Platform | Windows only (MEX binary) | Windows, Linux, macOS |
| Metadata formats | Old `ParsePlan` only | Old `ParsePlan` + new `AcquisitionPlan` |
| `getTimeSeries` | Incomplete / syntax errors | Rewritten, functional |

Everything else — class names, package namespaces, property names, method
signatures, `dynamicprops` wiring — is preserved so that existing code using
`slap2.Slap2DataFile` works without modification.
