# Controles qualite locaux : tests, lint, formatage, couverture.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

$root = Split-Path -Parent $PSScriptRoot

$rscript = Find-Rscript
if (-not $rscript) {
    Write-Error "Rscript introuvable. Installez R 4.4+ depuis https://cran.r-project.org/."
    exit 1
}

Push-Location $root
try {
    Write-Host "== Installation des outils qualite (si absents) =="
    & $rscript -e "pkgs <- c('lintr','styler','covr'); to_install <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly=TRUE)]; if (length(to_install)) install.packages(to_install, repos='https://cloud.r-project.org')"

    Write-Host ""
    Write-Host "== Tests (testthat) =="
    & $rscript -e "devtools::test()"

    Write-Host ""
    Write-Host "== Lint (lintr) =="
    & $rscript -e "print(lintr::lint_package())"

    Write-Host ""
    Write-Host "== Formatage (styler, verification) =="
    & $rscript -e "res <- styler::style_pkg(dry='on'); changed <- res\$changed; if (any(changed)) { cat('Fichiers a reformater :\n'); print(res\$file[changed]) } else cat('Formatage conforme.\n')"

    Write-Host ""
    Write-Host "== Couverture (covr) =="
    & $rscript -e "cov <- covr::package_coverage(); print(cov); cat(sprintf('Couverture totale : %.1f%%\n', covr::percent_coverage(cov)))"
}
finally {
    Pop-Location
}
