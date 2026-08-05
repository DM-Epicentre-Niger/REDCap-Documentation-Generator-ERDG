# Generateur du Data Dictionary lisible (Word + Excel). Reference/audit :
# reproduit fidelement le contenu du Data Dictionary (le HTML des libelles est
# nettoye pour la lisibilite ; codes, choix, logique et calculs restent bruts).

.dict_yes <- function(x) {
  ifelse(tolower(trimws(x)) %in% c("y", "yes", "1", "true"), "Oui", "")
}

# Tableau maitre : une ligne par champ, colonnes lisibles (avec Instrument).
.dictionary_fields <- function(project) {
  f <- project$fields
  ordre <- stats::ave(f$.order, f$form_name, FUN = function(z) seq_along(z))
  data.frame(
    Ordre = ordre,
    Instrument = f$form_name,
    Variable = f$field_name,
    "Num\u00e9ro de question" = f$question_number,
    "Libell\u00e9" = .strip_html(f$field_label),
    Type = f$field_type,
    "Choix ou calcul" = f$choices,
    Validation = f$validation_type,
    Min = f$validation_min,
    Max = f$validation_max,
    Obligatoire = .dict_yes(f$required),
    Identifiant = .dict_yes(f$identifier),
    "Branching Logic" = f$branching_logic,
    Note = .strip_html(f$field_note),
    Annotation = f$annotation,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

# Sous-tableaux thematiques pour Excel.
.dictionary_calc <- function(dict) {
  d <- dict[tolower(trimws(dict$Type)) == "calc", , drop = FALSE]
  data.frame(
    Instrument = d$Instrument, Variable = d$Variable, "Libell\u00e9" = d[["Libell\u00e9"]],
    Calcul = d[["Choix ou calcul"]], check.names = FALSE, stringsAsFactors = FALSE
  )
}

.dictionary_branching <- function(dict) {
  d <- dict[nzchar(trimws(dict[["Branching Logic"]])), , drop = FALSE]
  data.frame(
    Instrument = d$Instrument, Variable = d$Variable, "Libell\u00e9" = d[["Libell\u00e9"]],
    "Branching Logic" = d[["Branching Logic"]],
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

.dictionary_validations <- function(dict) {
  d <- dict[nzchar(trimws(dict$Validation)), , drop = FALSE]
  data.frame(
    Instrument = d$Instrument, Variable = d$Variable, Type = d$Type,
    Validation = d$Validation, Min = d$Min, Max = d$Max,
    Obligatoire = d$Obligatoire, check.names = FALSE, stringsAsFactors = FALSE
  )
}

.dictionary_identifiers <- function(dict) {
  d <- dict[dict$Identifiant == "Oui", , drop = FALSE]
  data.frame(
    Instrument = d$Instrument, Variable = d$Variable, "Libell\u00e9" = d[["Libell\u00e9"]],
    Type = d$Type, check.names = FALSE, stringsAsFactors = FALSE
  )
}

.dictionary_choices <- function(project) {
  f <- project$fields
  rows <- list()
  idx <- which(tolower(trimws(f$field_type)) %in% c("radio", "dropdown", "checkbox"))
  for (i in idx) {
    ch <- parse_choices(f$choices[[i]])
    if (nrow(ch) == 0L) {
      next
    }
    rows[[length(rows) + 1L]] <- data.frame(
      Instrument = f$form_name[[i]], Variable = f$field_name[[i]],
      Type = f$field_type[[i]], Code = ch$code,
      "Libell\u00e9 du choix" = .strip_html(ch$label),
      check.names = FALSE, stringsAsFactors = FALSE
    )
  }
  if (length(rows) == 0L) {
    return(data.frame(
      Instrument = character(0), Variable = character(0), Type = character(0),
      Code = character(0), "Libell\u00e9 du choix" = character(0),
      check.names = FALSE, stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

.dictionary_summary_df <- function(summary) {
  data.frame(
    Indicateur = c(
      "Instruments", "Variables", "Champs obligatoires", "Champs calcul\u00e9s",
      "Champs identifiants", "Logiques conditionnelles", "Matrices",
      "Erreurs", "Avertissements"
    ),
    Valeur = c(
      summary$instruments, summary$variables, summary$required,
      summary$calculated, summary$identifiers, summary$branching,
      summary$matrices, summary$errors, summary$warnings
    ),
    stringsAsFactors = FALSE
  )
}

# --- Sortie Word -----------------------------------------------------------
.dictionary_docx <- function(project, dict, cfg, path) {
  b <- cfg$branding
  ft_h1 <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  ft_h2 <- officer::fp_text(font.size = b$title_size - 2, bold = TRUE, font.family = b$font)
  ft_meta <- officer::fp_text(font.size = b$body_size, italic = TRUE, font.family = b$font)

  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0("Data Dictionary lisible - ", cfg$project$study_name), ft_h1)
  ))
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(
    paste0("Version : ", cfg$project$version, "    |    Date : ", cfg$project$date,
      "    |    ", cfg$project$confidentiality), ft_meta
  )))
  doc <- officer::body_add_par(doc, "")

  cols <- setdiff(names(dict), "Instrument")
  for (inst in project$instruments) {
    d <- dict[dict$Instrument == inst, cols, drop = FALSE]
    doc <- officer::body_add_fpar(doc, officer::fpar(
      officer::ftext(.instrument_display_label(inst, cfg), ft_h2)
    ))
    doc <- officer::body_add_table(doc, d, header = TRUE, first_row = TRUE)
    doc <- officer::body_add_par(doc, "")
  }
  doc <- .docx_set_a4(doc, orient = "landscape")
  print(doc, target = path)
  path
}

# --- Sortie Excel ----------------------------------------------------------
.dictionary_xlsx <- function(project, dict, issues, summary, path) {
  wb <- openxlsx::createWorkbook()
  used <- character()

  add <- function(name, df) {
    nm <- .xlsx_safe_sheet_name(name, used)
    used <<- c(used, nm)
    .xlsx_add_sheet(wb, nm, df)
  }

  add("R\u00e9sum\u00e9", .dictionary_summary_df(summary))
  for (inst in project$instruments) {
    d <- dict[dict$Instrument == inst, setdiff(names(dict), "Instrument"), drop = FALSE]
    add(inst, d)
  }
  add("Variables calcul\u00e9es", .dictionary_calc(dict))
  add("Branching Logic", .dictionary_branching(dict))
  add("Validations", .dictionary_validations(dict))
  add("Choix", .dictionary_choices(project))
  add("Identifiants", .dictionary_identifiers(dict))
  add("Probl\u00e8mes d\u00e9tect\u00e9s", issues)

  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

#' Generer le Data Dictionary lisible (Word et/ou Excel)
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param format `"docx"`, `"xlsx"` ou `"all"` (par defaut).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le vecteur des chemins generes.
#' @export
build_dictionary <- function(csv, output = "output", format = "all", config = NULL) {
  format <- match.arg(format, c("all", "docx", "xlsx"))
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  issues <- validate_project(project)
  summary <- .project_summary(project, issues)
  dict <- .dictionary_fields(project)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  base <- tools::file_path_sans_ext(basename(csv))
  files <- character()
  cli::cli_h2("Data Dictionary lisible")

  if (format %in% c("all", "docx")) {
    p <- file.path(output, paste0("Data_Dictionary_", base, ".docx"))
    .dictionary_docx(project, dict, cfg, p)
    files <- c(files, p)
    cli::cli_alert_success("Word  : {basename(p)}")
  }
  if (format %in% c("all", "xlsx")) {
    p <- file.path(output, paste0("Data_Dictionary_", base, ".xlsx"))
    .dictionary_xlsx(project, dict, issues, summary, p)
    files <- c(files, p)
    cli::cli_alert_success("Excel : {basename(p)}")
  }
  cli::cli_alert_success("Genere dans {normalizePath(output, winslash = '/')}")
  invisible(files)
}
