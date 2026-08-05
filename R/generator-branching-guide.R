# Generateur du guide des Branching Logic (Word). Pour chaque champ conditionnel :
# logique originale, variables referencees, traduction lisible (si fiable),
# statut de validation et avertissements. Ne traduit pas approximativement une
# expression complexe.

# Table de correspondance variable -> libelle / type / choix (pour traduire).
.field_lookup <- function(project) {
  f <- project$fields
  lk <- vector("list", nrow(f))
  names(lk) <- f$field_name
  for (i in seq_len(nrow(f))) {
    lk[[f$field_name[[i]]]] <- list(
      label = .strip_html(trimws(f$field_label[[i]])),
      type = tolower(trimws(f$field_type[[i]])),
      choices = f$choices[[i]]
    )
  }
  lk
}

# Traduit un code de reponse en libelle pour une variable donnee.
.code_to_label <- function(info, code) {
  code <- trimws(code)
  if (is.null(info)) {
    return(code)
  }
  if (info$type == "yesno") {
    if (code == "1") return("Oui")
    if (code == "0") return("Non")
  }
  if (info$type == "truefalse") {
    if (code == "1") return("Vrai")
    if (code == "0") return("Faux")
  }
  if (info$type %in% c("radio", "dropdown", "checkbox")) {
    ch <- parse_choices(info$choices)
    hit <- ch$label[trimws(ch$code) == code]
    if (length(hit) > 0L && nzchar(hit[[1]])) {
      return(.strip_html(hit[[1]]))
    }
  }
  code
}

.OP_FR <- c(
  "=" = "est \u00e9gal \u00e0", "==" = "est \u00e9gal \u00e0",
  "<>" = "est diff\u00e9rent de", "!=" = "est diff\u00e9rent de",
  ">=" = "est sup\u00e9rieur ou \u00e9gal \u00e0", "<=" = "est inf\u00e9rieur ou \u00e9gal \u00e0",
  ">" = "est sup\u00e9rieur \u00e0", "<" = "est inf\u00e9rieur \u00e0"
)

# Traduit une expression de branching si elle est simple, sinon renvoie NA.
.branching_translate <- function(expr, lookup) {
  e <- trimws(expr)
  # Expression complexe : operateurs logiques, fonctions, cases a cocher.
  if (grepl("\\b(and|or)\\b", e, ignore.case = TRUE) ||
    grepl("\\(", e) || grepl("\\]\\s*\\[", e)) {
    return(NA_character_)
  }
  m <- regmatches(e, regexec(
    "^\\[([A-Za-z0-9_]+)\\]\\s*(<>|!=|==|>=|<=|=|>|<)\\s*'?([^']*?)'?$", e
  ))[[1]]
  if (length(m) != 4L) {
    return(NA_character_)
  }
  var <- m[[2]]
  op <- m[[3]]
  val <- m[[4]]
  info <- lookup[[var]]
  var_label <- if (!is.null(info) && nzchar(info$label)) info$label else var
  op_fr <- if (op %in% names(.OP_FR)) .OP_FR[[op]] else op
  val_label <- .code_to_label(info, val)
  val_disp <- if (identical(val_label, trimws(val))) val else paste0(val_label, " (", trimws(val), ")")
  paste0("Afficher ce champ uniquement si \u00ab ", var_label, " \u00bb ", op_fr,
    " ", val_disp, ".")
}

.BRANCH_LABELS <- c(
  Instrument = "Instrument", Variable = "Variable", Libelle = "Libell\u00e9",
  Logique = "Logique REDCap", Refs = "Variables r\u00e9f\u00e9renc\u00e9es",
  Traduction = "Traduction lisible", Statut = "Statut", Avertissements = "Avertissements"
)
.BRANCH_WIDTHS <- c(0.13, 0.09, 0.15, 0.16, 0.10, 0.20, 0.07, 0.10)

.branching_table <- function(project, cfg) {
  f <- project$fields
  lookup <- .field_lookup(project)
  all_vars <- f$field_name
  idx <- which(nzchar(trimws(f$branching_logic)))
  rows <- lapply(idx, function(i) {
    expr <- trimws(f$branching_logic[[i]])
    refs <- .extract_field_refs(expr)
    missing <- setdiff(refs, all_vars)
    tr <- .branching_translate(expr, lookup)
    complexe <- is.na(tr)
    if (complexe) {
      tr <- "Expression complexe - v\u00e9rification manuelle requise."
    }
    warn <- character()
    if (length(missing) > 0L) {
      warn <- c(warn, paste0("Variable(s) absente(s) : ", paste(missing, collapse = ", ")))
    }
    if (complexe) {
      warn <- c(warn, "Expression complexe.")
    }
    statut <- if (length(missing) > 0L) {
      "Avertissement"
    } else if (complexe) {
      "\u00c0 v\u00e9rifier"
    } else {
      "OK"
    }
    data.frame(
      Instrument = .instrument_display_label(f$form_name[[i]], cfg),
      Variable = f$field_name[[i]],
      Libelle = .strip_html(trimws(f$field_label[[i]])),
      Logique = expr,
      Refs = paste(refs, collapse = ", "),
      Traduction = tr,
      Statut = statut,
      Avertissements = paste(warn, collapse = " "),
      check.names = FALSE, stringsAsFactors = FALSE
    )
  })
  if (length(rows) == 0L) {
    return(NULL)
  }
  do.call(rbind, rows)
}

#' Generer le guide des Branching Logic (Word)
#'
#' Pour chaque champ conditionnel : logique originale, variables referencees,
#' traduction lisible (uniquement si l'expression est simple et fiable), statut
#' et avertissements.
#'
#' @param csv Chemin du Data Dictionary CSV.
#' @param output Dossier de sortie (cree si besoin).
#' @param config Chemin d'un YAML de configuration, ou `NULL`.
#'
#' @return De facon invisible, le chemin du fichier genere.
#' @export
build_branching_guide <- function(csv, output = "output", config = NULL) {
  project <- parse_data_dictionary(csv)
  cfg <- erdg_load_config(config)
  dir.create(output, showWarnings = FALSE, recursive = TRUE)

  b <- cfg$branding
  ft_title <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0("Guide des Branching Logic - ", cfg$project$study_name), ft_title)
  ))
  doc <- officer::body_add_par(doc, "")

  tab <- .branching_table(project, cfg)
  cli::cli_h2("Guide des Branching Logic")
  if (is.null(tab)) {
    doc <- officer::body_add_par(doc, "Aucune logique conditionnelle definie.")
  } else {
    names(tab) <- unname(.BRANCH_LABELS[names(tab)])
    doc <- officer::body_add_table(doc, tab, header = TRUE, first_row = TRUE)
    cli::cli_alert_info("{nrow(tab)} champ(s) conditionnel(s).")
  }
  doc <- .docx_set_a4(doc, orient = "landscape")

  base <- tools::file_path_sans_ext(basename(csv))
  path <- file.path(output, paste0("Guide_Branching_Logic_", base, ".docx"))
  print(doc, target = path)
  cli::cli_alert_success("{basename(path)}")
  invisible(path)
}
