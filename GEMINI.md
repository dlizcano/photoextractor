# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Package Overview

photoextractor is an R package allows you to extract single frames (pictures) from videos while preserving and stamping the original metadata from the video into the extracted images.
The package can be useful to convert camera trap videos to image sequences preserving the original date and time. 


### Testing

- Tests for `R/{name}.R` go in `tests/testthat/test-{name}.R`.
- Use `devtools::test(reporter = "check")` to run all tests
- Use `devtools::test(filter = "name", reporter = "check")` to run tests for `R/{name}.R`
- DO NOT USE `devtools::test_active_file()`
- All testing functions automatically load code; you don't need to.

- All new code should have an accompanying test.
- If there are existing tests, place new tests next to similar existing tests.

### Documentation

- Run `devtools::document()` after changing any roxygen2 docs.
- Every user facing function should be exported and have roxygen2 documentation.
- Whenever you add a new documentation file, make sure to also add the topic name to `_pkgdown.yml`.
- Run `pkgdown::check_pkgdown()` to check that all topics are included in the reference index.
- Use sentence case for all headings
- Any user facing changes should be briefly described in a bullet point at the top of NEWS.md, following the tidyverse style guide (https://style.tidyverse.org/news.html).

### Code style

- Use newspaper style/high-level first function organisation. Main logic at the top and helper functions should come below.
- Don't define functions inside of functions unless they are very brief.
- Add explanatory comments to make the code readable. 
- Implement error messages and follow the tidyverse style guide (https://style.tidyverse.org/errors.html)

## Architecture

### Core Components

- av av_video_images
- exiftoolr exif_read exif_call
- lubridate force_tz with_tz hours parse_date_time
- uses exiftoolr::exif_call(), which uses the copy of ExifTool bundled inside the package itself.

### Key Design Patterns

**S7 Type System**: Uses S7 for structured data types
- Type definitions for tool parameters and structured outputs
- Final result checking and validation
- The constructor validates inputs, creates the output directory, and reads the recording timestamp from the video's EXIF/metadata using exifr. 
- It tries several fields in priority order — DateTimeOriginal, CreateDate, MediaCreateDate, TrackCreateDate — If no date is found read the image as OCR using the function R/read_img_stamp_date_in_parallel.R 
- If no date is found printed in the photo then warns the user in the final phase of verification. 


## Key Files

### Core Implementation
- `R/pictogram_extractor.R` - Main class implementation
- `R/types.R` - S7 type definitions for structured data. To be implemented.
- `R/read_img_stamp_date_in_parallel.R` - Read the date printed in the picture with no date and stamp it as metadata. 

### Testing and Quality
- `tests/testthat/` - Test suite with VCR cassettes
- `vignettes/` - Documentation and examples
- `.github/workflows/` - CI/CD with R CMD check

## S7

photoextractor uses the S7 OOP system.

**Key concepts:**

- **Classes**: Define classes with `new_class()`, specifying a name and properties (typed data fields). Properties are accessed using `@` syntax
- **Generics and methods**: Create generic functions with `new_generic()` and register class-specific implementations using `method(generic, class) <- implementation`
- **Inheritance**: Classes can inherit from parent classes using the `parent` argument, enabling code reuse through method dispatch up the class hierarchy
- **Validation**: Properties are automatically type-checked based on their definitions

**Basic example:**

```r
# Define a class
Dog <- new_class("Dog", properties = list(
  name = class_character,
  age = class_numeric
))

# Create an instance
lola <- Dog(name = "Lola", age = 11)

# Access properties
lola@age  # 11

# Define generic and method
speak <- new_generic("speak", "x")
method(speak, Dog) <- function(x) "Woof"
speak(lola)  # "Woof"
```

## Development Notes

### Testing Strategy
- Uses a sample video at `inst/exdata/sample.mp4`
- Parallel test execution 
- Snapshot testing for output validation
- Separate test files for each major component

### Code Organization
- Collate field in DESCRIPTION defines file loading order
- Provider files follow consistent naming pattern
- Utility functions grouped by purpose (`utils_*.R`)
- Standalone imports minimize external dependencies

### Documentation
- Roxygen2 comments for all exported functions
- Vignettes demonstrate key use cases
- pkgdown site provides comprehensive documentation

