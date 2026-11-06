# Exclusion des champs REDCap tagges @HIDDEN / @READONLY des CRF de collecte.

test_that("les tags @HIDDEN/@READONLY (et variantes -APP/-FORM) sont exclus", {
  f <- data.frame(
    field_name = c("a", "b", "c", "d", "e", "f", "g"),
    annotation = c(
      "",                       # pas de tag -> garde
      "@HIDDEN",                # cache partout -> exclu
      "@READONLY @CALCTEXT(x)", # lecture seule -> exclu
      "@HIDDEN-APP",            # cache sur tablette -> exclu
      "@READONLY-APP",          # lecture seule tablette -> exclu
      "@HIDDEN-SURVEY",         # cache enquete seulement -> GARDE (visible formulaire)
      "@CHARLIMIT=10"           # autre tag -> garde
    ),
    stringsAsFactors = FALSE
  )
  cfg <- erdg_default_config()
  kept <- .exclude_action_tag_fields(f, cfg)$field_name
  expect_true(all(c("a", "f", "g") %in% kept))
  expect_false(any(c("b", "c", "d", "e") %in% kept))
})

test_that("une liste exclude_action_tags vide desactive l'exclusion", {
  f <- data.frame(field_name = c("a", "b"),
    annotation = c("@HIDDEN", "@READONLY"), stringsAsFactors = FALSE)
  cfg <- erdg_default_config()
  cfg$terrain$exclude_action_tags <- list()
  expect_equal(nrow(.exclude_action_tag_fields(f, cfg)), 2L)
})

test_that("l'exclusion retire les champs caches du CRF Terrain TMF", {
  # Data Dictionary d'exemple + un champ @HIDDEN ajoute a la volee.
  csv <- system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
  proj <- parse_data_dictionary(csv)
  n_tot <- sum(proj$fields$form_name == proj$instruments[[1]])
  # Aucun tag dans l'exemple : l'exclusion ne doit rien retirer.
  cfg <- erdg_default_config()
  f <- proj$fields[proj$fields$form_name == proj$instruments[[1]], ]
  expect_equal(nrow(.exclude_action_tag_fields(f, cfg)), n_tot)
})
