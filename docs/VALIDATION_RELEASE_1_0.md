# Validation de la release 1.0.0

Date : 2026-08-05 · Environnement : R 4.3.2, Windows 11, LibreOffice détecté.

## Tests automatisés

- **64 tests testthat** répartis sur 16 fichiers — **0 échec, 0 erreur**.
- `R CMD check` : **0 error, 0 warning**, 2 NOTES attendues :
  - packages Suggests (`lintr`, `styler`) non installés localement (installés en CI) ;
  - quelques dépendances déclarées non encore utilisées par certains chemins.

## Contrôles de release (sur `sample_data_dictionary.csv`)

| Contrôle | Résultat |
|---|---|
| CRF Terrain : les `.docx` s'ouvrent | ✅ |
| CRF Terrain : **aucun nom de variable** | ✅ |
| CRF Terrain : **aucune formule** | ✅ |
| CRF Terrain : **aucune logique REDCap** | ✅ |
| CRF Monitoring : éléments techniques présents | ✅ |
| Data Dictionary : le `.xlsx` s'ouvre | ✅ |
| Data Collection Specification : empreinte SHA-256 présente | ✅ |
| Manuel : marqueur `[À VALIDER PAR L'ÉQUIPE ÉTUDE]` présent | ✅ |
| Export PDF : moteur (LibreOffice) détecté | ✅ |

## Validation sur données réelles (MDF)

- `build-project projects/MDF` : **49 documents** générés (21 CRF Terrain, 21 CRF
  Monitoring, Data Dictionary Word+Excel, Specification, 2 manuels, 2 guides).
- Conversion PDF : **48 PDF** produits, `.docx` conservés.
- Parser : 21 instruments, 2652 variables, 0 erreur de structure, 5 avertissements
  (champs calculés déclarés obligatoires — à confirmer par l'équipe).

## Conformité aux principes

- Aucun contenu clinique inventé ; contenu non déductible marqué à valider.
- Fichiers source jamais modifiés ; nouveau Data Dictionary jamais remplacé.
- Code R en ASCII pur (accents via `\uXXXX`).

## Conclusion

**Release 1.0.0 validée.**
