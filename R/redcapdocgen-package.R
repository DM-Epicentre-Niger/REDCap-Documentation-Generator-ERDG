#' redcapdocgen : Epicentre REDCap Documentation Generator (ERDG)
#'
#' Genere de la documentation (Word, Excel, PDF) a partir d'un Data Dictionary
#' REDCap. Le Data Dictionary CSV est la source unique de verite.
#'
#' Ce fichier ne contient que la documentation du package. Les composants sont
#' organises par prefixe de nommage dans le dossier `R/` :
#'
#' * `domain-*`   : modeles metier (classes R6)
#' * `parser-*`   : lecture du Data Dictionary
#' * `service-*`  : chargement, validation, analyse
#' * `generator-*`: production des documents
#' * `exporter-*` : ecriture Word / Excel / PDF
#' * `cli.R`      : ligne de commande
#'
#' Points d'entree actuels : [run_cli()] et [erdg_doctor()].
#'
#' @keywords internal
"_PACKAGE"
