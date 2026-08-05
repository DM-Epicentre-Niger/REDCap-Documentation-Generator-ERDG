# Guide d'exécution pas à pas

Ce guide vous accompagne **du début à la fin** : de l'installation jusqu'à la
génération de tous vos documents, sous Windows. Aucune connaissance de R n'est
nécessaire.

> 💡 Toutes les commandes se lancent dans **PowerShell**, depuis le dossier
> racine du projet ERDG (celui qui contient le dossier `scripts\`).

---

## Étape 0 — Installer les prérequis (une seule fois)

1. **R** (moteur du logiciel) : télécharger et installer depuis
   <https://cran.r-project.org/bin/windows/base/> (version 4.4 recommandée).
2. **LibreOffice** (pour l'export PDF, facultatif mais recommandé) :
   <https://www.libreoffice.org/download/>.

> Pas besoin de configurer le PATH : ERDG retrouve R et LibreOffice tout seul.

## Étape 1 — Récupérer ERDG

**Option A — archive de distribution** (`ERDG_x.y.z_windows.zip`) :
décompressez-la où vous voulez (ex. `D:\ERDG`).

**Option B — dépôt Git** :

```powershell
git clone https://github.com/SOGA-AFRICA/REDCap-Documentation-Generator-ERDG.git
cd "REDCap-Documentation-Generator-ERDG"
```

## Étape 2 — Installer le logiciel

Dans PowerShell, depuis le dossier du projet :

```powershell
.\scripts\install_windows.ps1
```

Le script trouve R, installe les dépendances et le package. **Patientez** (la
première installation peut prendre quelques minutes).

## Étape 3 — Vérifier que tout est prêt

```powershell
.\scripts\redcap-doc.ps1 doctor
```

Vous devez voir la version de R, une liste de packages en ✔ vert, et le statut
des dossiers. Si un package est en rouge, relancez l'étape 2.

## Étape 4 — Préparer votre Data Dictionary

Dans REDCap : **Project Setup → Data Dictionary → Download the current Data
Dictionary (CSV)**. Vous obtenez un fichier `.csv`.

Placez-le dans un dossier de travail, par exemple `input\MonEtude.csv`.

## Étape 5 — Valider le Data Dictionary

```powershell
.\scripts\redcap-doc.ps1 validate input\MonEtude.csv
```

- Affiche un résumé : nombre d'instruments, de variables, d'**erreurs** et
  d'**avertissements**.
- Écrit aussi un rapport Markdown et JSON.

👉 **Corrigez d'abord les ERREURS** dans REDCap si possible ; les avertissements
sont informatifs.

## Étape 6 — Générer un premier document

Exemple : le CRF Terrain, avec le PDF, dans un dossier `output` :

```powershell
.\scripts\redcap-doc.ps1 build terrain input\MonEtude.csv --output output --pdf
```

Ouvrez le `.docx` (et le `.pdf`) créés dans `output\`.

Documents disponibles à la place de `terrain` :
`monitoring`, `dictionary`, `specification`, `interviewer-manual`,
`monitoring-manual`, `branching`, `calculations`.

## Étape 7 — Générer TOUT en une seule commande (recommandé)

### 7.1 Organiser un dossier projet

Créez cette structure :

```
MonProjet\
  input\        (mettez-y UN SEUL fichier .csv)
  output\       (sera rempli automatiquement)
  config.yml    (facultatif — voir étape 9)
```

### 7.2 Lancer

```powershell
.\scripts\redcap-doc.ps1 build-project MonProjet --pdf
```

Tous les documents sont générés et rangés dans `MonProjet\output\` par
sous-dossier (`terrain\`, `monitoring\`, `dictionary\`, `specification\`,
`manuals\`, `guides\`), avec leurs PDF.

## Étape 8 — Comparer deux versions du Data Dictionary

Très utile avant un déploiement :

```powershell
.\scripts\redcap-doc.ps1 compare ancienne_version.csv nouvelle_version.csv --output comparaison
```

Produit un rapport **Word + Excel + JSON** listant les changements classés de
**CRITIQUE** à **INFORMATION** (variables supprimées, choix recodés, formules
modifiées, etc.). Vos fichiers ne sont **jamais modifiés**.

## Étape 9 — Personnaliser (configuration)

Copiez le modèle `inst\extdata\config.example.yml` en `config.yml` dans votre
dossier projet et adaptez, notamment :

- `project.study_name`, `project.version`, `project.confidentiality` (affichés
  dans les documents) ;
- `instruments:` — **libellés lisibles** de vos formulaires. REDCap enlève les
  accents des noms de formulaires ; renseignez ici le vrai libellé, par exemple :

  ```yaml
  instruments:
    p01a_evaluation_dligibilit: "P01a — Évaluation d'éligibilité"
  ```

Puis relancez `build-project` : titres et noms de fichiers utiliseront ces
libellés.

## Étape 10 — Convertir des Word déjà générés en PDF

```powershell
.\scripts\redcap-doc.ps1 pdf output --output output\pdf
```

Convertit tous les `.docx` d'un dossier (les `.docx` sont conservés).

## Étape 11 — Interface graphique (sans ligne de commande)

```powershell
.\scripts\redcap-doc.ps1 gui
```

Une fenêtre s'ouvre dans votre navigateur : choisissez le fichier, cochez les
documents, cliquez **GÉNÉRER**. Validation, journal et barre de progression
inclus. Fermez l'onglet pour quitter.

---

## Dépannage rapide

| Problème | Solution |
|---|---|
| « Rscript introuvable » | Installer R (étape 0) puis relancer. |
| Un package en rouge dans `doctor` | Relancer `.\scripts\install_windows.ps1`. |
| PDF non généré | Installer LibreOffice ; les `.docx` restent produits. |
| « Plusieurs fichiers CSV trouvés » | Ne laisser **qu'un** `.csv` dans `input\`. |
| Un « NativeCommandError » rouge sous PowerShell | Artefact d'affichage (la librairie d'affichage écrit sur stderr) ; **la génération a bien réussi**. |
| Accents bizarres dans un document | Ouvrir avec Word ou LibreOffice récents (fichiers en UTF-8). |

## Pour aller plus loin

- [Guide utilisateur](GUIDE_UTILISATEUR.md) — référence des commandes et options.
- [Installation Windows](INSTALLATION_WINDOWS.md) — détails d'installation.
- [Limites connues](LIMITES_CONNUES.md) — ce que l'outil ne fait pas (encore).
