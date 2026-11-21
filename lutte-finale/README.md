# Communiste Land — prototype

Survivor-like 3D satirique (Godot 4.5, renderer Compatibilité par défaut pour marcher sur un maximum de PC). Des camarades en chapka contre des hordes de capitalistes en haut-de-forme.

## Lancer le jeu

- **Windows** : télécharge `CommunisteLand.exe` (dossier `export/` ou release) et double-clique.
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
| Esquive | Clic droit / C | LB |
| Capacité ultime | E | RB |
| Mini-carte (activer/désactiver) | M | — |
| Grande carte (maintenir) | Tab | Select |
| Pause | Échap | Start |

## Ce que contient le prototype

- **Une run = 3 zones de 10 minutes**, cartes générées à chaque run :
  1. **L'Hypermarché** (parkings, conteneurs, marchés, quais) — boss **Directeur Black Friday**.
  2. **Le Quartier d'Affaires** (tours, open spaces, passerelles en hauteur) — boss **PDG Vertical** (convoque ses cadres, saute sur toi).
  3. **La Bourse**, de nuit (corbeilles, écrans de cotation, réserves d'or) — boss final **La Main Invisible** (disparaît, réapparaît à côté de toi).
  Le boss arrive à 08:00 ; une fois battu, une **porte** s'ouvre vers la zone suivante (build conservé, soin complet). À 10:00, c'est le **Krach** et le Contrôleur Fiscal invincible.
- **3 difficultés** (Camarade, Commissaire, Héros de l'Union), départ possible depuis une zone déjà débloquée, **mode Sans fin** après la première victoire.
- **12 types d'ennemis** : stagiaires (horde), cadres (blindés), traders (chargent après un temps de visée), influenceurs (tirent de loin, aveuglent), banquiers (lancent des sacs qui laissent une zone de Dette), crypto-bros (explosent), avocats (très blindés, ralentissent), huissiers (saisissent une arme 5 s), coachs (soignent), lobbyistes (protègent leurs voisins), DRH (invoquent des stagiaires), actionnaires (tanks avec coup de zone). Plus le Golden Boy (élite à coffre).
- **20 armes**, chacune avec son **évolution** (arme niveau 6 + le bon Décret) : Marteau, Kalach, Faucille, Molotov, Matriochka, Spoutnik, Samovar, Haut-parleur, Tracteur du Kolkhoze, Ours de Sibérie, Vodka Frappée, Piolet, Rideau de Fer, Char du Peuple, Orgue du Peuple, Balalaïka, Goulag Portatif, Étoile Rouge, Tracts de Propagande, Havane Explosif.
- **8 fusions** : deux armes niveau 6+ fusionnent (elles tirent toujours toutes les deux, plus fort, et n'occupent plus qu'un emplacement), par exemple Faucille et Marteau, Armée Rouge, Conquête Spatiale.
- **Mini-carte** qui tourne avec la caméra (coffres, sanctuaires, élites, boss, tornades, porte), sans les ennemis normaux.
- **13 Décrets** pour 4 emplacements.
- **Raretés** (commun, rare, épique, légendaire) sur toutes les améliorations. Le Décret Chance les améliore.
- **Sanctuaires et défis** : Statue du Leader, File d'attente (défi), Bourse aux paris, Goulag, Marché noir, Distributeur de propagande, OPA hostile (défi).
- **Événements aléatoires** : Black Friday, pluie de billets, grève générale, OPA hostile, livraison express, soldes.
- Cartons et consignes à casser, coffres payants (prix croissant), tartines.

## Progression entre les runs (le Kolkhoze)

Le jeu démarre sur **le Kolkhoze**, un écran de menus entre les runs. Chaque run (victoire ou mort) rapporte des **médailles**.

- **Bureau du Plan** : 13 bonus permanents à plusieurs rangs (PV, dégâts, cadence, zone, XP, chance, armure, régénération, roubles, relances, résurrection, 5e arme).
- **Caserne** : 6 camarades (Stakhanov, Ilitch le Chauve, Petit Père Moustache, Babouchka Olga, Comandante Barbudo, Youri l'Orbital), 3 tenues chacun. Chacun a son arme de départ, un passif, une **capacité ultime** (touche E, se charge en bonkant des ennemis) et un **arbre de talents** à 3 branches de 5 talents. Le camarade gagne de l'XP quand on le joue.
- **Usine d'armement** : déblocage des armes. La **maîtrise** monte avec les dégâts infligés par chaque arme et débloque des **modules** qui changent son comportement (17 au total, un équipé par arme).
- **Plan quinquennal** : 3 quotas à remplir en 5 runs. Chaque quota rapporte des médailles, le plan complet un bonus et un camarade. Un plan raté déclenche une **purge** : un bonus du Bureau est désactivé pendant tout le plan suivant.
- **Directives du Parti** : 10 contraintes optionnelles (jusqu'à 18 points de ferveur). Chaque point donne +15 % de médailles.

Sauvegarde : `%APPDATA%/Godot/app_userdata/Communiste Land/lutte_finale_save.json` sous Windows.

Pas encore : sons et musique, familiers et gacha, modules pour les 12 nouvelles armes.

## Tests automatiques

Un bot (qui joue comme un très mauvais joueur) peut enchaîner des runs avec toute la progression :

```
godot --headless --path . -- bot multirun speed=8 runs=30 save=/tmp/sim.json
```

Une seule run : `godot --headless --path . -- bot speed=6 dur=700`. Option `botdirs` : le bot active des directives après ses victoires.

Options : `zone=2` (démarre dans une zone), `tier=`, `endless`, `god` (invulnérable), `killboss`, `give=kalach,ours` ou `give=allevo` (toutes les armes évoluées et fusionnées), `solo` (pas d'arme de départ), `bot`, `speed=` (accélère le temps), `dur=` (secondes de jeu), `seed=`, `warp=` (saute à un moment de la zone avec un build plausible), `shots=` + `shotdir=` (captures d'écran, nécessite un rendu).

## Look-dev

`lookdev/` contient la scène de test de direction artistique (style retenu : F, caméra mi-hauteur).

## Crédits

- Modèles 3D, textures d'effets et polices Kenney : [kenney.nl](https://kenney.nl) (CC0)
- Polices Oswald, Russo One, Bangers : Google Fonts (OFL)
- FreeSerif (symboles ☭ ★) : GNU FreeFont (GPL + exception de police)
