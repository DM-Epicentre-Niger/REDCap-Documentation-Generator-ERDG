sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

test_that("le parser lit le Data Dictionary d'exemple", {
  p <- parse_data_dictionary(sample_csv())
  expect_s3_class(p, "erdg_project")
  expect_equal(nrow(p$fields), 8L)
  expect_equal(length(p$instruments), 2L)
  expect_true(all(c("demographics", "clinical") %in% p$instruments))
  expect_equal(p$delimiter, ",")
})

test_that("le parser normalise les noms de colonnes REDCap", {
  p <- parse_data_dictionary(sample_csv())
  expect_true(all(c(
    "field_name", "form_name", "field_type", "field_label", "choices",
    "validation_type", "branching_logic", "required", "annotation"
  ) %in% names(p$fields)))
})

test_that("le parser conserve l'ordre d'origine et calcule une empreinte", {
  p <- parse_data_dictionary(sample_csv())
  expect_equal(p$fields$field_name[[1]], "record_id")
  expect_identical(p$fields$.order, seq_len(nrow(p$fields)))
  expect_match(p$sha256, "^[0-9a-f]{64}$")
})

test_that("le parser detecte un separateur point-virgule", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(c(
    "Variable / Field Name;Form Name;Field Type;Field Label",
    "v1;f1;text;Nom"
  ), tmp)
  p <- parse_data_dictionary(tmp)
  expect_equal(p$delimiter, ";")
  expect_equal(p$fields$field_name[[1]], "v1")
})

test_that("le parser refuse un fichier sans colonnes REDCap essentielles", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(c("a,b,c", "1,2,3"), tmp)
  expect_error(parse_data_dictionary(tmp), "Data Dictionary")
})
