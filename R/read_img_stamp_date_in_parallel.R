#' @importFrom tesseract tesseract ocr_data
#' @importFrom lubridate mdy_hms force_tz
#' @importFrom exiftoolr exif_call
#' @importFrom furrr future_map furrr_options
#' @importFrom future plan multisession sequential
#' @importFrom parallel detectCores
#' @importFrom utils tail
NULL

#' Stamp Date and Time from Image OCR in Parallel
#'
#' This function scans a list of images for printed date and time using OCR (Tesseract),
#' and then stamps that information into the images' EXIF metadata. It uses parallel
#' processing to speed up the operation.
#'
#' @param files character vector. Full paths to the folder with images to process.
#' @param tzone character. Time zone for the parsed dates (default "America/Bogota").
#' @param n_workers integer. Number of parallel workers (default detectCores() - 1).
#' @param verbose logical. If TRUE, prints progress and summary.
#'
#' @return A character vector of processed file paths.
#'
#' @details
#' The function assumes that the date and time are printed as text on the image and can be
#' found by Tesseract. Currently, it specifically looks at the last two identified
#' text elements and parses them using `lubridate::mdy_hms`. It means that it will not 
#' work well on date and time followed by extra information such as moon phase or temperature. 
#' For some camera models that print any other text or information after the date and time 
#' we plan a future fix. 
#'
#' @examples
#' \dontrun{
#' files <- list.files("path/to/images", pattern = "\\.jpg$", full.names = TRUE)
#' read_img_stamp_date_in_parallel(files)
#' }
#' @export
read_img_stamp_date_in_parallel <- function(files,
                                            tzone = "America/Bogota",
                                            n_workers = max(1L, parallel::detectCores() - 1L),
                                            verbose = TRUE) {

  if (length(files) == 0) {
    if (verbose) message("No files provided.")
    return(character(0))
  }

  if (verbose) {
    cat(sprintf("Photos found: %d\n", length(files)))
    cat(sprintf("Using %d workers in parallel\n\n", n_workers))
  }

  # Setup parallel plan
  future::plan(future::multisession, workers = n_workers)
  on.exit(future::plan(future::sequential), add = TRUE)

  tic <- proc.time()

  results <- furrr::future_map(
    files,
    .process_single_image,
    tzone = tzone,
    .options  = furrr::furrr_options(seed = NULL),
    .progress = verbose
  )

  elapsed <- proc.time() - tic

  procesadas  <- sum(!vapply(results, inherits, logical(1), what = "error"))
  con_error   <- length(results) - procesadas

  if (verbose) {
    cat(sprintf(
      "\nOK Processed: %d  |  FAILED Errors: %d  |  Time: %.1f sec\n",
      procesadas, con_error, elapsed["elapsed"]
    ))
  }

  invisible(unlist(results))
}

# ---------------------------------------------
# INTERNAL HELPERS
# ---------------------------------------------

#' @noRd
.stamp_image_ocr <- function(image_path, dt_posix) {
  # Format for EXIF
  dt_str <- format(lubridate::force_tz(dt_posix, tzone = "UTC"), "%Y:%m:%d %H:%M:%S")

  exiftoolr::exif_call(
    args = c(
      "-overwrite_original",
      paste0("-DateTimeOriginal=", dt_str),
      paste0("-CreateDate=",       dt_str)
    ),
    path = image_path
  )
}

#' @noRd
.process_single_image <- function(file_path, tzone) {
  tryCatch({
    # The engine is initialized INSIDE the worker to avoid
    # serialization problems between processes
    eng      <- tesseract::tesseract("eng")
    text_i   <- tesseract::ocr_data(file_path, engine = eng)

    # Assuming the last two tokens are date and time
    # This is a heuristic guess that might need adjustment for different camera models
    if (nrow(text_i) < 2) {
      stop("Could not find enough text for date/time in image")
    }

    fecha_hora_i <- lubridate::mdy_hms(
      paste(tail(text_i$word, 2)[1],
            tail(text_i$word, 2)[2],
            sep = " "),
      tz = tzone
    )

    if (is.na(fecha_hora_i)) {
      stop("Parsed date is NA")
    }

    .stamp_image_ocr(file_path, fecha_hora_i)
    return(file_path)
  }, error = function(e) {
    return(structure(file_path, class = "error", message = conditionMessage(e)))
  })
}
