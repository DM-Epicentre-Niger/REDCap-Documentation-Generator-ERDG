# En-tete minimal REDCap couvrant les colonnes utilisees.
.cmp_header <- paste(
  '"Variable / Field Name"', '"Form Name"', '"Field Type"', '"Field Label"',
  '"Choices, Calculations, OR Slider Labels"', '"Branching Logic"',
  '"Required Field?"',
  sep = ","
)

write_dd <- function(rows) {
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(.cmp_header, rows), tmp, useBytes = TRUE)
  tmp
}

old_rows <- c(
  '"record_id","form1","text","ID","","",""',
  '"consent","form1","yesno","Consentement","","",""',
  '"sex","form1","radio","Sexe","1, Masculin | 2, Feminin","",""',
  '"age","form1","calc","Age","datediff([birth])","",""',
  '"to_delete","form1","text","A supprimer","","",""',
  '"old_name","form1","text","Champ renomme","","",""'
)
new_rows <- c(
  '"record_id","form1","text","ID","","",""',
  '"consent","form1","yesno","Consentement modifie","","",""',
  '"sex","form1","radio","Sexe","1, Homme | 2, Feminin | 3, Autre","",""',
  '"age","form1","calc","Age","datediff([birth],today)","",""',
  '"new_name","form1","text","Champ renomme","","",""',
  '"brand_new","form1","text","Nouveau champ","","",""'
)

test_that("la comparaison detecte et classe les changements", {
  old_csv <- write_dd(old_rows)
  new_csv <- write_dd(new_rows)
  out <- tempfile("cmp_")
  on.exit(unlink(c(old_csv, new_csv, out), recursive = TRUE))

  res <- compare_dictionaries(old_csv, new_csv, output = out)
  ch <- res$changes
  cat_col <- ch[[2]] # colonne Categorie

  expect_true(any(grepl("renomm", cat_col))) # old_name -> new_name
  expect_true(any(grepl("supprim", cat_col))) # to_delete
  expect_true(any(grepl("recod", cat_col))) # sex choix 1 Masculin -> Homme
  expect_true(any(grepl("ajout", cat_col))) # choix 3 + brand_new
  expect_true(any(grepl("calcul", cat_col))) # formule age
  expect_true(any(grepl("libell", cat_col))) # consent label

  # classification : suppression et renommage et recodage sont CRITIQUE
  expect_gte(sum(ch$Niveau == "CRITIQUE"), 3L)
  expect_gte(sum(ch$Niveau == "MAJEUR"), 1L) # calcul
})

test_that("la comparaison produit les trois rapports", {
  old_csv <- write_dd(old_rows)
  new_csv <- write_dd(new_rows)
  out <- tempfile("cmp_")
  on.exit(unlink(c(old_csv, new_csv, out), recursive = TRUE))
  res <- compare_dictionaries(old_csv, new_csv, output = out)
  expect_true(file.exists(res$word))
  expect_true(file.exists(res$xlsx))
  expect_true(file.exists(res$json))
})

test_that("deux fichiers identiques ne produisent aucun changement", {
  csv <- write_dd(old_rows)
  out <- tempfile("cmp_")
  on.exit(unlink(c(csv, out), recursive = TRUE))
  res <- compare_dictionaries(csv, csv, output = out)
  expect_equal(nrow(res$changes), 0L)
})

test_that("la comparaison ne modifie pas les fichiers source", {
  old_csv <- write_dd(old_rows)
  new_csv <- write_dd(new_rows)
  out <- tempfile("cmp_")
  on.exit(unlink(c(old_csv, new_csv, out), recursive = TRUE))
  before <- c(old = digest::digest(file = old_csv), new = digest::digest(file = new_csv))
  compare_dictionaries(old_csv, new_csv, output = out)
  after <- c(old = digest::digest(file = old_csv), new = digest::digest(file = new_csv))
  expect_identical(before, after)
})
