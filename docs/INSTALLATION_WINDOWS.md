# Installation sous Windows

## Prérequis

- **R 4.4+** (fonctionne aussi sous R 4.3.x) — https://cran.r-project.org/
- Pour l'export **PDF** : **LibreOffice** (recommandé) — https://www.libreoffice.org/
  (MS Word peut aussi convenir, mais LibreOffice est plus robuste sur les chemins
  contenant des espaces).

> `soffice` n'a pas besoin d'être sur le PATH : ERDG le détecte automatiquement
> dans `C:\Program Files\LibreOffice\program\`.

## Installation du package

Depuis la racine du projet, dans PowerShell :

```powershell
.\scripts\install_windows.ps1
```

Le script localise `Rscript`, restaure les dépendances (renv si présent) et
installe le package en local.

Installation manuelle équivalente :

```powershell
Rscript -e "if (!requireNamespace('devtools', quietly=TRUE)) install.packages('devtools'); devtools::install()"
```

## Vérification

```powershell
.\scripts\redcap-doc.ps1 doctor
```

Affiche la version de R, les packages clés et le statut des dossiers de travail.

## Dépannage

- **« Rscript introuvable »** : installez R, ou vérifiez `C:\Program Files\R\`.
- **PDF non généré** : installez LibreOffice ; les `.docx` restent produits.
- **Accents illisibles** : les fichiers sont en UTF-8 ; ouvrez-les avec Word ou
  LibreOffice récents.
- **La CLI affiche un « NativeCommandError » sous PowerShell** : c'est un artefact
  (la librairie `cli` écrit sur stderr) ; la génération réussit tout de même.
