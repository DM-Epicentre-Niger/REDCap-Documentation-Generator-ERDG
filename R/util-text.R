# Utilitaires texte partages par le parser et les services.

# Normalise un en-tete de colonne en slug : minuscules, non-alphanumeriques
# remplaces par "_", underscores collapses et rognes.
.normalize_header <- function(x) {
  x <- tolower(trimws(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("_+", "_", x)
  gsub("^_|_$", "", x)
}

# Retire les balises HTML (champs REDCap "rich text") et decode quelques
# entites courantes, puis normalise les espaces (y compris insecables).
# Sert au rendu terrain lisible.
.strip_html <- function(x) {
  if (length(x) == 0L) {
    return(x)
  }
  x <- gsub("<[^>]+>", " ", x)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&#39;|&rsquo;|&lsquo;|&apos;", "'", x)
  x <- gsub("&quot;|&ldquo;|&rdquo;", "\"", x)
  x <- gsub("[[:space:]\u00a0]+", " ", x)
  trimws(x)
}

# Extrait les noms de variables references dans une expression REDCap.
# Reconnait `[var]` et `[var(code)]` ; ignore le code de la case a cocher.
.extract_field_refs <- function(expr) {
  if (length(expr) == 0L || is.na(expr) || !nzchar(expr)) {
    return(character(0))
  }
  hits <- regmatches(expr, gregexpr("\\[[A-Za-z0-9_]+", expr))[[1]]
  if (length(hits) == 0L) {
    return(character(0))
  }
  unique(sub("^\\[", "", hits))
}

# Recupere la valeur d'une option "--nom=valeur" dans un vecteur d'arguments.
.get_opt <- function(args, name, default = NULL) {
  pat <- paste0("^", name, "=")
  hit <- grep(pat, args, value = TRUE)
  if (length(hit) == 0L) {
    return(default)
  }
  sub(pat, "", hit[[1L]])
}
