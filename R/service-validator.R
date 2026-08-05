# Validation structuree d'un projet REDCap (niveaux ERROR / WARNING / INFO).

.new_issue <- function(level, code, variable, message) {
  data.frame(
    level = level, code = code, variable = variable, message = message,
    stringsAsFactors = FALSE
  )
}

#' Valider un projet REDCap
#'
#' Applique une serie de controles structurels sur les champs issus du Data
#' Dictionary et renvoie les problemes detectes. Ne modifie jamais les donnees
#' et ne corrige rien silencieusement.
#'
#' Controles : nom de variable duplique ; nom de variable manquant ; type de
#' champ inconnu ; choix mal formes ou absents ; `min` superieur a `max` ;
#' variable referencee dans une logique conditionnelle mais absente ; variable
#' referencee dans un calcul mais absente ; matrice sans groupe ; champ calcule
#' declare obligatoire ; nom de formulaire manquant.
#'
#' @param project Objet `erdg_project` issu de [parse_data_dictionary()].
#'
#' @return Un `data.frame` a colonnes `level`, `code`, `variable`, `message`
#'   (vide si aucun probleme).
#'
#' @examples
#' csv <- system.file("extdata", "sample_data_dictionary.csv",
#'                     package = "redcapdocgen")
#' if (nzchar(csv)) validate_project(parse_data_dictionary(csv))
#' @export
validate_project <- function(project) {
  checkmate::assert_class(project, "erdg_project")
  f <- project$fields
  all_vars <- f$field_name
  issues <- list()
  add <- function(level, code, variable, message) {
    issues[[length(issues) + 1L]] <<- .new_issue(level, code, variable, message)
  }

  # Noms de variables dupliques / manquants.
  named <- f$field_name[nzchar(f$field_name)]
  for (v in unique(named[duplicated(named)])) {
    add("ERROR", "duplicate_variable", v,
      glue::glue("Nom de variable duplique : '{v}'."))
  }
  for (i in which(!nzchar(f$field_name))) {
    add("ERROR", "missing_variable_name", "",
      glue::glue("Ligne {i} : nom de variable manquant."))
  }

  # Nom de formulaire manquant.
  if (any(!nzchar(f$form_name))) {
    add("WARNING", "missing_form_name", "",
      "Au moins un champ n'a pas de nom de formulaire.")
  }

  for (i in seq_len(nrow(f))) {
    var <- f$field_name[[i]]
    type <- tolower(trimws(f$field_type[[i]]))

    # Type de champ inconnu.
    if (nzchar(type) && !type %in% .known_field_types) {
      add("WARNING", "unknown_field_type", var,
        glue::glue("Type de champ inconnu : '{type}'."))
    }

    # Choix des champs a liste.
    if (type %in% .choice_field_types) {
      ch <- parse_choices(f$choices[[i]])
      if (nrow(ch) == 0L) {
        add("ERROR", "empty_choices", var,
          glue::glue("Champ '{type}' sans liste de choix."))
      } else if (any(!ch$valid)) {
        add("ERROR", "malformed_choice", var,
          "Choix mal forme (code ou libelle manquant, format attendu 'code, libelle').")
      }
    }

    # min > max (uniquement si les deux bornes sont numeriques).
    mn <- suppressWarnings(as.numeric(f$validation_min[[i]]))
    mx <- suppressWarnings(as.numeric(f$validation_max[[i]]))
    if (!is.na(mn) && !is.na(mx) && mn > mx) {
      add("ERROR", "min_greater_than_max", var,
        glue::glue("Validation : minimum ({mn}) superieur au maximum ({mx})."))
    }

    # Variables referencees dans la logique conditionnelle.
    for (ref in .extract_field_refs(f$branching_logic[[i]])) {
      if (!ref %in% all_vars) {
        add("WARNING", "branching_missing_var", var,
          glue::glue("Logique conditionnelle : variable '{ref}' introuvable."))
      }
    }

    # Variables referencees dans un calcul.
    if (type == "calc") {
      for (ref in .extract_field_refs(f$choices[[i]])) {
        if (!ref %in% all_vars) {
          add("WARNING", "calc_missing_var", var,
            glue::glue("Calcul : variable source '{ref}' introuvable."))
        }
      }
      if (tolower(trimws(f$required[[i]])) %in% c("y", "yes", "1", "true")) {
        add("WARNING", "required_calculated", var,
          "Champ calcule declare obligatoire (inhabituel).")
      }
    }

    # Matrice sans groupe.
    if (type == "matrix" && !nzchar(trimws(f$matrix_group[[i]]))) {
      add("WARNING", "matrix_without_group", var,
        "Champ de type matrice sans nom de groupe.")
    }
  }

  if (length(issues) == 0L) {
    return(.new_issue(character(0), character(0), character(0), character(0)))
  }
  out <- do.call(rbind, issues)
  ord <- match(out$level, c("ERROR", "WARNING", "INFO"))
  out[order(ord), , drop = FALSE]
}
