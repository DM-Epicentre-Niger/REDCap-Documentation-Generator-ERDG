# Generateur "CRF Terrain TMF" : variante du CRF Terrain destinee au Trial
# Master File. Reprend un gabarit Word de reference (en-tete avec logo, pied de
# page avec pagination, marges A4/Arial) et construit un formulaire propre :
# tableau d'identification, sections numerotees, questions en tableaux
# Question/Reponse, reponses rendues selon le type, listes longues et champs
# techniques renvoyes en annexes. N'invente aucune donnee : tout vient du Data
# Dictionary (les numeros de question sont ceux presents dans les libelles).

# Petit utilitaire : valeur de repli si NULL/NA/vide.
.tmf_or <- function(a, b) {
  if (is.null(a) || length(a) == 0L) {
    return(b)
  }
  if (length(a) == 1L && is.na(a)) {
    return(b)
  }
  if (length(a) == 1L && is.character(a) && !nzchar(a)) {
    return(b)
  }
  a
}

# Caractere case a cocher.
.TMF_BOX <- "\u2610"

# Separe un numero de question "N.M" en tete de libelle. Retourne
# list(num, text). num = "" si le libelle n'est pas numerote.
.tmf_split_num <- function(label) {
  label <- trimws(.strip_html(label))
  m <- regmatches(label, regexpr("^[0-9]+\\.[0-9]+", label))
  if (length(m) == 0L || !nzchar(m)) {
    return(list(num = "", text = label))
  }
  rest <- trimws(sub("^[0-9]+\\.[0-9]+\\s*", "", label))
  list(num = m, text = rest)
}

# Nettoie un intitule de section et determine s'il introduit une section de
# premier niveau (numerotee "N.") et/ou une sous-section. Retourne
# list(top = <chr|NA>, sub = <chr|"">). top = NA : garder la section courante.
.tmf_parse_section <- function(sh) {
  sh <- trimws(.strip_html(sh))
  sh <- gsub("\\*{2,}", "|", sh) # artefacts "******"
  parts <- trimws(unlist(strsplit(sh, "\\|")))
  parts <- parts[nzchar(parts)]
  top <- NA_character_
  sub <- ""
  for (p in parts) {
    if (grepl("^[0-9]+\\.", p)) {
      top <- p
    } else {
      s <- trimws(sub("^[-\u2013\u2014\\s]+", "", p))
      if (nzchar(s)) sub <- s
    }
  }
  # Section numerotee -> on repart avec la sous-section detectee (souvent "").
  if (!is.na(top)) {
    return(list(top = top, sub = sub))
  }
  list(top = NA_character_, sub = sub)
}

# Metadonnees d'un instrument pour le TMF (code CRF, titre, description...).
.tmf_meta <- function(form_name, cfg) {
  tmf <- .tmf_or(cfg$tmf, list())
  imap <- .tmf_or(tmf$instruments, list())
  meta <- .tmf_or(imap[[form_name]], list())

  code <- .tmf_or(meta$code, {
    tok <- regmatches(form_name, regexpr("^[a-z]+[0-9]+[a-z]?", form_name))
    if (length(tok) == 0L || !nzchar(tok)) {
      toupper(substr(form_name, 1L, 6L))
    } else {
      paste0(toupper(substr(tok, 1L, 1L)), substr(tok, 2L, nchar(tok)))
    }
  })
  title <- .tmf_or(meta$title, {
    rest <- sub("^[a-z]+[0-9]+[a-z]?_", "", form_name)
    tools::toTitleCase(gsub("_", " ", rest))
  })
  list(
    code = code,
    title = title,
    description = .tmf_or(meta$description, ""),
    study = .tmf_or(cfg$project$study_name, "Etude"),
    confidentiality = .tmf_or(cfg$project$confidentiality, "Confidentiel"),
    version = .tmf_or(tmf$version, .tmf_or(cfg$project$version, "0.1")),
    date = .tmf_or(tmf$date, format(Sys.Date(), "%d/%m/%Y")),
    subtitle_prefix = .tmf_or(tmf$subtitle_prefix, "Cahier d'observation terrain")
  )
}

# Masque d'identifiant (ex. "S-|__|-|__|__|__|__|") trouve dans le libelle ou la
# note du champ d'evaluation, sinon un masque generique.
.tmf_id_mask <- function(id_fields) {
  for (i in seq_len(nrow(id_fields))) {
    for (src in c(id_fields$field_label[i], id_fields$field_note[i])) {
      s <- .strip_html(.tmf_or(src, ""))
      # Sequence de cases "|__|" avec prefixe/separateurs, bornee avant toute
      # virgule, guillemet ou espace (on ne veut pas le texte explicatif).
      m <- regmatches(s, regexpr("[A-Za-z0-9]{0,3}-?(\\|_+\\|-?)+", s))
      if (length(m) && nzchar(m)) {
        return(trimws(sub("-$", "", m)))
      }
    }
  }
  "|__|__|__|__|"
}

# Reponse a afficher selon le type de champ. annexB = TRUE si les options sont
# renvoyees en Annexe B.
.tmf_response <- function(row, cfg, annexB = FALSE) {
  type <- tolower(trimws(row$field_type))
  vt <- tolower(trimws(row$validation_type))
  blank <- "________________________"

  if (type == "calc") {
    return("Calcul automatique")
  }
  if (type == "descriptive") {
    return("")
  }
  if (type %in% c("radio", "dropdown", "checkbox")) {
    ch <- parse_choices(.tmf_or(row$choices, ""))
    if (annexB) {
      return("Voir Annexe B (liste des codes)")
    }
    if (nrow(ch) == 0L) {
      return(blank)
    }
    labs <- ch$label
    boxes <- paste0(.TMF_BOX, " ", labs)
    sep <- if (type == "checkbox") "    " else "    "
    txt <- paste(boxes, collapse = sep)
    if (type == "checkbox") {
      txt <- paste0(txt, "   (plusieurs reponses possibles)")
    }
    return(txt)
  }
  if (grepl("date", vt)) {
    return("__ / __ / ____")
  }
  if (type == "notes") {
    return("______________________________________________________________")
  }
  blank
}

# ---- Rendu des blocs Word ----

.tmf_title_block <- function(doc, meta, cfg) {
  doc <- officer::body_add_par(doc, meta$title, style = "Title")
  doc <- officer::body_add_par(doc,
    sprintf("%s  |  %s %s", meta$study, meta$subtitle_prefix, meta$code))
  doc <- officer::body_add_par(doc, sprintf(
    "Version %s   \u2022   Date du document %s   \u2022   %s",
    meta$version, meta$date, meta$confidentiality))
  if (nzchar(trimws(meta$description))) {
    doc <- officer::body_add_par(doc, meta$description)
  }
  doc
}

.tmf_heading <- function(doc, text, level) {
  officer::body_add_par(doc, text, style = paste("heading", level))
}

.tmf_id_line <- function(doc, mask, cfg) {
  officer::body_add_par(doc,
    sprintf("N\u00b0 d'\u00e9valuation de l'enfant : %s", mask))
}

# Largeurs de colonnes (pouces) a partir des pourcentages de la config terrain.
.tmf_col_widths <- function(cfg) {
  usable <- 6.85 # A4 - marges ~1.8cm de chaque cote
  qp <- .tmf_or(cfg$terrain$question_width_percent, 45) / 100
  ap <- .tmf_or(cfg$terrain$answer_width_percent, 55) / 100
  c(q = usable * qp, a = usable * ap)
}

# Tableau stylise a deux colonnes (en-tete grisee, bordures, Arial).
.tmf_two_col <- function(doc, df, headers, cfg, body_size = 10) {
  w <- .tmf_col_widths(cfg)
  names(df) <- c("c1", "c2")
  ft <- flextable::flextable(df)
  ft <- flextable::set_header_labels(ft, c1 = headers[[1]], c2 = headers[[2]])
  ft <- flextable::border_outer(ft, part = "all",
    border = officer::fp_border(color = "#808080", width = 1))
  ft <- flextable::border_inner(ft, part = "all",
    border = officer::fp_border(color = "#BFBFBF", width = 0.5))
  ft <- flextable::bg(ft, part = "header", bg = "#D9D9D9")
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::font(ft, fontname = "Arial", part = "all")
  ft <- flextable::fontsize(ft, size = body_size, part = "all")
  ft <- flextable::valign(ft, valign = "top", part = "all")
  ft <- flextable::padding(ft, padding = 2, part = "all")
  ft <- flextable::width(ft, j = 1, width = unname(w["q"]))
  ft <- flextable::width(ft, j = 2, width = unname(w["a"]))
  doc <- flextable::body_add_flextable(doc, ft)
  officer::body_add_par(doc, "")
}

.tmf_note <- function(doc, text, cfg) {
  ft <- officer::fp_text(italic = TRUE, font.size = 9, font.family = "Arial")
  officer::body_add_fpar(doc,
    officer::fpar(officer::ftext(paste0("\u26a0 ", .strip_html(text)), ft)))
}

# ---- Construction du document ----

.tmf_document <- function(project, form_name, cfg) {
  meta <- .tmf_meta(form_name, cfg)
  thr <- .tmf_or(cfg$terrain$long_choice_threshold, 15)

  f <- project$fields[project$fields$form_name == form_name, , drop = FALSE]
  f <- f[order(f$.order), , drop = FALSE]
  # Exclut les champs caches / en lecture seule (@HIDDEN, @READONLY, variantes).
  f <- .exclude_action_tag_fields(f, cfg)

  # Classification en une passe.
  n <- nrow(f)
  cur_top <- ""
  cur_sub <- ""
  seen_section <- FALSE
  klass <- character(n)
  top_v <- character(n)
  sub_v <- character(n)
  num_v <- character(n)
  lab_v <- character(n)
  annexB <- logical(n)

  for (i in seq_len(n)) {
    r <- f[i, ]
    sh <- trimws(.tmf_or(r$section_header, ""))
    if (nzchar(sh)) {
      ps <- .tmf_parse_section(sh)
      if (!is.na(ps$top)) {
        cur_top <- ps$top
        cur_sub <- ps$sub
        seen_section <- TRUE
      } else {
        cur_sub <- ps$sub
      }
    }
    sp <- .tmf_split_num(.tmf_or(r$field_label, ""))
    type <- tolower(trimws(r$field_type))
    nch <- 0L
    if (type %in% c("radio", "dropdown", "checkbox")) {
      nch <- nrow(parse_choices(.tmf_or(r$choices, "")))
    }
    top_v[i] <- cur_top
    sub_v[i] <- cur_sub
    num_v[i] <- sp$num
    lab_v[i] <- sp$text

    if (type == "descriptive") {
      klass[i] <- "note"
    } else if (!seen_section && !nzchar(sp$num)) {
      klass[i] <- "ident"
    } else if (!nzchar(sp$num)) {
      klass[i] <- "annexA"
    } else {
      klass[i] <- "question"
      if (type %in% c("radio", "dropdown", "checkbox") && nch >= thr) {
        annexB[i] <- TRUE
      }
    }
  }

  # Document a partir du gabarit de reference. suppressWarnings : officer peut
  # emettre un avertissement benin en relisant le settings.xml du gabarit.
  ref <- .tmf_reference_path(cfg)
  doc <- suppressWarnings(officer::read_docx(path = ref))
  doc <- .tmf_fill_headers(doc, meta)

  doc <- .tmf_title_block(doc, meta, cfg)

  # Identification.
  id_idx <- which(klass == "ident")
  mask <- if (length(id_idx)) .tmf_id_mask(f[id_idx, , drop = FALSE]) else "|__|__|__|__|"
  if (length(id_idx)) {
    doc <- .tmf_heading(doc, "Identification", 1)
    rows <- lapply(id_idx, function(i) {
      data.frame(c1 = .strip_html(trimws(f$field_label[i])),
        c2 = .tmf_response(f[i, ], cfg), stringsAsFactors = FALSE)
    })
    doc <- .tmf_two_col(doc, do.call(rbind, rows), c("Champ", "\u00c0 renseigner"), cfg)
  }

  # Corps : sections / sous-sections / questions, dans l'ordre.
  main_idx <- which(klass %in% c("question", "note"))
  prev_top <- NA_character_
  prev_sub <- NA_character_
  buf <- list() # lignes Question/Reponse en attente

  flush <- function(doc) {
    if (length(buf) == 0L) {
      return(doc)
    }
    df <- do.call(rbind, buf)
    buf <<- list()
    .tmf_two_col(doc, df, c("Question", "R\u00e9ponse"), cfg)
  }

  for (i in main_idx) {
    if (!identical(top_v[i], prev_top)) {
      doc <- flush(doc)
      doc <- .tmf_heading(doc, top_v[i], 1)
      doc <- .tmf_id_line(doc, mask, cfg)
      prev_top <- top_v[i]
      prev_sub <- NA_character_
    }
    if (!identical(sub_v[i], prev_sub) && nzchar(sub_v[i])) {
      doc <- flush(doc)
      doc <- .tmf_heading(doc, sub_v[i], 2)
      prev_sub <- sub_v[i]
    }
    if (klass[i] == "note") {
      doc <- flush(doc)
      doc <- .tmf_note(doc, f$field_label[i], cfg)
      next
    }
    q <- if (nzchar(num_v[i])) paste0(num_v[i], " ", lab_v[i]) else lab_v[i]
    buf[[length(buf) + 1L]] <- data.frame(
      c1 = q, c2 = .tmf_response(f[i, ], cfg, annexB = annexB[i]),
      stringsAsFactors = FALSE)
  }
  doc <- flush(doc)

  # Annexe A : champs techniques (non numerotes).
  aidx <- which(klass == "annexA")
  if (length(aidx)) {
    doc <- .tmf_heading(doc, "Annexe A \u2014 Champs techniques REDCap", 1)
    doc <- .tmf_id_line(doc, mask, cfg)
    doc <- officer::body_add_par(doc, paste0(
      "Champs intermediaires du formulaire electronique, conserves pour la ",
      "tracabilite. Ils ne sont pas a remplir sur le terrain."))
    rows <- lapply(aidx, function(i) {
      type <- tolower(trimws(f$field_type[i]))
      detail <- if (type == "calc") {
        paste0("Calcul : ", .strip_html(trimws(.tmf_or(f$choices[i], ""))))
      } else {
        .strip_html(trimws(.tmf_or(f$field_type[i], "")))
      }
      data.frame(c1 = paste0(f$field_name[i], " \u2014 ", .strip_html(trimws(f$field_label[i]))),
        c2 = detail, stringsAsFactors = FALSE)
    })
    doc <- .tmf_two_col(doc, do.call(rbind, rows), c("Champ technique", "Type / calcul"), cfg)
  }

  # Annexe B : listes longues (codes).
  bidx <- which(annexB)
  if (length(bidx)) {
    doc <- .tmf_heading(doc, "Annexe B \u2014 Listes de codes", 1)
    doc <- .tmf_id_line(doc, mask, cfg)
    for (i in bidx) {
      q <- if (nzchar(num_v[i])) paste0(" (Question ", num_v[i], ")") else ""
      doc <- .tmf_heading(doc, paste0(lab_v[i], q), 2)
      ch <- parse_choices(.tmf_or(f$choices[i], ""))
      df <- data.frame(c1 = ch$code, c2 = ch$label, stringsAsFactors = FALSE)
      doc <- .tmf_two_col(doc, df, c("Code", "Libell\u00e9"), cfg)
    }
  }

  # Le gabarit de reference fixe deja A4, les marges et les en-tetes/pieds :
  # ne pas appeler .docx_set_a4 (qui remplacerait le sectPr et ses references).
  doc
}

# Chemin du gabarit de reference : config (relatif au projet) sinon celui du
# package.
.tmf_reference_path <- function(cfg) {
  ref <- .tmf_or(cfg$tmf$reference_docx, "")
  base <- .tmf_or(attr(cfg, "config_dir"), getwd())
  if (nzchar(ref)) {
    cand <- if (file.exists(ref)) ref else file.path(base, ref)
    if (file.exists(cand)) {
      return(cand)
    }
    cli::cli_warn("Gabarit TMF introuvable : {.path {cand}}. Utilisation du gabarit par defaut.")
  }
  pkg <- system.file("extdata", "tmf_reference.docx", package = "redcapdocgen")
  if (nzchar(pkg) && file.exists(pkg)) {
    return(pkg)
  }
  cli::cli_abort("Aucun gabarit de reference TMF disponible.")
}

# Remplit l'en-tete et le pied de page (placeholders -> valeurs). Les accolades
# sont echappees car officer traite le motif comme une expression reguliere.
.tmf_fill_headers <- function(doc, meta) {
  pat <- function(name) paste0("\\{\\{", name, "\\}\\}")
  doc <- officer::headers_replace_all_text(doc, pat("STUDY"), meta$study, warn = FALSE)
  doc <- officer::headers_replace_all_text(doc, pat("CRF"), meta$code, warn = FALSE)
  doc <- officer::footers_replace_all_text(doc, pat("CRF"), meta$code, warn = FALSE)
  doc <- officer::footers_replace_all_text(doc, pat("VERSION"), meta$version, warn = FALSE)
  doc <- officer::footers_replace_all_text(doc, pat("DATE"), meta$date, warn = FALSE)
  doc
}

#' Generer les CRF Terrain au format TMF (Word)
#'
#' Variante du CRF Terrain destinee au Trial Master File : en-tete avec logo,
#' pied de page avec pagination, tableau d'identification, sections numerotees,
#' questions en tableaux Question/Reponse, listes longues et champs techniques
#' renvoyes en annexes. Un document Word par instrument.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#' @param instruments Vecteur de noms de formulaires a generer (sinon tous).
#'
#' @return De facon invisible, le vecteur des chemins des fichiers generes.
#' @export
build_terrain_tmf <- function(csv, output = "output", config = NULL, instruments = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  if (!is.null(config) && nzchar(config)) {
    attr(cfg, "config_dir") <- dirname(normalizePath(config, winslash = "/", mustWork = FALSE))
  }
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  insts <- .tmf_or(instruments, project$instruments)
  insts <- intersect(insts, project$instruments)

  files <- character()
  cli::cli_h2("CRF Terrain TMF")
  cli::cli_alert_info("Instruments a generer : {length(insts)}")
  for (inst in insts) {
    meta <- .tmf_meta(inst, cfg)
    doc <- .tmf_document(project, inst, cfg)
    # Nom de fichier : code + reste du nom de formulaire (sans le prefixe-code).
    rest <- sub("^[a-z]+[0-9]+[a-z]?_", "", inst)
    slug <- gsub("(^_|_$)", "", gsub("[^A-Za-z0-9]+", "_",
      stringi::stri_trans_general(rest, "Latin-ASCII")))
    fname <- file.path(output, sprintf("CRF_Terrain_%s_%s_TMF.docx", meta$code, slug))
    print(doc, target = fname)
    files <- c(files, fname)
    cli::cli_alert_success("{basename(fname)}")
  }
  cli::cli_alert_success("{length(files)} document(s) genere(s) dans {normalizePath(output, winslash = '/')}")
  invisible(files)
}
