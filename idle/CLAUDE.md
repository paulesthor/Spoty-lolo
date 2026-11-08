# Big Odeur — consignes permanentes (jeu idle dans `idle/`)

Ces consignes viennent du propriétaire du jeu et s'appliquent à toutes les sessions.

## Projet
- Jeu incrémental (idle) **uniquement pour mobile**, PWA en HTML/CSS/JS sans dépendance, dans `idle/`.
- Mécaniques inspirées de Revolution Idle (prestiges empilés, défis, briser l'Infini, Éternité, couches infinies), rythme calé sur les temps réels des joueurs de Revolution Idle (voir `tools/resultats/rapport.html`).
- **Jeu privé.** Thème : le cliché « les gens de l'informatique puent », appliqué à l'univers de la **science des données**. Ton **très moqueur, humour noir, violent**. Ne pas adoucir.

## Interdit (« IA slop »)
- **Aucun emoji**, nulle part (interface, textes, icônes, messages, rapports).
- **Pas de barre de couleur sur le côté d'un bloc** (bordure gauche/droite colorée, liseré d'accent sur une carte).
- Plus généralement : rien qui fasse « généré par IA » (dégradés violet-bleu, icônes génériques, cartes toutes identiques avec ombre, puces décoratives).

## Méthode
- Avant de toucher à l'équilibrage : `node tools/tests.js` et `node tools/malin.js` / `tools/campaign.js` pour vérifier le rythme.
- Les identifiants internes (`sn_*`, `co_*`, couches 1, 2, 3…) ne changent pas : les sauvegardes doivent rester compatibles.
- Le jeu publié (artifact) partage la partie du joueur dans la base `parties` : la lire avec `ArtifactData` pour analyser sa progression.
