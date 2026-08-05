# Installation d'ERDG sous Windows.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

$root = Split-Path -Parent $PSScriptRoot

$rscript = Find-Rscript
if (-not $rscript) {
    Write-Error "Rscript introuvable. Installez R 4.4+ depuis https://cran.r-project.org/."
    exit 1
}
Write-Host "Rscript : $rscript"

Push-Location $root
try {
    Write-Host "1/2 - Restauration des dependances (renv)..."
    & $rscript -e "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://cloud.r-project.org'); if (file.exists('renv.lock')) renv::restore(prompt=FALSE) else message('renv.lock absent : etape renv ignoree (a initialiser au Prompt 1).')"

    Write-Host "2/2 - Installation du package en local..."
    & $rscript -e "if (!requireNamespace('devtools', quietly=TRUE)) install.packages('devtools', repos='https://cloud.r-project.org'); devtools::install(quiet=TRUE, upgrade='never')"

    Write-Host ""
    Write-Host "Installation terminee. Commandes suivantes :"
    Write-Host "  .\scripts\redcap-doc.ps1 doctor"
    Write-Host "  .\scripts\run_tests.ps1"
}
finally {
    Pop-Location
}
