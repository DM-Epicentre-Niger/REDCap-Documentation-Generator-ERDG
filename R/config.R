# Configuration ERDG : valeurs par defaut + fusion avec un YAML utilisateur.

# Fusion recursive de deux listes (les valeurs de `override` priment).
.merge_lists <- function(base, override) {
  for (nm in names(override)) {
    if (is.list(base[[nm]]) && is.list(override[[nm]])) {
      base[[nm]] <- .merge_lists(base[[nm]], override[[nm]])
    } else {
      base[[nm]] <- override[[nm]]
    }
  }
  base
}

#' Configuration ERDG par defaut
#'
#' @return Une liste imbriquee (`project`, `branding`, `terrain`, `output`).
#' @export
erdg_default_config <- function() {
  list(
    project = list(
      organization = "Epicentre",
      study_name = "Etude REDCap",
      short_name = "",
      language = "fr",
      version = "0.1",
      date = format(Sys.Date(), "%d/%m/%Y"),
      confidentiality = "Confidentiel"
    ),
    branding = list(
      font = "Calibri",
      title_size = 14,
      body_size = 9,
      grayscale = TRUE
    ),
    terrain = list(
      question_width_percent = 45,
      answer_width_percent = 55,
      show_response_codes = FALSE,
      show_field_notes = TRUE,
      show_calculated_fields = TRUE,
      move_long_choices_to_appendix = TRUE,
      long_choice_threshold = 15
    ),
    # Champs de monitoring renseignes manuellement par l'equipe (facultatifs).
    monitoring = list(
      source_document = "",
      sdv_required = "",
      critical_variable = "",
      custom_check = ""
    ),
    output = list(
      sanitize_filenames = TRUE,
      create_subfolders = TRUE,
      pdf = FALSE
    ),
    # Documents generes par `build-project` (dans l'ordre).
    build = list(
      documents = c(
        "terrain", "monitoring", "dictionary", "specification",
        "interviewer-manual", "monitoring-manual", "branching", "calculations"
      )
    ),
    # Correspondance optionnelle slug de formulaire -> libelle lisible accente.
    # A renseigner par projet (voir projects/MDF/config.yml).
    instruments = list()
  )
}

#' Charger une configuration ERDG
#'
#' Fusionne un fichier YAML utilisateur avec les valeurs par defaut.
#'
#' @param path Chemin d'un fichier YAML, ou `NULL` pour les valeurs par defaut.
#' @return La configuration fusionnee (liste).
#' @export
erdg_load_config <- function(path = NULL) {
  cfg <- erdg_default_config()
  if (!is.null(path) && nzchar(path)) {
    checkmate::assert_file_exists(path, access = "r")
    user <- yaml::read_yaml(path)
    if (is.list(user)) {
      cfg <- .merge_lists(cfg, user)
    }
  }
  cfg
}
