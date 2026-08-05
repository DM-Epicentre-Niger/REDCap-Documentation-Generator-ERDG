# Export PDF : conversion des .docx generes (mise en page identique, source
# unique) via LibreOffice en mode headless. Ne supprime JAMAIS le .docx d'origine.
#
# Choix technique : appel direct de LibreOffice (soffice) plutot que doconv, dont
# le backend MS Word (COM) echoue sur les chemins contenant espaces/parentheses.

.LIBREOFFICE_PATHS <- c(
  "C:/Program Files/LibreOffice/program/soffice.exe",
  "C:/Program Files (x86)/LibreOffice/program/soffice.exe",
  "/usr/bin/soffice", "/usr/bin/libreoffice",
  "/Applications/LibreOffice.app/Contents/MacOS/soffice"
)

# Localise l'executable LibreOffice (PATH puis emplacements connus).
.find_soffice <- function() {
  so <- Sys.which("soffice")
  if (nzchar(so)) {
    return(unname(so))
  }
  hit <- .LIBREOFFICE_PATHS[file.exists(.LIBREOFFICE_PATHS)]
  if (length(hit) > 0L) hit[[1L]] else ""
}

#' Verifier la disponibilite d'un moteur de conversion PDF
#'
#' @return `TRUE` si LibreOffice (soffice) est detecte, sinon `FALSE`.
#' @export
pdf_engine_available <- function() {
  nzchar(.find_soffice())
}

.pdf_engine_message <- function() {
  cli::cli_alert_danger("LibreOffice (soffice) introuvable : conversion PDF impossible.")
  cli::cli_alert_info(paste0(
    "Installez LibreOffice (https://www.libreoffice.org/) ; les fichiers .docx ",
    "sont conserves. L'export PDF sera disponible ensuite."
  ))
}

# Convertit un unique .docx en PDF via LibreOffice. Retourne le chemin du PDF ou "".
.soffice_convert <- function(soffice, docx, outdir, profile) {
  args <- c(
    "--headless", "--norestore", "--nologo", "--nofirststartwizard",
    paste0("-env:UserInstallation=", profile),
    "--convert-to", "pdf", "--outdir", shQuote(outdir), shQuote(docx)
  )
  status <- tryCatch(
    system2(soffice, args, stdout = FALSE, stderr = FALSE, timeout = 180),
    error = function(e) 1L, warning = function(w) 1L
  )
  pdf <- file.path(outdir, sub("\\.docx$", ".pdf", basename(docx), ignore.case = TRUE))
  if (file.exists(pdf)) pdf else ""
}

#' Convertir des fichiers Word en PDF
#'
#' Convertit chaque `.docx` en `.pdf` via LibreOffice. Le `.docx` d'origine est
#' toujours conserve. En cas d'echec sur un fichier, les autres sont tout de meme
#' traites et un recapitulatif est affiche.
#'
#' @param paths Vecteur de chemins de fichiers `.docx`.
#' @param output Dossier de sortie des PDF (par defaut : a cote de chaque .docx).
#'
#' @return De facon invisible, le vecteur des chemins PDF produits.
#' @export
convert_docx_to_pdf <- function(paths, output = NULL) {
  paths <- paths[grepl("\\.docx$", paths, ignore.case = TRUE)]
  if (length(paths) == 0L) {
    cli::cli_alert_warning("Aucun fichier .docx a convertir.")
    return(invisible(character(0)))
  }
  soffice <- .find_soffice()
  if (!nzchar(soffice)) {
    .pdf_engine_message()
    return(invisible(character(0)))
  }
  if (!is.null(output)) {
    dir.create(output, showWarnings = FALSE, recursive = TRUE)
  }
  profile_dir <- file.path(tempdir(), "erdg_lo_profile")
  profile <- paste0("file:///", gsub("\\\\", "/",
    normalizePath(profile_dir, winslash = "/", mustWork = FALSE)))

  produced <- character()
  failed <- character()
  for (p in paths) {
    p_abs <- normalizePath(p, winslash = "/", mustWork = TRUE)
    outdir <- if (is.null(output)) dirname(p_abs) else normalizePath(output, winslash = "/")
    pdf <- .soffice_convert(soffice, p_abs, outdir, profile)
    if (nzchar(pdf)) {
      cli::cli_alert_success("{basename(pdf)}")
      produced <- c(produced, pdf)
    } else {
      cli::cli_alert_danger("Echec de conversion : {basename(p)}")
      failed <- c(failed, p)
    }
  }
  cli::cli_alert_info("PDF produits : {length(produced)} ; echecs : {length(failed)}")
  invisible(produced)
}

#' Convertir en PDF un fichier .docx ou tous les .docx d'un dossier
#'
#' @param input Chemin d'un fichier `.docx` ou d'un dossier (parcouru
#'   recursivement).
#' @param output Dossier de sortie des PDF (facultatif).
#'
#' @return De facon invisible, le vecteur des chemins PDF produits.
#' @export
build_pdf <- function(input, output = NULL) {
  cli::cli_h2("Conversion PDF")
  if (dir.exists(input)) {
    docx <- list.files(input, pattern = "\\.docx$", recursive = TRUE,
      full.names = TRUE, ignore.case = TRUE)
  } else if (file.exists(input)) {
    docx <- input
  } else {
    cli::cli_abort("Fichier ou dossier introuvable : {.path {input}}.")
  }
  convert_docx_to_pdf(docx, output)
}
