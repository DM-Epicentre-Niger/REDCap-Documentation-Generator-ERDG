test_that("parse_choices decoupe code et libelle", {
  ch <- parse_choices("1, Oui | 0, Non")
  expect_equal(nrow(ch), 2L)
  expect_equal(ch$code, c("1", "0"))
  expect_equal(ch$label, c("Oui", "Non"))
  expect_true(all(ch$valid))
})

test_that("parse_choices gere les libelles contenant une virgule", {
  ch <- parse_choices("1, Oui, certainement | 2, Non")
  expect_equal(ch$code, c("1", "2"))
  expect_equal(ch$label, c("Oui, certainement", "Non"))
})

test_that("parse_choices renvoie un tableau vide pour une chaine vide", {
  expect_equal(nrow(parse_choices("")), 0L)
  expect_equal(nrow(parse_choices(NA_character_)), 0L)
})

test_that("parse_choices marque les choix mal formes", {
  ch <- parse_choices("1 Oui | 0, Non")
  expect_false(ch$valid[[1]])
  expect_true(ch$valid[[2]])
})
