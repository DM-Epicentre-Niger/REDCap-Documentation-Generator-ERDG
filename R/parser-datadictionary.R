# Lecture robuste du Data Dictionary REDCap (CSV) -> modele interne `erdg_project`.
#
# Le CSV est la source unique de verite : le texte des valeurs est conserve tel
# quel, seuls les noms de colonnes sont normalises.

# Colonnes REDCap standard : slug d'en-tete normalise -> nom canonique interne.
.redcap_column_map <- c(
  "variable_field_name" = "field_name",
  "form_name" = "form_name",
  "section_header" = "section_header",
  "field_type" = "field_type",
  "field_label" = "field_label",
  "choices_calculations_or_slider_labels" = "choices",
  "field_note" = "field_note",
  "text_validation_type_or_show_slider_number" = "validation_type",
  "text_validation_min" = "validation_min",
  "text_validation_max" = "validation_max",
  "identifier" = "identifier",
  "branching_logic_show_field_only_if" = "branching_logic",
  "branching_logic" = "branching_logic",
  "required_field" = "required",
  "custom_alignment" = "custom_alignment",
  "question_number" = "question_number",
  "question_number_surveys_only" = "question_number",
  "matrix_group_name" = "matrix_group",
  "matrix_ranking" = "matrix_ranking",
  "field_annotation" = "annotation"
)

# Types de champ REDCap reconnus.
.known_field_types <- c(
  "text", "notes", "radio", "dropdown", "checkbox", "yesno", "truefalse",
  "calc", "descriptive", "file", "slider", "sql", "matrix"
)

# Detecte l'encodage via readr::guess_encoding ; replie sur UTF-8.
.detect_encoding <- function(path) {
  guesses <- tryCatch(readr::guess_encoding(path), error = function(e) NULL)
  if (is.null(guesses) || nrow(guesses) == 0L) {
    return("UTF-8")
  }
  enc <- guesses$encoding[[1L]]
  if (is.na(enc) || toupper(enc) %in% c("ASCII", "")) {
    return("UTF-8")
  }
  if (grepl("BOM", enc, ignore.case = TRUE)) {
    return("UTF-8")
  }
  enc
}

# Detecte le separateur (',' ou ';') a partir de la ligne d'en-tete.
.detect_delimiter <- function(path, encoding) {
  con <- file(path, open = "r", encoding = encoding)
  on.exit(close(con), add = TRUE)
  first <- readLines(con, n = 1L, warn = FALSE)
  if (length(first) == 0L) {
    return(",")
  }
  n_comma <- nchar(gsub("[^,]", "", first))
  n_semi <- nchar(gsub("[^;]", "", first))
  if (n_semi > n_comma) ";" else ","
}

# Remplit vers le bas les valeurs vides d'un vecteur (form_name defensif).
.fill_down <- function(x) {
  for (i in seq_along(x)) {
    if ((is.na(x[[i]]) || !nzchar(x[[i]])) && i > 1L) {
      x[[i]] <- x[[i - 1L]]
    }
  }
  x
}

#' Lire un Data Dictionary REDCap
#'
#' Detecte l'encodage et le separateur, lit le CSV en conservant le texte brut,
#' normalise les noms de colonnes vers un schema interne stable, et regroupe les
#' champs par instrument dans leur ordre d'origine.
#'
#' @param path Chemin vers le fichier Data Dictionary CSV.
#'
#' @return Un objet de classe `erdg_project` (liste S3) contenant : `source_path`,
#'   `encoding`, `delimiter`, `sha256`, `columns_original`, `fields` (data.frame),
#'   `instruments` et `parsed_at`.
#'
#' @examples
#' csv <- system.file("extdata", "sample_data_dictionary.csv",
#'                     package = "redcapdocgen")
#' if (nzchar(csv)) parse_data_dictionary(csv)
#' @export
parse_data_dictionary <- function(path) {
  checkmate::assert_file_exists(path, access = "r")

  encoding <- .detect_encoding(path)
  delimiter <- .detect_delimiter(path, encoding)

  raw <- readr::read_delim(
    path,
    delim = delimiter,
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = encoding),
    na = character(0),
    trim_ws = FALSE,
    show_col_types = FALSE,
    progress = FALSE
  )
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  # Remplace les NA residuels par des chaines vides (champs vides conserves).
  for (col in names(raw)) {
    raw[[col]][is.na(raw[[col]])] <- ""
  }

  columns_original <- names(raw)
  slugs <- .normalize_header(columns_original)
  known <- slugs %in% names(.redcap_column_map)
  canon <- slugs
  canon[known] <- unname(.redcap_column_map[slugs[known]])
  names(raw) <- canon

  required_cols <- c("field_name", "form_name", "field_type")
  missing_cols <- setdiff(required_cols, names(raw))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(c(
      "Le fichier ne ressemble pas a un Data Dictionary REDCap.",
      "x" = "Colonnes essentielles absentes : {.val {missing_cols}}.",
      "i" = "Colonnes detectees : {.val {columns_original}}."
    ))
  }

  # S'assure que toutes les colonnes canoniques attendues existent.
  for (col in unique(unname(.redcap_column_map))) {
    if (!col %in% names(raw)) {
      raw[[col]] <- ""
    }
  }

  raw$form_name <- .fill_down(raw$form_name)
  raw$.order <- seq_len(nrow(raw))

  structure(
    list(
      source_path = normalizePath(path, winslash = "/"),
      encoding = encoding,
      delimiter = delimiter,
      sha256 = digest::digest(file = path, algo = "sha256"),
      columns_original = columns_original,
      fields = raw,
      instruments = unique(raw$form_name),
      parsed_at = Sys.time()
    ),
    class = "erdg_project"
  )
}

#' @export
print.erdg_project <- function(x, ...) {
  cli::cli_h2("Projet REDCap")
  cli::cli_alert_info("Source      : {basename(x$source_path)}")
  cli::cli_alert_info("Encodage    : {x$encoding}  |  Delimiteur : {.val {x$delimiter}}")
  cli::cli_alert_info("Instruments : {length(x$instruments)}")
  cli::cli_alert_info("Variables   : {nrow(x$fields)}")
  invisible(x)
}
