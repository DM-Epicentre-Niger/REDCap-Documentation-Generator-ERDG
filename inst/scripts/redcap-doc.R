#!/usr/bin/env Rscript
# Point d'entree de la ligne de commande d'ERDG, execute par Rscript.
#
# En production : le package est installe -> on appelle redcapdocgen::run_cli().
# En developpement : le package n'est pas installe -> on le charge via pkgload.

get_script_dir <- function() {
  ca <- commandArgs(FALSE)
  file_arg <- grep("^--file=", ca, value = TRUE)
  if (length(file_arg) > 0L) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]))))
  }
  getwd()
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (requireNamespace("redcapdocgen", quietly = TRUE)) {
    redcapdocgen::run_cli(args)
  } else if (requireNamespace("pkgload", quietly = TRUE)) {
    # Racine du package = deux niveaux au-dessus de inst/scripts/.
    pkg_root <- normalizePath(file.path(get_script_dir(), "..", ".."))
    pkgload::load_all(pkg_root, quiet = TRUE)
    run_cli(args)
  } else {
    stop(
      "Le package 'redcapdocgen' n'est pas installe et 'pkgload' est absent. ",
      "Executez scripts/install_windows.ps1."
    )
  }
}

main()
