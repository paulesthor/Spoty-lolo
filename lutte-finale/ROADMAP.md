# Communiste Land — feuille de route (décisions et travail restant)

Ce fichier garde en mémoire les décisions prises avec le créateur du jeu, pour ne rien perdre d'une session à l'autre.

## Principes
- Priorité au **gameplay pur et dur**. Le visuel reste minimal tant que le gameplay n'est pas solide (sauf menus lisibles).
- Seul le **niveau 1 (Hypermarché)** existe et il est loin d'être fini. Les idées liées aux niveaux suivants se décident en fonction des niveaux créés.
- Le bot de test joue comme un **très mauvais joueur** : un vrai joueur aura beaucoup plus de facilité. Cibles d'équilibrage avec le bot : mort vers 3-4 min sans progression, premières victoires après une vingtaine de runs.
- **« Sérieux » = un jeu soigné, complet, bien fini** (qualité de production). Le **ton du thème est humoristique** : vannes sur le communisme et le capitalisme, caricatures assumées, humour noir. Pas de vraies marques ni de vraies personnes : caricatures sous surnoms.
- Direction visuelle validée : éclairage de fin de journée, caméra mi-hauteur. Personnages : passage à des packs libres de droits avec de vraies animations (choix du style en cours).

## Lot 1 (fait, équilibrage en cours)
- [x] Esquive (dash invulnérable, clic droit / C / LB) + glissade qui laisse une **traînée de feu** qui brûle les ennemis (inspiré de PhD Slider, Call of Duty Zombies).
- [x] **Événements météo** façon carte du désert de Megabonk : tornades de caddies, pic de pollution (brouillard), orage (foudre annoncée par des cercles rouges).
- [x] **Élites à affixes** à partir de 03:00 : blindé, rapide, diviseur, vampire, téléporteur.
- [x] **Lisibilité** : effets du joueur plus discrets, flèche rouge vers l'origine des coups, alerte et ralenti à PV bas, cause de la mort, options (chiffres de dégâts, intensité des effets, tremblement).
- [x] **Relance / bannissement / passer** façon Megabonk : charges au Bureau du Plan (Recours administratif, Liste noire, Dispense) et « Dossier administratif » au Marché noir.

## À faire ensuite (validé sur le principe, à reprendre après le lot 1)
- **Armes : grosse mise au point** — beaucoup d'armes, énormément de builds différents « à la Megabonk », en gardant les **évolutions façon Survivor.io / Vampire Survivors**. Idées déjà notées : statuts communs (brûlure, étourdissement, ralentissement, marquage) exploités par des décrets, synergies entre armes, **Reliques** qui changent les règles (comme les objets de Megabonk).
- **Plancher de chance** : arme garantie si aucune avant le niveau 5, évolution disponible toujours proposée.
- **Verrouillage** d'une carte (garder une carte pour le choix suivant).
- **Directives qui changent la façon de jouer** (grève de l'électricité / nuit, marché libre, censure des cartes, exode : zone qui rétrécit) — selon les niveaux créés.
- **Formations ennemies** (murs de cadres, encerclements, colonnes de traders) — selon les niveaux.
- **Progression** : plus de déblocages de contenu (armes, reliques, modules, sanctuaires) que de pourcentages ; une récompense concrète à chaque run ; rattrapage pour les camarades secondaires.
- **Accumulation à l'écran** : fusion des gemmes, coffres d'élite ouverts automatiquement au bout de 20 s, plafond d'effets.
- **Zones 2 et 3** (Quartier d'Affaires vertical, Bourse au sol mouvant), variantes de la zone 1, défis du jour.
- **Hors gameplay, plus tard** : sons et retours sonores, musiques par zone, courts textes d'histoire entre les zones, familiers et gacha (Loterie d'État), meilleurs modèles 3D.

## Lot 2 (fait le 21/11/2026)
- [x] Personnages animés : héros KayKit + accessoires, capitalistes Quaternius recolorés, disparition immédiate des ennemis tués, animation allégée au loin.
- [x] 2 nouveaux camarades : **Comandante Barbudo** (Havane explosif, passif +3 % dégâts par élite/boss, ultime « ¡Viva la Revolución! » : les ennemis tués explosent) et **Youri l'Orbital** (Spoutnik, apesanteur, ultime « Retour sur Terre » : capsule qui s'écrase).
- [x] **Tenues** : 3 par camarade (1 gratuite + 2 à acheter en médailles), à la Caserne.
- [x] **Mini-carte** (M : on/off, Tab ou bouton Select : grande carte), tourne avec la caméra, sans les ennemis normaux. Option au Kolkhoze.
- [x] **Run en 3 zones** : Hypermarché → Quartier d'Affaires (passerelles, open spaces, boss « PDG Vertical » qui convoque ses cadres et saute sur le joueur) → La Bourse (de nuit, corbeilles, écrans de cotation, réserves d'or, boss final « La Main Invisible » qui disparaît et réapparaît). Porte vers la zone suivante après le boss, build conservé, soin complet.
- [x] Départ depuis une zone déjà débloquée (niveaux de rattrapage), **3 difficultés** (Camarade, Commissaire, Héros de l'Union), **mode Sans fin** (zones en boucle, boss renforcés), record sauvegardé.
- [x] **20 armes** (12 nouvelles : Tracteur, Ours de Sibérie, Vodka Frappée, Piolet, Rideau de Fer, Char du Peuple, Orgue du Peuple, Balalaïka, Goulag Portatif, Étoile Rouge, Tracts, Havane Explosif), chacune avec son évolution (arme niv 6 + décret), et **8 fusions** de deux armes (libèrent un emplacement).

- [x] Équilibrage des 20 armes au banc (bot seul avec une arme, 4 min) : Faucille, Spoutnik, Ours réduits ; Piolet, Haut-parleur (vise maintenant l'ennemi le plus proche), Balalaïka, Tracts, Samovar, Goulag, Orgue renforcés.
- À faire : modules d'Usine pour les 12 nouvelles armes ; vérifier l'équilibrage des zones 2 et 3 avec de vrais joueurs (le bot meurt encore en zone 1 après 8 runs).

## Réponses du créateur (questionnaire du 21/11/2026)
**À faire maintenant :**
- Personnages : taille des capitalistes inchangée ; ennemis tués = **disparition immédiate** (pas de cadavre) ; pas d'animation de frappe du héros ; je propose les 5e/6e camarades ; **skins débloquables** oui.
- Mini-carte : **M** = petite ↔ off, **Tab** = grande carte ; **pas d'ennemis normaux** dessus, seulement le reste (coffres, sanctuaires, élites, boss, météo, bâtiments) ; en haut à droite.
- Run : **3 zones × 10 min = 30 min** ; boss de zone tué → une porte s'ouvre, on garde le build ; niveaux suivants **au choix de Claude** ; zone N débloquée après avoir battu le boss de N-1 ; **mode Sans fin** après la 1re victoire ; **3 niveaux de difficulté** débloquables.
- Armes : **20 armes**, certains camarades ont une **arme de départ différente** ; évolutions **des deux types** (arme max + décret précis, ET fusion de deux armes) ; **4 emplacements** + 1 achetable ; **pas de statuts élémentaires** à synergies ; **pas de reliques**.

**Gardé pour plus tard (questions encore ouvertes) :** méta (vitesse des grades, familiers/gacha, quêtes/succès, 1 ou 2 monnaies), menus (menu titre, langues, manette, touches, options graphiques), son/musique/voix, histoire et limites de l'humour, cibles d'équilibrage, plateformes et fréquence des zips.

## Critiques du genre à garder en tête (recherche faite)
Répétitivité (peu de cartes/ennemis), grind ou progression triviale, brouillard visuel, manque de retour sur les dégâts, difficulté artificielle (juste des chiffres), fin de partie injuste et trop de hasard, personnages trop semblables, accumulation d'objets qui fait ramer, musique qui lasse, peu d'histoire.
