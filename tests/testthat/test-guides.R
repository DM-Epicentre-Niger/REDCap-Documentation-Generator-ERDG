sample_csv <- function() {
  system.file("extdata", "sample_data_dictionary.csv", package = "redcapdocgen")
}

docx_text <- function(path) {
  s <- officer::docx_summary(officer::read_docx(path))
  paste(s$text, collapse = "\n")
}

test_that("build_branching_guide produit un Word avec traduction lisible", {
  out <- tempfile("bg_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_branching_guide(sample_csv(), output = out)
  expect_true(file.exists(f))
  txt <- docx_text(f)
  expect_true(grepl("Branching Logic", txt, fixed = TRUE))
  # birth_date a la logique [consent] = '1' -> traduction lisible
  expect_true(grepl("Afficher ce champ uniquement si", txt, fixed = TRUE))
})

test_that("la traduction simple resout le code en libelle et laisse le complexe", {
  p <- parse_data_dictionary(sample_csv())
  lk <- .field_lookup(p)
  tr <- .branching_translate("[consent] = '1'", lk)
  expect_true(grepl("consenti", tr, ignore.case = TRUE)) # libelle de consent
  expect_true(grepl("Oui", tr, fixed = TRUE)) # code 1 -> Oui (yesno)
  # une expression avec and reste non traduite (complexe)
  expect_true(is.na(.branching_translate("[a] = '1' and [b] = '2'", lk)))
})

test_that("build_calculations_guide detecte les variables sources", {
  out <- tempfile("cg_")
  on.exit(unlink(out, recursive = TRUE))
  f <- build_calculations_guide(sample_csv(), output = out)
  expect_true(file.exists(f))
  txt <- docx_text(f)
  expect_true(grepl("calculs REDCap", txt, fixed = TRUE))
  expect_true(grepl("birth_date", txt, fixed = TRUE)) # source de age_years
})

test_that("l'analyse des risques de calcul detecte les cas connus", {
  expect_match(.calc_risks("[a]/[b]", character(0)), "division", ignore.case = TRUE)
  expect_match(.calc_risks("sum([a],[b]", character(0)), "quilibr") # parentheses desequilibrees
  expect_match(.calc_risks("[a]+[b]", c("b")), "absente")
  expect_match(.calc_risks("bidon([a])", character(0)), "non reconnue")
  expect_equal(.calc_risks("[a]+[b]", character(0)), "") # aucun risque
})
