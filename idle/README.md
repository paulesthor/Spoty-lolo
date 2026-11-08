# Cosmos Infini

Jeu incrémental (idle) pour mobile, à prestiges empilés à l'infini. PWA : HTML/CSS/JS sans dépendance, jouable hors connexion et installable sur l'écran d'accueil.

## Jouer
Servir le dossier `idle/` en HTTP(S), par exemple `python3 -m http.server` puis ouvrir `http://localhost:8000/` sur le téléphone. (En `file://` le jeu marche, mais sans mode hors-ligne.)

## Mécaniques
- **Générateurs** (8 étages) : chaque étage produit le précédent, les Particules produisent la Poussière. Le prix monte de 12 % à chaque achat et fait un grand saut tous les 10 achats, qui doublent la production de l'étage. **Accélérateur** : multiplie la Poussière.
- **Barre d'objectif** en haut de l'écran : progression (en %) vers le prochain prestige à débloquer.
- **Achats** : un tap = un achat ; appui long = achats en continu ; rien n'est acheté en faisant défiler. Les achats automatiques (débloqués par l'Effondrement) sont désactivés par défaut.
- **Supernova → Éclats** (1e15 Poussière) : multiplicateur + améliorations.
- **Effondrement → Singularités** (1e12 Éclats) : améliorations, jalons d'automatisation.
- **Big Bang → Points d'Infini** : la Poussière est plafonnée à l'Infini (1,8e308). 6 **défis**, puis **Briser l'Infini** (4 défis requis).
- **Éternité → Points d'Éternité** (1,8e308 Points d'Infini).
- **Strates** (Multivers, Omnivers, …, Strate XI, XII…) : couches générées à l'infini, chacune nourrie par la précédente (1e30) et qui la renforce.
- Jalons, automates (achat, prestiges auto « gain ≥ X× » ou « toutes les X s »), gains passifs, progression hors-ligne (7 jours max), export/import de sauvegarde.

## Fichiers
- `js/big.js` : grands nombres (mantisse × 10^exposant), affichage.
- `js/game.js` : moteur du jeu (sans DOM). Tous les réglages d'équilibrage sont ici.
- `js/ui.js` : interface mobile.
- `tools/sim.js` : bot joueur, 9 profils (`node tools/sim.js` pour la liste ; `node tools/sim.js patient 300 1 sortie.json`).
- `tools/campaign.js` : lance tous les profils en parallèle (`node tools/campaign.js 300 1 resultats/`).
- `tools/malin.js` : optimiseur de stratégies (« joueur malin ») : `node tools/malin.js bb|eter|strates <essais> <mutations>`.
- `tools/tests.js` : 37 tests de robustesse (resets instantanés, pas de temps, hors-ligne, valeurs extrêmes, sauvegardes corrompues, défis…).
- `tools/rapport.js` : génère le rapport d'équilibrage à partir des résultats (`tools/resultats/`).
- `tools/icons.js` : régénère les icônes PNG depuis `icon.svg`.

## Garde-fous d'équilibrage
- **Exposant critique < 1** (0,39 au départ, 0,76 au maximum) : la production ne peut pas s'emballer, quelle que soit la vitesse des ticks.
- **Plafond progressif** sur chaque effet de monnaie (au-delà de ×1e60, puissance 0,7) : pas de boucle prestige → production → prestige.
- **10 s minimum** entre deux prestiges d'une même couche (manuel ou automatique).
- **Poussière de départ < seuil de Supernova**, seuils des Strates croissants (1e10, 1e15, 1e20…).

## Rythme visé (calé sur Revolution Idle)
| Étape | Bon joueur (simulé) | Repère Revolution Idle |
|---|---|---|
| 1er Big Bang | 3-4,4 h | 1er Infini : 3 h 15 typique |
| Infini brisé | 10-11 h | ~8 h + 2 h 30 de défis |
| 1re Éternité | ~1,2 jour | 1 j 6 h à 3-7 jours |
| Multivers / Omnivers / Hypervers | ~3 j / ~8-9 j / ~3 semaines | — |

Détails et limites : `tools/resultats/rapport.html`.
