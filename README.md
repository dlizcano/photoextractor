# photoextractor

The `photoextractor` R package allows you to extract pictograms (frames) from videos while preserving and stamping the original metadata from the video into the extracted images.

## Installation

You can install the development version of `photoextractor` from this directory:

```r
devtools::install()
```

### External Dependencies

This package relies on **ExifTool**. After installing the package, you must ensure ExifTool is available. The `exiftoolr` package can download it for you:

```r
exiftoolr::install_exiftool()
```

## Usage

### Single Video Extraction

To extract frames from a single video:

```r
library(photoextractor)

# Create an extractor object
ext <- VideoFrameExtractor(
  video_path       = "path/to/your/video.mp4",
  output_dir       = "path/to/output/frames",
  fps              = 1,            # 1 frame per second
  format           = "jpg",        # "jpg" or "png"
  camera_tz_offset = -5            # Timezone offset (e.g., -5 for Colombia)
)

# Run the extraction
ext <- extract(ext, verbose = TRUE)

# Verify that timestamps were stamped correctly
verify_timestamps(ext)
```

### Batch Folder Processing

To process all videos in a folder:

```r
library(photoextractor)

# Create a folder extractor object
folder_ext <- FolderExtractor(
  folder_path      = "path/to/videos",
  output_dir       = "path/to/output",
  fps              = 1,
  format           = "jpg",
  camera_tz_offset = -5
)

# Run batch extraction
folder_ext <- extract(folder_ext, verbose = TRUE)
```

## Features

- **Metadata Preservation**: Automatically reads video start time from EXIF/metadata.
- **Timestamp Stamping**: Writes `DateTimeOriginal`, `CreateDate`, and filesystem timestamps to extracted frames.
- **Timezone Correction**: Handles UTC offsets and camera clock corrections.
- **Organized Output**: Automatically renames frames to include the source video name and zero-padded indices.
- **Modern OOP**: Built using the new **S7** object system for R.
