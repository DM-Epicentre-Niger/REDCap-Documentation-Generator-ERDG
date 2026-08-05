# Helpers d'export Excel (openxlsx). Aucune logique REDCap : ne manipule que des
# data.frames et un classeur.

# Rend un nom de feuille Excel valide : <= 31 caracteres, sans caracteres
# interdits, unique parmi `existing`.
.xlsx_safe_sheet_name <- function(name, existing = character()) {
  name <- gsub("[\\[\\]:*?/\\\\]", " ", name, perl = TRUE)
  name <- gsub("[[:space:]]+", " ", trimws(name))
  if (!nzchar(name)) {
    name <- "Feuille"
  }
  base <- substr(name, 1L, 31L)
  candidate <- base
  i <- 1L
  while (candidate %in% existing) {
    suffix <- paste0("_", i)
    candidate <- paste0(substr(base, 1L, 31L - nchar(suffix)), suffix)
    i <- i + 1L
  }
  candidate
}

# Ajoute une feuille avec en-tete stylise, filtre, volet fige et largeurs auto.
.xlsx_add_sheet <- function(wb, name, df) {
  openxlsx::addWorksheet(wb, name)
  header_style <- openxlsx::createStyle(
    textDecoration = "bold", fgFill = "#D9D9D9",
    border = "TopBottomLeftRight", borderColour = "#BFBFBF",
    halign = "left", valign = "top", wrapText = FALSE
  )
  if (nrow(df) == 0L) {
    df <- df[1, , drop = FALSE][0, , drop = FALSE] # conserve les colonnes
  }
  openxlsx::writeData(wb, name, df, headerStyle = header_style, withFilter = TRUE)
  openxlsx::freezePane(wb, name, firstActiveRow = 2L)
  widths <- pmin(pmax(nchar(names(df)) + 2L, 12L), 60L)
  openxlsx::setColWidths(wb, name, cols = seq_len(ncol(df)), widths = widths)
  invisible(name)
}
