sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

docx_text <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  paste(s$text, collapse = "\n")
}

test_that("build_monitoring_manual produit un document Word", {
  out <- tempfile("mm_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_monitoring_manual(sample_csv(), output = out)
  expect_true(file.exists(f))
  expect_gt(file.size(f), 0)
})

test_that("le manuel propose des controles techniques et un espace observations", {
  out <- tempfile("mm_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_monitoring_manual(sample_csv(), output = out)
  txt <- docx_text(f)
  expect_true(grepl("monitoring", txt, ignore.case = TRUE))
  expect_true(grepl("Observations", txt, fixed = TRUE))
  expect_true(grepl("rifier", txt)) # "Vérifier ..."
  # champ configurable a completer
  expect_true(grepl("compl", txt)) # "[À compléter par l'équipe étude]"
})

test_that("les controles proposes restent techniques", {
  f <- data.frame(
    field_type = "radio", required = "y", identifier = "",
    branching_logic = "", validation_type = "", validation_min = "",
    validation_max = "", stringsAsFactors = FALSE
  )
  checks <- .monmanual_checks(f)
  expect_true(grepl("renseign", checks)) # obligatoire -> "Vérifier que le champ est renseigné"
  expect_true(grepl("une seule option", checks)) # radio
  # aucune mention de criticite clinique / SDV inventee
  expect_false(grepl("SDV", checks, fixed = TRUE))
  expect_false(grepl("critique", checks, ignore.case = TRUE))
})

test_that("la carte des dependances relie une variable a ses references", {
  csv <- sample_csv()
  p <- parse_data_dictionary(csv)
  deps <- .dependents_map(p)
  # birth_date est reference par le calcul age_years (datediff([birth_date],...))
  expect_true("age_years" %in% deps[["birth_date"]])
})
