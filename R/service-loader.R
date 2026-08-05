# Orchestration de la commande `validate` : parse -> valide -> rapports.

# Compte les champs par instrument (dans l'ordre d'origine).
.instrument_counts <- function(project) {
  f <- project$fields
  data.frame(
    instrument = project$instruments,
    n_fields = as.integer(table(factor(f$form_name, levels = project$instruments))),
    stringsAsFactors = FALSE
  )
}

# Statistiques de synthese d'un projet.
.project_summary <- function(project, issues) {
  f <- project$fields
  type <- tolower(trimws(f$field_type))
  yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
  list(
    instruments = length(project$instruments),
    variables = nrow(f),
    required = sum(yes(f$required)),
    calculated = sum(type == "calc"),
    identifiers = sum(yes(f$identifier)),
    branching = sum(nzchar(trimws(f$branching_logic))),
    matrices = sum(type == "matrix"),
    errors = sum(issues$level == "ERROR"),
    warnings = sum(issues$level == "WARNING"),
    infos = sum(issues$level == "INFO")
  )
}

.write_validation_markdown <- function(path, project, issues, summary) {
  ic <- .instrument_counts(project)
  lines <- c(
    "# Rapport de validation - Data Dictionary REDCap",
    "",
    glue::glue("- **Source** : {basename(project$source_path)}"),
    glue::glue("- **Encodage** : {project$encoding}"),
    glue::glue("- **Delimiteur** : `{project$delimiter}`"),
    glue::glue("- **Empreinte SHA-256** : `{project$sha256}`"),
    glue::glue("- **Genere le** : {format(project$parsed_at, '%Y-%m-%d %H:%M:%S')}"),
    "",
    "## Synthese",
    "",
    glue::glue("| Indicateur | Valeur |"),
    "|---|---|",
    glue::glue("| Instruments | {summary$instruments} |"),
    glue::glue("| Variables | {summary$variables} |"),
    glue::glue("| Champs obligatoires | {summary$required} |"),
    glue::glue("| Champs calcules | {summary$calculated} |"),
    glue::glue("| Champs identifiants | {summary$identifiers} |"),
    glue::glue("| Logiques conditionnelles | {summary$branching} |"),
    glue::glue("| Matrices | {summary$matrices} |"),
    glue::glue("| Erreurs | {summary$errors} |"),
    glue::glue("| Avertissements | {summary$warnings} |"),
    "",
    "## Instruments",
    "",
    "| Instrument | Nombre de champs |",
    "|---|---|",
    paste0("| ", ic$instrument, " | ", ic$n_fields, " |"),
    "",
    "## Problemes detectes",
    ""
  )
  if (nrow(issues) == 0L) {
    lines <- c(lines, "_Aucun probleme detecte._")
  } else {
    lines <- c(
      lines,
      "| Niveau | Code | Variable | Message |",
      "|---|---|---|---|",
      paste0(
        "| ", issues$level, " | ", issues$code, " | ", issues$variable,
        " | ", gsub("|", "\\|", issues$message, fixed = TRUE), " |"
      )
    )
  }
  writeLines(enc2utf8(lines), path, useBytes = TRUE)
}

.write_validation_json <- function(path, project, issues, summary) {
  payload <- list(
    source = basename(project$source_path),
    encoding = project$encoding,
    delimiter = project$delimiter,
    sha256 = project$sha256,
    generated_at = format(project$parsed_at, "%Y-%m-%dT%H:%M:%S"),
    summary = summary,
    instruments = .instrument_counts(project),
    issues = issues
  )
  jsonlite::write_json(payload, path, auto_unbox = TRUE, pretty = TRUE)
}

#' Valider un Data Dictionary et produire les rapports
#'
#' Lit le Data Dictionary, applique la validation, affiche une synthese console
#' et ecrit un rapport Markdown et un rapport JSON dans le dossier de sortie.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie des rapports (cree si besoin).
#'
#' @return De facon invisible, une liste `project`, `issues`, `summary`,
#'   `markdown`, `json`.
#'
#' @export
erdg_validate <- function(csv, output = "output") {
  project <- parse_data_dictionary(csv)
  issues <- validate_project(project)
  summary <- .project_summary(project, issues)

  print(project)

  cli::cli_h2("Validation")
  if (summary$errors > 0L) {
    cli::cli_alert_danger("Erreurs      : {summary$errors}")
  } else {
    cli::cli_alert_success("Erreurs      : 0")
  }
  cli::cli_alert_warning("Avertissements : {summary$warnings}")
  cli::cli_alert_info("Obligatoires : {summary$required}  |  Calcules : {summary$calculated}  |  Identifiants : {summary$identifiers}")

  if (nrow(issues) > 0L) {
    n_show <- min(20L, nrow(issues))
    cli::cli_h3("Premiers problemes ({n_show}/{nrow(issues)})")
    for (i in seq_len(n_show)) {
      lvl <- issues$level[[i]]
      msg <- glue::glue("[{lvl}] {issues$variable[[i]]} : {issues$message[[i]]}")
      switch(lvl,
        "ERROR" = cli::cli_alert_danger(msg),
        "WARNING" = cli::cli_alert_warning(msg),
        cli::cli_alert_info(msg)
      )
    }
  }

  dir.create(output, showWarnings = FALSE, recursive = TRUE)
  base <- tools::file_path_sans_ext(basename(csv))
  md_path <- file.path(output, paste0(base, "_validation.md"))
  json_path <- file.path(output, paste0(base, "_validation.json"))
  .write_validation_markdown(md_path, project, issues, summary)
  .write_validation_json(json_path, project, issues, summary)

  cli::cli_alert_success("Rapport Markdown : {normalizePath(md_path, winslash = '/')}")
  cli::cli_alert_success("Rapport JSON     : {normalizePath(json_path, winslash = '/')}")

  invisible(list(
    project = project, issues = issues, summary = summary,
    markdown = md_path, json = json_path
  ))
}
