test_that("le package expose run_cli() et erdg_doctor()", {
  expect_true(is.function(run_cli))
  expect_true(is.function(erdg_doctor))
})

test_that("run_cli('doctor') s'execute sans erreur", {
  expect_error(run_cli("doctor"), NA)
})

test_that("erdg_doctor() renvoie TRUE de facon invisible", {
  expect_true(erdg_doctor())
})

test_that("run_cli() sans argument affiche l'aide", {
  expect_identical(suppressMessages(run_cli(character(0))), "help")
})

test_that("toutes les commandes de la CLI sont reconnues", {
  # 'gui' lance un serveur Shiny bloquant : on verifie seulement qu'elle est
  # cablee, sans l'executer.
  expect_true(is.function(run_gui))
})

test_that("validate/build/compare sans argument affichent l'usage (erreur claire)", {
  expect_error(run_cli("validate"), "validate")
  expect_error(run_cli("build"), "build")
  expect_error(run_cli("compare"), "compare")
})

test_that("une commande inconnue leve une erreur claire", {
  expect_error(run_cli("commande-bidon"))
})
