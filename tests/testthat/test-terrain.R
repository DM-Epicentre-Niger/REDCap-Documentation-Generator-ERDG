sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

docx_text <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  paste(s$text, collapse = "\n")
}

test_that("build_terrain genere un document par instrument", {
  out <- tempfile("terrain_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_terrain(sample_csv(), output = out)
  expect_length(files, 2L)
  expect_true(all(file.exists(files)))
  expect_true(all(file.size(files) > 0))
})

test_that("le CRF Terrain contient les libelles et rendus attendus", {
  out <- tempfile("terrain_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_terrain(sample_csv(), output = out)
  txt <- docx_text(grep("demographics", files, value = TRUE, ignore.case = TRUE))
  expect_true(grepl("Date de naissance", txt, fixed = TRUE))
  expect_true(grepl("Masculin", txt, fixed = TRUE))
  expect_true(grepl("Calcul automatique", txt, fixed = TRUE))
  expect_true(grepl("__ / __ / ____", txt, fixed = TRUE))
})

test_that("le CRF Terrain ne fuite ni nom de variable ni syntaxe REDCap", {
  out <- tempfile("terrain_")
  on.exit(unlink(out, recursive = TRUE))
  files <- build_terrain(sample_csv(), output = out)
  txt <- docx_text(grep("demographics", files, value = TRUE, ignore.case = TRUE))

  # Noms de variables (bornes de mot pour eviter les faux positifs comme
  # "consent" dans "Consentement").
  expect_false(grepl("\\brecord_id\\b", txt))
  expect_false(grepl("\\bbirth_date\\b", txt))
  expect_false(grepl("\\bage_years\\b", txt))
  # Formule de calcul et logique conditionnelle.
  expect_false(grepl("datediff", txt, fixed = TRUE))
  expect_false(grepl("[consent]", txt, fixed = TRUE))
})

test_that("le rendu terrain retire le HTML des libelles rich-text", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  header <- paste(
    '"Variable / Field Name"', '"Form Name"', '"Field Type"', '"Field Label"',
    sep = ","
  )
  row <- paste0(
    '"q1","f1","text",',
    '"<div class=""rich-text-field-label""><p>Quel est votre <b>age</b> ?</p></div>"'
  )
  writeLines(c(header, row), tmp)

  out <- tempfile("terrain_")
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  files <- build_terrain(tmp, output = out)
  txt <- docx_text(files[[1]])
  expect_true(grepl("Quel est votre age ?", txt, fixed = TRUE))
  expect_false(grepl("<div", txt, fixed = TRUE))
  expect_false(grepl("rich-text-field-label", txt, fixed = TRUE))
})

test_that("les listes longues sont deplacees en annexe", {
  # Data Dictionary avec une liste de 20 choix (> seuil par defaut 15).
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  choices <- paste(sprintf("%d, Village %d", 1:20, 1:20), collapse = " | ")
  header <- paste(
    '"Variable / Field Name"', '"Form Name"', '"Field Type"', '"Field Label"',
    '"Choices, Calculations, OR Slider Labels"',
    sep = ","
  )
  row <- sprintf('"village","f1","radio","Village de residence","%s"', choices)
  writeLines(c(header, row), tmp)

  out <- tempfile("terrain_")
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  files <- build_terrain(tmp, output = out)
  txt <- docx_text(files[[1]])
  expect_true(grepl("annexe", txt, ignore.case = TRUE))
  expect_true(grepl("Annexe", txt, fixed = TRUE))
  expect_true(grepl("Village 20", txt, fixed = TRUE))
})
