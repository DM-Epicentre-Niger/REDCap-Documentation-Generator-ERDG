sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

docx_text <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  paste(s$text, collapse = "\n")
}

test_that("build_specification produit un document Word", {
  out <- tempfile("spec_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_specification(sample_csv(), output = out)
  expect_true(file.exists(f))
  expect_gt(file.size(f), 0)
})

test_that("la specification contient les sections normalisees et l'empreinte", {
  out <- tempfile("spec_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_specification(sample_csv(), output = out)
  txt <- docx_text(f)
  expect_true(grepl("Data Collection Specification", txt, fixed = TRUE))
  expect_true(grepl("Historique des versions", txt, fixed = TRUE))
  expect_true(grepl("Conventions de nommage", txt, fixed = TRUE))
  expect_true(grepl("SHA-256", txt, fixed = TRUE))
  # empreinte de 64 caracteres hexadecimaux presente
  expect_true(grepl("[0-9a-f]{64}", txt))
})

test_that("le commentaire technique reste factuel", {
  out <- tempfile("spec_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_specification(sample_csv(), output = out)
  txt <- docx_text(f)
  expect_true(grepl("Champ obligatoire", txt, fixed = TRUE))
  expect_true(grepl("Valeur calcul", txt)) # "Valeur calculee automatiquement"
})

test_that("le commentaire technique n'invente rien pour un champ texte simple", {
  f <- data.frame(
    field_type = "text", required = "", branching_logic = "",
    validation_type = "", validation_min = "", validation_max = "",
    identifier = "", stringsAsFactors = FALSE
  )
  expect_equal(.spec_comments(f), "")
})
