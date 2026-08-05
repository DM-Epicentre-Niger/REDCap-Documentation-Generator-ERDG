# REDCap Documentation Generator (ERDG)

Package **R** qui transforme un *Data Dictionary* REDCap (`.csv`) en un ensemble
de documents Word, Excel et PDF. Le Data Dictionary est la **source unique de
vérité**.

> **Version 1.0.0** — fonctionnelle. Voir [CHANGELOG.md](CHANGELOG.md), le
> [guide utilisateur](docs/GUIDE_UTILISATEUR.md) et les
> [limites connues](docs/LIMITES_CONNUES.md).

## Documents produits

CRF Terrain · CRF Monitoring · Data Dictionary lisible (Word/Excel) · Data
Collection Specification · Manuel enquêteur · Manuel de monitoring · Branching
Logic Guide · Calculations Guide · Rapport de comparaison entre deux versions ·
Export PDF.

## Commandes

```text
redcap-doc doctor
redcap-doc validate <csv>
redcap-doc build <document> <csv> [--output=<dir>] [--config=<yml>] [--pdf]
redcap-doc compare <old.csv> <new.csv> [--output=<dir>]
redcap-doc build-project <dossier_projet> [--pdf]
redcap-doc pdf <docx_ou_dossier> [--output=<dir>]
redcap-doc gui
```

## Prérequis

- **R 4.4+** (recommandé ; fonctionne aussi sous R 4.3.x).
- Windows. Pour l'export PDF (V5) : **LibreOffice** (recommandé) ou MS Word.

## Installation (Windows)

```powershell
.\scripts\install_windows.ps1
```

Le script localise `Rscript`, restaure les dépendances (renv si présent) et
installe le package en local.

## Utilisation

```powershell
# Diagnostic de l'environnement
.\scripts\redcap-doc.ps1 doctor

# Aide
.\scripts\redcap-doc.ps1 --help
```

Sans PowerShell, en appelant directement Rscript :

```bash
Rscript inst/scripts/redcap-doc.R doctor
```

Commandes prévues (non encore actives dans le squelette) :

```text
redcap-doc validate <csv>
redcap-doc build <document> <csv> [--output=<dir>] [--config=<yml>] [--pdf]
redcap-doc compare <old.csv> <new.csv> [--output=<dir>]
redcap-doc build-project <project_dir>
redcap-doc gui
```

## Tests

```powershell
.\scripts\run_tests.ps1
```

## Structure

Package R standard : les sources sont à plat dans `R/`, organisées par préfixe
(`domain-*`, `parser-*`, `service-*`, `generator-*`, `exporter-*`). Voir la
section Architecture de [`ERDG_PROMPTS_R.md`](ERDG_PROMPTS_R.md).

## Confidentialité

Les données réelles (ex. essai MDF) vont dans `projects/MDF/input/` et
`projects/MDF/output/`, **exclues de git** (`.gitignore`). Elles ne doivent
jamais figurer dans les fixtures, les tests ni l'archive de distribution.

## Licence

MIT — voir [`LICENSE`](LICENSE).
