# Ligne de commande d'ERDG.
#
# Le squelette n'implemente que `doctor`. Les autres commandes sont declarees
# dans l'aide et repondent "non encore implementee" en indiquant le prompt qui
# les livrera. Le dispatch est fait en R base (pas de sortie de processus), ce
# qui rend `run_cli()` testable ; `docopt` (declare dans Imports) servira a
# l'analyse fine des options de chaque commande a partir du Prompt 1.

# Chaine d'usage affichee par `redcap-doc --help`.
.erdg_usage <- "ERDG - Epicentre REDCap Documentation Generator

Usage :
  redcap-doc doctor
  redcap-doc validate <csv>
  redcap-doc build <document> <csv> [--output=<dir>] [--config=<yml>] [--pdf]
  redcap-doc compare <old_csv> <new_csv> [--output=<dir>]
  redcap-doc build-project <project_dir> [--pdf]
  redcap-doc pdf <docx_ou_dossier> [--output=<dir>]
  redcap-doc gui
  redcap-doc (-h | --help)
  redcap-doc --version

Options :
  -h --help          Affiche cette aide.
  --version          Affiche la version du package.
  --output=<dir>     Dossier de sortie [defaut : output].
  --config=<yml>     Fichier de configuration YAML.
  --pdf              Genere aussi le PDF (necessite LibreOffice ou MS Word).

Documents (commande build) :
  terrain, monitoring, dictionary, specification, interviewer-manual,
  monitoring-manual, branching, calculations
"

# Version du package, avec repli si le package n'est pas encore installe.
.erdg_version <- function() {
  v <- tryCatch(
    as.character(utils::packageVersion("redcapdocgen")),
    error = function(e) NA_character_
  )
  if (is.na(v)) "0.1.0" else v
}

# Message standard pour une commande pas encore livree.
.erdg_not_implemented <- function(command, when) {
  cli::cli_alert_info(
    "Commande {.val {command}} non encore implementee (prevue au {when})."
  )
  invisible(FALSE)
}

#' Point d'entree de la ligne de commande ERDG
#'
#' Analyse le premier argument comme nom de commande et delegue au traitement
#' correspondant. Concu pour etre appele par `inst/scripts/redcap-doc.R`, mais
#' aussi directement en R (utile pour les tests).
#'
#' @param args Vecteur de caracteres. Par defaut les arguments passes a Rscript
#'   (`commandArgs(trailingOnly = TRUE)`).
#'
#' @return De facon invisible, le nom de la commande traitee (ou `"help"` /
#'   `"version"`).
#'
#' @examples
#' run_cli("doctor")
#' @export
run_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) == 0L || args[[1L]] %in% c("-h", "--help")) {
    cat(.erdg_usage)
    return(invisible("help"))
  }
  if (identical(args[[1L]], "--version")) {
    cat(.erdg_version(), "\n", sep = "")
    return(invisible("version"))
  }

  command <- args[[1L]]
  rest <- args[-1L]
  switch(command,
    "doctor" = erdg_doctor(),
    "validate" = {
      if (length(rest) < 1L) {
        cli::cli_abort(c(
          "Usage : {.code redcap-doc validate <csv> [--output=<dir>]}"
        ))
      }
      erdg_validate(rest[[1L]], output = .get_opt(rest, "--output", "output"))
    },
    "build" = {
      if (length(rest) < 2L) {
        cli::cli_abort(c(
          "Usage : {.code redcap-doc build <document> <csv> [--output=<dir>] [--config=<yml>]}",
          "i" = "Documents disponibles : {.val terrain}, {.val monitoring}."
        ))
      }
      document <- rest[[1L]]
      csv <- rest[[2L]]
      out <- .get_opt(rest, "--output", "output")
      conf <- .get_opt(rest, "--config", NULL)
      res <- switch(document,
        "terrain" = build_terrain(csv, output = out, config = conf),
        "monitoring" = build_monitoring(csv, output = out, config = conf),
        "monitoring-merged" = build_monitoring_merged(csv, output = out, config = conf),
        "dictionary" = build_dictionary(csv,
          output = out, config = conf,
          format = .get_opt(rest, "--format", "all")
        ),
        "specification" = build_specification(csv, output = out, config = conf),
        "interviewer-manual" = build_interviewer_manual(csv, output = out, config = conf),
        "monitoring-manual" = build_monitoring_manual(csv, output = out, config = conf),
        "branching" = build_branching_guide(csv, output = out, config = conf),
        "calculations" = build_calculations_guide(csv, output = out, config = conf),
        cli::cli_abort(c(
          "Document inconnu : {.val {document}}.",
          "i" = "Documents disponibles : {.val terrain}, {.val monitoring}, {.val monitoring-merged}, {.val dictionary}, {.val specification}, {.val interviewer-manual}, {.val monitoring-manual}, {.val branching}, {.val calculations}."
        ))
      )
      if ("--pdf" %in% rest) {
        convert_docx_to_pdf(grep("\\.docx$", unlist(res), value = TRUE))
      }
      invisible(res)
    },
    "compare" = {
      if (length(rest) < 2L) {
        cli::cli_abort(c(
          "Usage : {.code redcap-doc compare <ancien.csv> <nouveau.csv> [--output=<dir>]}"
        ))
      }
      compare_dictionaries(rest[[1L]], rest[[2L]],
        output = .get_opt(rest, "--output", "comparison"),
        config = .get_opt(rest, "--config", NULL)
      )
    },
    "build-project" = {
      if (length(rest) < 1L) {
        cli::cli_abort(c(
          "Usage : {.code redcap-doc build-project <dossier_projet>}"
        ))
      }
      files <- build_project(rest[[1L]], config = .get_opt(rest, "--config", NULL))
      if ("--pdf" %in% rest) {
        convert_docx_to_pdf(grep("\\.docx$", files, value = TRUE))
      }
      invisible(files)
    },
    "pdf" = {
      if (length(rest) < 1L) {
        cli::cli_abort(c(
          "Usage : {.code redcap-doc pdf <fichier.docx|dossier> [--output=<dir>]}"
        ))
      }
      build_pdf(rest[[1L]], output = .get_opt(rest, "--output", NULL))
    },
    "gui" = run_gui(),
    cli::cli_abort(c(
      "Commande inconnue : {.val {command}}.",
      "i" = "Utilisez {.code redcap-doc --help} pour la liste des commandes."
    ))
  )
  invisible(command)
}

#' Diagnostic de l'environnement ERDG
#'
#' Affiche la version de R, son emplacement, le repertoire courant, la version
#' du package, la disponibilite des packages cles et le statut des dossiers de
#' travail. Equivalent de `redcap-doc doctor`.
#'
#' @return `TRUE` de facon invisible.
#'
#' @examples
#' erdg_doctor()
#' @export
erdg_doctor <- function() {
  ver <- .erdg_version()
  cli::cli_h1("ERDG doctor")
  cli::cli_alert_info("Version de R      : {R.version.string}")
  cli::cli_alert_info("Emplacement de R  : {normalizePath(R.home(), winslash = '/')}")
  cli::cli_alert_info("Repertoire courant: {normalizePath(getwd(), winslash = '/')}")
  cli::cli_alert_info("Version du package : {ver}")

  cli::cli_h2("Packages cles")
  pkgs <- c(
    "readr", "dplyr", "stringi", "yaml", "officer", "flextable", "openxlsx",
    "docopt", "cli", "R6", "checkmate", "digest", "glue", "jsonlite"
  )
  for (p in pkgs) {
    v <- tryCatch(
      as.character(utils::packageVersion(p)),
      error = function(e) NA_character_
    )
    if (is.na(v)) {
      cli::cli_alert_danger("{p} : absent")
    } else {
      cli::cli_alert_success("{p} : {v}")
    }
  }

  cli::cli_h2("Dossiers de travail")
  for (d in c("input", "output", "templates")) {
    if (dir.exists(d)) {
      cli::cli_alert_success("{d}/ : present")
    } else {
      cli::cli_alert_warning("{d}/ : absent")
    }
  }

  invisible(TRUE)
}
