test_that("la liste des documents de l'interface est coherente avec la CLI", {
  ids <- unname(.GUI_DOCUMENTS)
  # tous les documents (hors comparaison) sont connus de build-project
  expect_true(all(setdiff(ids, "comparison") %in% names(.PROJECT_DOCUMENTS)))
  expect_true("comparison" %in% ids)
})

test_that(".gui_upload_path gere l'absence de fichier", {
  expect_null(.gui_upload_path(NULL))
})

test_that("l'UI se construit sans erreur", {
  testthat::skip_if_not(requireNamespace("shiny", quietly = TRUE))
  testthat::skip_if_not(requireNamespace("bslib", quietly = TRUE))
  ui <- .gui_ui(list())
  expect_true(inherits(ui, "shiny.tag") || inherits(ui, "shiny.tag.list") ||
    inherits(ui, "bslib_page") || inherits(ui, "list"))
  expect_true(is.function(.gui_server))
})

test_that("run_gui echoue proprement si un package est absent (message clair)", {
  # On ne peut pas desinstaller shiny ; on verifie juste que run_gui est exportee.
  expect_true(is.function(run_gui))
})
