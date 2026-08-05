# Helpers d'export Word (officer + flextable). Aucune logique REDCap ici :
# ces fonctions ne connaissent que du texte et des tableaux.

.DOCX_DARK <- "#595959"   # fond des titres de section
.DOCX_LIGHT <- "#D9D9D9"  # fond des en-tetes de colonnes
.DOCX_GRAY_TEXT <- "#7F7F7F"

# Largeur utile d'une page A4 portrait (pouces) avec marges ~2 cm.
.A4_USABLE_WIDTH <- 6.7

# Nettoie une chaine pour en faire un nom de fichier sur.
.sanitize_filename <- function(x) {
  x <- gsub("[^A-Za-z0-9_-]+", "_", x)
  x <- gsub("_+", "_", x)
  gsub("^_|_$", "", x)
}

# Ajoute le bloc de titre (equivalent en-tete) en haut du document.
.docx_add_title_block <- function(doc, cfg, instrument_label, doc_kind = "CRF Terrain") {
  b <- cfg$branding
  ft_org <- officer::fp_text(font.size = b$title_size, bold = TRUE, font.family = b$font)
  ft_h2 <- officer::fp_text(font.size = b$title_size - 2, bold = TRUE, font.family = b$font)
  ft_meta <- officer::fp_text(font.size = b$body_size, italic = TRUE, font.family = b$font)

  meta <- paste(
    paste0("Version : ", cfg$project$version),
    paste0("Date : ", cfg$project$date),
    cfg$project$confidentiality,
    sep = "    |    "
  )

  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(cfg$project$organization, ft_org)))
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(cfg$project$study_name, ft_h2)))
  doc <- officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(paste0(doc_kind, " - ", instrument_label), ft_h2)
  ))
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(meta, ft_meta)))
  officer::body_add_par(doc, "")
}

# Construit et stylise un tableau Question / Reponse pour une section.
# `df` : data.frame a colonnes Question / Reponse. `title` : titre de section
# (peut etre vide).
.docx_section_table <- function(df, title, cfg) {
  b <- cfg$branding
  border <- officer::fp_border(color = "black", width = 0.5)

  ft <- flextable::flextable(df)
  ft <- flextable::set_header_labels(ft, Question = "Question", Reponse = "R\u00e9ponse")

  has_title <- nzchar(trimws(title))
  if (has_title) {
    ft <- flextable::add_header_row(ft, values = title, colwidths = 2, top = TRUE)
  }

  ft <- flextable::font(ft, part = "all", fontname = b$font)
  ft <- flextable::fontsize(ft, size = b$body_size, part = "body")
  ft <- flextable::fontsize(ft, size = b$body_size + 1, part = "header")

  if (has_title) {
    ft <- flextable::bg(ft, part = "header", i = 1, bg = .DOCX_DARK)
    ft <- flextable::color(ft, part = "header", i = 1, color = "white")
    ft <- flextable::bold(ft, part = "header", i = 1)
    ft <- flextable::align(ft, part = "header", i = 1, align = "left")
    ft <- flextable::bg(ft, part = "header", i = 2, bg = .DOCX_LIGHT)
    ft <- flextable::bold(ft, part = "header", i = 2)
  } else {
    ft <- flextable::bg(ft, part = "header", i = 1, bg = .DOCX_LIGHT)
    ft <- flextable::bold(ft, part = "header", i = 1)
  }

  ft <- flextable::border_outer(ft, part = "all", border = border)
  ft <- flextable::border_inner(ft, part = "all", border = border)
  ft <- flextable::valign(ft, valign = "top", part = "body")
  ft <- flextable::align(ft, j = 1, align = "left", part = "body")

  qw <- .A4_USABLE_WIDTH * cfg$terrain$question_width_percent / 100
  aw <- .A4_USABLE_WIDTH * cfg$terrain$answer_width_percent / 100
  ft <- flextable::width(ft, j = 1, width = qw)
  ft <- flextable::width(ft, j = 2, width = aw)
  ft <- flextable::set_table_properties(ft, layout = "fixed")
  ft
}

# Tableau generique a N colonnes. `df` : data.frame ; `labels` : vecteur nomme
# (noms = colonnes de df, valeurs = en-tetes affiches) ; `widths` : fractions de
# la largeur utile (somme ~1) ; `title` : titre de section (peut etre vide).
# Aucune logique metier : les en-tetes sont fournis par l'appelant.
.docx_grid_table <- function(df, labels, widths, title, cfg) {
  b <- cfg$branding
  border <- officer::fp_border(color = "black", width = 0.5)

  ft <- flextable::flextable(df)
  ft <- do.call(flextable::set_header_labels, c(list(ft), as.list(labels)))

  has_title <- nzchar(trimws(title))
  if (has_title) {
    ft <- flextable::add_header_row(ft, values = title, colwidths = ncol(df), top = TRUE)
  }

  ft <- flextable::font(ft, part = "all", fontname = b$font)
  ft <- flextable::fontsize(ft, size = max(7, b$body_size - 1), part = "body")
  ft <- flextable::fontsize(ft, size = b$body_size, part = "header")

  if (has_title) {
    ft <- flextable::bg(ft, part = "header", i = 1, bg = .DOCX_DARK)
    ft <- flextable::color(ft, part = "header", i = 1, color = "white")
    ft <- flextable::bold(ft, part = "header", i = 1)
    ft <- flextable::align(ft, part = "header", i = 1, align = "left")
    ft <- flextable::bg(ft, part = "header", i = 2, bg = .DOCX_LIGHT)
    ft <- flextable::bold(ft, part = "header", i = 2)
  } else {
    ft <- flextable::bg(ft, part = "header", i = 1, bg = .DOCX_LIGHT)
    ft <- flextable::bold(ft, part = "header", i = 1)
  }

  ft <- flextable::border_outer(ft, part = "all", border = border)
  ft <- flextable::border_inner(ft, part = "all", border = border)
  ft <- flextable::valign(ft, valign = "top", part = "body")
  ft <- flextable::align(ft, align = "left", part = "body")

  for (j in seq_along(widths)) {
    ft <- flextable::width(ft, j = j, width = .A4_USABLE_WIDTH * widths[[j]])
  }
  flextable::set_table_properties(ft, layout = "fixed")
}

# Applique la section A4 par defaut (portrait ou paysage).
.docx_set_a4 <- function(doc, orient = "portrait") {
  short <- 8.27
  long <- 11.69
  if (orient == "landscape") {
    w <- long
    h <- short
  } else {
    w <- short
    h <- long
  }
  officer::body_set_default_section(
    doc,
    officer::prop_section(
      page_size = officer::page_size(width = w, height = h, orient = orient),
      page_margins = officer::page_mar(
        top = 0.59, bottom = 0.59, left = 0.59, right = 0.59,
        header = 0.4, footer = 0.4, gutter = 0
      ),
      type = "continuous"
    )
  )
}
