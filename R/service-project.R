# Orchestration "build-project" : genere tous les documents configures d'un
# projet a partir d'un dossier standard (input/, output/, config.yml).

# Association document -> fonction de generation + sous-dossier de sortie.
.PROJECT_DOCUMENTS <- list(
  "terrain" = list(sub = "terrain", fn = function(csv, out, cfg) {
    build_terrain(csv, output = out, config = cfg)
  }),
  "terrain-tmf" = list(sub = "TMF", fn = function(csv, out, cfg) {
    build_terrain_tmf(csv, output = out, config = cfg)
  }),
  "monitoring" = list(sub = "monitoring", fn = function(csv, out, cfg) {
    build_monitoring(csv, output = out, config = cfg)
  }),
  "monitoring-merged" = list(sub = "monitoring", fn = function(csv, out, cfg) {
    build_monitoring_merged(csv, output = out, config = cfg)
  }),
  "dictionary" = list(sub = "dictionary", fn = function(csv, out, cfg) {
    build_dictionary(csv, output = out, config = cfg, format = "all")
  }),
  "specification" = list(sub = "specification", fn = function(csv, out, cfg) {
    build_specification(csv, output = out, config = cfg)
  }),
  "interviewer-manual" = list(sub = "manuals", fn = function(csv, out, cfg) {
    build_interviewer_manual(csv, output = out, config = cfg)
  }),
  "monitoring-manual" = list(sub = "manuals", fn = function(csv, out, cfg) {
    build_monitoring_manual(csv, output = out, config = cfg)
  }),
  "branching" = list(sub = "guides", fn = function(csv, out, cfg) {
    build_branching_guide(csv, output = out, config = cfg)
  }),
  "calculations" = list(sub = "guides", fn = function(csv, out, cfg) {
    build_calculations_guide(csv, output = out, config = cfg)
  })
)

# Trouve l'unique CSV du dossier input/ (erreur si 0 ou plusieurs).
.project_find_csv <- function(input_dir) {
  if (!dir.exists(input_dir)) {
    cli::cli_abort("Dossier d'entree introuvable : {.path {input_dir}}.")
  }
  csvs <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
  if (length(csvs) == 0L) {
    cli::cli_abort(c(
      "Aucun fichier CSV dans {.path {input_dir}}.",
      "i" = "Placez le Data Dictionary REDCap dans ce dossier."
    ))
  }
  if (length(csvs) > 1L) {
    cli::cli_abort(c(
      "Plusieurs fichiers CSV trouves dans {.path {input_dir}} :",
      stats::setNames(basename(csvs), rep("x", length(csvs))),
      "i" = "N'en gardez qu'un seul (le Data Dictionary a documenter)."
    ))
  }
  csvs[[1L]]
}

#' Generer tous les documents d'un projet
#'
#' Cherche automatiquement le Data Dictionary CSV dans `<project_dir>/input`, la
#' configuration dans `<project_dir>/config.yml` et ecrit les sorties dans
#' `<project_dir>/output` (en sous-dossiers si la configuration l'active). La
#' liste des documents est definie par `build$documents` dans la configuration.
#'
#' @param project_dir Dossier du projet (contenant `input/`, `output/`,
#'   `config.yml`).
#' @param config Chemin d'un YAML de configuration explicite (sinon
#'   `<project_dir>/config.yml`).
#'
#' @return De facon invisible, le vecteur des chemins generes.
#' @export
build_project <- function(project_dir, config = NULL) {
  if (!dir.exists(project_dir)) {
    cli::cli_abort("Dossier projet introuvable : {.path {project_dir}}.")
  }
  project_dir <- normalizePath(project_dir, winslash = "/")
  input_dir <- file.path(project_dir, "input")
  output_dir <- file.path(project_dir, "output")

  csv <- .project_find_csv(input_dir)

  cfg_path <- config
  if (is.null(cfg_path)) {
    default_cfg <- file.path(project_dir, "config.yml")
    cfg_path <- if (file.exists(default_cfg)) default_cfg else NULL
  }
  cfg <- erdg_load_config(cfg_path)

  documents <- cfg$build$documents
  if (is.null(documents) || length(documents) == 0L) {
    documents <- names(.PROJECT_DOCUMENTS)
  }
  subfolders <- isTRUE(cfg$output$create_subfolders)

  cli::cli_h1("build-project")
  cli::cli_alert_info("Projet  : {project_dir}")
  cli::cli_alert_info("Source  : {basename(csv)}")
  cli::cli_alert_info("Config  : {if (is.null(cfg_path)) 'valeurs par defaut' else basename(cfg_path)}")
  cli::cli_alert_info("Documents : {length(documents)}")

  files <- character()
  for (doc in documents) {
    spec <- .PROJECT_DOCUMENTS[[doc]]
    if (is.null(spec)) {
      cli::cli_alert_warning("Document inconnu ignore : {.val {doc}}.")
      next
    }
    out <- if (subfolders) file.path(output_dir, spec$sub) else output_dir
    res <- tryCatch(
      spec$fn(csv, out, cfg_path),
      error = function(e) {
        cli::cli_alert_danger("Echec de {.val {doc}} : {conditionMessage(e)}")
        NULL
      }
    )
    if (!is.null(res)) {
      files <- c(files, unlist(res))
    }
  }

  if (isTRUE(cfg$output$pdf) && length(files) > 0L) {
    convert_docx_to_pdf(grep("\\.docx$", files, value = TRUE))
  }

  cli::cli_alert_success("{length(files)} fichier(s) genere(s) dans {output_dir}")
  invisible(files)
}
