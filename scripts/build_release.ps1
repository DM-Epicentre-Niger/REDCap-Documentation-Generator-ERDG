# Construit l'archive de distribution ERDG (tar.gz + ZIP), sans donnee
# confidentielle ni fichier temporaire. Processus entierement scripte.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null

$R = Find-Rscript
if (-not $R) { Write-Error "Rscript introuvable."; exit 1 }
$Rexe = $R -replace "Rscript\.exe$", "R.exe"

# Version depuis DESCRIPTION.
$version = (Select-String -Path (Join-Path $root "DESCRIPTION") -Pattern '^Version:\s*(.+)$').Matches.Groups[1].Value.Trim()
Write-Host "Version : $version"

Push-Location $root
try {
    Write-Host "== Construction de l'archive source (.tar.gz) =="
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Rexe CMD build . --no-build-vignettes --no-manual 2>&1 | Out-Null
    $buildCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($buildCode -ne 0) { Write-Error "R CMD build a echoue (code $buildCode)."; exit 1 }
    $tar = "redcapdocgen_$version.tar.gz"
    Move-Item -Force $tar (Join-Path $dist $tar)
    Write-Host "  -> dist\$tar"

    # Assemblage du ZIP utilisateur.
    $stage = Join-Path $dist "staging"
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force $stage | Out-Null

    # Liste blanche : seuls ces elements entrent dans le ZIP.
    Copy-Item (Join-Path $dist $tar) $stage
    Copy-Item (Join-Path $root "README.md") $stage
    Copy-Item (Join-Path $root "CHANGELOG.md") $stage -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $root "LICENSE") $stage
    New-Item -ItemType Directory -Force (Join-Path $stage "scripts") | Out-Null
    Copy-Item (Join-Path $root "scripts\*.ps1") (Join-Path $stage "scripts")
    New-Item -ItemType Directory -Force (Join-Path $stage "docs") | Out-Null
    Copy-Item (Join-Path $root "docs\*.md") (Join-Path $stage "docs") -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force (Join-Path $stage "examples") | Out-Null
    Copy-Item (Join-Path $root "inst\extdata\sample_data_dictionary.csv") (Join-Path $stage "examples")
    # Configuration modele generique (aucune donnee projet reelle).
    Copy-Item (Join-Path $root "inst\extdata\config.example.yml") (Join-Path $stage "config.example.yml")

    # Verification anti-fuite : aucun contenu confidentiel MDF.
    $bad = Get-ChildItem $stage -Recurse -File | Where-Object {
        $_.FullName -match "MDF_DataDictionary" -or $_.FullName -match "\\output\\"
    }
    if ($bad) {
        Write-Error "Contenu confidentiel detecte dans le ZIP : $($bad.FullName -join ', ')"
        exit 1
    }

    $zip = Join-Path $dist "ERDG_$($version)_windows.zip"
    if (Test-Path $zip) { Remove-Item -Force $zip }
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
    Remove-Item -Recurse -Force $stage

    # Empreinte SHA-256 + inventaire.
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    "$hash  $(Split-Path $zip -Leaf)" | Out-File -Encoding ascii "$zip.sha256"
    Write-Host ""
    Write-Host "== Livrable =="
    Write-Host "  ZIP    : $zip"
    Write-Host "  SHA256 : $hash"
    Write-Host "  Contenu :"
    Expand-Archive $zip -DestinationPath (Join-Path $dist "verify_tmp") -Force
    Get-ChildItem (Join-Path $dist "verify_tmp") -Recurse -File | ForEach-Object {
        Write-Host ("    " + $_.FullName.Substring((Join-Path $dist 'verify_tmp').Length + 1) + " (" + [math]::Round($_.Length/1KB) + " Ko)")
    }
    Remove-Item -Recurse -Force (Join-Path $dist "verify_tmp")
}
finally {
    Pop-Location
}
