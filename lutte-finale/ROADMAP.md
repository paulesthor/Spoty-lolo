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

## Lot 3 — animations, décor, refonte visuelle (21/11/2026)
- [x] Animations : ennemis qui frappent, tirent, lancent, saluent, encaissent, reculent et se déplacent en crabe ; mort du héros au ralenti ; acclamation, sort et interaction ; coffres qui s'ouvrent ; entrées des élites et boss.
- [x] Décor vivant par zone : drapeaux, pigeons qui s'envolent, dirigeable à slogan, écrans boursiers animés, mascotte gonflable, taureau d'or, néons, fumées, mobilier urbain.
- [x] Vérificateur automatique d'objets flottants ou superposés (`-- layoutcheck zone=N seed=S`) : 0 défaut réel sur 12 cartes testées.
- [x] Refonte visuelle (demande du créateur : « un vrai rendu professionnel avec une identité forte ») : sols PBR texturés (asphalte, pavés, béton, marbre, ambientCG CC0), végétation stylisée Quaternius (feuillage texturé), relief de crépi et de briques sur les immeubles, affiches de propagande constructivistes et publicités détournées générées pour le jeu, palissades d'affiches, étalonnage « affiche » (papier chaud, ombres froides, rouges poussés, vignettage, grain), contours encrés sur le héros, les élites et les boss, écran de chargement et Kolkhoze illustrés, HUD aux panneaux inclinés.
- À poursuivre (identité visuelle) : effets des armes plus graphiques, ciel et lointains, plus de variété de façades, vérifier les performances sur le PC du créateur (FPS en fin de partie).

## Lot 4 — correctifs et sensation de puissance (21/11/2026)
- [x] Animation de course figée : les clips importés ne bouclaient pas (course, marche, attente). Boucles forcées pour le héros et les ennemis, et délai de grâce au sol (rampes, bordures).
- [x] Optimisation mesurée (5:00, 106 ennemis) : appels de dessin 3541 → 1913, triangles 1,85 M → 0,83 M. Fusion des décors statiques, accessoires fusionnés, horde sans ombre temps réel (ombre ronde au sol), ombres en 2 passes à 48 m, arbres légers, petits objets non dessinés au-delà de 62 m.
- [x] Sensation de puissance : la chair à canon (stagiaires, cadres) se renforce moins vite, tireurs et lanceurs plafonnés en nombre, +1,5 % de dégâts par niveau.
- [x] Fin de partie : cartes « Surplus du Plan » sans limite (dégâts, cadence, PV, régénération, critique, aimant, vitesse) et « Surcharge » des armes au maximum ; conservées d'une zone à l'autre.

## Lot 5 — vrais menus (22/11/2026)
- [x] Écran titre 3D : camarade sur une tribune (acclamation régulière), mur d'affiches, rideaux, drapeaux, projecteur, tracts qui tombent, capitalistes recroquevillés au premier plan, slogans d'humour noir qui défilent, crédits.
- [x] Sélection des camarades 3D : 6 estrades sous projecteurs, le choisi s'avance et salue, silhouettes « ??? » pour les camarades à réhabiliter (achat direct), tenues, zone, difficulté et mode, lancement.
- [x] Kit d'interface constructiviste partagé (boutons inclinés, liseré rouge, Russo One), Kolkhoze restylé (filigrane d'affiche), écrans de mort, victoire et pause avec affiche, cartes de récompense en forme d'affiches.
- Parcours : Titre → Sélection → Partie → Kolkhoze → Titre/Sélection.
- [x] Musique originale (marche du Kolkhoze pour les menus, thème de combat, thème de boss, fanfare de victoire, trombone triste à la mort) rendue avec la banque FluidR3 ; bruitages Kenney (CC0) + quelques sons synthétisés ; gestionnaire audio avec fondus et anti-cacophonie ; volumes réglables.
- [x] Icônes des 20 armes et 13 décrets : bibliothèque game-icons.net (CC BY 3.0, crédits dans le jeu) dans des médaillons aux couleurs du jeu (cartes, HUD, Usine, Bureau, sélection). Consigne du créateur : chercher d'abord dans les bibliothèques d'assets plutôt que dessiner soi-même.
- [x] Introduction animée (premier lancement, passable, rejouable depuis les crédits).
- [x] Boutons cliquables sur la pause et les écrans de fin (reprendre, abandonner, rejouer, Kolkhoze).

## Lot 6 — 15 camarades (22/11/2026)
- [x] 9 nouveaux camarades débloqués par des défis (seuils durcis à la demande du créateur : une run classique fait 5000-6000 éliminations) : Natacha la Kolkhozienne (Tracteur), Sergent Vodkine (Vodka), Tankiste Tamara (Char), Mikhaïl le Dresseur (Ours), Le Grand Timonier (Tracts), Lev le Bâtisseur (Rideau de Fer), Svetlana la Pyromane (Molotov), Dmitri le Musicien (Balalaïka), Valentina de l'Observatoire (Étoile Rouge). Chacun : allure propre (accessoires), passif, ultime, 3 branches de talents, 3 tenues.
- [x] Sélection : animation signature pour chaque camarade au survol, caméra qui parcourt la rangée, défi et progression affichés pour les camarades verrouillés (aussi à la Caserne).
- [x] Caméra en jeu : inclinaison verticale à la souris, au stick droit et avec Page haut / Page bas.
- Ensuite (demande du créateur) : le reste des niveaux.

## Lot 7 — objets en main et finitions des têtes (22/11/2026)
- [x] Le marteau générique est remplacé par un objet propre à chaque camarade (KayKit CC0, `assets/kaykit_props`) : marteau, carte roulée, fusil, poêle, pistolet, clé à molette, fourche, chope, clé plate, maillet, Petit Livre, truelle, torche enflammée, cuillère, bâton à étoile.
- [x] Chapeaux enfoncés dans les cheveux (le haut du modèle est une mèche, pas le crâne) ; correction de hauteur pour le corps « Knight » ; lunettes de soleil au niveau des yeux ; casque de tankiste refait (bourrelets bas, lunettes sur le front) ; barbe recollée au menton.

## Lot 8 — 9 zones en 3 actes, cartes géantes (22/11/2026)
- [x] Cartes ~1,7× plus grandes (≈ 250-300 m de côté) : coffres, autels et objets cassables proportionnels à la surface.
- [x] Blocs d'immeubles hauts à l'intérieur de l'arène (22-30 % des lots) : on ne voit plus toute la carte en tournant la caméra. Ils deviennent transparents quand ils cachent le joueur (la caméra ne se rapproche plus), et servent d'occulteurs (ce qui est derrière n'est pas dessiné).
- [x] Acte I : Hypermarché, Quartier d'Affaires, Bourse (modifiés : plus grands, blocs hauts).
- [x] Acte II : Paradis Fiscal (plage, marina, boîtes aux lettres, hôtels, mer à l'horizon ; boss : le Domicilié), Start-up Nation (espace bien-être, livreurs, food trucks ; boss : la Licorne), Centre de Données (salles de serveurs, refroidissement, drones ; boss : l'Algorithme).
- [x] Acte III : Station du 1 % (neige, chalets, sapins, télésiège, pistes, falaises ; boss : le Rentier), Fusée du Milliardaire (pas de tir, tours de lancement, gravité réduite ; boss : l'Exilé Spatial), Le Grand Soir (défilé, tribunes, lampions, feux d'artifice ; boss : le Marché Lui-Même).
- [x] Ennemis rhabillés et renommés selon la zone ; une run = un acte (victoire au boss des zones 3, 6, 9) ; zone de départ choisie parmi les 9.

## Lot 9 — effets d'armes (22/11/2026)
- [x] Nouveau module `scripts/vfx.gd` : vrais systèmes de particules avec le Kenney Particle Pack complet (CC0) : feu vivant (flammes, langues, braises, fumée, sol brûlé et lueur), traînée de feu de la glissade en continu, explosions (éclair, boule de feu, étincelles, fumée, débris, onde au sol, trace brûlée), impacts à étincelles, flashs de tir, traînées de fumée / feu / étincelles sur les projectiles, vapeur du samovar, ondes sonores du haut-parleur, nuage de poussière des coups de marteau.
- [x] Look-dev des effets : `lookdev/vfx.tscn`.
- Ensuite (demande du créateur) : identité propre à chaque niveau avec ennemis et boss spécifiques.

## Lot 10 — coop en ligne 2 à 4 (22/11/2026)
- [x] Moteur à plusieurs camarades : armes, ultime et passif propres ; XP, niveau, roubles et décrets communs ; choix de cartes simultanés ; mise à terre et relève (3 s) ; difficulté et XP ajustées au nombre de joueurs ; les ennemis chassent le camarade le plus proche.
- [x] Réseau (`scripts/net.gd`, ENet, port 24517 UDP, UPnP) : l'hôte calcule tout, les camarades envoient leur position et leurs actions, reçoivent 15 instantanés/s (ennemis proches, joueurs, niveau…) et les événements (butin, coffres, sanctuaires, attaques ennemies, choix, fin de partie, changement de zone).
- [x] Écran « Jouer en ligne » (héberger / rejoindre / salon, choix du camarade, zone, difficulté). Notice : `JOUER_EN_LIGNE.txt`.
- [x] Testé à 2 et 3 instances sur la même machine (pas encore entre deux vraies connexions internet).
- Ensuite : identité propre à chaque niveau (ennemis et boss spécifiques).

## Lot 11 — retours de test (22/11/2026)
- [x] Solo : plus de barres de camarades ni de message « les camarades choisissent » (l'affichage du HUD les révélait).
- [x] Vrai mur d'enceinte (briques/béton/métal selon la zone, piliers, affiches, slogans) exactement là où le joueur est bloqué ; immeubles du pourtour collés derrière.
- [x] Les ennemis sautent sur les plates-formes depuis n'importe quel bord (et en redescendent), et montent sur les conteneurs.
- [x] Textes des cartes de récompense et de l'écran de fin réduits automatiquement pour tenir dans leur cadre.
- [x] Manette dans les menus (autoload `Pad` : focus automatique, stick gauche, A/B ; gâchettes pour changer de camarade).
- [x] 8 nouvelles musiques originales, une par zone (+ salon en ligne).
- [x] Affichage des PV : plus de 159/158 (arrondi).

## Réponses du créateur (questionnaire du 21/11/2026)
**À faire maintenant :**
- Personnages : taille des capitalistes inchangée ; ennemis tués = **disparition immédiate** (pas de cadavre) ; pas d'animation de frappe du héros ; je propose les 5e/6e camarades ; **skins débloquables** oui.
- Mini-carte : **M** = petite ↔ off, **Tab** = grande carte ; **pas d'ennemis normaux** dessus, seulement le reste (coffres, sanctuaires, élites, boss, météo, bâtiments) ; en haut à droite.
- Run : **3 zones × 10 min = 30 min** ; boss de zone tué → une porte s'ouvre, on garde le build ; niveaux suivants **au choix de Claude** ; zone N débloquée après avoir battu le boss de N-1 ; **mode Sans fin** après la 1re victoire ; **3 niveaux de difficulté** débloquables.
- Armes : **20 armes**, certains camarades ont une **arme de départ différente** ; évolutions **des deux types** (arme max + décret précis, ET fusion de deux armes) ; **4 emplacements** + 1 achetable ; **pas de statuts élémentaires** à synergies ; **pas de reliques**.

**Gardé pour plus tard (questions encore ouvertes) :** méta (vitesse des grades, familiers/gacha, quêtes/succès, 1 ou 2 monnaies), menus (menu titre, langues, manette, touches, options graphiques), son/musique/voix, histoire et limites de l'humour, cibles d'équilibrage, plateformes et fréquence des zips.

## Critiques du genre à garder en tête (recherche faite)
Répétitivité (peu de cartes/ennemis), grind ou progression triviale, brouillard visuel, manque de retour sur les dégâts, difficulté artificielle (juste des chiffres), fin de partie injuste et trop de hasard, personnages trop semblables, accumulation d'objets qui fait ramer, musique qui lasse, peu d'histoire.
