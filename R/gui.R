# Interface graphique locale (Shiny). N'implemente AUCUNE logique metier : elle
# appelle exactement les memes fonctions de service que la ligne de commande.
# shiny/bslib restent dans Suggests (verifies au demarrage).

# Documents proposes (libelle affiche -> identifiant interne).
.GUI_DOCUMENTS <- c(
  "CRF Terrain" = "terrain",
  "CRF Monitoring" = "monitoring",
  "Fusion CRF Monitoring" = "monitoring-merged",
  "Data Dictionary (Word + Excel)" = "dictionary",
  "Data Collection Specification" = "specification",
  "Manuel enqu\u00eateur" = "interviewer-manual",
  "Manuel de monitoring" = "monitoring-manual",
  "Guide Branching Logic" = "branching",
  "Guide des calculs" = "calculations",
  "Rapport de comparaison" = "comparison"
)

# Chemin du fichier de preferences de l'interface.
.gui_prefs_path <- function() {
  file.path(rappdirs::user_config_dir("erdg"), "gui_prefs.yml")
}

.gui_load_prefs <- function() {
  p <- .gui_prefs_path()
  if (file.exists(p)) {
    tryCatch(yaml::read_yaml(p), error = function(e) list())
  } else {
    list()
  }
}

.gui_save_prefs <- function(prefs) {
  p <- .gui_prefs_path()
  dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
  tryCatch(yaml::write_yaml(prefs, p), error = function(e) NULL)
  invisible(p)
}

# Copie un fichier telecharge dans un dossier temporaire en conservant son nom
# d'origine (pour que les noms de fichiers de sortie restent parlants).
.gui_upload_path <- function(fileinput) {
  if (is.null(fileinput)) {
    return(NULL)
  }
  dest <- file.path(tempdir(), fileinput$name)
  file.copy(fileinput$datapath, dest, overwrite = TRUE)
  dest
}

.gui_ui <- function(prefs) {
  sel_docs <- prefs$documents
  if (is.null(sel_docs)) {
    sel_docs <- setdiff(unname(.GUI_DOCUMENTS), c("comparison", "monitoring-merged"))
  }
  out_dir <- if (!is.null(prefs$output)) prefs$output else "output"
  pdf_default <- isTRUE(prefs$pdf)

  bslib::page_sidebar(
    title = "REDCap Documentation Generator (ERDG)",
    theme = bslib::bs_theme(preset = "flatly"),
    sidebar = bslib::sidebar(
      width = 380,
      shiny::fileInput("csv", "Data Dictionary (.csv)", accept = ".csv"),
      shiny::fileInput("old_csv", "Ancien Data Dictionary (comparaison, facultatif)",
        accept = ".csv"),
      shiny::fileInput("config", "Configuration YAML (facultatif)",
        accept = c(".yml", ".yaml")),
      shiny::textInput("output", "Dossier de sortie", value = out_dir),
      shiny::checkboxGroupInput("documents", "Documents \u00e0 g\u00e9n\u00e9rer",
        choices = .GUI_DOCUMENTS, selected = sel_docs),
      shiny::checkboxInput("pdf", "G\u00e9n\u00e9rer aussi le PDF (LibreOffice)", value = pdf_default),
      shiny::checkboxInput("force", "G\u00e9n\u00e9rer malgr\u00e9 les avertissements", value = FALSE),
      shiny::hr(),
      shiny::actionButton("validate", "Valider le Data Dictionary", class = "btn-secondary"),
      shiny::actionButton("generate", "G\u00c9N\u00c9RER", class = "btn-primary"),
      shiny::actionButton("open", "Ouvrir le dossier de sortie", class = "btn-light")
    ),
    bslib::card(
      bslib::card_header("Validation"),
      shiny::tableOutput("issues")
    ),
    bslib::card(
      bslib::card_header("Journal"),
      shiny::verbatimTextOutput("log")
    )
  )
}

.gui_server <- function(input, output, session) {
  log_lines <- shiny::reactiveVal(character())
  issues_rv <- shiny::reactiveVal(NULL)

  add_log <- function(...) {
    log_lines(c(log_lines(), paste0(format(Sys.time(), "%H:%M:%S"), " - ", ...)))
  }

  output$log <- shiny::renderText(paste(log_lines(), collapse = "\n"))
  output$issues <- shiny::renderTable(issues_rv())

  # Validation.
  shiny::observeEvent(input$validate, {
    csv <- .gui_upload_path(input$csv)
    if (is.null(csv)) {
      shiny::showNotification("Selectionnez d'abord un Data Dictionary.", type = "warning")
      return(NULL)
    }
    tryCatch(
      {
        project <- parse_data_dictionary(csv)
        iss <- validate_project(project)
        issues_rv(iss)
        n_err <- sum(iss$level == "ERROR")
        n_warn <- sum(iss$level == "WARNING")
        add_log(sprintf("Validation : %d erreur(s), %d avertissement(s).", n_err, n_warn))
        shiny::showNotification(
          sprintf("Validation terminee : %d erreur(s), %d avertissement(s).", n_err, n_warn),
          type = if (n_err > 0) "error" else "message"
        )
      },
      error = function(e) {
        add_log("Erreur de validation : ", conditionMessage(e))
        shiny::showNotification(paste("Erreur :", conditionMessage(e)), type = "error")
      }
    )
  })

  # Generation.
  shiny::observeEvent(input$generate, {
    csv <- .gui_upload_path(input$csv)
    if (is.null(csv)) {
      shiny::showNotification("Selectionnez un Data Dictionary.", type = "warning")
      return(NULL)
    }
    old_csv <- .gui_upload_path(input$old_csv)
    conf <- .gui_upload_path(input$config)
    out <- input$output
    docs <- input$documents
    if (length(docs) == 0L) {
      shiny::showNotification("Selectionnez au moins un document.", type = "warning")
      return(NULL)
    }

    # Blocage si erreurs de validation (sauf forcage).
    iss <- tryCatch(validate_project(parse_data_dictionary(csv)), error = function(e) NULL)
    if (!is.null(iss) && sum(iss$level == "ERROR") > 0 && !isTRUE(input$force)) {
      shiny::showNotification(
        "Des erreurs de validation existent. Cochez 'Generer malgre les avertissements' pour forcer.",
        type = "error", duration = 8
      )
      issues_rv(iss)
      return(NULL)
    }

    cfg <- erdg_load_config(conf)
    subfolders <- isTRUE(cfg$output$create_subfolders)
    produced <- character()

    shiny::withProgress(message = "Generation en cours", value = 0, {
      n <- length(docs)
      for (i in seq_along(docs)) {
        doc <- docs[[i]]
        shiny::incProgress(1 / n, detail = doc)
        outdir <- if (subfolders && doc != "comparison") {
          spec <- .PROJECT_DOCUMENTS[[doc]]
          file.path(out, if (is.null(spec)) doc else spec$sub)
        } else {
          out
        }
        res <- tryCatch(
          {
            if (doc == "comparison") {
              if (is.null(old_csv)) {
                add_log("Comparaison ignoree : ancien Data Dictionary manquant.")
                NULL
              } else {
                r <- compare_dictionaries(old_csv, csv,
                  output = file.path(out, "comparison"), config = conf)
                c(r$word, r$xlsx, r$json)
              }
            } else {
              spec <- .PROJECT_DOCUMENTS[[doc]]
              spec$fn(csv, outdir, conf)
            }
          },
          error = function(e) {
            add_log(sprintf("Echec [%s] : %s", doc, conditionMessage(e)))
            shiny::showNotification(sprintf("Echec [%s] : %s", doc, conditionMessage(e)),
              type = "error")
            NULL
          }
        )
        if (!is.null(res)) {
          add_log(sprintf("OK [%s] : %d fichier(s).", doc, length(unlist(res))))
          produced <- c(produced, unlist(res))
        }
      }
    })

    if (isTRUE(input$pdf) && length(produced) > 0L) {
      docx <- grep("\\.docx$", produced, value = TRUE)
      add_log(sprintf("Conversion PDF de %d document(s)...", length(docx)))
      pdfs <- tryCatch(convert_docx_to_pdf(docx), error = function(e) character(0))
      produced <- c(produced, pdfs)
      add_log(sprintf("PDF produits : %d.", length(pdfs)))
    }

    add_log(sprintf("Termine : %d fichier(s) genere(s).", length(produced)))
    shiny::showNotification(sprintf("Termine : %d fichier(s).", length(produced)),
      type = "message")

    .gui_save_prefs(list(documents = docs, output = out, pdf = isTRUE(input$pdf)))
  })

  # Ouvrir le dossier de sortie.
  shiny::observeEvent(input$open, {
    out <- input$output
    if (!dir.exists(out)) {
      shiny::showNotification("Le dossier de sortie n'existe pas encore.", type = "warning")
      return(NULL)
    }
    full <- normalizePath(out)
    ok <- tryCatch(
      {
        if (.Platform$OS.type == "windows") {
          shell.exec(full)
        } else {
          utils::browseURL(full)
        }
        TRUE
      },
      error = function(e) FALSE
    )
    if (!ok) {
      shiny::showNotification("Impossible d'ouvrir le dossier.", type = "warning")
    }
  })
}

#' Lancer l'interface graphique ERDG
#'
#' Ouvre une interface Shiny locale pour selectionner un Data Dictionary, choisir
#' les documents et lancer la generation. L'interface appelle les memes fonctions
#' de service que la ligne de commande.
#'
#' @param launch_browser Ouvrir automatiquement le navigateur (defaut `TRUE`).
#' @param port Port du serveur Shiny (facultatif).
#'
#' @return Ne retourne pas (bloque tant que l'application tourne).
#' @export
run_gui <- function(launch_browser = TRUE, port = NULL) {
  for (pkg in c("shiny", "bslib", "rappdirs")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(c(
        "Le package {.pkg {pkg}} est requis pour l'interface graphique.",
        "i" = "Installez-le : {.code install.packages(\"{pkg}\")}"
      ))
    }
  }
  prefs <- .gui_load_prefs()
  app <- shiny::shinyApp(ui = .gui_ui(prefs), server = .gui_server)
  shiny::runApp(app, launch.browser = launch_browser, port = port)
}
