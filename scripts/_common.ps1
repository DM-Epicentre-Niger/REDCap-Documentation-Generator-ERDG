# Fonctions communes aux scripts ERDG.

function Find-Rscript {
    # Cherche Rscript sur le PATH, puis dans C:\Program Files\R (version la plus recente).
    $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $base = "C:\Program Files\R"
    if (Test-Path $base) {
        $dirs = Get-ChildItem $base -Directory | Sort-Object Name -Descending
        foreach ($d in $dirs) {
            $p = Join-Path $d.FullName "bin\Rscript.exe"
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}
