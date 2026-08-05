# Generateur du Manuel de monitoring (Word). Aide le moniteur a verifier la
# coherence entre CRF, REDCap et regles techniques. Les controles proposes sont
# UNIQUEMENT techniques : on n'invente ni source document, ni frequence SDV, ni
# criticite clinique, ni regle de protocole.

# Carte des dependances : variable -> champs qui la referencent (logique/calcul).
.dependents_map <- function(project) {
  f <- project$fields
  deps <- list()
  for (i in seq_len(nrow(f))) {
    refs <- .extract_field_refs(f$branching_logic[[i]])
    if (tolower(trimws(f$field_type[[i]])) == "calc") {
      refs <- c(refs, .extract_field_refs(f$choices[[i]]))
    }
    for (r in unique(refs)) {
      deps[[r]] <- c(deps[[r]], f$field_name[[i]])
    }
  }
  deps
}

# Valeur attendue lisible (codes = libelles) pour le moniteur.
.monmanual_expected <- function(row, cfg) {
  type <- tolower(trimws(row$field_type))
  vt <- tolower(trimws(row$validation_type))
  if (type == "yesno") {
    return("1 = Oui / 0 = Non")
  }
  if (type == "truefalse") {
    return("1 = Vrai / 0 = Faux")
  }
  if (type == "calc") {
    return("Valeur calcul\u00e9e")
  }
  if (type %in% c("radio", "dropdown", "checkbox")) {
    ch <- parse_choices(row$choices)
    if (nrow(ch) == 0L) {
      return("(liste vide)")
    }
    ch$label <- .strip_html(ch$label)
    if (nrow(ch) > cfg$terrain$long_choice_threshold) {
      return(paste0(nrow(ch), " modalit\u00e9s (voir dictionnaire)"))
    }
    return(paste0(ch$code, " = ", ch$label, collapse = " ; "))
  }
  if (grepl("date", vt)) {
    return("Date")
  }
  if (grepl("number|integer", vt)) {
    return("Num\u00e9rique")
  }
  "Texte"
}

# Validation et plage autorisee.
.monmanual_validation <- function(row) {
  vt <- trimws(row$validation_type)
  mn <- trimws(row$validation_min)
  mx <- trimws(row$validation_max)
  if (!nzchar(vt) && !nzchar(mn) && !nzchar(mx)) {
    return("")
  }
  out <- if (nzchar(vt)) vt else "-"
  if (nzchar(mn) || nzchar(mx)) {
    out <- paste0(out, " (min: ", if (nzchar(mn)) mn else "-",
      " ; max: ", if (nzchar(mx)) mx else "-", ")")
  }
  out
}

# Cellule "Calcul / dependances".
.monmanual_calc_deps <- function(row, deps) {
  parts <- character()
  if (tolower(trimws(row$field_type)) == "calc") {
    formula <- .strip_html(trimws(row$choices))
    if (nzchar(formula)) {
      parts <- c(parts, paste0("Calcul : ", formula))
    }
  }
  d <- deps[[row$field_name]]
  if (length(d) > 0L) {
    shown <- unique(d)
    more <- if (length(shown) > 5L) paste0(" (+", length(shown) - 5L, ")") else ""
    parts <- c(parts, paste0("Utilis\u00e9e par : ",
      paste(utils::head(shown, 5L), collapse = ", "), more))
  }
  paste(parts, collapse = " ; ")
}

# Controles de monitoring proposes (techniques uniquement).
.monmanual_checks <- function(row) {
  yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
  type <- tolower(trimws(row$field_type))
  vt <- tolower(trimws(row$validation_type))
  mn <- trimws(row$validation_min)
  mx <- trimws(row$validation_max)
  c1 <- character()
  if (yes(row$required)) {
    c1 <- c(c1, "V\u00e9rifier que le champ est renseign\u00e9.")
  }
  if (nzchar(mn) || nzchar(mx)) {
    c1 <- c(c1, "V\u00e9rifier que la valeur respecte les bornes (min/max).")
  }
  if (nzchar(trimws(row$branching_logic))) {
    c1 <- c(c1, "V\u00e9rifier que le champ appara\u00eet uniquement si la condition est satisfaite.")
  }
  if (type == "calc") {
    c1 <- c(c1, "V\u00e9rifier que le calcul correspond aux variables sources.")
  }
  if (type %in% c("radio", "dropdown")) {
    c1 <- c(c1, "V\u00e9rifier qu'une seule option est s\u00e9lectionn\u00e9e.")
  }
  if (type == "checkbox") {
    c1 <- c(c1, "V\u00e9rifier les r\u00e9ponses multiples coch\u00e9es.")
  }
  if (grepl("date", vt)) {
    c1 <- c(c1, "V\u00e9rifier le format de date.")
  }
  if (type %in% c("radio", "dropdown", "checkbox")) {
    c1 <- c(c1, "V\u00e9rifier la coh\u00e9rence du code et du libell\u00e9.")
  }
  if (yes(row$identifier)) {
    c1 <- c(c1, "Donn\u00e9e sensible : v\u00e9rifier la confidentialit\u00e9.")
  }
  paste(c1, collapse = " ; ")
}

.MONMAN_LABELS <- c(
  Variable = "Variable",
  Question = "Question",
  Type = "Type",
  Attendu = "Valeur attendue",
  Obligatoire = "Oblig.",
  Validation = "Validation / plage",
  Logique = "Logique d'affichage",
  Calcul = "Calcul / d\u00e9pendances",
  Controles = "Contr\u00f4les de monitoring propos\u00e9s",
  Observations = "Observations"
)

# Bloc de configuration renseignee par l'equipe (ou marqueur a completer).
.monmanual_add_config <- function(doc, cfg) {
  ft_lbl <- officer::fp_text(font.size = cfg$branding$body_size, bold = TRUE,
    font.family = cfg$branding$font)
  ft_val <- officer::fp_text(font.size = cfg$branding$body_size,
    font.family = cfg$branding$font)
  m <- cfg$monitoring
  fields <- list(
    "Document source" = m$source_document,
    "SDV requis" = m$sdv_required,
    "Variable critique" = m$critical_variable,
    "Controle personnalise" = m$custom_check
  )
  for (nm in names(fields)) {
    val <- fields[[nm]]
    if (is.null(val) || !nzchar(as.character(val))) {
      val <- "[\u00c0 compl\u00e9ter par l'\u00e9quipe \u00e9tude]"
    }
    doc <- officer::body_add_fpar(doc, officer::fpar(
      officer::ftext(paste0(nm, " : "), ft_lbl),
      officer::ftext(as.character(val), ft_val)
    ))
  }
  officer::body_add_par(doc, "")
}

.monmanual_document <- function(project, cfg) {
  b <- cfg$branding
  ft_title <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  ft_sec <- officer::fp_text(font.size = b$title_size - 2, bold = TRUE, font.family = b$font)
  ft_intro <- officer::fp_text(font.size = b$body_size, italic = TRUE, font.family = b$font)

  deps <- .dependents_map(project)
  widths <- c(0.08, 0.15, 0.06, 0.12, 0.05, 0.10, 0.11, 0.11, 0.12, 0.10)

  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0("Manuel de monitoring - ", cfg$project$study_name), ft_title)
  ))
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(paste0(
    "Ce manuel aide le moniteur a verifier la coherence entre le CRF, REDCap et ",
    "les regles techniques. Les controles proposes sont uniquement techniques. ",
    "La criticite clinique, la frequence de SDV et les documents source relevent ",
    "de l'equipe etude."
  ), ft_intro)))
  doc <- officer::body_add_par(doc, "")
  doc <- .monmanual_add_config(doc, cfg)

  for (inst in project$instruments) {
    fi <- project$fields[project$fields$form_name == inst, , drop = FALSE]
    doc <- officer::body_add_fpar(doc, officer::fpar(
      officer::ftext(.instrument_display_label(inst, cfg), ft_sec)
    ))
    rows <- lapply(seq_len(nrow(fi)), function(i) {
      row <- fi[i, , drop = FALSE]
      yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
      data.frame(
        Variable = row$field_name,
        Question = .strip_html(trimws(row$field_label)),
        Type = tolower(trimws(row$field_type)),
        Attendu = .monmanual_expected(row, cfg),
        Obligatoire = if (yes(row$required)) "Oui" else "",
        Validation = .monmanual_validation(row),
        Logique = .mon_humanize_logic(row$branching_logic),
        Calcul = .monmanual_calc_deps(row, deps),
        Controles = .monmanual_checks(row),
        Observations = "",
        check.names = FALSE, stringsAsFactors = FALSE
      )
    })
    df <- do.call(rbind, rows)
    names(df) <- unname(.MONMAN_LABELS[names(df)])
    doc <- officer::body_add_table(doc, df, header = TRUE, first_row = TRUE)
    doc <- officer::body_add_par(doc, "")
  }
  .docx_set_a4(doc, orient = "landscape")
}

#' Generer le Manuel de monitoring (Word)
#'
#' Produit un manuel oriente controle qualite, avec pour chaque variable des
#' controles techniques proposes et un espace d'observations. N'invente ni source
#' document, ni frequence SDV, ni criticite clinique.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le chemin du fichier genere.
#' @export
build_monitoring_manual <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  base <- tools::file_path_sans_ext(basename(csv))
  path <- file.path(output, paste0("Manuel_monitoring_", base, ".docx"))
  cli::cli_h2("Manuel de monitoring")
  doc <- .monmanual_document(project, cfg)
  print(doc, target = path)
  cli::cli_alert_success("{basename(path)}")
  cli::cli_alert_success("Genere dans {normalizePath(output, winslash = '/')}")
  invisible(path)
}
