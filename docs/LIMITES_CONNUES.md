# Limites connues (v1.0.0)

## Libellés d'instruments

Le Data Dictionary REDCap ne contient **pas** les noms de formulaires accentués
(la colonne *Form Name* est un slug technique sans accents). Les libellés
lisibles sont **fournis manuellement** dans `instruments:` de la configuration et
doivent être **relus/validés par l'équipe étude**.

## En-tête / pied de page / numéros de page

Les documents Word portent un **bloc de titre** en tête de corps, mais **pas** de
véritable en-tête/pied de page courant ni de numéro de page automatique — officer
l'exige via un modèle `.docx` (évolution prévue au stade « templates »).

## Piping REDCap dans les libellés

Le *piping* REDCap (ex. `[variable]` inséré dans un libellé) est affiché **tel
quel** ; il n'est pas résolu en valeur.

## Traduction des Branching Logic

Seules les **expressions simples** (une condition) sont traduites en langage
lisible. Les expressions complexes (plusieurs conditions, fonctions, cases à
cocher) sont marquées **« Expression complexe — vérification manuelle requise »**.

## Détection des risques de calcul

Les risques (division par zéro, fonction inconnue, parenthèses déséquilibrées…)
sont signalés de façon **conservatrice et factuelle** : un signalement n'est pas
nécessairement une erreur, mais un point à vérifier.

## Export PDF

Nécessite **LibreOffice** (ou MS Word). En son absence, seuls les `.docx` sont
produits. La conversion passe par LibreOffice en direct (le backend Word de
`doconv` échoue sur les chemins contenant espaces/parenthèses).

## Performance

La génération des CRF Terrain et CRF Monitoring (rendu `flextable` par section)
prend plusieurs minutes sur un gros Data Dictionary (~2600 variables). Les autres
documents sont rapides.

## Contenu métier

ERDG ne produit **aucune** consigne clinique, source documentaire, fréquence SDV
ni criticité : ce contenu est marqué **`[À VALIDER PAR L'ÉQUIPE ÉTUDE]`** et
relève de l'équipe.
