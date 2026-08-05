# Changelog

Toutes les évolutions notables de **redcapdocgen** (ERDG).

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/).

## [1.0.0] - 2026-08-05

Première version stable.

### Ajouté

- **Moteur** : lecture robuste du Data Dictionary REDCap (détection d'encodage
  et de séparateur, normalisation des colonnes, regroupement par instrument) et
  validation structurée à trois niveaux (ERROR / WARNING / INFO).
- **Générateurs Word/Excel** :
  - CRF Terrain (sans nom de variable ni syntaxe REDCap) ;
  - CRF Monitoring (tableau technique 4 colonnes) ;
  - Data Dictionary lisible (Word + Excel, feuilles thématiques) ;
  - Data Collection Specification (audit-ready, empreinte SHA-256) ;
  - Manuel enquêteur et Manuel de monitoring ;
  - Guide des Branching Logic (traduction lisible) et Guide des calculs
    (détection de risques).
- **Comparaison** de deux versions d'un Data Dictionary (Word + Excel + JSON,
  classification CRITIQUE → INFORMATION).
- **Export PDF** des documents Word via LibreOffice (`.docx` conservé).
- **Projets** : commande `build-project` (génération complète en une commande,
  sorties rangées par sous-dossier) et configuration YAML par projet (dont la
  table de correspondance des libellés d'instruments).
- **Interface graphique** Shiny locale (`redcap-doc gui`).
- **Ligne de commande** complète (`doctor`, `validate`, `build`, `compare`,
  `build-project`, `pdf`, `gui`) et scripts Windows PowerShell.
- **Qualité** : suite de tests testthat, configuration lintr/styler, hooks
  pre-commit et workflow CI (GitHub Actions).

### Principes respectés

- Le Data Dictionary REDCap est l'unique source de vérité.
- Aucune règle clinique, protocolaire ou de monitoring inventée : le contenu non
  déductible est marqué `[À VALIDER PAR L'ÉQUIPE ÉTUDE]`.
- Les fichiers source ne sont jamais modifiés ; le nouveau Data Dictionary n'est
  jamais remplacé lors d'une comparaison.
