# Generateur du CRF Terrain (Word). Destine aux equipes terrain : aucun nom de
# variable, aucune syntaxe REDCap, aucune formule, aucune logique conditionnelle.

.BOX <- "\u2610" # case a cocher vide (U+2610)
.BLANK_LINE <- strrep("_", 40L)

# Libelle lisible d'un instrument a partir de son nom de formulaire (repli).
# REDCap a deja retire les accents du nom de formulaire ; ce repli ne fait que
# remplacer les underscores et capitaliser.
.instrument_label <- function(form_name) {
  x <- gsub("_", " ", form_name)
  x <- trimws(x)
  if (!nzchar(x)) {
    return("Formulaire")
  }
  paste0(toupper(substr(x, 1L, 1L)), substr(x, 2L, nchar(x)))
}

# Libelle d'affichage : utilise la correspondance `instruments` de la config
# (slug -> libelle lisible accente) si presente, sinon le repli.
.instrument_display_label <- function(form_name, cfg) {
  m <- cfg$instruments
  if (is.list(m) && !is.null(m[[form_name]]) && nzchar(as.character(m[[form_name]]))) {
    return(as.character(m[[form_name]]))
  }
  .instrument_label(form_name)
}

# Fragment de nom de fichier pour un instrument : libelle d'affichage translittere
# en ASCII (e accents -> lettres simples) puis assaini.
.instrument_filename <- function(form_name, cfg) {
  lab <- .instrument_display_label(form_name, cfg)
  ascii <- stringi::stri_trans_general(lab, "Latin-ASCII")
  fn <- .sanitize_filename(ascii)
  if (!nzchar(fn)) .sanitize_filename(form_name) else fn
}

# Calcule le groupe de section de chaque champ (report du dernier en-tete).
.section_groups <- function(fields) {
  sec <- fields$section_header
  gid <- 0L
  group <- integer(nrow(fields))
  titles <- character()
  for (i in seq_len(nrow(fields))) {
    has <- nzchar(trimws(sec[[i]]))
    if (has || gid == 0L) {
      gid <- gid + 1L
      titles[gid] <- if (has) trimws(sec[[i]]) else ""
    }
    group[[i]] <- gid
  }
  list(group = group, titles = titles)
}

# Cellule "Reponse" pour un champ. Retourne text + eventuelle entree d'annexe.
.terrain_answer <- function(row, cfg) {
  type <- tolower(trimws(row$field_type))
  vt <- tolower(trimws(row$validation_type))
  show_codes <- isTRUE(cfg$terrain$show_response_codes)
  none <- list(text = "", appendix = NULL, appendix_title = NULL)

  choice_lines <- function(ch) {
    if (show_codes) {
      paste0(.BOX, " (", ch$code, ") ", ch$label)
    } else {
      paste0(.BOX, " ", ch$label)
    }
  }

  if (type %in% c("radio", "dropdown", "checkbox")) {
    ch <- parse_choices(row$choices)
    if (nrow(ch) == 0L) {
      return(list(text = .BLANK_LINE, appendix = NULL, appendix_title = NULL))
    }
    ch$label <- .strip_html(ch$label)
    long <- isTRUE(cfg$terrain$move_long_choices_to_appendix) &&
      nrow(ch) > cfg$terrain$long_choice_threshold
    if (long) {
      return(list(
        text = paste0("Inscrire le code : ", strrep("_", 12L),
          "\n(liste complete en annexe)"),
        appendix = ch,
        appendix_title = .strip_html(trimws(row$field_label))
      ))
    }
    return(list(
      text = paste(choice_lines(ch), collapse = "\n"),
      appendix = NULL, appendix_title = NULL
    ))
  }

  txt <- switch(type,
    "yesno" = paste0(.BOX, " Oui    ", .BOX, " Non"),
    "truefalse" = paste0(.BOX, " Vrai    ", .BOX, " Faux"),
    "notes" = paste(rep(.BLANK_LINE, 3L), collapse = "\n"),
    "calc" = if (isTRUE(cfg$terrain$show_calculated_fields)) "Calcul automatique" else NA_character_,
    "descriptive" = "",
    "file" = paste0("Document joint : ", strrep("_", 20L)),
    "sql" = NA_character_,
    "slider" = .BLANK_LINE,
    # text et types par defaut
    {
      if (grepl("date", vt)) {
        "__ / __ / ____"
      } else if (grepl("time", vt)) {
        "__ : __"
      } else {
        .BLANK_LINE
      }
    }
  )
  if (length(txt) == 1L && is.na(txt)) {
    return(NULL) # champ non affiche sur le CRF terrain
  }
  list(text = txt, appendix = NULL, appendix_title = NULL)
}

# Cellule "Question" : libelle + note de champ optionnelle.
.terrain_question <- function(row, cfg) {
  label <- .strip_html(trimws(row$field_label))
  if (!nzchar(label)) {
    label <- "(sans libelle)"
  }
  note <- .strip_html(trimws(row$field_note))
  if (isTRUE(cfg$terrain$show_field_notes) && nzchar(note)) {
    label <- paste0(label, "\n(", note, ")")
  }
  label
}

# Construit le document officer d'un instrument.
# Construit la regex des tags d'action a exclure. Pour chaque tag de base (ex.
# @HIDDEN) on accepte les variantes -APP et -FORM, mais PAS -SURVEY (le champ
# reste visible sur le formulaire). Correspondance via une limite negative pour
# ne pas confondre @HIDDEN avec @HIDDEN-SURVEY.
.action_tag_exclude_regex <- function(tags) {
  bases <- toupper(gsub("^@", "", tags))
  bases <- bases[nzchar(bases)]
  if (length(bases) == 0L) {
    return(NULL)
  }
  alt <- paste(paste0("@", bases, "(-APP|-FORM)?"), collapse = "|")
  paste0("(", alt, ")(?![-A-Za-z0-9])")
}

# Retire d'un CRF de collecte les champs dont l'annotation REDCap porte un tag
# d'exclusion (champ cache ou en lecture seule). Pilote par
# cfg$terrain$exclude_action_tags (defaut : @HIDDEN et @READONLY, variantes
# -APP/-FORM comprises). Une liste vide desactive l'exclusion.
.exclude_action_tag_fields <- function(fields, cfg) {
  tags <- cfg$terrain$exclude_action_tags
  if (is.null(tags)) {
    tags <- c("@HIDDEN", "@READONLY")
  }
  tags <- unlist(tags) # une liste YAML devient un vecteur
  rx <- .action_tag_exclude_regex(tags)
  if (is.null(rx) || nrow(fields) == 0L) {
    return(fields)
  }
  ann <- toupper(ifelse(is.na(fields$annotation), "", fields$annotation))
  fields[!grepl(rx, ann, perl = TRUE), , drop = FALSE]
}

.terrain_document <- function(project, instrument, cfg) {
  fields <- project$fields[project$fields$form_name == instrument, , drop = FALSE]
  fields <- .exclude_action_tag_fields(fields, cfg)
  grp <- .section_groups(fields)
  doc <- officer::read_docx()
  doc <- .docx_add_title_block(doc, cfg, .instrument_display_label(instrument, cfg))

  appendix <- list()

  for (g in unique(grp$group)) {
    idx <- which(grp$group == g)
    title <- .strip_html(grp$titles[[g]])
    q <- character()
    a <- character()
    for (i in idx) {
      row <- fields[i, , drop = FALSE]
      ans <- .terrain_answer(row, cfg)
      if (is.null(ans)) {
        next # champ masque (calc cache, sql...)
      }
      q <- c(q, .terrain_question(row, cfg))
      a <- c(a, ans$text)
      if (!is.null(ans$appendix)) {
        appendix[[length(appendix) + 1L]] <- list(
          title = ans$appendix_title, choices = ans$appendix
        )
      }
    }
    if (length(q) == 0L) {
      next
    }
    df <- data.frame(Question = q, Reponse = a, stringsAsFactors = FALSE, check.names = FALSE)
    ft <- .docx_section_table(df, title, cfg)
    doc <- flextable::body_add_flextable(doc, ft)
    doc <- officer::body_add_par(doc, "")
  }

  if (length(appendix) > 0L) {
    doc <- .terrain_appendix(doc, appendix, cfg)
  }

  .docx_set_a4(doc)
}

# Ajoute l'annexe des listes de codes longues.
.terrain_appendix <- function(doc, appendix, cfg) {
  b <- cfg$branding
  ft_h <- officer::fp_text(font.size = b$title_size - 2, bold = TRUE, font.family = b$font)
  doc <- officer::body_add_break(doc)
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext("Annexe - Listes de codes", ft_h)
  ))
  doc <- officer::body_add_par(doc, "")
  for (entry in appendix) {
    df <- data.frame(
      Code = entry$choices$code,
      Libelle = entry$choices$label,
      stringsAsFactors = FALSE, check.names = FALSE
    )
    ft <- .docx_section_table(
      stats::setNames(df, c("Question", "Reponse")),
      paste0("Liste : ", entry$title), cfg
    )
    ft <- flextable::set_header_labels(ft, Question = "Code", Reponse = "Libelle")
    doc <- flextable::body_add_flextable(doc, ft)
    doc <- officer::body_add_par(doc, "")
  }
  doc
}

#' Generer les CRF Terrain (Word) d'un Data Dictionary
#'
#' Produit un document Word par instrument REDCap, destine aux equipes terrain.
#' Aucun nom de variable, aucune formule ni logique REDCap n'apparait.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le vecteur des chemins des fichiers generes.
#' @export
build_terrain <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  files <- character()
  cli::cli_h2("CRF Terrain")
  cli::cli_alert_info("Instruments a generer : {length(project$instruments)}")
  for (inst in project$instruments) {
    doc <- .terrain_document(project, inst, cfg)
    fname <- file.path(output, paste0("CRF_Terrain_", .instrument_filename(inst, cfg), ".docx"))
    print(doc, target = fname)
    files <- c(files, fname)
    cli::cli_alert_success("{basename(fname)}")
  }
  cli::cli_alert_success("{length(files)} document(s) genere(s) dans {normalizePath(output, winslash = '/')}")
  invisible(files)
}
