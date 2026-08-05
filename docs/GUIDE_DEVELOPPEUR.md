# Guide développeur

## Architecture

Package R standard ; sources à plat dans `R/`, organisées par préfixe :

| Préfixe | Rôle |
|---|---|
| `parser-*` | lecture du Data Dictionary → modèle interne |
| `service-*` | chargement, validation, orchestration (`build-project`) |
| `generator-*` | production des documents (terrain, monitoring, dictionary, …) |
| `exporter-*` | écriture Word (officer/flextable), Excel (openxlsx), PDF (LibreOffice) |
| `config.R` | configuration + fusion YAML |
| `cli.R` | dispatch de la ligne de commande |
| `gui.R` | interface Shiny (appelle les mêmes services que la CLI) |

Règle de dépendance : `parser → services → generators → exporters`. Les
générateurs ne lisent jamais le CSV ; les exporteurs ne contiennent aucune
logique REDCap.

## Ajouter un nouveau document

1. Créer `R/generator-<nom>.R` avec `build_<nom>(csv, output, config)`.
2. Câbler la commande dans `R/cli.R` (branche `switch` de `build`).
3. Ajouter l'entrée dans `.PROJECT_DOCUMENTS` (`R/service-project.R`) et dans
   `.GUI_DOCUMENTS` (`R/gui.R`).
4. Ajouter un test dans `tests/testthat/test-<nom>.R`.

## Encodage (piège important)

Le **code R doit rester ASCII** (portabilité, `R CMD check`). Les accents des
chaînes de sortie sont écrits en échappements `\uXXXX`.

- Écrire le fichier avec accents naturels, puis convertir :
  ```bash
  perl -CSD -i -pe 's/([^\x00-\x7f])/sprintf("\x5cu%04x", ord($1))/ge' R/fichier.R
  ```
- **Commentaires et blocs roxygen `#'` : ASCII pur** (Rd interprète `\u` comme une
  macro → WARNING). Éviter aussi les crochets `[...]` dans roxygen (liens Rd).
- Les **noms d'arguments/colonnes accentués** doivent être **quotés** :
  `"Catégorie" = x` (un symbole nu ne peut pas contenir `\u`).

## Performance des documents Word

- `officer::body_add_fpar` / `body_add_par` sont **O(n²)** : ne jamais faire des
  milliers d'appels. Regrouper le contenu en **tableaux**.
- `officer::body_add_table` est **rapide** (~90 s pour 2652 lignes) mais **ne rend
  pas les `\n`** en sauts de ligne → utiliser un séparateur (` | `).
- `flextable` donne un rendu stylé mais est **lent** sur les gros tableaux : le
  réserver aux petits tableaux par section (CRF Terrain / Monitoring).

## Tests et qualité

```powershell
.\scripts\run_tests.ps1     # testthat
.\scripts\run_checks.ps1    # tests + lintr + styler + covr
```

Ou directement :

```r
devtools::test()
lintr::lint_package()
styler::style_pkg(dry = "on")
covr::package_coverage()
```

`R CMD check` : utiliser `R CMD build` puis `R CMD check` (le package est pur R,
pas besoin de Rtools) avec `_R_CHECK_FORCE_SUGGESTS_=false`.

## CI et hooks

- `.github/workflows/R-CMD-check.yaml` : R CMD check + tests + lint (r-lib/actions).
- `.pre-commit-config.yaml` : styler, lintr, roxygenize (package `precommit`).
