# Guide utilisateur

ERDG transforme un **Data Dictionary REDCap** (`.csv`) en documents Word, Excel
et PDF. Le Data Dictionary est la **source unique de vérité**.

## 1. Valider le Data Dictionary

```powershell
.\scripts\redcap-doc.ps1 validate input\MonDataDictionary.csv
```

Produit un résumé console + un rapport Markdown et JSON (erreurs / avertissements).

## 2. Générer un document

```powershell
.\scripts\redcap-doc.ps1 build <document> input\MonDataDictionary.csv --output output [--config config.yml] [--pdf]
```

Documents disponibles : `terrain`, `monitoring`, `dictionary`, `specification`,
`interviewer-manual`, `monitoring-manual`, `branching`, `calculations`.

Exemple :

```powershell
.\scripts\redcap-doc.ps1 build terrain input\MonDataDictionary.csv --output output --pdf
```

## 3. Générer TOUT un projet en une commande

Organisez un dossier projet :

```
mon_projet/
  config.yml
  input/   (UN seul .csv)
  output/
```

Puis :

```powershell
.\scripts\redcap-doc.ps1 build-project mon_projet --pdf
```

Les documents sont rangés par sous-dossier (`terrain/`, `monitoring/`, …).

## 4. Comparer deux versions

```powershell
.\scripts\redcap-doc.ps1 compare ancien.csv nouveau.csv --output comparison
```

Rapport Word + Excel + JSON, changements classés **CRITIQUE → INFORMATION**.

## 5. Convertir en PDF

```powershell
.\scripts\redcap-doc.ps1 pdf output --output output\pdf
```

Convertit tous les `.docx` d'un dossier (ou un fichier). Les `.docx` sont conservés.

## 6. Interface graphique

```powershell
.\scripts\redcap-doc.ps1 gui
```

Ouvre une fenêtre (navigateur) pour choisir le fichier, les documents et lancer
la génération, avec validation, journal et barre de progression.

## Configuration (YAML)

Voir [`projects/MDF/config.yml`](../projects/MDF/config.yml). Points clés :

- `project.study_name`, `project.version`, `project.confidentiality` — apparaissent
  dans les documents ;
- `instruments:` — libellés lisibles (accentués) des formulaires REDCap, dont le
  nom d'origine est un slug sans accents ;
- `terrain:` — options d'affichage (codes, notes, seuil des listes longues…) ;
- `output.create_subfolders`, `output.pdf` ;
- `build.documents` — liste des documents produits par `build-project`.

## Rappels importants

- Aucune règle clinique n'est inventée : le contenu à confirmer est marqué
  **`[À VALIDER PAR L'ÉQUIPE ÉTUDE]`**.
- Le CRF Terrain ne contient **aucun** nom de variable ni syntaxe REDCap.
- Les fichiers source ne sont **jamais** modifiés.
