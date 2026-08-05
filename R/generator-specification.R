# Generateur de la Data Collection Specification (Word). Document technique,
# audit-ready. Reutilise le tableau maitre du dictionnaire et y ajoute un
# commentaire technique FACTUEL (deduit des metadonnees, jamais invente).

# En-tete de section.
.spec_heading <- function(doc, text, cfg) {
  ft <- officer::fp_text(font.size = cfg$branding$title_size - 2, bold = TRUE,
    font.family = cfg$branding$font)
  doc <- officer::body_add_par(doc, "")
  officer::body_add_fpar(doc, officer::fpar(officer::ftext(text, ft)))
}

# Sous-titre (nom d'instrument dans la section 8).
.spec_subheading <- function(doc, text, cfg) {
  ft <- officer::fp_text(font.size = cfg$branding$body_size + 2, bold = TRUE,
    font.family = cfg$branding$font)
  officer::body_add_fpar(doc, officer::fpar(officer::ftext(text, ft)))
}

# Paragraphe de texte courant.
.spec_text <- function(doc, text, cfg, italic = FALSE) {
  ft <- officer::fp_text(font.size = cfg$branding$body_size, italic = italic,
    font.family = cfg$branding$font)
  officer::body_add_fpar(doc, officer::fpar(officer::ftext(text, ft)))
}

# Commentaire technique factuel par champ (aucune interpretation clinique).
.spec_comments <- function(f) {
  yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
  out <- character(nrow(f))
  for (i in seq_len(nrow(f))) {
    type <- tolower(trimws(f$field_type[[i]]))
    vt <- tolower(trimws(f$validation_type[[i]]))
    mn <- trimws(f$validation_min[[i]])
    mx <- trimws(f$validation_max[[i]])
    parts <- character()
    if (yes(f$required[[i]])) {
      parts <- c(parts, "Champ obligatoire.")
    }
    if (nzchar(trimws(f$branching_logic[[i]]))) {
      parts <- c(parts, "Affich\u00e9 conditionnellement.")
    }
    if (type == "calc") {
      parts <- c(parts, "Valeur calcul\u00e9e automatiquement.")
    }
    if (grepl("number|integer", vt)) {
      if (nzchar(mn) && nzchar(mx)) {
        parts <- c(parts, "Validation num\u00e9rique avec limite minimale et maximale.")
      } else if (nzchar(mn)) {
        parts <- c(parts, "Validation num\u00e9rique avec limite minimale.")
      } else if (nzchar(mx)) {
        parts <- c(parts, "Validation num\u00e9rique avec limite maximale.")
      } else {
        parts <- c(parts, "Validation num\u00e9rique.")
      }
    } else if (grepl("date", vt)) {
      parts <- c(parts, "Validation de date.")
    } else if (grepl("time", vt)) {
      parts <- c(parts, "Validation d'heure.")
    }
    if (type == "checkbox") {
      parts <- c(parts, "Choix multiples autoris\u00e9s.")
    }
    if (type %in% c("radio", "dropdown")) {
      parts <- c(parts, "S\u00e9lection d'une seule modalit\u00e9.")
    }
    if (yes(f$identifier[[i]])) {
      parts <- c(parts, "Donn\u00e9e identifiante (sensible).")
    }
    out[[i]] <- paste(parts, collapse = " ")
  }
  out
}

# Tableau de synthese par instrument.
.spec_instrument_summary <- function(project, cfg) {
  f <- project$fields
  yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
  rows <- lapply(project$instruments, function(inst) {
    fi <- f[f$form_name == inst, , drop = FALSE]
    data.frame(
      Instrument = .instrument_display_label(inst, cfg),
      Variables = nrow(fi),
      Obligatoires = sum(yes(fi$required)),
      "Calcul\u00e9s" = sum(tolower(trimws(fi$field_type)) == "calc"),
      Identifiants = sum(yes(fi$identifier)),
      Logiques = sum(nzchar(trimws(fi$branching_logic))),
      check.names = FALSE, stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

# Colonnes retenues pour le tableau detaille (section 8).
.SPEC_DETAIL_COLS <- c(
  "Ordre", "Variable", "Num\u00e9ro de question", "Libell\u00e9", "Type",
  "Choix ou calcul", "Validation", "Min", "Max", "Obligatoire",
  "Identifiant", "Branching Logic", "Annotation", "Commentaire technique"
)

.specification_document <- function(project, cfg, source_csv) {
  dict <- .dictionary_fields(project)
  dict[["Commentaire technique"]] <- .spec_comments(project$fields)
  issues <- validate_project(project)
  summary <- .project_summary(project, issues)

  doc <- officer::read_docx()

  # --- Page de garde ---
  ft_title <- officer::fp_text(font.size = 22, bold = TRUE, font.family = cfg$branding$font)
  ft_sub <- officer::fp_text(font.size = 14, bold = TRUE, font.family = cfg$branding$font)
  ft_meta <- officer::fp_text(font.size = cfg$branding$body_size + 1, font.family = cfg$branding$font)
  doc <- officer::body_add_par(doc, "")
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext("Data Collection Specification", ft_title)))
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(cfg$project$study_name, ft_sub)))
  doc <- officer::body_add_par(doc, "")
  for (line in c(
    paste0("Organisation : ", cfg$project$organization),
    paste0("Version : ", cfg$project$version),
    paste0("Date : ", cfg$project$date),
    paste0("Confidentialit\u00e9 : ", cfg$project$confidentiality),
    paste0("Fichier source : ", basename(source_csv)),
    paste0("Empreinte SHA-256 : ", project$sha256),
    paste0("Date de g\u00e9n\u00e9ration : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  )) {
    doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(line, ft_meta)))
  }
  doc <- officer::body_add_break(doc)

  # --- 1. Historique des versions ---
  doc <- .spec_heading(doc, "1. Historique des versions", cfg)
  hist <- data.frame(
    Version = cfg$project$version,
    Date = cfg$project$date,
    Description = "G\u00e9n\u00e9ration initiale a partir du Data Dictionary. [\u00c0 compl\u00e9ter par l'\u00e9quipe \u00e9tude]",
    check.names = FALSE, stringsAsFactors = FALSE
  )
  doc <- officer::body_add_table(doc, hist, header = TRUE, first_row = TRUE)

  # --- 2. Objectif ---
  doc <- .spec_heading(doc, "2. Objectif", cfg)
  doc <- .spec_text(doc, paste0(
    "Ce document specifie la structure de collecte des donnees telle que definie ",
    "dans le Data Dictionary REDCap de l'etude. Il sert de reference technique ",
    "pour la programmation, la validation et le monitoring des donnees."
  ), cfg)

  # --- 3. P\u00e9rim\u00e8tre ---
  doc <- .spec_heading(doc, "3. P\u00e9rim\u00e8tre", cfg)
  doc <- .spec_text(doc, paste0(
    "Le present document couvre les ", summary$instruments, " instruments et ",
    summary$variables, " variables definis dans le Data Dictionary source. ",
    "Il ne decrit ni les procedures cliniques ni le protocole de l'etude."
  ), cfg)

  # --- 4. Source de v\u00e9rit\u00e9 ---
  doc <- .spec_heading(doc, "4. Source de v\u00e9rit\u00e9", cfg)
  doc <- .spec_text(doc, paste0(
    "Le Data Dictionary REDCap (fichier ", basename(source_csv), ") est l'unique ",
    "source de verite. Son integrite est attestee par l'empreinte SHA-256 : ",
    project$sha256, "."
  ), cfg)

  # --- 5. Conventions de nommage ---
  doc <- .spec_heading(doc, "5. Conventions de nommage", cfg)
  doc <- .spec_text(doc, paste0(
    "Les noms de variables suivent les conventions REDCap (minuscules, chiffres ",
    "et underscores). Chaque instrument correspond a un formulaire REDCap. Les ",
    "codes de reponse et la logique conditionnelle sont repris tels quels depuis ",
    "le Data Dictionary."
  ), cfg)

  # --- 6. R\u00e9sum\u00e9 des instruments ---
  doc <- .spec_heading(doc, "6. R\u00e9sum\u00e9 des instruments", cfg)
  doc <- officer::body_add_table(doc, .spec_instrument_summary(project, cfg),
    header = TRUE, first_row = TRUE)

  # --- 7. Sp\u00e9cifications d\u00e9taill\u00e9es par instrument ---
  doc <- .spec_heading(doc, "7. Sp\u00e9cifications d\u00e9taill\u00e9es par instrument", cfg)
  for (inst in project$instruments) {
    d <- dict[dict$Instrument == inst, .SPEC_DETAIL_COLS, drop = FALSE]
    doc <- .spec_subheading(doc, .instrument_display_label(inst, cfg), cfg)
    doc <- officer::body_add_table(doc, d, header = TRUE, first_row = TRUE)
    doc <- officer::body_add_par(doc, "")
  }

  # --- 8. Logiques conditionnelles ---
  doc <- .spec_heading(doc, "8. Logiques conditionnelles", cfg)
  bl <- .dictionary_branching(dict)
  if (nrow(bl) == 0L) {
    doc <- .spec_text(doc, "Aucune logique conditionnelle definie.", cfg)
  } else {
    doc <- officer::body_add_table(doc, bl, header = TRUE, first_row = TRUE)
  }

  # --- 9. Variables calcul\u00e9es ---
  doc <- .spec_heading(doc, "9. Variables calcul\u00e9es", cfg)
  cc <- .dictionary_calc(dict)
  if (nrow(cc) == 0L) {
    doc <- .spec_text(doc, "Aucune variable calculee.", cfg)
  } else {
    doc <- officer::body_add_table(doc, cc, header = TRUE, first_row = TRUE)
  }

  # --- 10. Contr\u00f4les de validation ---
  doc <- .spec_heading(doc, "10. Contr\u00f4les de validation", cfg)
  vv <- .dictionary_validations(dict)
  if (nrow(vv) == 0L) {
    doc <- .spec_text(doc, "Aucun controle de validation defini.", cfg)
  } else {
    doc <- officer::body_add_table(doc, vv, header = TRUE, first_row = TRUE)
  }

  # --- 11. Identifiants et donn\u00e9es sensibles ---
  doc <- .spec_heading(doc, "11. Identifiants et donn\u00e9es sensibles", cfg)
  id <- .dictionary_identifiers(dict)
  if (nrow(id) == 0L) {
    doc <- .spec_text(doc, "Aucun champ marque comme identifiant.", cfg)
  } else {
    doc <- officer::body_add_table(doc, id, header = TRUE, first_row = TRUE)
  }

  # --- 12. Matrices ---
  doc <- .spec_heading(doc, "12. Matrices", cfg)
  mx <- dict[tolower(trimws(dict$Type)) == "matrix", , drop = FALSE]
  if (nrow(mx) == 0L) {
    doc <- .spec_text(doc, "Aucun champ de type matrice.", cfg)
  } else {
    doc <- officer::body_add_table(doc,
      mx[, c("Instrument", "Variable", "Libell\u00e9", "Type"), drop = FALSE],
      header = TRUE, first_row = TRUE)
  }

  # --- 13. Probl\u00e8mes d\u00e9tect\u00e9s ---
  doc <- .spec_heading(doc, "13. Probl\u00e8mes d\u00e9tect\u00e9s \u00e0 la validation", cfg)
  if (nrow(issues) == 0L) {
    doc <- .spec_text(doc, "Aucun probleme detecte.", cfg)
  } else {
    doc <- officer::body_add_table(doc, issues, header = TRUE, first_row = TRUE)
  }

  # --- 14. Annexes ---
  doc <- .spec_heading(doc, "14. Annexes", cfg)
  doc <- .spec_text(doc, paste0(
    "Les listes de codes completes figurent dans le Data Dictionary lisible ",
    "(sorties Excel : feuille 'Choix'). [Sections complementaires a completer ",
    "par l'equipe etude si necessaire.]"
  ), cfg, italic = TRUE)

  .docx_set_a4(doc, orient = "landscape")
}

#' Generer la Data Collection Specification (Word)
#'
#' Document technique audit-ready : page de garde avec empreinte SHA-256, sections
#' normalisees et specifications detaillees par variable avec commentaire
#' technique factuel.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le chemin du fichier genere.
#' @export
build_specification <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  base <- tools::file_path_sans_ext(basename(csv))
  path <- file.path(output, paste0("Data_Collection_Specification_", base, ".docx"))
  cli::cli_h2("Data Collection Specification")
  doc <- .specification_document(project, cfg, csv)
  print(doc, target = path)
  cli::cli_alert_success("{basename(path)}")
  cli::cli_alert_success("Genere dans {normalizePath(output, winslash = '/')}")
  invisible(path)
}
