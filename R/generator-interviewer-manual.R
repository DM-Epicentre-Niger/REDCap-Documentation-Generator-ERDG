# Generateur du Manuel enqueteur (Word). Genere a partir du Data Dictionary.
# Trois categories de contenu : (1) issu du DD ; (2) instruction generique
# deduite du type ; (3) a valider, marque par le libelle A_VALIDER ci-dessous.
# N'invente jamais d'instruction clinique.
#
# Performance : un tableau (flextable) par instrument (et non des milliers de
# paragraphes), pour eviter le cout quadratique de body_add_fpar.

.MANUAL_TOVALIDATE <- "[\u00c0 VALIDER PAR L'\u00c9QUIPE \u00c9TUDE]"

# Comment renseigner le champ (instruction generique par type).
.manual_how_to <- function(type, vt) {
  if (type == "text") {
    if (grepl("date", vt)) {
      return("Saisir la date au format jour/mois/ann\u00e9e.")
    }
    if (grepl("time", vt)) {
      return("Saisir l'heure au format heures:minutes.")
    }
    if (grepl("number|integer", vt)) {
      return("Saisir uniquement une valeur num\u00e9rique.")
    }
    return("Inscrire la r\u00e9ponse.")
  }
  switch(type,
    "notes" = "Inscrire la r\u00e9ponse (texte libre).",
    "radio" = "S\u00e9lectionner une seule r\u00e9ponse.",
    "dropdown" = "S\u00e9lectionner une seule r\u00e9ponse dans la liste.",
    "checkbox" = "Plusieurs r\u00e9ponses peuvent \u00eatre s\u00e9lectionn\u00e9es.",
    "yesno" = "Cocher Oui ou Non.",
    "truefalse" = "Cocher Vrai ou Faux.",
    "calc" = "Ne pas saisir manuellement. La valeur est calcul\u00e9e par REDCap.",
    "slider" = "Positionner le curseur sur la valeur voulue.",
    "file" = "Joindre le document demand\u00e9.",
    "descriptive" = "",
    "Inscrire la r\u00e9ponse."
  )
}

# Format attendu (issu du type de validation).
.manual_format <- function(vt) {
  if (grepl("date", vt)) {
    return("jour/mois/ann\u00e9e")
  }
  if (grepl("time", vt)) {
    return("heures:minutes")
  }
  if (grepl("integer", vt)) {
    return("nombre entier")
  }
  if (grepl("number", vt)) {
    return("valeur num\u00e9rique")
  }
  ""
}

# Erreurs frequentes generiques (par type).
.manual_common_errors <- function(type, vt) {
  if (type == "text" && grepl("date", vt)) {
    return("V\u00e9rifier l'ordre jour/mois/ann\u00e9e.")
  }
  if (type == "text" && grepl("number|integer", vt)) {
    return("Ne pas inscrire de texte ni d'unit\u00e9 dans un champ num\u00e9rique.")
  }
  switch(type,
    "radio" = "Ne s\u00e9lectionner qu'une seule r\u00e9ponse.",
    "checkbox" = "Ne pas oublier de cocher toutes les r\u00e9ponses applicables.",
    "dropdown" = "Choisir la r\u00e9ponse exacte dans la liste.",
    ""
  )
}

# Choix de reponse lisibles (code = libelle).
.manual_answers <- function(row, cfg) {
  type <- tolower(trimws(row$field_type))
  if (type == "yesno") {
    return("Oui / Non")
  }
  if (type == "truefalse") {
    return("Vrai / Faux")
  }
  if (!type %in% c("radio", "dropdown", "checkbox")) {
    return("")
  }
  ch <- parse_choices(row$choices)
  if (nrow(ch) == 0L) {
    return("")
  }
  ch$label <- .strip_html(ch$label)
  if (nrow(ch) > cfg$terrain$long_choice_threshold) {
    return(paste0("Voir la liste des ", nrow(ch),
      " r\u00e9ponses sur le CRF (trop longue pour le manuel)."))
  }
  paste0(ch$code, " = ", ch$label, collapse = " ; ")
}

# Message d'attention (obligatoire, calcul, identifiant).
.manual_warning <- function(row) {
  yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
  type <- tolower(trimws(row$field_type))
  msg <- character()
  if (yes(row$required)) {
    msg <- c(msg, "Ce champ doit \u00eatre renseign\u00e9.")
  }
  if (type == "calc") {
    msg <- c(msg, "Ne pas saisir : valeur calcul\u00e9e automatiquement.")
  }
  if (yes(row$identifier)) {
    msg <- c(msg, "Donn\u00e9e sensible : respecter la confidentialit\u00e9.")
  }
  paste(msg, collapse = " ")
}

# Cellule "Question" : numero + libelle.
.manual_question_label <- function(row) {
  label <- .strip_html(trimws(row$field_label))
  if (!nzchar(label)) {
    label <- "(sans libelle)"
  }
  qnum <- trimws(row$question_number)
  if (nzchar(qnum)) paste0("Q", qnum, " - ", label) else label
}

# Cellule "Consignes" : lignes libellees, uniquement si contenu.
.manual_consignes <- function(row, cfg) {
  type <- tolower(trimws(row$field_type))
  vt <- tolower(trimws(row$validation_type))
  lines <- character()
  add <- function(lbl, value) {
    if (nzchar(value)) {
      lines[[length(lines) + 1L]] <<- paste0(lbl, " : ", value)
    }
  }
  add("Objectif", paste("\u00c0 compl\u00e9ter par l'\u00e9quipe \u00e9tude", .MANUAL_TOVALIDATE))
  add("Comment renseigner", .manual_how_to(type, vt))
  add("R\u00e9ponses", .manual_answers(row, cfg))
  add("Format attendu", .manual_format(vt))
  bl <- .mon_humanize_logic(row$branching_logic)
  if (nzchar(bl)) {
    add("Quand poser la question", paste0("Uniquement si : ", bl))
  }
  add("Attention", .manual_warning(row))
  add("Erreurs fr\u00e9quentes", .manual_common_errors(type, vt))
  add("Note terrain", .strip_html(trimws(row$field_note)))
  paste(lines, collapse = "   |   ")
}

.MANUAL_LABELS <- c(Question = "Question", Consignes = "Consignes enqu\u00eateur")
.MANUAL_WIDTHS <- c(0.30, 0.70)

.manual_document <- function(project, cfg) {
  b <- cfg$branding
  ft_title <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  ft_sec <- officer::fp_text(font.size = b$title_size - 2, bold = TRUE, font.family = b$font)
  ft_intro <- officer::fp_text(font.size = b$body_size, italic = TRUE, font.family = b$font)

  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0("Manuel enqu\u00eateur - ", cfg$project$study_name), ft_title)
  ))
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(paste0(
    "Ce manuel est g\u00e9n\u00e9r\u00e9 automatiquement \u00e0 partir du Data Dictionary REDCap. ",
    "Trois types de contenu : (1) informations issues du Data Dictionary ; ",
    "(2) instructions g\u00e9n\u00e9riques d\u00e9duites du type de champ ; (3) contenu \u00e0 ",
    "valider, signal\u00e9 par ", .MANUAL_TOVALIDATE, ". Les objectifs et consignes ",
    "m\u00e9tier doivent \u00eatre valid\u00e9s par l'\u00e9quipe \u00e9tude avant utilisation terrain."
  ), ft_intro)))
  doc <- officer::body_add_par(doc, "")

  for (inst in project$instruments) {
    fi <- project$fields[project$fields$form_name == inst, , drop = FALSE]
    fi <- fi[tolower(trimws(fi$field_type)) != "sql", , drop = FALSE]
    if (nrow(fi) == 0L) {
      next
    }
    doc <- officer::body_add_fpar(doc, officer::fpar(
      officer::ftext(.instrument_display_label(inst, cfg), ft_sec)
    ))
    df <- data.frame(
      Question = vapply(seq_len(nrow(fi)),
        function(i) .manual_question_label(fi[i, , drop = FALSE]), character(1)),
      Consignes = vapply(seq_len(nrow(fi)),
        function(i) .manual_consignes(fi[i, , drop = FALSE], cfg), character(1)),
      check.names = FALSE, stringsAsFactors = FALSE
    )
    names(df) <- unname(.MANUAL_LABELS[names(df)])
    doc <- officer::body_add_table(doc, df, header = TRUE, first_row = TRUE)
    doc <- officer::body_add_par(doc, "")
  }
  .docx_set_a4(doc)
}

#' Generer le Manuel enqueteur (Word)
#'
#' Produit un manuel global genere depuis le Data Dictionary. Distingue les
#' informations issues du DD, les instructions generiques et le contenu a
#' valider (marque A VALIDER PAR L'EQUIPE ETUDE). N'invente aucune consigne
#' clinique.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le chemin du fichier genere.
#' @export
build_interviewer_manual <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  base <- tools::file_path_sans_ext(basename(csv))
  path <- file.path(output, paste0("Manuel_enqueteur_", base, ".docx"))
  cli::cli_h2("Manuel enqueteur")
  doc <- .manual_document(project, cfg)
  print(doc, target = path)
  cli::cli_alert_success("{basename(path)}")
  cli::cli_alert_success("Genere dans {normalizePath(output, winslash = '/')}")
  invisible(path)
}
