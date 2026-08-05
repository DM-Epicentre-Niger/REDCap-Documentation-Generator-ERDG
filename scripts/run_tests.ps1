# Execute la suite de tests d'ERDG (testthat).
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
    & $rscript -e "if (!requireNamespace('devtools', quietly=TRUE)) install.packages('devtools', repos='https://cloud.r-project.org'); devtools::test()"
}
finally {
    Pop-Location
}
