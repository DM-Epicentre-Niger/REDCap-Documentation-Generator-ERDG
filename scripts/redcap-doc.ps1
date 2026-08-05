# Wrapper ERDG : appelle la ligne de commande R.
# Exemple : .\scripts\redcap-doc.ps1 doctor
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

$root  = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $root "inst\scripts\redcap-doc.R"

$rscript = Find-Rscript
if (-not $rscript) {
    Write-Error "Rscript introuvable. Installez R 4.4+ depuis https://cran.r-project.org/."
    exit 1
}

& $rscript $entry @args
exit $LASTEXITCODE
