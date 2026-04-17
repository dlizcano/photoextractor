#' @import S7
#' @importFrom av av_video_images
#' @importFrom exiftoolr exif_read exif_call
#' @importFrom lubridate force_tz with_tz hours parse_date_time
#' @importFrom tools file_path_sans_ext file_ext
#' @importFrom methods new
NULL

# =============================================================================
# -- INTERNAL HELPERS ---------------------------------------------------------
# =============================================================================

#' @noRd
.to_exif_dt <- function(x) {
  x_utc <- lubridate::force_tz(x, tzone = "UTC")
  format(x_utc, "%Y:%m:%d %H:%M:%S")
}

#' @noRd
.parse_exif_tz_offset <- function(raw_str) {
  m <- regmatches(raw_str,
                  regexpr("([+-])(\\d{2}):(\\d{2})$", raw_str, perl = TRUE))
  if (length(m) == 0 || m == "") return(NA_real_)

  sign  <- ifelse(startsWith(m, "+"), 1, -1)
  parts <- as.numeric(strsplit(substring(m, 2), ":")[[1]])
  sign * (parts[1] + parts[2] / 60)
}

#' @noRd
.read_video_start_time <- function(video_path, camera_tz_offset = -5) {

  probe_tags <- c(
    "FileModifyDate", "DateTimeOriginal", "CreateDate",
    "MediaCreateDate", "TrackCreateDate"
  )

  meta <- tryCatch(
    exiftoolr::exif_read(video_path, tags = probe_tags),
    error = function(e) {
      warning(sprintf("exif_read() failed for '%s': %s",
                      basename(video_path), conditionMessage(e)))
      NULL
    }
  )

  recording_start <- NA
  tag_used        <- NA_character_

  if (!is.null(meta) && nrow(meta) > 0) {
    for (tag in probe_tags) {
      val <- meta[[tag]]
      if (!is.null(val) && length(val) > 0 &&
          !is.na(val[1])  && nchar(trimws(val[1])) > 0) {

        raw_str  <- as.character(val[1])
        tz_found <- .parse_exif_tz_offset(raw_str)

        # Normalise date separators  "YYYY:MM:DD" -> "YYYY-MM-DD"
        ts_clean <- gsub("^(\\d{4}):(\\d{2}):(\\d{2})", "\\1-\\2-\\3", raw_str)
        # Strip trailing tz token so lubridate parses cleanly
        ts_clean <- gsub("[+-]\\d{2}:\\d{2}$", "", trimws(ts_clean))

        parsed <- suppressWarnings(
          lubridate::parse_date_time(ts_clean,
                                     orders = c("Ymd HMS", "Ymd HMSz"),
                                     quiet  = TRUE)
        )

        if (!is.na(parsed)) {
          if (!is.na(tz_found)) {
            # EXIF string has a real UTC offset -> convert properly to UTC
            parsed_local <- lubridate::force_tz(parsed,
                                                tzone = sprintf("Etc/GMT%+d", -as.integer(tz_found)))
            recording_start <- lubridate::with_tz(parsed_local, "UTC")
          } else {
            # No offset in EXIF: camera stores local time without tz label.
            # Treat parsed value as camera local time, then shift to UTC.
            recording_start <- lubridate::force_tz(parsed, "UTC") -
              lubridate::hours(camera_tz_offset)
          }
          tag_used <- tag
          break
        }
      }
    }
  }

  if (is.na(recording_start)) {
    warning(sprintf(
      "No readable timestamp in '%s'. Falling back to file mtime.",
      basename(video_path)))
    recording_start <- lubridate::force_tz(
      as.POSIXct(file.info(video_path)$mtime), "UTC")
  }
  ### Hardcoded time zone correction
  as.POSIXct(recording_start) + lubridate::hours(camera_tz_offset)
}

#' @noRd
.stamp_image <- function(image_path, dt_posix) {
  dt_str <- .to_exif_dt(dt_posix)

  # Pass 1 - embedded EXIF (needs -overwrite_original to avoid backup files)
  exiftoolr::exif_call(
    args = c(
      "-overwrite_original",
      paste0("-DateTimeOriginal=", dt_str),
      paste0("-CreateDate=",       dt_str)
    ),
    path = image_path
  )

  # Pass 2 - filesystem timestamps (OS metadata, no -overwrite_original needed)
  # Note: FileCreateDate is only writable on Windows and macOS, not Linux.
  exiftoolr::exif_call(
    args = c(
      paste0("-FileModifyDate=",  dt_str),
      paste0("-FileAccessDate=",  dt_str),
      paste0("-FileCreateDate=",  dt_str)
    ),
    path = image_path
  )
}

#' @noRd
.rename_frames <- function(frame_files, video_path) {
  video_stem <- tools::file_path_sans_ext(basename(video_path))
  n          <- length(frame_files)
  pad_width  <- nchar(as.character(n))   # auto width: 10 frames->2, 999->3 ...
  ext        <- tools::file_ext(frame_files[1])

  new_paths <- file.path(
    dirname(frame_files),
    sprintf("%s_frame_%0*d.%s", video_stem, pad_width, seq_len(n), ext)
  )

  mapply(file.rename, frame_files, new_paths)
  new_paths
}

# =============================================================================
# -- S7 CLASS: VideoFrameExtractor --------------------------------------------
# Single-video extractor
# =============================================================================

#' S7 Class for Single Video Frame Extraction
#'
#' @param video_path character. Full path to source video.
#' @param output_dir character. Directory for extracted frames.
#' @param fps numeric. Frames per second (default 1).
#' @param format character. "jpg" or "png".
#' @param camera_tz_offset numeric. Camera UTC offset in hours (e.g. -5).
#'
#' @slot video_path character. Full path to source video.
#' @slot output_dir character. Directory for extracted frames.
#' @slot fps numeric. Frames per second (default 1).
#' @slot format character. "jpg" or "png".
#' @slot camera_tz_offset numeric. Camera UTC offset in hours (e.g. -5).
#' @slot start_time POSIXct. Recording start (UTC).
#' @slot frame_paths character. Paths of saved frames (after extract).
#'
#' @return An object of class `VideoFrameExtractor`. This object stores information
#'   about a single video file, its output directory, frame rate, and calculated
#'   start time based on metadata. It is used to perform frame extraction and
#'   metadata stamping.
#'
#' @details
#' This function scan a video for its metadata specifically date and time of creation
#' and then extract a number of frames per second, saving the frames as pictures in format
#' JPG or PNG on a specified path. The extracted frames are saved with date and time on Metadata.
#' The function would be useful in situations when you program camera traps to shoot videos,
#' but you need pictures to upload to Wildlife Insights.
#'
#' @examples
#' video_file <- system.file("extdata", "sample.mp4", package = "photoextractor")
#' if (video_file != "") {
#'   extractor <- VideoFrameExtractor(
#'     video_path = video_file,
#'     output_dir = tempdir(),
#'     fps = 1,
#'     camera_tz_offset = -5
#'   )
#'   print(extractor)
#' }
#' @export
VideoFrameExtractor <- S7::new_class(
  name = "VideoFrameExtractor",

  properties = list(
    video_path       = S7::class_character,
    output_dir       = S7::class_character,
    fps              = S7::class_numeric,
    format           = S7::class_character,
    camera_tz_offset = S7::class_numeric,
    start_time       = S7::class_POSIXct,
    frame_paths      = S7::class_character
  ),

  constructor = function(
    video_path,
    output_dir       = file.path(dirname(normalizePath(video_path)), "frames"),
    fps              = 1,
    format           = "jpg",
    camera_tz_offset = -5
  ) {
    if (!file.exists(video_path))
      stop("video_path not found: ", video_path)

    ext_ok <- tolower(tools::file_ext(video_path)) %in% c("avi", "mp4", "mov",
                                                          "mkv", "m4v")
    if (!ext_ok)
      stop("Unsupported video format. Supported: AVI, MP4, MOV, MKV, M4V")

    if (!format %in% c("jpg", "png"))
      stop("`format` must be 'jpg' or 'png'.")

    if (fps <= 0.5)
      stop("`fps` must be > 0.5.")

    if (!is.numeric(camera_tz_offset) || abs(camera_tz_offset) > 14)
      stop("`camera_tz_offset` must be a number between -14 and +14.")

    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    start <- .read_video_start_time(video_path,
                                    camera_tz_offset = camera_tz_offset)

    S7::new_object(
      S7::S7_object(),
      video_path       = normalizePath(video_path),
      output_dir       = normalizePath(output_dir),
      fps              = fps,
      format           = format,
      camera_tz_offset = camera_tz_offset,
      start_time       = start,
      frame_paths      = character(0)
    )
  }
)

# =============================================================================
# -- GENERIC: extract()
# =============================================================================

#' Extract Frames from Video or Folder
#'
#' Generic function to extract frames from a video file or all videos in a folder.
#'
#' @param extractor An object of class `VideoFrameExtractor` or `FolderExtractor`.
#' @param verbose logical. If TRUE, progress messages are printed.
#' @param ... Additional arguments.
#'
#' @return The original extractor object (either `VideoFrameExtractor` or
#'   `FolderExtractor`) returned invisibly. The object is updated with the
#'   paths to the extracted frames or the results of the batch processing.
#'
#' @examples
#' video_file <- system.file("extdata", "sample.mp4", package = "photoextractor")
#' # Check if external tools are available
#' if (video_file != "" && av::av_media_info(video_file)$duration > 0) {
#'   extractor <- VideoFrameExtractor(video_file, output_dir = tempdir())
#'   # extract(extractor) # This requires exiftool to be installed
#' }
#' @export
extract <- S7::new_generic("extract", "extractor", function(extractor, verbose = TRUE, ...) {  S7::S7_dispatch()
})

#' @method extract VideoFrameExtractor
#' @export
S7::method(extract, VideoFrameExtractor) <- function(extractor, verbose = TRUE, ...) {

  vname <- basename(extractor@video_path)

  if (verbose) {
    message("\n-- Starting VideoFrameExtractor -----------------------")
    message("  Video      : ", vname)
    message("  Output dir : ", extractor@output_dir)
    message("  FPS        : ", extractor@fps)
    message("  Format     : ", extractor@format)
    message("  Camera tz  : UTC", sprintf("%+.1f", extractor@camera_tz_offset))
    message("  Start (UTC): ", format(extractor@start_time,
                                      "%Y-%m-%d %H:%M:%S %Z"))
    message("--------------------------------------------------------")
    message("Step 1/3 - Extracting frames")
  }

  frame_files <- tryCatch(
    av::av_video_images(
      video   = extractor@video_path,
      destdir = extractor@output_dir,
      format  = extractor@format,
      fps     = extractor@fps
    ),
    error = function(e) {
      stop(sprintf("av_video_images() failed for '%s': %s",
                   vname, conditionMessage(e)))
    }
  )

  if (length(frame_files) == 0)
    stop(sprintf("No frames extracted from '%s'. File may be corrupt.", vname))

  if (verbose)
    message(sprintf("  Extracted %d raw frame(s).", length(frame_files)))

  if (verbose) message("Step 2/3 - Renaming frames to include video name ...")
  frame_files <- .rename_frames(frame_files, extractor@video_path)

  if (verbose) message("Step 3/3 - Writing timestamps via exiftoolr ...")

  secs_per_frame <- 1 / extractor@fps

  for (i in seq_along(frame_files)) {
    frame_time <- extractor@start_time + (i - 1) * secs_per_frame

    tryCatch(
      .stamp_image(frame_files[i], frame_time),
      error = function(e) warning(sprintf(
        "Could not stamp '%s': %s", basename(frame_files[i]),
        conditionMessage(e)))
    )

    if (verbose) {
      message(sprintf("  [%d/%d]  %-20s  ->  %s",
                      i, length(frame_files),
                      basename(frame_files[i]),
                      .to_exif_dt(frame_time)))
    }
  }

  extractor@frame_paths <- frame_files
  if (verbose)
    message(sprintf("%d frame(s) saved to: %s\n",
                    length(frame_files), extractor@output_dir))
  invisible(extractor)
}

# =============================================================================
# -- GENERIC: verify_timestamps()
# =============================================================================

#' Verify Timestamps of Extracted Frames
#'
#' Reads back the metadata from the extracted frames to verify it was correctly stamped.
#'
#' @param extractor An object of class `VideoFrameExtractor`.
#' @param ... Additional arguments.
#'
#' @return A `data.frame` (returned invisibly) containing metadata extracted
#'   from the frames, such as original and modified timestamps. If no frames
#'   have been extracted, returns `NULL` invisibly with a message.
#'
#' @examples
#' video_file <- system.file("extdata", "sample.mp4", package = "photoextractor")
#' if (video_file != "") {
#'   extractor <- VideoFrameExtractor(video_file, output_dir = tempdir())
#'   # verify_timestamps(extractor) # Only works after extract()
#' }
#' @export
verify_timestamps <- S7::new_generic("verify_timestamps", "extractor")
#' @method verify_timestamps VideoFrameExtractor
#' @export
S7::method(verify_timestamps, VideoFrameExtractor) <- function(extractor, ...) {
  if (length(extractor@frame_paths) == 0) {
    message("No frames extracted yet - run extract() first.")
    return(invisible(NULL))
  }
  meta <- exiftoolr::exif_read(
    extractor@frame_paths,
    tags = c("FileName", "DateTimeOriginal", "CreateDate",
             "FileModifyDate", "FileAccessDate", "FileCreateDate")
  )
  cat("\n-- Verified timestamps ---------------------------------\n")
  print(meta[, c("FileName", "DateTimeOriginal", "CreateDate",
                 "FileModifyDate", "FileAccessDate", "FileCreateDate")])
  cat("--------------------------------------------------------\n")
  invisible(meta)
}

# =============================================================================
# -- S7 print method for VideoFrameExtractor
# =============================================================================
#' @method print VideoFrameExtractor
#' @export
S7::method(print, VideoFrameExtractor) <- function(x, ...) {
  cat("-- VideoFrameExtractor ---------------------------------\n")
  cat("  video_path       :", x@video_path, "\n")
  cat("  output_dir       :", x@output_dir, "\n")
  cat("  fps              :", x@fps, "\n")
  cat("  format           :", x@format, "\n")
  cat("  camera_tz_offset :", sprintf("UTC%+.1f", x@camera_tz_offset), "\n")
  cat("  start_time (UTC) :", format(x@start_time, "%Y-%m-%d %H:%M:%S %Z"), "\n")
  cat("  frames           :", length(x@frame_paths),
      if (length(x@frame_paths) > 0) "(extracted)" else "(not yet extracted)",
      "\n")
  cat("--------------------------------------------------------\n")
  invisible(x)
}

# =============================================================================
# -- S7 CLASS: FolderExtractor ------------------------------------------------
# Batch processor
# =============================================================================

#' S7 Class for Batch Folder Video Frame Extraction
#'
#' @param folder_path character. Folder containing videos.
#' @param output_dir character. Root output folder.
#' @param fps numeric.
#' @param format character.
#' @param camera_tz_offset numeric.
#'
#' @slot folder_path character. Folder containing videos.
#' @slot output_dir character. Root output folder.
#' @slot fps numeric.
#' @slot format character.
#' @slot camera_tz_offset numeric.
#' @slot video_files character. Discovered video paths.
#' @slot results list. List of VideoFrameExtractor objects.
#'
#' @return An object of class `FolderExtractor`. This object stores settings for
#'   batch processing multiple video files within a directory. It identifies
#'   all compatible video files and prepares for extraction.
#'
#' @examples
#' video_dir <- system.file("extdata", package = "photoextractor")
#' if (video_dir != "") {
#'   extractor <- FolderExtractor(
#'     folder_path = video_dir,
#'     output_dir = tempdir(),
#'     fps = 1,
#'     camera_tz_offset = -5
#'   )
#'   print(extractor)
#' }
#' @export
FolderExtractor <- S7::new_class(
  name = "FolderExtractor",

  properties = list(
    folder_path      = S7::class_character,
    output_dir       = S7::class_character,
    fps              = S7::class_numeric,
    format           = S7::class_character,
    camera_tz_offset = S7::class_numeric,
    video_files      = S7::class_character,
    results          = S7::class_list
  ),

  constructor = function(
    folder_path,
    output_dir       = file.path(folder_path, "frames"),
    fps              = 1,
    format           = "jpg",
    camera_tz_offset = -5
  ) {
    if (!dir.exists(folder_path))
      stop("folder_path does not exist: ", folder_path)

    all_files   <- list.files(folder_path, full.names = TRUE, recursive = FALSE)
    video_files <- all_files[grepl("\\.(avi|mp4|mov|mkv|m4v)$",
                                   all_files, ignore.case = TRUE)]

    if (length(video_files) == 0)
      stop(sprintf("No AVI/MP4/MOV/MKV/M4V files found in: %s\n", folder_path))

    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    S7::new_object(
      S7::S7_object(),
      folder_path      = normalizePath(folder_path),
      output_dir       = normalizePath(output_dir),
      fps              = fps,
      format           = format,
      camera_tz_offset = camera_tz_offset,
      video_files      = video_files,
      results          = list()
    )
  }
)

#' @method extract FolderExtractor
#' @export
S7::method(extract, FolderExtractor) <- function(extractor, verbose = TRUE, ...) {

  n      <- length(extractor@video_files)
  results <- vector("list", n)

  if (verbose) message(sprintf("\n== FolderExtractor: processing %d video(s) ==", n))

  for (i in seq_len(n)) {
    vpath <- extractor@video_files[i]
    vname <- tools::file_path_sans_ext(basename(vpath))
    vid_out <- file.path(extractor@output_dir, vname)

    if (verbose) message(sprintf("\n[%d/%d] %s", i, n, basename(vpath)))

    results[[i]] <- tryCatch({
      ext_i <- VideoFrameExtractor(
        video_path       = vpath,
        output_dir       = vid_out,
        fps              = extractor@fps,
        format           = extractor@format,
        camera_tz_offset = extractor@camera_tz_offset
      )
      extract(ext_i, verbose = verbose)
    },
    error = function(e) {
      if (verbose) message(sprintf("  !! SKIPPED - error: %s", conditionMessage(e)))
      NULL
    })
  }

  if (verbose) {
    ok      <- sum(!vapply(results, is.null, logical(1)))
    message(sprintf("\n== Batch complete: %d/%d video(s) processed ==\n", ok, n))
  }

  extractor@results <- results
  invisible(extractor)
}

#' @method print FolderExtractor
#' @export
S7::method(print, FolderExtractor) <- function(x, ...) {
  n_ok <- sum(!vapply(x@results, is.null, logical(1)))
  cat("-- FolderExtractor -------------------------------------\n")
  cat("  folder_path      :", x@folder_path, "\n")
  cat("  output_dir       :", x@output_dir, "\n")
  cat("  fps              :", x@fps, "\n")
  cat("  format           :", x@format, "\n")
  cat("  camera_tz_offset :", sprintf("UTC%+.1f", x@camera_tz_offset), "\n")
  cat("  videos found     :", length(x@video_files), "\n")
  cat("  videos processed :", n_ok, "\n")
  cat("--------------------------------------------------------\n")
  invisible(x)
}

