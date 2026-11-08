# Cosmos Infini

Jeu incrémental (idle) pour mobile, à prestiges empilés à l'infini. PWA : HTML/CSS/JS sans dépendance, jouable hors connexion et installable sur l'écran d'accueil.

## Jouer
Servir le dossier `idle/` en HTTP(S), par exemple `python3 -m http.server` puis ouvrir `http://localhost:8000/` sur le téléphone. (En `file://` le jeu marche, mais sans mode hors-ligne.)

## Mécaniques
- **Générateurs** (8 étages) : chaque étage produit le précédent, les Particules produisent la Poussière. Tous les 10 achats, ×2 sur l'étage. **Accélérateur** : multiplie tous les étages.
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
- `tools/sim.js` : bot d'équilibrage, `node tools/sim.js <heures> <pas>`.
- `tools/icons.js` : régénère les icônes PNG depuis `icon.svg`.

## Rythme mesuré (bot actif)
Supernova ~5 min · Effondrement ~1 h · Big Bang ~3 h · Infini brisé ~21 h · Éternité ~23 h · Multivers ~3 j · Omnivers ~4 j.
