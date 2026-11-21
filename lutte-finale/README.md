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

- Zone 1 « Hypermarché » : 10 minutes, vagues de stagiaires toutes les minutes, Golden Boys (élites qui lâchent un coffre), boss **Directeur Black Friday** à 08:00, puis **le Krach** et le Contrôleur Fiscal invincible à 10:00.
- 4 armes automatiques (Marteau, Kalach, Faucille, Cocktail Molotov), niveaux 1 à 8. Le Marteau frappe deux fois plus fort quand on retombe d'un saut.
- 8 Décrets (stats), 4 emplacements.
- XP, montées de niveau avec choix de 3 cartes, coffres payants en roubles, tartines qui soignent, Statue du Leader (reste dans le cercle pour obtenir une faveur).
- Conteneurs sur lesquels sauter, voitures et décor comme obstacles.

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
