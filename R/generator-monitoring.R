# Generateur du CRF Monitoring (Word). Destine aux data managers et moniteurs :
# contrairement au CRF Terrain, il EXPOSE les elements techniques (nom de
# variable, type, validation, logique, calcul) pour le controle qualite.

# Traduction lisible d'une logique conditionnelle REDCap (retire les crochets).
.mon_humanize_logic <- function(expr) {
  expr <- .strip_html(trimws(expr))
  if (!nzchar(expr)) {
    return("")
  }
  expr <- gsub("\\[|\\]", "", expr)
  gsub("[[:space:]]+", " ", expr)
}

# Cellule "Reponse attendue" : valeurs / codes acceptes.
.mon_expected <- function(row, cfg) {
  type <- tolower(trimws(row$field_type))
  vt <- tolower(trimws(row$validation_type))
  none <- list(text = "", appendix = NULL, appendix_title = NULL)

  if (type %in% c("radio", "dropdown", "checkbox")) {
    ch <- parse_choices(row$choices)
    if (nrow(ch) == 0L) {
      return(list(text = "(liste de choix vide)", appendix = NULL, appendix_title = NULL))
    }
    ch$label <- .strip_html(ch$label)
    if (isTRUE(cfg$terrain$move_long_choices_to_appendix) &&
      nrow(ch) > cfg$terrain$long_choice_threshold) {
      return(list(
        text = paste0("Voir annexe (", nrow(ch), " modalit\u00e9s)"),
        appendix = ch,
        appendix_title = paste0(row$field_name, " - ", .strip_html(trimws(row$field_label)))
      ))
    }
    lab <- if (type == "checkbox") " (choix multiples)" else ""
    return(list(
      text = paste0(paste0(ch$code, " = ", ch$label, collapse = "\n"), lab),
      appendix = NULL, appendix_title = NULL
    ))
  }

  txt <- switch(type,
    "yesno" = "1 = Oui / 0 = Non",
    "truefalse" = "1 = Vrai / 0 = Faux",
    "calc" = "Valeur calcul\u00e9e",
    "notes" = "Texte libre",
    "descriptive" = "(\u00e9l\u00e9ment descriptif)",
    "file" = "Fichier t\u00e9l\u00e9vers\u00e9",
    "slider" = "Curseur num\u00e9rique",
    {
      if (grepl("date", vt)) {
        "Date"
      } else if (grepl("time", vt)) {
        "Heure"
      } else if (grepl("integer", vt)) {
        "Entier"
      } else if (grepl("number", vt)) {
        "Num\u00e9rique"
      } else {
        "Texte"
      }
    }
  )
  list(text = txt, appendix = NULL, appendix_title = NULL)
}

# Cellule "Controles et notes de monitoring" : metadonnees techniques + points
# de verification. Ne jamais inventer de source document ni de regle clinique.
.mon_controls <- function(row, all_vars) {
  type <- tolower(trimws(row$field_type))
  vt <- trimws(row$validation_type)
  yes <- function(x) tolower(trimws(x)) %in% c("y", "yes", "1", "true")
  lines <- paste0("Type : ", if (nzchar(type)) type else "(non defini)")

  if (yes(row$required)) {
    lines <- c(lines, "Obligatoire")
  }
  if (yes(row$identifier)) {
    lines <- c(lines, "Identifiant (donn\u00e9e sensible)")
  }
  if (nzchar(vt)) {
    v <- paste0("Validation : ", vt)
    mn <- trimws(row$validation_min)
    mx <- trimws(row$validation_max)
    if (nzchar(mn) || nzchar(mx)) {
      v <- paste0(v, " (min: ", if (nzchar(mn)) mn else "-",
        " ; max: ", if (nzchar(mx)) mx else "-", ")")
    }
    lines <- c(lines, v)
  }
  bl <- .mon_humanize_logic(row$branching_logic)
  if (nzchar(bl)) {
    lines <- c(lines, paste0("Afficher uniquement si : ", bl))
  }
  if (type == "calc") {
    formula <- .strip_html(trimws(row$choices))
    if (nzchar(formula)) {
      lines <- c(lines, paste0("Calcul : ", formula))
    }
    lines <- c(lines, "Valeur calcul\u00e9e automatiquement ; v\u00e9rifier les variables sources.")
    missing <- setdiff(.extract_field_refs(row$choices), all_vars)
    if (length(missing) > 0L) {
      lines <- c(lines, paste0("Variables sources introuvables : ",
        paste(missing, collapse = ", ")))
    }
  }
  note <- .strip_html(trimws(row$field_note))
  if (nzchar(note)) {
    lines <- c(lines, paste0("Note : ", note))
  }
  annot <- trimws(row$annotation)
  if (nzchar(annot)) {
    lines <- c(lines, paste0("Annotation : ", annot))
  }
  mg <- trimws(row$matrix_group)
  if (nzchar(mg)) {
    lines <- c(lines, paste0("Matrice : ", mg))
  }
  paste(lines, collapse = "\n")
}

# Legende technique en tete de document.
.mon_add_legend <- function(doc, cfg) {
  ft <- officer::fp_text(font.size = cfg$branding$body_size, italic = TRUE,
    font.family = cfg$branding$font)
  txt <- paste0(
    "Document technique destin\u00e9 aux data managers et moniteurs ",
    "(ne pas diffuser aux \u00e9quipes terrain). Colonnes : Variable = nom REDCap ; ",
    "Question = libell\u00e9 ; R\u00e9ponse attendue = valeurs / codes accept\u00e9s ; ",
    "Contr\u00f4les = type, validation, caract\u00e8re obligatoire, identifiant, logique ",
    "d'affichage, calcul et points \u00e0 v\u00e9rifier."
  )
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(txt, ft)))
  officer::body_add_par(doc, "")
}

.MON_LABELS <- c(
  Variable = "Variable REDCap",
  Question = "Question / libell\u00e9",
  Reponse = "R\u00e9ponse attendue",
  Controles = "Contr\u00f4les et notes de monitoring"
)
.MON_WIDTHS <- c(0.16, 0.30, 0.22, 0.32)

# Construit le document officer d'un instrument.
.monitoring_document <- function(project, instrument, cfg) {
  fields <- project$fields[project$fields$form_name == instrument, , drop = FALSE]
  all_vars <- project$fields$field_name
  grp <- .section_groups(fields)

  doc <- officer::read_docx()
  doc <- .docx_add_title_block(doc, cfg, .instrument_display_label(instrument, cfg),
    doc_kind = "CRF Monitoring")
  doc <- .mon_add_legend(doc, cfg)

  appendix <- list()
  for (g in unique(grp$group)) {
    idx <- which(grp$group == g)
    title <- .strip_html(grp$titles[[g]])
    variable <- character()
    question <- character()
    reponse <- character()
    controles <- character()
    for (i in idx) {
      row <- fields[i, , drop = FALSE]
      exp <- .mon_expected(row, cfg)
      variable <- c(variable, row$field_name)
      question <- c(question, .strip_html(trimws(row$field_label)))
      reponse <- c(reponse, exp$text)
      controles <- c(controles, .mon_controls(row, all_vars))
      if (!is.null(exp$appendix)) {
        appendix[[length(appendix) + 1L]] <- list(
          title = exp$appendix_title, choices = exp$appendix
        )
      }
    }
    if (length(variable) == 0L) {
      next
    }
    df <- data.frame(
      Variable = variable, Question = question,
      Reponse = reponse, Controles = controles,
      stringsAsFactors = FALSE, check.names = FALSE
    )
    ft <- .docx_grid_table(df, .MON_LABELS, .MON_WIDTHS, title, cfg)
    doc <- flextable::body_add_flextable(doc, ft)
    doc <- officer::body_add_par(doc, "")
  }

  if (length(appendix) > 0L) {
    doc <- .terrain_appendix(doc, appendix, cfg)
  }

  .docx_set_a4(doc)
}

#' Generer les CRF Monitoring (Word) d'un Data Dictionary
#'
#' Produit un document Word par instrument, destine aux data managers et
#' moniteurs. Expose les elements techniques (type, validation, logique, calcul)
#' pour le controle qualite. N'invente aucune source ni regle clinique.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le vecteur des chemins des fichiers generes.
#' @export
build_monitoring <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  files <- character()
  cli::cli_h2("CRF Monitoring")
  cli::cli_alert_info("Instruments a generer : {length(project$instruments)}")
  for (inst in project$instruments) {
    doc <- .monitoring_document(project, inst, cfg)
    fname <- file.path(output, paste0("CRF_Monitoring_", .instrument_filename(inst, cfg), ".docx"))
    print(doc, target = fname)
    files <- c(files, fname)
    cli::cli_alert_success("{basename(fname)}")
  }
  cli::cli_alert_success("{length(files)} document(s) genere(s) dans {normalizePath(output, winslash = '/')}")
  invisible(files)
}
