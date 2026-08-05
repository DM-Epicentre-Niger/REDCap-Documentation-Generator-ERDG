# ERDG — Epicentre REDCap Documentation Generator (version R)

Référence complète des prompts à passer à Codex, dans l'ordre, pour développer
le projet **en R** (package R idiomatique, et non un script monolithique).

- Cible : **R 4.4+** (le squelette fonctionne aussi sous R 4.3.x), **Windows**.
- Unité de projet : **un package R** nommé `redcapdocgen`.

---

## 1. Correspondance des technologies Python → R

| Besoin | Python (plan initial) | R (équivalent retenu) |
|---|---|---|
| Langage | Python 3.12+ | **R 4.4+** |
| Word (.docx) | python-docx | **officer** + **flextable** |
| Templates | Jinja2 | modèle `.docx` via `officer::read_docx()` + **glue** |
| Données tabulaires | pandas | **readr** + **dplyr** / data.table |
| Excel (.xlsx) | openpyxl | **openxlsx** |
| PDF | reportlab | **doconv::docx2pdf()** (LibreOffice/Word) |
| CLI | Typer | **docopt** + **cli** |
| Console riche | Rich | **cli** |
| GUI | PySide6 | **shiny** (appli locale) + **bslib** |
| Modèles / validation | pydantic + dataclasses | **R6** + **checkmate** |
| Tests | pytest | **testthat** (3e édition) |
| Couverture | pytest-cov | **covr** |
| Lint / format | ruff / mypy | **lintr** + **styler** |
| Hooks | pre-commit | package **precommit** |
| YAML | PyYAML | **yaml** |
| Hash SHA-256 | hashlib | **digest** |
| Encodage CSV | chardet | **readr::guess_encoding()** (stringi) |
| JSON | json | **jsonlite** |

Décisions par défaut :
- **GUI = Shiny local** (réutilise les fonctions de service, multiplateforme).
- **PDF = conversion du .docx** via `doconv` (nécessite **LibreOffice** ou MS Word).

---

## 2. Architecture cible (package R)

En R, tous les fichiers source sont **à plat dans `R/`** : on simule les couches
par des préfixes de nommage.

```
redcapdocgen/
  DESCRIPTION
  NAMESPACE                 # généré par roxygen2
  .Rbuildignore
  .gitignore
  R/
    domain-project.R        # classes R6
    domain-instrument.R
    domain-field.R
    domain-choice.R
    domain-validation.R
    domain-branching.R
    parser-datadictionary.R
    service-loader.R
    service-validator.R
    service-choice.R
    service-branching.R
    service-calculation.R
    generator-terrain.R
    generator-monitoring.R
    generator-dictionary.R
    generator-specification.R
    generator-interviewer-manual.R
    generator-monitoring-manual.R
    generator-branching-guide.R
    generator-calculations-guide.R
    generator-compare.R
    exporter-docx.R
    exporter-xlsx.R
    exporter-pdf.R
    template-styles.R
    template-components.R
    util-paths.R
    util-text.R
    util-logging.R
    cli.R
    gui.R
  inst/
    scripts/redcap-doc.R
    templates/
    extdata/sample_data_dictionary.csv
  tests/testthat/
  man/
  projects/MDF/{input,output}/
  docs/
  scripts/                  # scripts Windows PowerShell
  README.md
```

Règle de dépendance : `parser → domain → services → generators → exporters`.
Les générateurs ne lisent jamais le CSV ; les exporteurs ne contiennent aucune
logique REDCap.

---

## 3. Ordre d'exécution des prompts

| Étape | Prompt |
|---|---|
| Fondation | **INIT** (squelette package) |
| V1 – Moteur | 0 (audit) → 1 (env) → 2 (archi) → 3 (parser) |
| V2 – Générateurs | 4 (terrain) → 5 (monitoring) → 6 (dictionary) → 7 (specification) |
| V3 – Manuels | 8 (enquêteur) → 9 (monitoring) → 10 (branching + calculs) |
| V4 – Interface | **V4-GUI** (Shiny enrichi) |
| V5 – Avancé | 11 (comparaison) → **PDF** → 13 (config MDF) |
| Qualité/Release | 14 (tests) → 15 (release) → **DIST** (packaging) |
| Toutes sessions | Prompt de supervision (à coller en tête) |

---

## PROMPT INIT — Squelette du package R (à passer en premier)

```
Tu démarres un nouveau projet R vide (ou presque vide). Objectif : créer un
squelette de package R propre et installable, SANS logique métier pour l'instant.
C'est la fondation ; ne code aucune fonctionnalité de génération.

Nom du package : redcapdocgen
Titre : Epicentre REDCap Documentation Generator (ERDG)
Cible : R 4.4+, Windows.

Travail demandé :

1. Créer la structure standard d'un package R :
   redcapdocgen/
     DESCRIPTION
     NAMESPACE            (généré par roxygen2, ne pas écrire à la main)
     .Rbuildignore
     .gitignore
     R/
     man/
     tests/testthat/
     tests/testthat.R
     inst/scripts/
     inst/templates/
     inst/extdata/
     projects/MDF/input/
     projects/MDF/output/
     docs/
     scripts/
     README.md

2. Rédiger DESCRIPTION avec :
   Package: redcapdocgen
   Version: 0.1.0
   Title: Epicentre REDCap Documentation Generator (ERDG)
   Description: Génère de la documentation (Word, Excel, PDF) à partir d'un
     Data Dictionary REDCap.
   License: MIT + file LICENSE
   Encoding: UTF-8
   Roxygen: list(markdown = TRUE)
   RoxygenNote: (version courante)
   Imports:
     readr, dplyr, stringi, yaml, officer, flextable, openxlsx,
     docopt, cli, R6, checkmate, digest, glue, jsonlite
   Suggests:
     testthat (>= 3.0.0), covr, lintr, styler, shiny, bslib, doconv
   Config/testthat/edition: 3

3. Initialiser renv (renv::init()) et générer renv.lock à partir des Imports.
   Ajouter renv/library/ au .gitignore et .Rbuildignore.

4. Créer un fichier R/redcapdocgen-package.R contenant la doc du package
   (#' @keywords internal, "_PACKAGE") et les @importFrom nécessaires plus tard.
   Aucune library() dans le package : toujours pkg::fonction ou @importFrom.

5. Créer un squelette de dispatcher CLI :
   - R/cli.R : une fonction run_cli(args = commandArgs(TRUE)) qui, pour l'instant,
     reconnaît seulement la commande "doctor" et affiche un message cli, et
     renvoie une erreur claire (cli::cli_abort) pour toute commande inconnue.
     Prévoir la structure docopt (chaîne d'usage) listant les futures commandes :
     doctor, validate, build, compare, build-project, gui — même si elles ne
     sont pas encore implémentées (afficher "non encore implémenté").
   - inst/scripts/redcap-doc.R : charge le package (ou pkgload::load_all en dev)
     et appelle run_cli(). C'est le point d'entrée exécuté par Rscript.

6. Créer les scripts Windows PowerShell (chemins portables, pas de "\" en dur) :
   - scripts/install_windows.ps1
   - scripts/redcap-doc.ps1  (wrapper Rscript inst/scripts/redcap-doc.R <args>)
   - scripts/run_tests.ps1
   - scripts/run_generator.ps1

7. Ajouter un test testthat minimal (tests/testthat/test-smoke.R) qui vérifie
   que le package se charge et que run_cli("doctor") ne lève pas d'erreur.

8. Créer LICENSE (MIT) et README.md (but, installation Windows, commandes prévues).

9. Générer NAMESPACE et man/ via roxygen2::roxygenise().

Contraintes :
- Aucune logique métier (ni parser, ni générateur).
- R CMD check sans erreur (NOTES tolérées).
- Fichiers à plat dans R/, roxygen2 pour la doc.

À la fin : liste des fichiers créés ; résultat de devtools::test() ; résumé de
R CMD check ; commandes d'installation.
```

---

## PROMPT 0 — Audit du projet existant

```
Tu travailles dans le projet R actuellement ouvert.

Objectif : audit complet AVANT toute modification.

Contexte : ce projet doit devenir un générateur professionnel de documentation
REDCap (package R) à partir d'un Data Dictionary CSV. Il devra produire :
1. CRF Terrain ; 2. CRF Monitoring ; 3. Data Dictionary lisible ;
4. Data Collection Specification ; 5. Manuel enquêteur ; 6. Manuel de monitoring ;
7. guide des Branching Logic ; 8. guide des calculs REDCap ;
9. rapport de comparaison entre deux versions de Data Dictionary.

Consignes :
1. Inspecter tous les fichiers et dossiers (DESCRIPTION, NAMESPACE, R/, tests/,
   inst/ s'ils existent).
2. Identifier : point d'entrée actuel ; dépendances déclarées (Imports/Suggests) ;
   fonctions/classes existantes ; fonctionnalités déjà implémentées ; erreurs
   d'architecture ; fonctionnalités incomplètes ; risques de régression.
3. Ne supprimer aucun fichier. Ne modifier aucun code à cette étape.
4. Produire docs/AUDIT_INITIAL.md contenant : architecture actuelle ; fichiers
   importants ; dépendances R manquantes ; problèmes détectés ; fonctionnalités
   opérationnelles ; recommandations ; plan de migration progressif ; ordre
   conseillé des développements.

Important : ne prétends pas qu'une fonctionnalité existe sans l'avoir vérifiée
dans le code. Ne commence aucune réécriture avant la fin de l'audit.
```

---

## PROMPT 1 — Stabiliser l'environnement R

```
À partir de docs/AUDIT_INITIAL.md, stabilise l'environnement R du projet.

Objectifs : installation propre sous Windows avec R 4.4+ ; dépendances complètes ;
environnement reproductible.

Travail demandé :
1. Vérifier ou créer : DESCRIPTION, NAMESPACE (via roxygen2), .Rbuildignore,
   .gitignore, README.md.
2. Déclarer les dépendances au minimum :
   Imports : readr, dplyr, stringi, yaml, officer, flextable, openxlsx,
             docopt, cli, R6, checkmate, digest, glue, jsonlite.
   Suggests : testthat, covr, lintr, styler, shiny, bslib, doconv.
3. Utiliser renv pour figer les versions (renv::init(), renv.lock).
4. Ajouter un point d'entrée exécutable : inst/scripts/redcap-doc.R (docopt).
5. Lancement via : Rscript inst/scripts/redcap-doc.R <commande>
6. Ajouter les scripts Windows : scripts/install_windows.ps1,
   scripts/run_generator.ps1, scripts/run_tests.ps1, scripts/redcap-doc.ps1.
7. Le script d'installation : initialise/restaure renv ; installe le package en
   local ; affiche les commandes suivantes.
8. Corriger tous les avertissements de chemins Windows (file.path(),
   normalizePath(), jamais de "\" en dur).
9. Ajouter la commande de diagnostic : redcap-doc doctor
   qui affiche : version de R ; chemin de R ; packages clés et versions ;
   répertoire courant ; statut des dossiers input, output, templates.

Contraintes : ne pas réécrire la logique métier ; préserver l'existant ; exécuter
les tests ou créer un smoke test (testthat) ; documenter les commandes dans README.

À la fin : fichiers modifiés ; commandes d'installation ; résultat du smoke test.
```

---

## PROMPT 2 — Architecture métier (package R)

```
Refactorise progressivement le projet vers une architecture modulaire R.

Rappel R : fichiers à plat dans R/, couches simulées par préfixes de nommage.
Architecture cible :

R/
  domain-project.R / domain-instrument.R / domain-field.R / domain-choice.R /
  domain-validation.R / domain-branching.R      (classes R6)
  parser-datadictionary.R
  service-loader.R / service-validator.R / service-choice.R /
  service-branching.R / service-calculation.R
  generator-terrain.R / generator-monitoring.R / generator-dictionary.R /
  generator-specification.R / generator-interviewer-manual.R /
  generator-monitoring-manual.R / generator-branching-guide.R /
  generator-calculations-guide.R
  exporter-docx.R / exporter-xlsx.R
  template-styles.R / template-components.R
  util-paths.R / util-text.R / util-logging.R
  cli.R
tests/testthat/    inst/templates/    inst/extdata/

Contraintes :
1. Préserver la compatibilité avec le fonctionnement actuel.
2. Classes R6 (champs typés + méthodes), validées à la construction avec checkmate :
   Project, Instrument, Field, Choice, Validation, BranchingLogic, Calculation.
3. Les générateurs ne lisent jamais le CSV directement.
4. Le CSV est transformé en modèle métier interne (objets R6).
5. Les exporteurs (officer/openxlsx) ne contiennent aucune logique REDCap.
6. Modules idéalement < 400 lignes.
7. Documenter chaque fonction/classe avec roxygen2, puis régénérer NAMESPACE et
   man/ via roxygen2::roxygenise().
8. Ne pas supprimer les anciens modules avant que les nouveaux soient testés.

Créer docs/ARCHITECTURE.md : couches ; responsabilités ; flux des données ;
règles de dépendance ; procédure pour ajouter un nouveau générateur.

Exécuter les tests (testthat) après le refactoring.
```

---

## PROMPT 3 — Parser fiable du Data Dictionary REDCap

```
Implémente un parser robuste du Data Dictionary REDCap CSV (source de vérité).

Colonnes REDCap standard à reconnaître :
Variable / Field Name ; Form Name ; Section Header ; Field Type ; Field Label ;
Choices, Calculations, OR Slider Labels ; Field Note ;
Text Validation Type OR Show Slider Number ; Text Validation Min ;
Text Validation Max ; Identifier? ; Branching Logic ; Required Field? ;
Custom Alignment ; Question Number ; Matrix Group Name ; Matrix Ranking? ;
Field Annotation.

Fonctionnalités :
1. Détection d'encodage via readr::guess_encoding() ; gérer UTF-8, UTF-8 BOM,
   Windows-1252.
2. Détection du séparateur (virgule vs point-virgule) via l'en-tête.
3. Lecture avec readr::read_delim (col_types = cols(.default = "c")).
4. Normalisation des noms de colonnes (snake_case), texte des valeurs conservé.
5. Gérer les champs vides.
6. Types : text, notes, radio, dropdown, checkbox, yesno, truefalse, calc,
   descriptive, file, slider, sql, matrix.
7. Parser les choix "1, Oui | 0, Non" (séparateur |, code + libellé).
8. Parser checkbox ; conserver tous les codes.
9. Lire validations min/max, obligatoires, identifiants, calculs, logiques.
10. Regrouper par instrument en CONSERVANT l'ordre d'origine.

Validation à trois niveaux : ERROR, WARNING, INFO. Retour en data.frame
(level, code, variable, message). Détecter : variable dupliquée ; formulaire vide ;
type inconnu ; choix mal formé ; min > max ; variable référencée absente ;
matrice sans groupe ; champ obligatoire calculé inhabituel.

Commande : redcap-doc validate input/MDF_DataDictionary.csv
-> résumé console (cli) ; rapport Markdown ; rapport JSON (jsonlite).

Tests testthat avec plusieurs CSV de fixtures. Ne jamais corriger silencieusement.
```

---

## PROMPT 4 — Générateur du CRF Terrain

```
Implémente le générateur du CRF Terrain en Word (.docx) avec officer + flextable.

Public : infirmiers, enquêteurs, équipes terrain.
Principes : épuré ; facile à compléter ; imprimable en noir et blanc ; AUCUNE
syntaxe REDCap, AUCUN nom de variable, AUCUNE formule, AUCUNE logique technique
visible. Uniquement questions, réponses, instructions et alertes utiles.

Structure :
1. Un document par instrument. 2. A4 portrait.
3. En-tête (configurable) : organisation ; étude ; instrument ; version ; date ;
   confidentialité.
4. Pied de page : étude ; version ; Page X / Y.
5. Chaque section dans un tableau flextable indépendant.
6. Deux colonnes : Question 45 % / Réponse 55 %.
7. Titre de section gris foncé ; en-tête de colonnes gris clair.
8. Police Arial ou Calibri (configurable) ; bordures simples homogènes.

Rendu par type :
- text : ligne de saisie ; date : __ / __ / ____ ; number : ligne + unité ;
- notes : zone multi-lignes ; radio : cases à cocher ; dropdown : cases/liste
  compacte ; checkbox : plusieurs cases ; yesno : ☐ Oui ☐ Non ;
  truefalse : ☐ Vrai ☐ Faux ;
- calc : zone grisée "Calcul automatique" si visible ;
- descriptive : instruction/alerte ; section header : nouvelle sous-section ;
  field note : petit texte sous la question si pertinent.

Conserver exactement : libellés ; codes de réponse si nécessaires ; unités ;
instructions terrain présentes dans le DD.

Listes longues (villages) : déplaçables en annexe ; le CRF garde un champ pour
saisir/sélectionner ; l'annexe présente Code + Libellé, regroupés par site/variable.

Configuration YAML :
terrain:
  show_response_codes: true
  move_long_choices_to_appendix: true
  long_choice_threshold: 15
  show_calculated_fields: true
  show_field_notes: true

Commande : redcap-doc build terrain input/MDF_DataDictionary.csv --output output

Tests testthat : générer le .docx, le rouvrir avec officer::read_docx(), vérifier
qu'il ne contient aucun nom de variable ni syntaxe REDCap.
```

---

## PROMPT 5 — Générateur du CRF Monitoring

```
Implémente le générateur du CRF Monitoring en Word (officer + flextable).

Public : data managers, moniteurs, programmeurs REDCap, statisticiens.
Un document par instrument. Tableau principal à 4 colonnes :
1. Variable REDCap ; 2. Question/libellé ; 3. Réponse attendue ;
4. Contrôles et notes de monitoring.

Colonne 4 (si disponible) : type ; validation ; min/max ; obligatoire ;
identifiant ; logique conditionnelle simplifiée ; calcul ; note de champ ;
annotation ; groupe de matrice ; points à vérifier.

Ne pas inventer de source document ni de règle clinique absente du DD.
- Calculés : afficher le calcul + "Valeur calculée automatiquement" + vérifier
  les variables sources.
- Conditionnels : "Afficher uniquement si …".
- Obligatoires : "Obligatoire".
- Listes longues : codes en annexe + renvoi.

Légende en début de document.
Commande : redcap-doc build monitoring input/MDF_DataDictionary.csv --output output

Tests testthat : champs calculés ; branching ; checkbox ; matrice ; validation
numérique ; date ; listes longues.
```

---

## PROMPT 6 — Data Dictionary lisible (Word + Excel)

```
Implémente la génération d'un Data Dictionary lisible en Word (officer) et Excel
(openxlsx).

Word : un chapitre par instrument. Colonnes : Ordre ; Variable ; Numéro de
question ; Libellé ; Type ; Choix ou calcul ; Validation ; Min ; Max ;
Obligatoire ; Identifiant ; Branching Logic ; Note ; Annotation.

Excel (feuilles) : 1. "Résumé" ; 2. une par instrument ; 3. "Variables calculées" ;
4. "Branching Logic" ; 5. "Validations" ; 6. "Choix" ; 7. "Identifiants" ;
8. "Problèmes détectés".

Feuille Résumé : nombre d'instruments ; de variables ; d'obligatoires ; de
calculés ; d'identifiants ; de logiques ; de matrices ; d'erreurs ;
d'avertissements.

Ne modifier aucun contenu du DD.

Commandes :
redcap-doc build dictionary input/MDF_DataDictionary.csv --format docx
redcap-doc build dictionary input/MDF_DataDictionary.csv --format xlsx
redcap-doc build dictionary input/MDF_DataDictionary.csv --format all
```

---

## PROMPT 7 — Data Collection Specification

```
Implémente la Data Collection Specification en Word (officer). Document technique,
complet, audit-ready.

Structure : 1. Page de garde. 2. Historique des versions. 3. Objectif.
4. Périmètre. 5. Source de vérité. 6. Conventions de nommage. 7. Résumé des
instruments. 8. Spécifications détaillées par instrument. 9. Logiques
conditionnelles. 10. Variables calculées. 11. Contrôles de validation.
12. Identifiants et données sensibles. 13. Matrices. 14. Annexes.

Par variable : instrument ; ordre ; nom ; numéro de question ; libellé ; type ;
choix codés ; format ; validation ; min ; max ; obligatoire ; identifiant ;
branching logic ; calcul ; annotation ; commentaire technique généré.

Commentaire factuel autorisé : "Champ obligatoire." / "Affiché conditionnellement."
/ "Valeur calculée automatiquement." / "Validation numérique avec limite minimale
et maximale." / "Choix multiples autorisés." Interdit : justification clinique,
source, règle de protocole inventées.

Ajouter date de génération + empreinte SHA-256 du CSV source
(digest::digest(file = ..., algo = "sha256")).

Commande : redcap-doc build specification input/MDF_DataDictionary.csv --output output
```

---

## PROMPT 8 — Manuel enquêteur

```
Implémente un Manuel enquêteur (Word, officer) généré depuis le Data Dictionary.

Attention : le DD ne suffit pas toujours. Distinguer trois catégories :
(1) info issue directement du DD ; (2) instruction générique déduite du type ;
(3) contenu nécessitant validation métier.

Par question : numéro ; libellé ; objectif (si déductible sans ambiguïté, sinon
"À compléter par l'équipe étude") ; manière de renseigner ; choix ; unité ;
format attendu ; condition d'affichage en langage simple ; message d'attention ;
erreurs fréquentes génériques ; note terrain.

Instructions génériques autorisées :
- Date : "Saisir la date au format jour/mois/année."
- Radio : "Sélectionner une seule réponse."
- Checkbox : "Plusieurs réponses peuvent être sélectionnées."
- Number : "Saisir uniquement une valeur numérique."
- Required : "Ce champ doit être renseigné."
- Calcul : "Ne pas saisir manuellement. La valeur est calculée par REDCap."

Marquer [À VALIDER PAR L'ÉQUIPE ÉTUDE] tout contenu absent du DD.
Ne jamais inventer d'instruction clinique.

Manuel global (et éventuellement un par instrument).
Commande : redcap-doc build interviewer-manual input/MDF_DataDictionary.csv --output output
```

---

## PROMPT 9 — Manuel de monitoring

```
Implémente le Manuel de monitoring (Word, officer). Aide le moniteur à vérifier la
cohérence entre CRF, REDCap et règles techniques.

Par variable : instrument ; variable ; question ; type ; valeur attendue ; code de
réponse ; obligatoire ; validation ; plage autorisée ; logique conditionnelle ;
calcul ; variables dépendantes ; statut identifiant ; contrôle de monitoring
proposé ; espace pour observations.

Contrôles UNIQUEMENT techniques : champ renseigné si obligatoire ; valeur dans
min/max ; champ visible seulement si condition satisfaite ; calcul cohérent avec
variables sources ; une seule option pour un radio ; réponses multiples pour un
checkbox ; format de date ; cohérence code/libellé.

Ne pas inventer : source document, fréquence SDV, criticité clinique, règle de
protocole.

Champ configurable (YAML) pour ajout manuel :
monitoring:
  source_document:
  sdv_required:
  critical_variable:
  custom_check:

Commande : redcap-doc build monitoring-manual input/MDF_DataDictionary.csv --output output
```

---

## PROMPT 10 — Guide Branching Logic + Guide des calculs

```
Implémente deux documents Word indépendants (officer).

DOCUMENT 1 — Branching Logic Guide. Par champ conditionnel : instrument ;
variable ; libellé ; logique REDCap originale ; variables référencées ; traduction
lisible ; statut de validation ; avertissements. Exemple : "[p1_naissance] = 1" ->
"Afficher ce champ uniquement si 'Date de naissance connue ?' = Oui." Si
l'expression est complexe et la traduction non fiable, afficher : "Expression
complexe — vérification manuelle requise."

DOCUMENT 2 — Calculations Guide. Par champ calculé : instrument ; variable ;
libellé ; formule REDCap ; variables sources ; description technique ; risque
éventuel ; statut de validation. Détecter : références vers variables absentes ;
division potentielle par zéro ; parenthèses déséquilibrées ; fonction inconnue ;
comparaison incohérente ; chaîne vide inhabituelle.

Commandes :
redcap-doc build branching input/MDF_DataDictionary.csv --output output
redcap-doc build calculations input/MDF_DataDictionary.csv --output output
```

---

## PROMPT V4-GUI — Interface graphique Shiny enrichie

```
Implémente l'interface graphique locale d'ERDG avec Shiny, lancée par :
redcap-doc gui  (shiny::runApp, ouvre le navigateur par défaut).

Règle d'or : l'UI ne contient AUCUNE logique métier. Elle appelle exactement les
mêmes fonctions de service que la CLI. Toute duplication est interdite.

Placement : R/gui.R (run_gui()). shiny, bslib restent dans Suggests : vérifier
requireNamespace au démarrage, sinon message cli clair. Les utilisateurs CLI seuls
ne doivent jamais être forcés d'installer Shiny.

Fonctionnalités :
1. Sélection du Data Dictionary CSV.
2. Sélection facultative d'un ANCIEN DD (comparaison).
3. Choix du dossier de sortie.
4. Sélection d'un YAML de configuration (facultatif ; sinon valeurs par défaut).
5. Cases des documents : CRF Terrain ; CRF Monitoring ; DD Word ; DD Excel ;
   Specification ; Manuel enquêteur ; Manuel monitoring ; Branching Guide ;
   Calculations Guide ; Rapport de comparaison (activable seulement si ancien DD).
6. Case globale "Générer aussi le PDF" (grisée si doconv indisponible).
7. Bouton "Valider le DD" : affiche le tableau ERROR/WARNING/INFO avec couleurs.
   Bloquer la génération si des ERROR existent (sauf case "malgré les
   avertissements" ; les WARNING n'empêchent jamais).
8. Bouton "GÉNÉRER" : barre de progression (withProgress/incProgress), un document
   à la fois, étape courante affichée.
9. Journal en direct : chaque fichier produit, succès/échec, chemin complet.
10. Bouton "Ouvrir le dossier de sortie" : Windows -> shell.exec(normalizePath(...)),
    fallback multiplateforme (utils::browseURL).
11. Sauvegarde/restauration des préférences en YAML local (rappdirs) : chemins,
    documents cochés, PDF, thème ; rechargées au démarrage.

Robustesse (forte) : l'appli ne se ferme JAMAIS silencieusement ; chaque appel de
service dans tryCatch -> showNotification(type="error") + journal, puis continuer ;
récapitulatif final réussis/échecs.

Thème : bslib (bs_theme) + toggle clair/sombre uniquement si trivial. Interface en
français.

Tests : ne pas tester le rendu Shiny complet ; tester les utilitaires hors session
(préférences YAML, construction de la liste des documents). testthat.

Documentation : section GUI dans docs/GUIDE_UTILISATEUR.md + README.

Note : Shiny n'a pas de sélecteur de dossier natif -> utiliser shinyFiles
(shinyDirButton) OU un champ texte de chemin.
```

---

## PROMPT 11 — Comparaison de deux versions

```
Implémente la comparaison entre deux Data Dictionary REDCap.
Commande : redcap-doc compare old.csv new.csv --output comparison

Produire : rapport Word (officer) ; Excel (openxlsx) ; JSON (jsonlite) ; résumé
console (cli).

Détecter : instruments ajoutés/supprimés/renommés ; variables ajoutées/supprimées/
déplacées ; noms modifiés (si identifiable) ; libellés modifiés ; types modifiés ;
choix ajoutés/supprimés/recodés ; validations modifiées ; min/max modifiés ;
obligatoire modifié ; identifiant modifié ; logique modifiée ; calcul modifié ;
annotation modifiée ; matrice modifiée.

Classer : CRITIQUE ; MAJEUR ; MODÉRÉ ; MINEUR ; INFORMATION.
Règles : suppression de variable = CRITIQUE ; modification de nom = CRITIQUE ;
recodage d'un choix = CRITIQUE ; modification de formule = MAJEUR ; modification de
logique = MAJEUR ; changement min/max = MAJEUR ; libellé seul = MODÉRÉ ; ajout de
note = MINEUR.

Ne jamais remplacer automatiquement le nouveau fichier. Ne jamais modifier les DD.
Tests testthat sur chaque catégorie de changement.
```

---

## PROMPT PDF — Export PDF (V5)

```
Implémente l'export PDF des documents Word déjà générés.

Principe : ne PAS réécrire une mise en page PDF. Le PDF est produit par conversion
des .docx existants (mise en page identique, source unique).

Moteur : doconv::docx2pdf() (LibreOffice OU MS Word installé sous Windows).
Détecter la disponibilité au démarrage (doconv). Si aucun moteur :
- ne pas planter le programme entier ;
- message cli clair (installer LibreOffice recommandé, avec l'URL) ;
- continuer à produire les .docx, signaler que le PDF est ignoré.

Comportement :
1. Option --pdf sur les commandes build (ex. build terrain ... --pdf) : chaque
   .docx converti en .pdf dans le même dossier, même nom de base.
2. Commande dédiée : redcap-doc pdf input_or_folder --output output (fichier
   unique OU tous les .docx d'un dossier).
3. Config YAML :
   output:
     pdf: true
     keep_docx: true    # ne JAMAIS supprimer le .docx source
4. Journaliser chaque conversion (source, pdf, durée, succès/échec).
5. En cas d'échec d'un fichier, poursuivre les autres + récapitulatif final.

Placement : exporter-pdf.R ; aucune logique REDCap. doconv en Suggests :
requireNamespace avant usage, message d'installation clair si absent.

Tests testthat : skip si aucun moteur (skip_if_not) ; sinon générer un .docx,
convertir, vérifier .pdf non vide et .docx conservé.

Documentation : docs/INSTALLATION_WINDOWS.md (LibreOffice + note MS Word) + README.

Contrainte : ne jamais supprimer le .docx d'origine.
```

---

## PROMPT 13 — Configuration projet MDF

```
Crée une configuration spécifique au projet MDF sans coder les valeurs dans le
moteur.

Créer projects/MDF/config.yml :
project:
  organization: "Epicentre"
  study_name: "MDF - Étude principale"
  short_name: "MDF"
  language: "fr"
  confidentiality: "Confidentiel"
  version: "À compléter"
  date: "À compléter"
branding:
  font: "Arial"
  title_size: 14
  body_size: 9
  grayscale: true
  logo_path: ""
terrain:
  question_width_percent: 45
  answer_width_percent: 55
  show_response_codes: true
  show_field_notes: true
  show_calculated_fields: true
  move_long_choices_to_appendix: true
  long_choice_threshold: 15
monitoring:
  show_branching_logic: true
  show_calculations: true
  show_validation: true
  show_identifiers: true
  show_annotations: true
output:
  create_subfolders: true
  sanitize_filenames: true
  include_generation_date: true
  include_source_hash: true

Créer aussi projects/MDF/input/ et projects/MDF/output/ + un README propre au MDF.

Commande : redcap-doc build-project projects/MDF
qui cherche le CSV dans input, la config dans config.yml, les sorties dans output.
Si plusieurs CSV : erreur claire (cli::cli_abort).
```

---

## PROMPT 14 — Tests et qualité

```
Ajoute une suite complète de tests et d'outils qualité pour le package R.

Tests unitaires (testthat) : parsing des choix ; parsing des validations ;
normalisation des colonnes ; détection d'encodage ; regroupement par formulaire ;
logique conditionnelle ; variables calculées ; noms de fichiers ; lecture YAML.

Tests d'intégration : génération CRF Terrain ; CRF Monitoring ; DD Word ; DD Excel ;
Specification ; Manuel enquêteur ; Manuel monitoring ; Branching Guide ;
Calculations Guide ; comparaison de versions.

Vérifications DOCX : fichier existe ; non vide ; se rouvre (officer::read_docx()) ;
titres attendus ; tableaux attendus ; CRF Terrain SANS syntaxe REDCap ni nom de
variable.

Ajouter : testthat (3e édition) ; covr ; lintr ; styler ; hooks (package precommit).

Commandes :
Rscript -e 'devtools::test()'
Rscript -e 'covr::package_coverage()'
Rscript -e 'lintr::lint_package()'
Rscript -e 'styler::style_pkg(dry = "on")'

Créer un workflow CI (GitHub Actions r-lib/actions : R CMD check + tests +
couverture) ; sinon scripts/run_tests.ps1 équivalent.
```

---

## PROMPT 15 — Préparation de la version 1.0

```
Prépare une version 1.0 stable du package Epicentre REDCap Documentation Generator.

Avant la release :
1. Tous les tests (devtools::test()) + R CMD check (0 error, 0 warning).
2. Corriger les erreurs. 3. Vérifier les scripts Windows.
4. Tester avec inst/extdata/sample_data_dictionary.csv.
5. Tester avec un DD REDCap réel si présent dans input.
6. Vérifier que les .docx s'ouvrent (officer::read_docx()).
7. Vérifier que les .xlsx s'ouvrent (openxlsx::loadWorkbook()).
8. CRF Terrain : aucun nom de variable, aucune formule, aucune logique REDCap.
9. CRF Monitoring : éléments techniques présents.
10. Aucun contenu clinique inventé.

Créer : CHANGELOG.md ; docs/INSTALLATION_WINDOWS.md ; docs/GUIDE_UTILISATEUR.md ;
docs/GUIDE_DEVELOPPEUR.md ; docs/LIMITES_CONNUES.md ;
docs/VALIDATION_RELEASE_1_0.md.

Mettre à jour Version dans DESCRIPTION (1.0.0).

Construire l'archive (R CMD build -> .tar.gz) et un ZIP contenant : code ; scripts
Windows ; fichier d'exemple ; configurations modèles ; documentation ; SANS
renv/library ; SANS fichier temporaire ; SANS donnée MDF confidentielle.

À la fin : statut des tests ; couverture ; limites connues ; commandes
d'installation ; commandes de génération ; liste exacte des fichiers produits.
```

---

## PROMPT DIST — Packaging et distribution

```
Implémente la construction de l'archive de distribution d'ERDG. Livrable propre,
installable sur une autre machine Windows, SANS donnée confidentielle ni fichier
temporaire.

1. Mettre à jour .Rbuildignore pour EXCLURE : renv/ et renv.lock ; projects/
   (dont MDF) ; docs/ de travail non nécessaires ; scripts/ de dev si non requis ;
   .Rproj/.git/.github ; fichiers temporaires.
2. Construire l'archive source : Rscript -e 'devtools::build(path = "dist")'
   -> dist/redcapdocgen_<version>.tar.gz (après R CMD check : 0 error, 0 warning).
3. Construire un ZIP "utilisateur" dans dist/ contenant : le .tar.gz ; les scripts
   Windows ; inst/extdata/sample_data_dictionary.csv ; un config.example.yml
   VIERGE (copie de projects/MDF/config.yml sans données réelles) ; README.md,
   docs/INSTALLATION_WINDOWS.md, docs/GUIDE_UTILISATEUR.md, CHANGELOG.md, LICENSE.
4. Le ZIP NE DOIT PAS contenir : renv/library/ ; cache de dépendances ; .venv ;
   fichiers temporaires ; AUCUNE donnée MDF (ni CSV réel, ni output réel). Ajouter
   une vérification programmatique : lister le contenu et échouer (cli::cli_abort)
   si un chemin correspond à projects/MDF/input|output non vides ou hors liste
   blanche.
5. Script reproductible scripts/build_release.ps1 (ou build_release()) :
   check -> build tar.gz -> assemblage ZIP -> vérification -> chemin + liste des
   fichiers.
6. Nom du ZIP : ERDG_<version>_windows.zip (version lue depuis DESCRIPTION).
7. dist/CONTENU.txt (fichiers + tailles) + empreinte SHA-256 du ZIP dans
   dist/ERDG_<version>_windows.zip.sha256 (digest, algo = "sha256").

Contraintes : processus entièrement scripté et reproductible ; liste blanche =
référence, tout le reste exclu par défaut ; jamais de données confidentielles.

À la fin : chemin du .tar.gz ; chemin du ZIP ; contenu exact ; SHA-256 ; commande
d'installation sur machine cible ; limites restantes.
```

---

## Prompt de supervision (à coller au début de chaque session Codex)

```
Règles permanentes pour ce projet (package R) :
1. Ne jamais supprimer une fonctionnalité existante sans justification.
2. Ne jamais modifier un Data Dictionary source.
3. Ne jamais inventer de règle clinique, protocolaire ou de monitoring.
4. Le Data Dictionary REDCap est la source de vérité.
5. Toute information générée est classée : issue de REDCap ; générée
   techniquement ; à valider par l'équipe étude.
6. Toujours exécuter les tests (testthat) après une modification importante.
7. Toujours documenter les changements (roxygen2 + docs/).
8. Toujours préserver la compatibilité Windows et R 4.4+.
9. Ne jamais inclure de données confidentielles dans les fixtures ou les tests.
10. Respecter les conventions R : fichiers à plat dans R/, classes R6 pour le
    domaine, dépendances dans DESCRIPTION, pas de library() dans le package
    (pkg::fonction ou @importFrom).
11. Ne pas déclarer une tâche terminée si les tests échouent.
12. À la fin de chaque intervention : fichiers créés ; fichiers modifiés ; tests
    exécutés ; résultats ; limites restantes ; prochaine étape recommandée.
```
