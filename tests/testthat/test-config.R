test_that("erdg_load_config fusionne study_name et la table instruments", {
  yml <- tempfile(fileext = ".yml")
  on.exit(unlink(yml))
  writeLines(c(
    "project:",
    "  study_name: \"Etude X\"",
    "instruments:",
    "  f1: \"Formulaire Special\""
  ), yml)
  cfg <- erdg_load_config(yml)
  expect_equal(cfg$project$study_name, "Etude X")
  expect_equal(cfg$instruments$f1, "Formulaire Special")
  # les valeurs par defaut non surchargees restent presentes
  expect_equal(cfg$branding$font, "Calibri")
})

test_that("le libelle d'affichage utilise la config, sinon un repli", {
  cfg <- erdg_default_config()
  cfg$instruments <- list(f1 = "Formulaire Special")
  expect_equal(.instrument_display_label("f1", cfg), "Formulaire Special")
  # instrument non mappe -> repli (underscores -> espaces, capitalise)
  expect_equal(.instrument_display_label("autre_form", cfg), "Autre form")
})

test_that("le nom de fichier d'instrument est translittere en ASCII", {
  e_acute <- intToUtf8(233) # e accent aigu
  cfg <- erdg_default_config()
  cfg$instruments <- list(f1 = paste0("Ev", e_acute, "nement grave"))
  fn <- .instrument_filename("f1", cfg)
  expect_false(grepl("[^A-Za-z0-9_-]", fn)) # aucun caractere non-ASCII
  expect_true(grepl("Ev", fn))
  expect_true(grepl("nement", fn))
})
