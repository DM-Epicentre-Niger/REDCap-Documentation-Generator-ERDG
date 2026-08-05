make_project <- function(with_config = TRUE, n_csv = 1L) {
  dir <- tempfile("proj_")
  dir.create(file.path(dir, "input"), recursive = TRUE, showWarnings = FALSE)
  src <- system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
  for (i in seq_len(n_csv)) {
    file.copy(src, file.path(dir, "input", paste0("dd", i, ".csv")))
  }
  if (with_config) {
    writeLines(c(
      "build:",
      "  documents:",
      "    - dictionary",
      "    - branching",
      "output:",
      "  create_subfolders: true"
    ), file.path(dir, "config.yml"))
  }
  dir
}

test_that("build_project genere les documents configures en sous-dossiers", {
  dir <- make_project()
  on.exit(unlink(dir, recursive = TRUE))
  files <- build_project(dir)
  expect_gte(length(files), 3L) # dictionary (docx+xlsx) + branching (docx)
  expect_true(dir.exists(file.path(dir, "output", "dictionary")))
  expect_true(dir.exists(file.path(dir, "output", "guides")))
  expect_true(any(grepl("Data_Dictionary", files)))
  expect_true(any(grepl("Guide_Branching", files)))
})

test_that("build_project echoue si plusieurs CSV", {
  dir <- make_project(n_csv = 2L)
  on.exit(unlink(dir, recursive = TRUE))
  expect_error(build_project(dir), "Plusieurs")
})

test_that("build_project echoue si aucun CSV", {
  dir <- tempfile("proj_")
  dir.create(file.path(dir, "input"), recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE))
  expect_error(build_project(dir), "Aucun")
})
