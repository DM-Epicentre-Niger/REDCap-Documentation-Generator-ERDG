# Comparaison de deux versions d'un Data Dictionary REDCap. Ne modifie jamais les
# fichiers source et ne remplace jamais le nouveau. Classe chaque changement :
# CRITIQUE / MAJEUR / MODERE / MINEUR / INFORMATION.

.LEVEL_ORDER <- c("CRITIQUE", "MAJEUR", "MOD\u00c9R\u00c9", "MINEUR", "INFORMATION")

.cmp_row <- function(level, category, instrument, variable, attribute, old, new) {
  data.frame(
    Niveau = level, "Cat\u00e9gorie" = category, Instrument = instrument,
    Variable = variable, Attribut = attribute,
    "Ancienne valeur" = old, "Nouvelle valeur" = new,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

# Index nom de variable -> ligne (1 ligne par variable).
.rows_by_name <- function(f) {
  lk <- split(f, f$field_name)
  lapply(lk, function(d) d[1, , drop = FALSE])
}

# Compare les listes de choix de deux versions d'un champ.
.compare_choices <- function(old_row, new_row, instrument, variable) {
  co <- parse_choices(old_row$choices)
  cn <- parse_choices(new_row$choices)
  om <- stats::setNames(.strip_html(co$label), co$code)
  nm <- stats::setNames(.strip_html(cn$label), cn$code)
  out <- list()
  for (code in intersect(names(om), names(nm))) {
    if (!identical(om[[code]], nm[[code]])) {
      out[[length(out) + 1L]] <- .cmp_row("CRITIQUE", "choix recod\u00e9", instrument,
        variable, paste0("choix ", code), om[[code]], nm[[code]])
    }
  }
  for (code in setdiff(names(om), names(nm))) {
    out[[length(out) + 1L]] <- .cmp_row("CRITIQUE", "choix supprim\u00e9", instrument,
      variable, paste0("choix ", code), om[[code]], "")
  }
  for (code in setdiff(names(nm), names(om))) {
    out[[length(out) + 1L]] <- .cmp_row("MINEUR", "choix ajout\u00e9", instrument,
      variable, paste0("choix ", code), "", nm[[code]])
  }
  out
}

# Compare une variable presente dans les deux versions.
.compare_field <- function(old_row, new_row, cfg) {
  instrument <- .instrument_display_label(new_row$form_name, cfg)
  variable <- new_row$field_name
  type_old <- tolower(trimws(old_row$field_type))
  type_new <- tolower(trimws(new_row$field_type))
  out <- list()
  add <- function(level, category, attribute, oldv, newv) {
    out[[length(out) + 1L]] <<- .cmp_row(level, category, instrument, variable,
      attribute, oldv, newv)
  }
  diff <- function(a, b) !identical(trimws(a), trimws(b))

  if (diff(old_row$form_name, new_row$form_name)) {
    add("MOD\u00c9R\u00c9", "variable d\u00e9plac\u00e9e", "instrument", old_row$form_name, new_row$form_name)
  }
  if (diff(.strip_html(old_row$field_label), .strip_html(new_row$field_label))) {
    add("MOD\u00c9R\u00c9", "libell\u00e9 modifi\u00e9", "libell\u00e9",
      .strip_html(old_row$field_label), .strip_html(new_row$field_label))
  }
  if (diff(type_old, type_new)) {
    add("MAJEUR", "type modifi\u00e9", "type", type_old, type_new)
  }

  if (type_new == "calc" || type_old == "calc") {
    if (diff(old_row$choices, new_row$choices)) {
      add("MAJEUR", "calcul modifi\u00e9", "formule", old_row$choices, new_row$choices)
    }
  } else if (type_new %in% c("radio", "dropdown", "checkbox")) {
    out <- c(out, .compare_choices(old_row, new_row, instrument, variable))
  } else if (diff(old_row$choices, new_row$choices)) {
    add("MOD\u00c9R\u00c9", "param\u00e8tres modifi\u00e9s", "choix/param\u00e8tres", old_row$choices, new_row$choices)
  }

  if (diff(old_row$validation_type, new_row$validation_type)) {
    add("MAJEUR", "validation modifi\u00e9e", "validation",
      old_row$validation_type, new_row$validation_type)
  }
  if (diff(old_row$validation_min, new_row$validation_min)) {
    add("MAJEUR", "borne modifi\u00e9e", "min", old_row$validation_min, new_row$validation_min)
  }
  if (diff(old_row$validation_max, new_row$validation_max)) {
    add("MAJEUR", "borne modifi\u00e9e", "max", old_row$validation_max, new_row$validation_max)
  }
  if (diff(old_row$required, new_row$required)) {
    add("MOD\u00c9R\u00c9", "obligatoire modifi\u00e9", "obligatoire", old_row$required, new_row$required)
  }
  if (diff(old_row$identifier, new_row$identifier)) {
    add("MAJEUR", "identifiant modifi\u00e9", "identifiant", old_row$identifier, new_row$identifier)
  }
  if (diff(old_row$branching_logic, new_row$branching_logic)) {
    add("MAJEUR", "logique modifi\u00e9e", "branching logic",
      old_row$branching_logic, new_row$branching_logic)
  }
  if (diff(old_row$matrix_group, new_row$matrix_group)) {
    add("MOD\u00c9R\u00c9", "matrice modifi\u00e9e", "groupe de matrice",
      old_row$matrix_group, new_row$matrix_group)
  }
  if (diff(old_row$annotation, new_row$annotation)) {
    add("MINEUR", "annotation modifi\u00e9e", "annotation", old_row$annotation, new_row$annotation)
  }
  if (diff(.strip_html(old_row$field_note), .strip_html(new_row$field_note))) {
    add("MINEUR", "note modifi\u00e9e", "note",
      .strip_html(old_row$field_note), .strip_html(new_row$field_note))
  }
  if (diff(old_row$question_number, new_row$question_number)) {
    add("INFORMATION", "num\u00e9ro modifi\u00e9", "num\u00e9ro de question",
      old_row$question_number, new_row$question_number)
  }
  out
}

# Construit le tableau complet des changements entre deux projets.
.compare_projects <- function(old, new, cfg) {
  o_by <- .rows_by_name(old$fields)
  n_by <- .rows_by_name(new$fields)
  o_names <- names(o_by)
  n_names <- names(n_by)

  removed <- setdiff(o_names, n_names)
  added <- setdiff(n_names, o_names)
  common <- intersect(o_names, n_names)

  changes <- list()

  # Detection de renommage : variable retiree + variable ajoutee de meme
  # formulaire, meme libelle et meme type.
  key <- function(r) paste(trimws(r$form_name), .strip_html(trimws(r$field_label)),
    tolower(trimws(r$field_type)), sep = "")
  rem_keys <- vapply(removed, function(v) key(o_by[[v]]), character(1))
  add_keys <- vapply(added, function(v) key(n_by[[v]]), character(1))
  renamed_old <- character()
  renamed_new <- character()
  for (i in seq_along(removed)) {
    j <- which(add_keys == rem_keys[[i]])
    j <- j[!added[j] %in% renamed_new]
    if (length(j) > 0L && nzchar(.strip_html(trimws(o_by[[removed[[i]]]]$field_label)))) {
      changes[[length(changes) + 1L]] <- .cmp_row("CRITIQUE", "variable renomm\u00e9e",
        .instrument_display_label(n_by[[added[[j[1]]]]]$form_name, cfg),
        paste0(removed[[i]], " -> ", added[[j[1]]]), "nom de variable",
        removed[[i]], added[[j[1]]])
      renamed_old <- c(renamed_old, removed[[i]])
      renamed_new <- c(renamed_new, added[[j[1]]])
    }
  }
  removed <- setdiff(removed, renamed_old)
  added <- setdiff(added, renamed_new)

  for (v in removed) {
    changes[[length(changes) + 1L]] <- .cmp_row("CRITIQUE", "variable supprim\u00e9e",
      .instrument_display_label(o_by[[v]]$form_name, cfg), v, "variable",
      .strip_html(o_by[[v]]$field_label), "")
  }
  for (v in added) {
    changes[[length(changes) + 1L]] <- .cmp_row("MINEUR", "variable ajout\u00e9e",
      .instrument_display_label(n_by[[v]]$form_name, cfg), v, "variable", "",
      .strip_html(n_by[[v]]$field_label))
  }
  for (v in common) {
    changes <- c(changes, .compare_field(o_by[[v]], n_by[[v]], cfg))
  }

  # Instruments ajoutes / supprimes.
  for (inst in setdiff(new$instruments, old$instruments)) {
    changes[[length(changes) + 1L]] <- .cmp_row("INFORMATION", "instrument ajout\u00e9",
      .instrument_display_label(inst, cfg), "", "instrument", "", inst)
  }
  for (inst in setdiff(old$instruments, new$instruments)) {
    changes[[length(changes) + 1L]] <- .cmp_row("INFORMATION", "instrument supprim\u00e9",
      .instrument_display_label(inst, cfg), "", "instrument", inst, "")
  }

  if (length(changes) == 0L) {
    return(.cmp_row(character(0), character(0), character(0), character(0),
      character(0), character(0), character(0)))
  }
  tab <- do.call(rbind, changes)
  tab[order(match(tab$Niveau, .LEVEL_ORDER)), , drop = FALSE]
}

.compare_summary <- function(changes) {
  counts <- vapply(.LEVEL_ORDER, function(l) sum(changes$Niveau == l), integer(1))
  data.frame(Niveau = .LEVEL_ORDER, Nombre = as.integer(counts),
    check.names = FALSE, stringsAsFactors = FALSE)
}

#' Comparer deux versions d'un Data Dictionary REDCap
#'
#' Detecte et classe les differences entre deux Data Dictionary (CRITIQUE a
#' INFORMATION), et produit un rapport Word, Excel et JSON. Ne modifie jamais les
#' fichiers source et ne remplace jamais le nouveau.
#'
#' @param old_csv Ancien Data Dictionary CSV.
#' @param new_csv Nouveau Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, une liste (`changes`, `summary`, `word`, `xlsx`,
#'   `json`).
#' @export
compare_dictionaries <- function(old_csv, new_csv, output = "comparison", config = NULL) {
  old <- parse_data_dictionary(old_csv)
  new <- parse_data_dictionary(new_csv)
  cfg <- erdg_load_config(config)
  changes <- .compare_projects(old, new, cfg)
  summary <- .compare_summary(changes)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  cli::cli_h2("Comparaison de Data Dictionary")
  for (i in seq_len(nrow(summary))) {
    lvl <- summary$Niveau[[i]]
    n <- summary$Nombre[[i]]
    if (lvl == "CRITIQUE" && n > 0L) {
      cli::cli_alert_danger("{lvl} : {n}")
    } else if (lvl == "MAJEUR" && n > 0L) {
      cli::cli_alert_warning("{lvl} : {n}")
    } else {
      cli::cli_alert_info("{lvl} : {n}")
    }
  }

  meta <- list(
    ancien = basename(old_csv), nouveau = basename(new_csv),
    sha256_ancien = old$sha256, sha256_nouveau = new$sha256,
    genere_le = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  )

  base <- tools::file_path_sans_ext(basename(new_csv))
  word_path <- file.path(output, paste0("Comparaison_", base, ".docx"))
  xlsx_path <- file.path(output, paste0("Comparaison_", base, ".xlsx"))
  json_path <- file.path(output, paste0("Comparaison_", base, ".json"))

  .compare_write_word(word_path, changes, summary, meta, cfg)
  .compare_write_xlsx(xlsx_path, changes, summary, meta)
  jsonlite::write_json(
    list(meta = meta, summary = summary, changes = changes),
    json_path, auto_unbox = TRUE, pretty = TRUE
  )

  cli::cli_alert_success("Word  : {normalizePath(word_path, winslash = '/')}")
  cli::cli_alert_success("Excel : {normalizePath(xlsx_path, winslash = '/')}")
  cli::cli_alert_success("JSON  : {normalizePath(json_path, winslash = '/')}")
  invisible(list(changes = changes, summary = summary,
    word = word_path, xlsx = xlsx_path, json = json_path))
}

.compare_write_word <- function(path, changes, summary, meta, cfg) {
  b <- cfg$branding
  ft_title <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  ft_meta <- officer::fp_text(font.size = b$body_size, italic = TRUE, font.family = b$font)
  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0("Rapport de comparaison - ", cfg$project$study_name), ft_title)
  ))
  for (line in c(
    paste0("Ancien : ", meta$ancien, "  (SHA-256 : ", meta$sha256_ancien, ")"),
    paste0("Nouveau : ", meta$nouveau, "  (SHA-256 : ", meta$sha256_nouveau, ")"),
    paste0("G\u00e9n\u00e9r\u00e9 le : ", meta$genere_le)
  )) {
    doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(line, ft_meta)))
  }
  doc <- officer::body_add_par(doc, "")
  doc <- officer::body_add_table(doc, summary, header = TRUE, first_row = TRUE)
  doc <- officer::body_add_par(doc, "")
  if (nrow(changes) == 0L) {
    doc <- officer::body_add_par(doc, "Aucune difference detectee.")
  } else {
    doc <- officer::body_add_table(doc, changes, header = TRUE, first_row = TRUE)
  }
  doc <- .docx_set_a4(doc, orient = "landscape")
  print(doc, target = path)
  path
}

.compare_write_xlsx <- function(path, changes, summary, meta) {
  wb <- openxlsx::createWorkbook()
  meta_df <- data.frame(
    Champ = names(meta), Valeur = unlist(meta, use.names = FALSE),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  .xlsx_add_sheet(wb, "M\u00e9tadonn\u00e9es", meta_df)
  .xlsx_add_sheet(wb, "R\u00e9sum\u00e9", summary)
  .xlsx_add_sheet(wb, "Changements", changes)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}
