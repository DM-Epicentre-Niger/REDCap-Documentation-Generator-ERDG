# Analyse des choix REDCap ("1, Oui | 0, Non").

#' Analyser une chaine de choix REDCap
#'
#' Decoupe une chaine de la forme `"1, Oui | 0, Non"` en un tableau code/libelle.
#' Le decoupage code/libelle se fait sur la **premiere** virgule, ce qui permet
#' aux libelles de contenir des virgules.
#'
#' @param text Chaine de choix (colonne "Choices, Calculations, OR Slider
#'   Labels"). Peut etre vide ou `NA`.
#'
#' @return Un `data.frame` a colonnes `code`, `label`, `valid`. Vide si `text`
#'   est vide.
#'
#' @examples
#' parse_choices("1, Oui | 0, Non")
#' @export
parse_choices <- function(text) {
  empty <- data.frame(
    code = character(0), label = character(0), valid = logical(0),
    stringsAsFactors = FALSE
  )
  if (length(text) == 0L || is.na(text) || !nzchar(trimws(text))) {
    return(empty)
  }

  parts <- strsplit(text, "\\|")[[1]]
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L) {
    return(empty)
  }

  code <- character(length(parts))
  label <- character(length(parts))
  valid <- logical(length(parts))
  for (i in seq_along(parts)) {
    p <- parts[[i]]
    m <- regexpr(",", p, fixed = TRUE)
    if (m == -1L) {
      code[[i]] <- NA_character_
      label[[i]] <- p
      valid[[i]] <- FALSE
    } else {
      code[[i]] <- trimws(substr(p, 1L, m - 1L))
      label[[i]] <- trimws(substr(p, m + 1L, nchar(p)))
      valid[[i]] <- nzchar(code[[i]]) && nzchar(label[[i]])
    }
  }
  data.frame(code = code, label = label, valid = valid, stringsAsFactors = FALSE)
}

# Types de champ qui doivent porter une liste de choix explicite.
.choice_field_types <- c("radio", "dropdown", "checkbox")
