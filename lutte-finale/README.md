# Lutte Finale — prototype

Survivor-like 3D satirique (Godot 4.5, renderer Compatibilité par défaut pour marcher sur un maximum de PC). Des camarades en chapka contre des hordes de capitalistes en haut-de-forme.

## Lancer le jeu

- **Windows** : télécharge `LutteFinale.exe` (dossier `export/` ou release) et double-clique.
- **Depuis les sources** : installe [Godot 4.5.1](https://godotengine.org/download), ouvre ce dossier (`project.godot`), puis F5.

## Contrôles

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD (ou WASD) / flèches | Stick gauche |
| Tourner la caméra | Souris, ou A / R | Stick droit |
| Saut (double saut) | Espace | A |
| Glissade | Maj | B |
| Ouvrir un coffre | F | X |
| Choisir une amélioration | 1 / 2 / 3 ou clic | Gauche/droite + A |
| Pause | Échap | Start |

## Ce que contient le prototype

- **Zone 1 « Hypermarché »**, environ 4 fois plus grande qu'au début : parkings, dépôts de conteneurs, marchés, places. 10 minutes, boss **Directeur Black Friday** à 08:00, **Krach** et Contrôleur Fiscal invincible à 10:00.
- **12 types d'ennemis** : stagiaires (horde), cadres (blindés), traders (chargent après un temps de visée), influenceurs (tirent de loin, aveuglent), banquiers (lancent des sacs qui laissent une zone de Dette), crypto-bros (explosent), avocats (très blindés, ralentissent), huissiers (saisissent une arme 5 s), coachs (soignent), lobbyistes (protègent leurs voisins), DRH (invoquent des stagiaires), actionnaires (tanks avec coup de zone). Plus le Golden Boy (élite à coffre).
- **8 armes** avec 8 **évolutions** (arme niveau 6 + le bon Décret) : Marteau, Kalach, Faucille, Molotov, Matriochka, Spoutnik, Samovar, Haut-parleur.
- **13 Décrets** pour 4 emplacements.
- **Raretés** (commun, rare, épique, légendaire) sur toutes les améliorations. Le Décret Chance les améliore.
- **Sanctuaires et défis** : Statue du Leader, File d'attente (défi), Bourse aux paris, Goulag, Marché noir, Distributeur de propagande, OPA hostile (défi).
- **Événements aléatoires** : Black Friday, pluie de billets, grève générale, OPA hostile, livraison express, soldes.
- Cartons et consignes à casser, coffres payants (prix croissant), tartines.

Pas encore : sons et musique, familiers et gacha, autres personnages, zones 2 et 3, progression entre les runs.

## Tests automatiques

Un bot peut jouer seul (utile pour l'équilibrage) :

```
godot --headless --path . -- bot speed=6 dur=700 seed=1
```

Options : `bot`, `speed=` (accélère le temps), `dur=` (secondes de jeu), `seed=`, `warp=` (saute à un moment de la zone avec un build plausible), `shots=` + `shotdir=` (captures d'écran, nécessite un rendu).

## Look-dev

`lookdev/` contient la scène de test de direction artistique (style retenu : F, caméra mi-hauteur).

## Crédits

- Modèles 3D, textures d'effets et polices Kenney : [kenney.nl](https://kenney.nl) (CC0)
- Polices Oswald, Russo One, Bangers : Google Fonts (OFL)
- FreeSerif (symboles ☭ ★) : GNU FreeFont (GPL + exception de police)
