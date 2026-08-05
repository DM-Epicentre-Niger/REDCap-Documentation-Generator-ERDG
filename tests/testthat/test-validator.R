# Construit un Data Dictionary de test comportant des problemes connus.
write_problem_dd <- function() {
  tmp <- tempfile(fileext = ".csv")
  header <- paste(
    '"Variable / Field Name"', '"Form Name"', '"Field Type"', '"Field Label"',
    '"Choices, Calculations, OR Slider Labels"', '"Text Validation Min"',
    '"Text Validation Max"', '"Branching Logic"', '"Required Field?"',
    sep = ","
  )
  rows <- c(
    '"dup1","f1","text","Label A","","","","","n"',
    '"dup1","f1","radio","Choix invalide","1 Oui | 2, Non","","","","n"',
    '"v3","f1","text","Intervalle","","10","5","","n"',
    '"v4","f1","radio","Sans choix","","","","","n"',
    '"v5","f1","text","Conditionnel","","","","[nexiste] = 1","n"',
    '"v6","f1","typebizarre","Type inconnu","","","","","n"',
    '"v7","f1","calc","Age","datediff([v3],[absent],\'y\')","","","","y"'
  )
  writeLines(c(header, rows), tmp)
  tmp
}

test_that("la validation detecte les problemes structurels", {
  tmp <- write_problem_dd()
  on.exit(unlink(tmp))
  issues <- validate_project(parse_data_dictionary(tmp))
  codes <- issues$code

  expect_true("duplicate_variable" %in% codes)
  expect_true("malformed_choice" %in% codes)
  expect_true("min_greater_than_max" %in% codes)
  expect_true("empty_choices" %in% codes)
  expect_true("branching_missing_var" %in% codes)
  expect_true("unknown_field_type" %in% codes)
  expect_true("calc_missing_var" %in% codes)
  expect_true("required_calculated" %in% codes)
})

test_that("la validation classe les niveaux et met les erreurs en premier", {
  tmp <- write_problem_dd()
  on.exit(unlink(tmp))
  issues <- validate_project(parse_data_dictionary(tmp))
  expect_true(all(issues$level %in% c("ERROR", "WARNING", "INFO")))
  first_warning <- match("WARNING", issues$level)
  last_error <- suppressWarnings(max(which(issues$level == "ERROR")))
  if (is.finite(last_error) && !is.na(first_warning)) {
    expect_lt(last_error, first_warning)
  }
})

test_that("un Data Dictionary propre ne produit aucune erreur", {
  csv <- system.file("extdata", "sample_data_dictionary.csv",
    package = "redcapdocgen"
  )
  issues <- validate_project(parse_data_dictionary(csv))
  expect_equal(sum(issues$level == "ERROR"), 0L)
})

test_that("erdg_validate ecrit les rapports Markdown et JSON", {
  csv <- system.file("extdata", "sample_data_dictionary.csv",
    package = "redcapdocgen"
  )
  out <- tempfile("erdg_out_")
  on.exit(unlink(out, recursive = TRUE))
  res <- erdg_validate(csv, output = out)
  expect_true(file.exists(res$markdown))
  expect_true(file.exists(res$json))
  expect_gt(file.size(res$markdown), 0)
})
