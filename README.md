

# photoextractor <img src="man/figures/photoextractor_logo_small.png" align="right" alt="photoextractor" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/dlizcano/photoextractor/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dlizcano/photoextractor/actions/workflows/R-CMD-check.yaml)
[![CRAN downloads](http://cranlogs.r-pkg.org/badges/grand-total/photoextractor?color=blue)](https://cran.r-project.org/package=photoextractor)
[![CRAN status](https://www.r-pkg.org/badges/version/photoextractor)](https://CRAN.R-project.org/package=photoextractor)
[![lifecycle](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![size](https://img.shields.io/github/languages/code-size/dlizcano/photoextractor.svg)](https://github.com/dlizcano/photoextractor)
<!-- badges: end -->


The `photoextractor` R package allows you to extract pictograms (frames) from videos while preserving and stamping the original metadata from the video into the extracted images.

## Installation

You can install `photoextractor` from CRAN with:

```r
# install.packages("photoextractor")
```
You can install the development version of `photoextractor` from GitHub with:

```r
devtools::install_github("dlizcano/photoextractor")
```


### External Dependencies

This package relies on **ExifTool**. After installing the package, you must ensure ExifTool is available. The [`exiftoolr`](https://joshobrien.github.io/exiftoolr/) package can download it for you:

```r
exiftoolr::install_exiftool()
```

## Usage

### 🎬 Single Video Extraction

To extract frames from a single video (avi|mp4|mov|mkv|m4v):

```r
library(photoextractor)

# Create an extractor object
ext <- VideoFrameExtractor(
  video_path       = "path/to/your/video.mp4", 
  output_dir       = "path/to/output/frames", 
  fps              = 1,            # 1 frame per second
  format           = "jpg",        # photo format "jpg" or "png"
  camera_tz_offset = -5            # Timezone offset (e.g., -5 for Colombia)
)

# Run the extraction
ext <- extract(ext, verbose = TRUE)

# Verify that timestamps were stamped correctly
verify_timestamps(ext)
```

### 📁 Batch Folder Processing

To process all videos in a folder:

```r
library(photoextractor)

# Create a folder extractor object
folder_ext <- FolderExtractor(
  folder_path      = "path/to/videos",
  output_dir       = "path/to/output",
  fps              = 1,           # 1 frame per second
  format           = "jpg",       # photo format "jpg" or "png"
  camera_tz_offset = -5           # Timezone offset (e.g., -5 for Colombia)
)

# Run batch extraction
folder_ext <- extract(folder_ext, verbose = TRUE)

# Verify that timestamps were stamped correctly
print(folder_ext@results)
```

## Features

- **Metadata Preservation**: Automatically reads video start time from EXIF/metadata.
- **Timestamp Stamping**: Writes `DateTimeOriginal`, `CreateDate`, and filesystem timestamps to extracted frames.
- **Timezone Correction**: Handles UTC offsets and camera clock corrections.
- **Organized Output**: Automatically renames frames to include the source video name and zero-padded indices.
- **Modern OOP**: Built using the new **S7** object system for R.



