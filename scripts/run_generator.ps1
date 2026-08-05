# Genere les documents du projet MDF (CRF Terrain, CRF Monitoring, Data
# Dictionary) en utilisant la configuration MDF (libelles accentues + study_name).
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

$root  = Split-Path -Parent $PSScriptRoot
$entry = Join-Path $root "inst\scripts\redcap-doc.R"

$rscript = Find-Rscript
if (-not $rscript) {
    Write-Error "Rscript introuvable. Installez R 4.4+ depuis https://cran.r-project.org/."
    exit 1
}

$csv = Join-Path $root "projects\MDF\input\MDF_DataDictionary.csv"
$cfg = Join-Path $root "projects\MDF\config.yml"

if (-not (Test-Path $csv)) {
    Write-Error "Data Dictionary introuvable : $csv"
    exit 1
}

Write-Host "== CRF Terrain =="
& $rscript $entry build terrain $csv "--config=$cfg" "--output=$(Join-Path $root 'projects\MDF\output\terrain')"

Write-Host "== CRF Monitoring =="
& $rscript $entry build monitoring $csv "--config=$cfg" "--output=$(Join-Path $root 'projects\MDF\output\monitoring')"

Write-Host "== Data Dictionary (Word + Excel) =="
& $rscript $entry build dictionary $csv "--format=all" "--config=$cfg" "--output=$(Join-Path $root 'projects\MDF\output\dictionary')"

Write-Host ""
Write-Host "Termine. Sorties dans projects\MDF\output\."
