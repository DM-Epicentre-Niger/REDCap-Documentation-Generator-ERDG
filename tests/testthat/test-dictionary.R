sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

test_that("build_dictionary produit Word et Excel", {
  out <- tempfile("dict_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_dictionary(sample_csv(), output = out, format = "all")
  expect_length(files, 2L)
  expect_true(all(file.exists(files)))
  expect_true(any(grepl("\\.docx$", files)))
  expect_true(any(grepl("\\.xlsx$", files)))
})

test_that("le classeur Excel contient les feuilles attendues", {
  out <- tempfile("dict_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_dictionary(sample_csv(), output = out, format = "xlsx")
  wb <- openxlsx::loadWorkbook(files[[1]])
  sheets <- openxlsx::sheets(wb)
  expect_true(any(grepl("sum", sheets, ignore.case = TRUE))) # Resume
  expect_true("Branching Logic" %in% sheets)
  expect_true("Validations" %in% sheets)
  expect_true("Choix" %in% sheets)
  expect_true("Identifiants" %in% sheets)
  # une feuille par instrument (2) + 7 feuilles thematiques = 9
  expect_gte(length(sheets), 9L)
})

test_that("la feuille Resume rapporte les bons totaux", {
  out <- tempfile("dict_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_dictionary(sample_csv(), output = out, format = "xlsx")
  wb <- openxlsx::loadWorkbook(files[[1]])
  resume <- openxlsx::readWorkbook(wb, sheet = 1)
  variables <- resume$Valeur[resume$Indicateur == "Variables"]
  expect_equal(as.integer(variables), 8L)
})

test_that("le Data Dictionary lisible respecte les seuls formats connus", {
  expect_error(build_dictionary(sample_csv(), format = "pdf"))
})
