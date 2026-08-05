sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

docx_text <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  paste(s$text, collapse = "\n")
}

test_that("build_monitoring genere un document par instrument", {
  out <- tempfile("mon_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_monitoring(sample_csv(), output = out)
  expect_length(files, 2L)
  expect_true(all(file.exists(files)))
  expect_true(all(file.size(files) > 0))
})

test_that("le CRF Monitoring EXPOSE les elements techniques", {
  out <- tempfile("mon_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_monitoring(sample_csv(), output = out)
  txt <- docx_text(grep("demographics", files, value = TRUE, ignore.case = TRUE))

  # Contrairement au terrain, le monitoring montre les noms de variables,
  # les types, la logique et le calcul.
  expect_true(grepl("record_id", txt, fixed = TRUE))
  expect_true(grepl("birth_date", txt, fixed = TRUE))
  expect_true(grepl("Obligatoire", txt, fixed = TRUE))
  expect_true(grepl("Type :", txt, fixed = TRUE))
  # Le champ calcule age_years montre sa formule et l'avertissement.
  expect_true(grepl("datediff", txt, fixed = TRUE))
  expect_true(grepl("Afficher uniquement si", txt, fixed = TRUE))
})

test_that("le CRF Monitoring inclut une legende technique", {
  out <- tempfile("mon_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_monitoring(sample_csv(), output = out)
  txt <- docx_text(files[[1]])
  expect_true(grepl("data managers", txt, fixed = TRUE))
  expect_true(grepl("Contr", txt))
})
