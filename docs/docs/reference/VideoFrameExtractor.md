# S7 Class for Single Video Frame Extraction

S7 Class for Single Video Frame Extraction

## Usage

``` r
VideoFrameExtractor(
  video_path,
  output_dir = file.path(dirname(normalizePath(video_path)), "frames"),
  fps = 1,
  format = "jpg",
  camera_tz_offset = -5
)
```

## Arguments

- video_path:

  character. Full path to source video.

- output_dir:

  character. Directory for extracted frames.

- fps:

  numeric. Frames per second (default 1).

- format:

  character. "jpg" or "png".

- camera_tz_offset:

  numeric. Camera UTC offset in hours (e.g. -5).

## Slots

- `video_path`:

  character. Full path to source video.

- `output_dir`:

  character. Directory for extracted frames.

- `fps`:

  numeric. Frames per second (default 1).

- `format`:

  character. "jpg" or "png".

- `camera_tz_offset`:

  numeric. Camera UTC offset in hours (e.g. -5).

- `start_time`:

  POSIXct. Recording start (UTC).

- `frame_paths`:

  character. Paths of saved frames (after extract).
