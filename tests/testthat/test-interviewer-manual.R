sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

docx_text <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  paste(s$text, collapse = "\n")
}

test_that("build_interviewer_manual produit un document Word", {
  out <- tempfile("man_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_interviewer_manual(sample_csv(), output = out)
  expect_true(file.exists(f))
  expect_gt(file.size(f), 0)
})

test_that("le manuel contient les instructions generiques et le marqueur a valider", {
  out <- tempfile("man_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_interviewer_manual(sample_csv(), output = out)
  txt <- docx_text(f)
  expect_true(grepl("Comment renseigner", txt, fixed = TRUE))
  expect_true(grepl("VALIDER PAR", txt)) # marqueur [À VALIDER PAR L'ÉQUIPE ÉTUDE]
  # instruction generique pour un champ radio (sex)
  expect_true(grepl("une seule r", txt)) # "Sélectionner une seule réponse"
  # instruction calcul
  expect_true(grepl("calcul", txt))
})

test_that("les instructions generiques dependent du type de champ", {
  expect_match(.manual_how_to("checkbox", ""), "[Pp]lusieurs")
  expect_match(.manual_how_to("calc", ""), "REDCap")
  expect_match(.manual_how_to("text", "date_dmy"), "jour/mois")
  # un champ texte simple ne recoit qu'une consigne generique neutre
  expect_match(.manual_how_to("text", ""), "^Inscrire la r")
})
