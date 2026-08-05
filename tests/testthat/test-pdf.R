test_that("convert_docx_to_pdf ignore les non-docx et gere l'absence de moteur", {
  # Un chemin non-docx ne produit rien et ne plante pas.
  expect_silent_or_message <- convert_docx_to_pdf(character(0))
  expect_equal(expect_silent_or_message, character(0))
})

test_that("build_pdf echoue proprement sur un chemin inexistant", {
  expect_error(build_pdf(tempfile("nexiste_pas_")), "introuvable")
})

test_that("la conversion PDF fonctionne quand un moteur est disponible", {
  testthat::skip_if_not(pdf_engine_available(), "Aucun moteur PDF (LibreOffice/Word).")

  # Genere un petit .docx puis le convertit.
  csv <- system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
  out <- tempfile("pdf_")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE))
  docx <- build_branching_guide(csv, output = out)

  pdfs <- convert_docx_to_pdf(docx)
  expect_length(pdfs, 1L)
  expect_true(file.exists(pdfs[[1]]))
  expect_gt(file.size(pdfs[[1]]), 0)
  # le .docx d'origine est conserve
  expect_true(file.exists(docx))
})
