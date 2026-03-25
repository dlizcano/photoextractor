# S7 Class for Batch Folder Video Frame Extraction

S7 Class for Batch Folder Video Frame Extraction

## Usage

``` r
FolderExtractor(
  folder_path,
  output_dir = file.path(folder_path, "frames"),
  fps = 1,
  format = "jpg",
  camera_tz_offset = -5
)
```

## Arguments

- folder_path:

  character. Folder containing videos.

- output_dir:

  character. Root output folder.

- fps:

  numeric.

- format:

  character.

- camera_tz_offset:

  numeric.

## Slots

- `folder_path`:

  character. Folder containing videos.

- `output_dir`:

  character. Root output folder.

- `fps`:

  numeric.

- `format`:

  character.

- `camera_tz_offset`:

  numeric.

- `video_files`:

  character. Discovered video paths.

- `results`:

  list. List of VideoFrameExtractor objects.
