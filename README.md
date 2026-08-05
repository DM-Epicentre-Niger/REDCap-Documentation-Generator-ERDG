# REDCap Documentation Generator (ERDG)

[![R-CMD-check](https://github.com/SOGA-AFRICA/REDCap-Documentation-Generator-ERDG/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SOGA-AFRICA/REDCap-Documentation-Generator-ERDG/actions/workflows/R-CMD-check.yaml)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![R](https://img.shields.io/badge/R-%E2%89%A5%204.3-1f65cc.svg)](https://cran.r-project.org/)
[![Tests](https://img.shields.io/badge/tests-64%20passing-brightgreen.svg)](tests/testthat)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Package **R** qui transforme un *Data Dictionary* REDCap (`.csv`) en un ensemble
> de documents **Word, Excel et PDF**. Le Data Dictionary est la **source unique
> de vérité** ; aucune règle clinique n'est inventée.

---

## ✨ Documents produits

| Document | Public | Format |
|---|---|---|
| **CRF Terrain** | Enquêteurs / terrain (sans nom de variable ni syntaxe REDCap) | Word / PDF |
| **CRF Monitoring** | Data managers / moniteurs (tableau technique) | Word / PDF |
| **Data Dictionary lisible** | Tous | Word + Excel |
| **Data Collection Specification** | Audit (empreinte SHA-256) | Word / PDF |
| **Manuel enquêteur** · **Manuel de monitoring** | Terrain / monitoring | Word / PDF |
| **Guide Branching Logic** · **Guide des calculs** | Programmeurs REDCap | Word / PDF |
| **Rapport de comparaison** de deux versions | Data management | Word + Excel + JSON |

## 🚀 Démarrage rapide

```powershell
# Installation (Windows)
.\scripts\install_windows.ps1

# Diagnostic
.\scripts\redcap-doc.ps1 doctor

# Générer un document
.\scripts\redcap-doc.ps1 build terrain input\DataDictionary.csv --output output --pdf

# Tout un projet en une commande
.\scripts\redcap-doc.ps1 build-project mon_projet --pdf

# Comparer deux versions
.\scripts\redcap-doc.ps1 compare ancien.csv nouveau.csv --output comparison

# Interface graphique
.\scripts\redcap-doc.ps1 gui
```

Un exemple de Data Dictionary est fourni dans
[`inst/extdata/sample_data_dictionary.csv`](inst/extdata/sample_data_dictionary.csv)
et un modèle de configuration dans
[`inst/extdata/config.example.yml`](inst/extdata/config.example.yml).

## 📦 Prérequis

- **R 4.4+** (fonctionne aussi sous R 4.3.x).
- Pour l'export **PDF** : **LibreOffice** (détecté automatiquement).

## 📚 Documentation

- [Guide utilisateur](docs/GUIDE_UTILISATEUR.md)
- [Installation Windows](docs/INSTALLATION_WINDOWS.md)
- [Guide développeur](docs/GUIDE_DEVELOPPEUR.md)
- [Limites connues](docs/LIMITES_CONNUES.md)
- [Changelog](CHANGELOG.md)

## 🧪 Développement

```powershell
.\scripts\run_tests.ps1     # tests testthat
.\scripts\run_checks.ps1    # tests + lintr + styler + couverture
```

Architecture (package R, sources à plat dans `R/`) : `parser → services →
generators → exporters`. Voir le [guide développeur](docs/GUIDE_DEVELOPPEUR.md).

## 🔒 Principes

- Le Data Dictionary REDCap est l'**unique source de vérité**.
- Aucune règle clinique, source ou criticité inventée : le contenu à confirmer
  est marqué **`[À VALIDER PAR L'ÉQUIPE ÉTUDE]`**.
- Les fichiers source ne sont **jamais modifiés** ; lors d'une comparaison, le
  nouveau Data Dictionary n'est **jamais remplacé**.

## 📄 Licence

[MIT](LICENSE) © Souna Garba Soumana
