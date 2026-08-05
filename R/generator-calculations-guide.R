# Generateur du guide des calculs REDCap (Word). Pour chaque champ calcule :
# formule, variables sources, description technique, risque eventuel et statut.
# Detecte : references absentes, division potentielle par zero, parentheses
# desequilibrees, fonction inconnue, chaine vide inhabituelle.

# Fonctions REDCap reconnues dans les calculs.
.REDCAP_CALC_FUNCTIONS <- c(
  "sum", "abs", "min", "max", "mean", "median", "stdev", "round", "roundup",
  "rounddown", "sqrt", "power", "log", "ln", "exp", "mod", "datediff", "today",
  "now", "if", "and", "or", "not", "isblank", "isblankormissingcode", "isnumber",
  "contains", "starts_with", "ends_with", "length", "left", "right", "mid",
  "upper", "lower", "trim", "concat", "replace", "find", "sqrt", "div"
)

# Extrait les noms de fonctions utilisees (jeton suivi de "(").
.calc_functions_used <- function(formula) {
  hits <- regmatches(formula, gregexpr("([A-Za-z_][A-Za-z0-9_]*)\\s*\\(", formula))[[1]]
  if (length(hits) == 0L) {
    return(character(0))
  }
  unique(tolower(sub("\\s*\\($", "", hits)))
}

# Risques detectes dans une formule.
.calc_risks <- function(formula, missing) {
  risks <- character()
  if (length(missing) > 0L) {
    risks <- c(risks, paste0("R\u00e9f\u00e9rence(s) absente(s) : ", paste(missing, collapse = ", "), "."))
  }
  n_open <- nchar(gsub("[^(]", "", formula))
  n_close <- nchar(gsub("[^)]", "", formula))
  if (n_open != n_close) {
    risks <- c(risks, "Parenth\u00e8ses d\u00e9s\u00e9quilibr\u00e9es.")
  }
  used <- .calc_functions_used(formula)
  unknown <- setdiff(used, .REDCAP_CALC_FUNCTIONS)
  if (length(unknown) > 0L) {
    risks <- c(risks, paste0("Fonction(s) non reconnue(s) : ", paste(unknown, collapse = ", "), "."))
  }
  if (grepl("/", formula, fixed = TRUE)) {
    risks <- c(risks, "Division pr\u00e9sente - v\u00e9rifier le risque de division par z\u00e9ro.")
  }
  if (grepl("''", formula, fixed = TRUE) || grepl("\"\"", formula, fixed = TRUE)) {
    risks <- c(risks, "Cha\u00eene vide utilis\u00e9e - \u00e0 v\u00e9rifier.")
  }
  if (grepl("(^|[^A-Za-z0-9_])if\\s*\\(", formula)) {
    risks <- c(risks, "Contient une condition (if) - v\u00e9rifier la logique.")
  }
  paste(risks, collapse = " ")
}

.CALC_LABELS <- c(
  Instrument = "Instrument", Variable = "Variable", Libelle = "Libell\u00e9",
  Formule = "Formule REDCap", Sources = "Variables sources",
  Description = "Description", Risque = "Risque \u00e9ventuel", Statut = "Statut"
)
.CALC_WIDTHS <- c(0.13, 0.10, 0.15, 0.20, 0.10, 0.12, 0.14, 0.06)

.calculations_table <- function(project, cfg) {
  f <- project$fields
  all_vars <- f$field_name
  idx <- which(tolower(trimws(f$field_type)) == "calc")
  rows <- lapply(idx, function(i) {
    formula <- .strip_html(trimws(f$choices[[i]]))
    refs <- .extract_field_refs(f$choices[[i]])
    missing <- setdiff(refs, all_vars)
    risk <- .calc_risks(formula, missing)
    data.frame(
      Instrument = .instrument_display_label(f$form_name[[i]], cfg),
      Variable = f$field_name[[i]],
      Libelle = .strip_html(trimws(f$field_label[[i]])),
      Formule = formula,
      Sources = paste(refs, collapse = ", "),
      Description = paste0("Formule r\u00e9f\u00e9ren\u00e7ant ", length(refs), " variable(s) source(s)."),
      Risque = risk,
      Statut = if (nzchar(risk)) "\u00c0 v\u00e9rifier" else "OK",
      check.names = FALSE, stringsAsFactors = FALSE
    )
  })
  if (length(rows) == 0L) {
    return(NULL)
  }
  do.call(rbind, rows)
}

#' Generer le guide des calculs REDCap (Word)
#'
#' Pour chaque champ calcule : formule, variables sources, description technique,
#' risque eventuel (references absentes, division par zero, parentheses
#' desequilibrees, fonction inconnue, chaine vide) et statut.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le chemin du fichier genere.
#' @export
build_calculations_guide <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  b <- cfg$branding
  ft_title <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0("Guide des calculs REDCap - ", cfg$project$study_name), ft_title)
  ))
  doc <- officer::body_add_par(doc, "")

  tab <- .calculations_table(project, cfg)
  cli::cli_h2("Guide des calculs REDCap")
  if (is.null(tab)) {
    doc <- officer::body_add_par(doc, "Aucune variable calculee.")
  } else {
    names(tab) <- unname(.CALC_LABELS[names(tab)])
    doc <- officer::body_add_table(doc, tab, header = TRUE, first_row = TRUE)
    cli::cli_alert_info("{nrow(tab)} champ(s) calcule(s).")
  }
  doc <- .docx_set_a4(doc, orient = "landscape")

  base <- tools::file_path_sans_ext(basename(csv))
  path <- file.path(output, paste0("Guide_Calculs_", base, ".docx"))
  print(doc, target = path)
  cli::cli_alert_success("{basename(path)}")
  invisible(path)
}
