tmf_sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

tmf_header_footer_text <- function(path) {
  td <- tempfile()
  dir.create(td)
  on.exit(unlink(td, recursive = TRUE))
  utils::unzip(path, exdir = td)
  files <- list.files(file.path(td, "word"), pattern = "^(header|footer)",
    full.names = TRUE)
  paste(vapply(files, function(p) {
    paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  }, character(1)), collapse = " ")
}

test_that("le gabarit de reference TMF est livre dans le package", {
  ref <- system.file("extdata", "tmf_reference.docx", package = "redcapdocgen")
  expect_true(nzchar(ref) && file.exists(ref))
  # officer peut l'ouvrir et le corps est vide.
  s <- officer::docx_summary(officer::read_docx(ref))
  expect_equal(nrow(s), 0L)
})

test_that("build_terrain_tmf genere un document par instrument", {
  out <- tempfile("tmf_")
  on.exit(unlink(out, recursive = TRUE))
  files <- suppressWarnings(build_terrain_tmf(tmf_sample_csv(), output = out))
  expect_length(files, 2L)
  expect_true(all(file.exists(files)))
  expect_true(all(file.size(files) > 0))
  expect_true(all(grepl("_TMF\\.docx$", files)))
})

test_that("l'en-tete et le pied de page sont renseignes (placeholders remplaces)", {
  out <- tempfile("tmf_")
  on.exit(unlink(out, recursive = TRUE))
  files <- suppressWarnings(build_terrain_tmf(tmf_sample_csv(), output = out))
  hf <- tmf_header_footer_text(files[[1]])
  # Les placeholders ont disparu ; le pied contient la pagination.
  expect_false(grepl("\\{\\{", hf))
  expect_true(grepl("CRF", hf))
  expect_true(grepl("Confidentiel", hf))
  expect_true(grepl("PAGE|NUMPAGES", hf))
})

test_that("le document TMF contient un bloc de titre et des tableaux", {
  out <- tempfile("tmf_")
  on.exit(unlink(out, recursive = TRUE))
  files <- suppressWarnings(build_terrain_tmf(tmf_sample_csv(), output = out))
  s <- officer::docx_summary(officer::read_docx(files[[1]]))
  expect_true(any(s$content_type == "table cell"))
  styles <- s$style_name[s$content_type == "paragraph"]
  expect_true("Title" %in% styles)
})
