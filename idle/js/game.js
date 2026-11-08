/*
 * Cosmos Infini : moteur du jeu (aucune dépendance au DOM).
 *
 * Boucle de base : 8 générateurs en chaîne. Chaque générateur produit le
 * précédent, les Particules produisent la Poussière. Tous les 10 achats d'un
 * générateur, sa production est multipliée.
 *
 * Couches de prestige (chacune remet à zéro tout ce qui est en dessous) :
 *   1. Supernova    -> Éclats           (depuis la Poussière)
 *   2. Effondrement -> Singularités     (depuis les Éclats)
 *   3. Big Bang     -> Points d'Infini  (Poussière plafonnée à l'Infini, défis, briser l'Infini)
 *   4. Éternité     -> Points d'Éternité (depuis les Points d'Infini)
 *   5+. Strates     -> générées à l'infini, chacune nourrie par la précédente.
 */
(function (root) {
  'use strict';
  const Big = root.Big;
  const B = (x) => Big.from(x);
  const P = (l) => Big.pow10(l);
  const INF = Big.INF;
  const INF_LOG = INF.log10();

  // ------------------------------------------------------------------
  // Données
  // ------------------------------------------------------------------
  const GENS = [
    { name: 'Aisselles de stagiaire', icon: 'sweat', base: 1, step: 3.6, flavor: "Il a cru que le déo était une dépendance optionnelle du package.json. Personne ne lui a dit. Personne ne lui parle." },
    { name: 'Chaussettes de sysadmin', icon: 'sock', base: 2, step: 4.8, flavor: 'Portées depuis le dernier reboot du serveur. Uptime : 847 jours.' },
    { name: 'Mugs de café fermenté', icon: 'mug', base: 4, step: 6, flavor: 'Le fond a développé une conscience et réclame des congés payés.' },
    { name: 'Cartons de pizza de la mise en prod', icon: 'pizza', base: 6, step: 7.2, flavor: "Datés de 2019. Un dev a goûté. On a gardé son badge en souvenir." },
    { name: 'Hoodies de conférence tech', icon: 'hoodie', base: 9, step: 9.6, flavor: "Pas lavé depuis la DevFest. Il tient debout tout seul et vote aux élections du CSE." },
    { name: 'Claviers mécaniques gras', icon: 'keyboard', base: 13, step: 12, flavor: "40 % plastique, 60 % croûtes. Le support refuse d'y toucher sans combinaison." },
    { name: 'Open spaces sans clim', icon: 'office', base: 18, step: 14.4, flavor: "Les plantes sont mortes en premier. Puis Kevin, de la compta." },
    { name: 'Datacenters sans ventilation', icon: 'rack', base: 24, step: 18, flavor: "Même les serveurs transpirent. Le technicien de maintenance n'est jamais remonté." },
  ];
  const ACCEL = { base: 3, step: 1 };

  // Le défi n°i se débloque après 4 + 3×i Big Bangs (7, 10, 13, 16, 19, 22).
  const CHALLENGES = [
    { id: 'c1', name: 'Ventilo HS', desc: "Ton laptop est mort, lui aussi. Le Laptop qui chauffe n'a aucun effet.", reward: 'Laptop qui chauffe +0,02 par achat.' },
    { id: 'c2', name: 'Gel des mises en prod', desc: 'Le DSI a gelé les mises en prod. Même le vendredi. Ce connard.', reward: 'Effet des Bugs en prod : exposant +0,2.' },
    { id: 'c3', name: 'Télétravail imposé', desc: "On t'a viré de l'open space. Seules tes affaires perso (générateurs 1 à 4) puent encore.", reward: "Générateurs 1 à 4 ×(1 + Plaintes RH)." },
    { id: 'c4', name: 'Budget gelé par la DAF', desc: 'La DAF a coupé les budgets. Tout coûte 50 % plus cher, même ta dignité.', reward: 'Hausse des prix des générateurs −5 %.' },
    { id: 'c5', name: 'Semaine du bien-être', desc: 'Burn-out interdit. Yoga à 8 h, méditation à 9 h, licenciements à 10 h.', reward: 'Gain de Points de cynisme ×5.' },
    { id: 'c6', name: 'Déodorant offert par l\'équipe', desc: "Avec un petit mot : « Pour toi, gros dégueulasse. » Les Relents sont mis à la puissance 0,75.", reward: 'Exposant de production +0,03.' },
  ];
  const BREAK_CHALLENGES = 4;
  const ETER_REQ = +(globalThis.__ETER_REQ || 116); // calé pour une 1re Éternité vers 1,5 jour (bon joueur)
  // Durée minimale d'une partie avant de pouvoir refaire le même prestige (manuel ou
  // automatique). Sans elle, tapoter le bouton le plus vite possible bat les automates.
  const MIN_RUN = 10;

  // ------------------------------------------------------------------
  // État
  // ------------------------------------------------------------------
  let S = null;
  let M = null; // modificateurs recalculés à chaque tick
  const listeners = [];

  function newLayerState() {
    return { cur: Big.ZERO, total: Big.ZERO, best: Big.ZERO, resets: 0, time: 0, upg: {}, auto: { on: false, mode: 'mult', value: 10 } };
  }

  function newState() {
    return {
      version: 2,
      dust: B(10),
      gens: GENS.map(() => ({ amount: Big.ZERO, bought: 0 })),
      accel: 0,
      layers: {},
      chal: { active: null, done: {} },
      seen: {},
      auto: { gens: false, accel: false, snUpg: true },
      stats: { time: 0, bestDust: B(10), totalDust: Big.ZERO, created: Date.now(), admin: false, firsts: {} },
      options: { notation: 'scientifique', buy: '1', offline: true, admin: false, adminSpeed: 1 },
      lastTick: Date.now(),
    };
  }

  function lay(k) {
    let l = S.layers[k];
    if (!l) { l = S.layers[k] = newLayerState(); }
    return l;
  }
  function lvl(k, id) { const l = S.layers[k]; return (l && l.upg[id]) || 0; }
  function resets(k) { const l = S.layers[k]; return l ? l.resets : 0; }
  function cur(k) { const l = S.layers[k]; return l ? l.cur : Big.ZERO; }
  function chalDone(id) { return !!S.chal.done[id]; }
  function chalCount() { return Object.keys(S.chal.done).filter((k) => S.chal.done[k]).length; }
  function inChal(id) { return S.chal.active === id; }
  function isBroken() { return lvl(3, 'in_break') > 0 && !S.chal.active; }

  function emit(type, data) { listeners.forEach((f) => f(type, data)); }

  // ------------------------------------------------------------------
  // Définitions des couches
  // ------------------------------------------------------------------
  const R = (base, mult) => (l) => base + mult * l; // coût en log10

  const FIXED = {
    1: {
      name: 'Mise en prod du vendredi', verb: 'Mise en prod', cur: 'Bugs en prod', sym: 'bug',
      flavor: "17 h 58. Tu push en prod sans tests et tu te casses. L'astreinte, c'est le collègue resté au bureau. Il ne respire déjà plus très bien.",
      reqLog: 15,
      reqText: () => 'Atteins 1e15 Relents',
      sourceLog: () => S.dust.log10(),
      rawLog() {
        const l = S.dust.log10();
        if (l < 15) return -Infinity;
        return ((l - 15) / 4) * (1 + 0.05 * lvl(4, 'et_shard'));
      },
      blocked: () => inChal('c2') ? 'Bloqué par le défi « Sans étoiles »' : null,
      effectText: () => 'Production ×' + fmt(shardEffect()) + capNote(1, shardExp()),
      upgrades: [
        { id: 'sn_fusion', name: 'Code spaghetti', flavor: "Personne ne sait pourquoi ça marche. Le mec qui l'a écrit est mort. Ne touche à rien.", desc: () => 'Production ×2 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(0, Math.log10(3)), max: Infinity },
        { id: 'sn_pulsar', name: 'Ventilo overclocké', flavor: "Il souffle ta crasse jusqu'au 3e étage. Le 3e étage a porté plainte.", desc: () => 'Laptop qui chauffe +0,01 par achat', eff: (l) => '+' + (0.01 * l).toFixed(2), cost: R(0.5, 0.6), max: 10 },
        { id: 'sn_remnant', name: 'Odeur résiduelle', flavor: "Même après ta mort, la salle de réunion se souviendra de toi.", desc: () => 'Commence avec plus de Relents après chaque prestige', eff: (l) => fmt(startDust()), cost: R(0.7, 0.9), max: 5 },
        { id: 'sn_gravity', name: 'Attraction des mouches', flavor: "Elles ont monté un syndicat. Il a plus de membres que celui des devs.", desc: () => 'Aisselles ×(1 + log(Relents))^1,5', eff: () => '×' + fmt(gravityEffect()), cost: R(1.4, 0), max: 1 },
        { id: 'sn_mass', name: 'Masse critique de linge sale', flavor: "Le panier a pris conscience. Il réclame un exorcisme.", desc: () => 'Bonus par 10 achats +0,05', eff: (l) => '×' + (M ? M.perTen : 2).toFixed(2), cost: R(2, 1), max: 5 },
        { id: 'sn_echo', name: 'Hotfix du hotfix', flavor: "Chaque correctif crée deux bugs. Ton manager appelle ça « la croissance ».", desc: () => 'Gain de Bugs en prod ×2 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(3, 0.7), max: Infinity },
        { id: 'sn_nova', name: 'Dette technique', flavor: "Les intérêts sont composés. Ton odeur aussi. Les deux finiront par tuer quelqu'un.", desc: () => 'Effet des Bugs en prod : exposant +0,05', eff: (l) => '^' + shardExp().toFixed(2), cost: R(4, 2), max: 5 },
      ],
      milestones: [],
    },
    2: {
      name: 'Burn-out', verb: 'Burn-out', cur: 'Points de cynisme', sym: 'skull',
      flavor: "Tu craques, tu chiales dans les chiottes, tu reviens et tu pues encore plus. Les RH appellent ça « résilience ».",
      reqLog: 9,
      reqText: () => 'Atteins 1e9 Bugs en prod',
      sourceLog: () => cur(1).log10(),
      rawLog() {
        const l = cur(1).log10();
        if (l < 9) return -Infinity;
        return (l - 9) / 6;
      },
      blocked: () => inChal('c5') ? 'Bloqué par le défi « Vide quantique »' : null,
      effectText: () => 'Production ×' + fmt(P(curEffLog(2, 3))) + capNote(2, 3) + ', gain de Bugs ×' + fmt(P(curEffLog(2))),
      upgrades: [
        { id: 'co_horizon', name: 'Café à 4 h du matin', flavor: "Ton haleine est classée Seveso seuil haut.", desc: () => 'Production ×5 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(5))), cost: R(0, 0.5), max: Infinity },
        { id: 'co_spaghetti', name: 'Réunion qui aurait pu être un mail', flavor: "1 h 30, 14 personnes, 0 fenêtre. Deux malaises, un procès-verbal.", desc: () => 'Gain de Bugs en prod ×3 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(3))), cost: R(0.3, 0.6), max: Infinity },
        { id: 'co_hawking', name: 'Fuite de mémoire', flavor: "La RAM fuit, toi aussi, par tous les pores. Aucun des deux n'a été patché.", desc: () => 'Gagne passivement 1 % par seconde du gain de Mise en prod', eff: (l) => l + ' %/s', cost: R(0.7, 1), max: 10 },
        { id: 'co_density', name: 'Sueur concentrée', flavor: "Réduite à feu doux pendant un sprint de 3 semaines. Interdite dans 12 pays.", desc: () => 'Exposant de production +0,01', eff: (l) => '^' + (M ? M.prodExp : 1).toFixed(2), cost: R(1, 1.4), max: 5 },
        { id: 'co_bulk', name: 'Compression (des données et du linge)', flavor: "Tout tient dans un seul sac. Le sac a demandé à être incinéré.", desc: () => 'Hausse des prix des générateurs −1 %', eff: (l) => '−' + l + ' %', cost: R(1.4, 1), max: 5 },
      ],
      milestones: [
        { n: 1, text: 'Un stagiaire achète les générateurs à ta place (il n\'a pas le choix)' },
        { n: 3, text: 'Achat automatique du Laptop qui chauffe' },
        { n: 5, text: 'Garde les améliorations de Mise en prod lors d\'un Burn-out' },
        { n: 8, text: 'Mise en prod automatique (le vendredi, évidemment)' },
      ],
    },
    3: {
      name: "Évacuation de l'open space", verb: 'Évacuation', cur: 'Plaintes RH', sym: 'alarm',
      flavor: "L'air de l'étage est officiellement une arme chimique. Les pompiers évacuent tout le monde sauf toi : personne n'a voulu te toucher.",
      reqLog: INF_LOG,
      reqText: () => 'Atteins le seuil de la Convention de Genève (1,8e308 Relents)',
      sourceLog: () => S.dust.log10(),
      rawLog() {
        const l = S.dust.log10();
        if (l < INF_LOG - 1e-9) return -Infinity;
        if (isBroken()) return Math.max(0, (l - INF_LOG) / 40);
        return 0;
      },
      blocked: () => null,
      effectText: () => 'Production ×' + fmt(P(curEffLog(3, 2))) + capNote(3, 2),
      upgrades: [
        { id: 'in_time', name: 'Laisser mariner', flavor: "Comme un camembert. Mais en sueur et en Java.", desc: () => 'Production ×(1 + minutes depuis la dernière Évacuation)^1,5', eff: () => '×' + fmt(timeEffect()), cost: R(0, 0), max: 1 },
        { id: 'in_count', name: 'Réputation', flavor: "Ton nom est dans le règlement intérieur, article 12 : « Ne pas faire comme lui. »", desc: () => 'Production ×(1 + nombre d\'Évacuations)²', eff: () => '×' + fmt(B(resets(3) + 1).pow(2)), cost: R(0, 0), max: 1 },
        { id: 'in_sn', name: 'Bugs légendaires', flavor: "Tes bugs ont leur page Wikipédia et un fan-club sur Stack Overflow.", desc: () => 'Gain de Bugs en prod ×(1 + Plaintes RH)^0,5', eff: () => '×' + fmt(P(curEffLog(3, 0.5))), cost: R(0.3, 0), max: 1 },
        { id: 'in_gen', name: 'Effet de groupe', flavor: "Toute l'équipe s'est alignée sur ton hygiène. Le bailleur a résilié le bail.", desc: () => 'Bonus par 10 achats +0,25', eff: () => '+0,25', cost: R(0.7, 0), max: 1 },
        { id: 'in_auto', name: 'Alarme incendie connectée', flavor: "Elle se déclenche quand tu badges. Le seul objet connecté de la boîte qui marche.", desc: () => 'Débloque l\'Évacuation automatique', eff: () => 'Débloqué', cost: R(1, 0), max: 1 },
        { id: 'in_ipmult', name: 'Délation anonyme', flavor: "Le formulaire RH a un champ « odeur ». Il est obligatoire et pré-rempli avec ton nom.", desc: () => 'Plaintes RH ×2 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(1, 0.5), max: Infinity },
        { id: 'in_hawk', name: 'Burn-out chronique', flavor: "Tu ne craques plus, tu fuis en continu, comme un vieux serveur Windows.", desc: () => 'Gagne passivement 1 % par seconde du gain de Burn-out', eff: (l) => l + ' %/s', cost: R(1.5, 0.5), max: 10 },
        {
          id: 'in_break', name: 'Violer la Convention de Genève', flavor: "Ton odeur est une arme non conventionnelle. La Haye a ouvert un dossier.", desc: () => 'Les Relents dépassent le seuil légal et l\'Évacuation rapporte plus', eff: () => 'Brisé',
          cost: R(4, 0), max: 1,
          req: () => chalCount() >= BREAK_CHALLENGES, reqText: () => 'Survis à ' + BREAK_CHALLENGES + ' plans RH (' + chalCount() + '/' + BREAK_CHALLENGES + ')',
        },
        { id: 'in_postcost', name: 'Lobbying', flavor: "Un sénateur a reniflé ton hoodie. Il a signé, puis il a vomi sur le texte.", desc: () => 'Hausse des prix au-delà du seuil légal −10 %', eff: (l) => '−' + 10 * l + ' %', cost: R(3, 1), max: 3, req: () => lvl(3, 'in_break') > 0, reqText: () => "Brise l'Infini" },
        { id: 'in_prodpow', name: 'Pipeline MLOps', flavor: "Ta puanteur est déployée en continu, avec monitoring et alerting. Surtout l'alerting.", desc: () => 'Exposant de production +0,01', eff: (l) => '^' + (M ? M.prodExp : 1).toFixed(2), cost: R(4, 3), max: 5, req: () => lvl(3, 'in_break') > 0, reqText: () => "Brise l'Infini" },
      ],
      milestones: [
        { n: 1, text: 'Production ×10 par plan RH survécu' },
        { n: 2, text: 'Garde les améliorations de Mise en prod lors d\'une Évacuation' },
        { n: 3, text: 'Burn-out automatique (enfin un truc qui marche tout seul)' },
        { n: 4, text: 'Achat automatique des améliorations de Mise en prod' },
        { n: 5, text: 'Garde les améliorations de Burn-out lors d\'une Évacuation' },
        { n: 10, text: 'Gagne passivement 10 % par seconde du gain de Mise en prod' },
      ],
    },
    4: {
      name: 'Licenciement', verb: 'Licenciement', cur: 'Lettres de licenciement', sym: 'carton',
      flavor: "Motif : « faute olfactive grave ». Le vigile t'a sorti avec une perche de 3 mètres. Ton carton a été brûlé sur le parking.",
      reqLog: ETER_REQ,
      reqText: () => 'Accumule ' + fmt(P(ETER_REQ)) + ' Plaintes RH',
      sourceLog: () => cur(3).log10(),
      rawLog() {
        const l = cur(3).log10();
        if (l < ETER_REQ) return -Infinity;
        return (l - ETER_REQ) / 10;
      },
      blocked: () => S.chal.active ? 'Quitte le défi en cours' : null,
      effectText: () => 'Plaintes RH ×' + fmt(P(curEffLog(4))) + ', production ×' + fmt(P(curEffLog(4, 3))) + capNote(4),
      upgrades: [
        { id: 'et_ip', name: 'Avocat aux prud\'hommes', flavor: "Il plaide avec un masque à gaz. Il a quand même perdu l'odorat.", desc: () => 'Plaintes RH ×5 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(5))), cost: R(0, 0.5), max: Infinity },
        { id: 'et_prod', name: 'Fermentation lente', flavor: "Le temps travaille pour toi. Contre tous les autres.", desc: () => 'Exposant de production +0,005', eff: (l) => '+' + (0.005 * l).toFixed(3).replace('.', ','), cost: R(0.3, 0.7), max: 5 },
        { id: 'et_time', name: 'Jet lag Paris–San Francisco', flavor: "11 h d'avion dans le même t-shirt. L'équipage a demandé un atterrissage d'urgence.", desc: () => 'Vitesse du jeu +25 %', eff: (l) => '×' + (1 + 0.25 * l).toFixed(2), cost: R(0.7, 1), max: 8 },
        { id: 'et_passive', name: 'Rumeurs de couloir', flavor: "Les plaintes arrivent avant toi. Les ambulances aussi.", desc: () => 'Gagne passivement 1 % par seconde du gain d\'Évacuation', eff: (l) => l + ' %/s', cost: R(1, 1), max: 10 },
        { id: 'et_shard', name: 'Bugs fossilisés', flavor: "Retrouvés dans du COBOL de 1974. Ils puent presque autant que toi.", desc: () => 'Gain de Bugs en prod : exposant +5 %', eff: (l) => '+' + 5 * l + ' %', cost: R(0.5, 0.8), max: 5 },
        { id: 'et_gens', name: 'Harmonie olfactive', flavor: "Tes chaussettes et ton café jouent enfin la même note : la mort.", desc: () => 'Bonus par 10 achats +0,0625', eff: (l) => '+' + (0.0625 * l).toFixed(3).replace('.', ','), cost: R(0.6, 0.6), max: 4 },
      ],
      milestones: [
        { n: 1, text: 'Garde les améliorations d\'Évacuation' },
        { n: 2, text: 'Évacuation automatique' },
        { n: 3, text: 'Plaintes RH ×(1 + nombre de Licenciements)' },
        { n: 5, text: 'Gagne passivement 5 % par seconde du gain d\'Évacuation' },
      ],
    },
  };

  const META_NAMES = ['Startup', 'Licorne', 'GAFAM', 'Ministère du Numérique', 'Commission européenne', 'ONU', 'Atmosphère', 'Système solaire', 'Galaxie', 'Multivers'];
  const META_FLAVORS = ['Tu lèves 2 M€. Les investisseurs ont signé en apnée, deux sont restés au parking.', 'Valorisée 1 milliard. Personne n\'a jamais mis les pieds au bureau. Personne n\'est assez con.', 'On t\'a racheté pour t\'enterrer. Raté : ton odeur tourne maintenant sur 40 000 serveurs.', 'Nommé « référent IA ». Le ministre démissionne, déménage, puis porte plainte.', 'Une directive porte ton nom. Elle oblige à souder les fenêtres de tes bureaux.', 'Résolution 2847 : ta puanteur menace la paix mondiale. Les Casques bleus ont refusé la mission.', 'Le GIEC ajoute une courbe à ses rapports. Elle s\'appelle « toi ».', 'Les sondes Voyager ont fait demi-tour pour te fuir.', 'La Voie lactée a demandé à changer de nom.', 'Dans tous les univers parallèles, tu pues. C\'est la seule constante physique.'];
  const META_SYMS = [];
  // seuil d'une strate : croît avec la profondeur (sinon les strates s'enchaînent en cascade)
  const META_REQS = { 5: 21.3, 6: 8, 7: 12.3 }; // Multivers ~3 j, Omnivers ~8-9 j, Hypervers ~3 semaines
  const metaReq = (k) => (globalThis.__META_REQ ? globalThis.__META_REQ(k) : META_REQS[k] !== undefined ? META_REQS[k] : 12.3 + 1.5 * (k - 7));

  function roman(n) {
    const t = [[1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'], [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']];
    let s = '';
    for (const [v, r] of t) while (n >= v) { s += r; n -= v; }
    return s;
  }

  const metaCache = {};
  function metaLayer(k) {
    if (metaCache[k]) return metaCache[k];
    const i = k - 5;
    const name = i < META_NAMES.length ? META_NAMES[i] : 'Strate ' + roman(k);
    const prev = layerDef(k - 1);
    const d = {
      name, verb: name, cur: 'Essence ' + (/^[AEIOUÉÈÊHaeiouéè]/.test(name) ? "d'" : 'de ') + name, sym: 'cloud',
      flavor: i < META_FLAVORS.length ? META_FLAVORS[i] : 'Strate ' + roman(k) + ' : la science a abandonné. Les mouches, jamais.',
      meta: true,
      reqLog: metaReq(k),
      reqText: () => 'Atteins ' + fmt(P(metaReq(k))) + ' ' + prev.cur,
      sourceLog: () => cur(k - 1).log10(),
      rawLog() {
        const l = cur(k - 1).log10();
        if (l < metaReq(k)) return -Infinity;
        return (l - metaReq(k)) / 4;
      },
      blocked: () => S.chal.active ? 'Quitte le défi en cours' : null,
      effectText: () => prev.cur + ' ×' + fmt(P(curEffLog(k))) + ', production ×' + fmt(P(curEffLog(k, 2))) + capNote(k),
      upgrades: [
        { id: 'g_gain', name: 'Lobbying olfactif', desc: () => 'Gain de ' + prev.cur + ' ×3 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(3))), cost: R(0, 0.5), max: Infinity },
        { id: 'g_prod', name: 'Diffusion ' + roman(k - 4), desc: () => 'Production ×1000 par niveau', eff: (l) => '×' + fmt(P(l * 3)), cost: R(0, 0.3), max: Infinity },
        { id: 'g_self', name: 'Récursion sans condition d\'arrêt', desc: () => 'Gain de ' + name + ' ×2 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(1, 1), max: Infinity },
        { id: 'g_speed', name: 'Nuits blanches', desc: () => 'Vitesse du jeu +10 %', eff: (l) => '×' + (1 + 0.1 * l).toFixed(1), cost: R(0.7, 0.7), max: 10 },
        { id: 'g_passive', name: 'Fuite de gaz', desc: () => 'Gagne passivement 1 % par seconde du gain de ' + prev.name, eff: (l) => l + ' %/s', cost: R(0.5, 0.8), max: 10 },
      ],
      milestones: [
        { n: 1, text: 'Garde toutes les améliorations des couches inférieures, ' + prev.name + ' automatique' },
      ],
    };
    metaCache[k] = d;
    return d;
  }

  function layerDef(k) { return k <= 4 ? FIXED[k] : metaLayer(k); }

  // nombre de couches à considérer (les 4 fixes + les strates découvertes + 1)
  function layerCount() {
    let n = 4;
    while (S.seen[n + 1] || resets(n + 1) > 0) n++;
    return n;
  }

  // ------------------------------------------------------------------
  // Effets
  // ------------------------------------------------------------------
  function shardExp() {
    return 1.15 + 0.05 * lvl(1, 'sn_nova') + (chalDone('c2') ? 0.2 : 0);
  }
  // Plafond progressif : au-delà de « cap » (en log10), un effet ne croît plus
  // qu'à la puissance 0,7. Garantit qu'aucune boucle prestige → production → prestige
  // ne peut s'emballer, quel que soit le nombre de resets.
  const CAPS = { 1: 60, 2: 60, 3: 60, 4: 60, meta: +(globalThis.__META_CAP || 10) };
  function capLog(L, cap) { return L <= cap ? L : cap * Math.pow(L / cap, 0.7); }
  function curEffLog(k, mult) {
    const L = cur(k).add(1).log10() * (mult || 1);
    return capLog(L, k <= 4 ? CAPS[k] : CAPS.meta);
  }
  function capped(k, mult) { return cur(k).add(1).log10() * (mult || 1) > (k <= 4 ? CAPS[k] : CAPS.meta); }
  function capNote(k, mult) { return capped(k, mult) ? ' (plafonné)' : ''; }
  function shardEffect() { return P(curEffLog(1, shardExp())); }
  function gravityEffect() { return B(1 + Math.max(0, S.dust.log10())).pow(1.5); }
  function timeEffect() { return B(1 + lay(3).time / 60).pow(1.5); }
  // toujours sous le seuil de Supernova (1e15), sinon Supernova en boucle sans attendre
  function startDust() {
    return P(1 + 2.5 * lvl(1, 'sn_remnant'));
  }

  // à quel niveau de prestige les améliorations de la couche j survivent
  function keepLevel(j) {
    let k = 0;
    if (j === 1) {
      if (resets(2) >= 5) k = 2;
      if (resets(3) >= 2) k = 3;
    }
    if (j === 2 && resets(3) >= 5) k = 3;
    if (j <= 3 && resets(4) >= 1) k = 4;
    const n = layerCount();
    for (let m = 5; m <= n + 1; m++) if (m > j && resets(m) >= 1) k = Math.max(k, m);
    return k;
  }

  function autoUnlocked(k) {
    if (k === 1) return resets(2) >= 8;
    if (k === 2) return resets(3) >= 3;
    if (k === 3) return lvl(3, 'in_auto') > 0 || resets(4) >= 2;
    return resets(k + 1) >= 1;
  }
  const SN_AUTO_AT = 4; // Big Bangs nécessaires pour l'achat automatique des améliorations de Supernova
  function autoSnUpgUnlocked() { return resets(3) >= SN_AUTO_AT || resets(4) >= 1; }
  // achète l'amélioration de Supernova la moins chère tant que c'est possible
  function autoBuySnUpgrades() {
    const d = layerDef(1);
    for (let guard = 0; guard < 50; guard++) {
      let best = null, bestC = null;
      for (const u of d.upgrades) {
        if (!upgAvailable(1, u) || lvl(1, u.id) >= u.max) continue;
        const c = upgCost(1, u);
        if (cur(1).gte(c) && (!bestC || c.lt(bestC))) { best = u; bestC = c; }
      }
      if (!best) break;
      buyUpg(1, best.id);
    }
  }
  function autoGensUnlocked() { return resets(2) >= 1 || resets(3) >= 1 || resets(4) >= 1; }
  function autoAccelUnlocked() { return resets(2) >= 3 || resets(3) >= 1 || resets(4) >= 1; }

  function computeMods() {
    const n = layerCount();
    const m = {};
    m.speed = 1 + 0.25 * lvl(4, 'et_time');
    for (let k = 5; k <= n; k++) m.speed *= 1 + 0.1 * lvl(k, 'g_speed');

    m.perTen = 2 + 0.05 * lvl(1, 'sn_mass') + (lvl(3, 'in_gen') ? 0.25 : 0) + 0.0625 * lvl(4, 'et_gens');
    m.accelBase = 1.15 + 0.01 * lvl(1, 'sn_pulsar') + (chalDone('c1') ? 0.02 : 0);
    m.accelOn = !inChal('c1');
    m.prodExp = 1 + 0.01 * lvl(2, 'co_density') + 0.01 * lvl(3, 'in_prodpow') + 0.005 * lvl(4, 'et_prod') + (chalDone('c6') ? 0.03 : 0);
    m.dustExp = m.prodExp * (inChal('c6') ? 0.75 : 1);
    m.costPow = (1 - 0.01 * lvl(2, 'co_bulk') - (chalDone('c4') ? 0.05 : 0)) * (inChal('c4') ? 1.5 : 1);
    m.postScale = 1.5 - 0.1 * lvl(3, 'in_postcost');

    // multiplicateur global (en log10 pour rester rapide)
    let lp = 0;
    lp += lvl(1, 'sn_fusion') * Math.log10(2);
    lp += shardEffect().log10();
    lp += lvl(2, 'co_horizon') * Math.log10(5);
    lp += curEffLog(2, 2.5);
    lp += curEffLog(3, 2);
    if (lvl(3, 'in_time')) lp += timeEffect().log10();
    if (lvl(3, 'in_count')) lp += 2 * Math.log10(resets(3) + 1);
    if (resets(3) >= 1) lp += chalCount();
    lp += curEffLog(4, 3);
    for (let k = 5; k <= n; k++) {
      lp += curEffLog(k, 2);
      lp += 3 * lvl(k, 'g_prod');
    }
    m.prodLog = lp;

    m.genLog = GENS.map(() => 0);
    if (lvl(1, 'sn_gravity')) m.genLog[0] += gravityEffect().log10();
    if (chalDone('c3')) for (let i = 0; i < 4; i++) m.genLog[i] += curEffLog(3);
    m.genOn = GENS.map((_, i) => !(inChal('c3') && i >= 4));

    // multiplicateurs de gain par couche (log10)
    m.gainLog = {};
    for (let k = 1; k <= n; k++) m.gainLog[k] = 0;
    m.gainLog[1] += lvl(1, 'sn_echo') * Math.log10(2) + lvl(2, 'co_spaghetti') * Math.log10(3) + curEffLog(2);
    if (lvl(3, 'in_sn')) m.gainLog[1] += curEffLog(3, 0.5);
    if (chalDone('c5')) m.gainLog[2] += Math.log10(5);
    m.gainLog[3] += lvl(3, 'in_ipmult') * Math.log10(2) + lvl(4, 'et_ip') * Math.log10(5) + curEffLog(4);
    if (resets(4) >= 3) m.gainLog[3] += Math.log10(resets(4) + 1);
    for (let k = 5; k <= n + 1; k++) {
      if (m.gainLog[k - 1] === undefined) continue;
      m.gainLog[k - 1] += curEffLog(k) + lvl(k, 'g_gain') * Math.log10(3);
      if (m.gainLog[k] !== undefined) m.gainLog[k] += lvl(k, 'g_self') * Math.log10(2);
    }

    // gains passifs (fraction par seconde)
    m.passive = {};
    m.passive[1] = 0.01 * lvl(2, 'co_hawking') + (resets(3) >= 10 ? 0.1 : 0);
    m.passive[2] = 0.01 * lvl(3, 'in_hawk');
    m.passive[3] = 0.01 * lvl(4, 'et_passive') + (resets(4) >= 5 ? 0.05 : 0);
    for (let k = 5; k <= n; k++) m.passive[k - 1] = (m.passive[k - 1] || 0) + 0.01 * lvl(k, 'g_passive');
    return m;
  }

  // ------------------------------------------------------------------
  // Générateurs
  // ------------------------------------------------------------------
  function scaleLog(lc) {
    if (lc > INF_LOG) lc = INF_LOG + (lc - INF_LOG) * M.postScale;
    return lc;
  }
  // le prix augmente de 12 % à chaque achat, puis fait un grand saut tous les 10 achats
  const UNIT_STEP = Math.log10(1.12);
  function genCostLog(i, bought) {
    const g = GENS[i];
    return scaleLog(g.base + g.step * M.costPow * Math.floor(bought / 10) + (bought % 10) * UNIT_STEP);
  }
  function genCost(i) { return P(genCostLog(i, S.gens[i].bought)); }
  // multiplicateur propre à un générateur (bonus par 10 achats, Accélérateur)
  function genMultLog(i) {
    let l = M.genLog[i] + Math.floor(S.gens[i].bought / 10) * Math.log10(M.perTen);
    if (i === 0) l += M.prodLog; // le multiplicateur global ne s'applique qu'à la Poussière
    if (i === 0 && M.accelOn) l += S.accel * Math.log10(M.accelBase); // l'Accélérateur ne touche que la Poussière
    return l;
  }
  function genMult(i) { return P(genMultLog(i)); }

  // « Exposant critique » E : de combien le log de la production augmente quand le
  // log de la Poussière augmente de 1 (si on dépense tout en achats). Si E ≥ 1 la
  // production s'emballe (croissance explosive qui dépend de la vitesse des ticks).
  function criticalExponent(mods) {
    const m = mods || M;
    let e = 0;
    for (const g of GENS) e += Math.log10(m.perTen) / (g.step * m.costPow);
    e += Math.log10(m.accelBase) / (ACCEL.step * m.costPow);
    return e * m.prodExp;
  }
  function genUnlocked(i) {
    if (!M.genOn[i]) return false;
    return i === 0 || S.gens[i - 1].bought > 0 || S.gens[i].bought > 0;
  }

  // log10 de la somme des prix des achats n° from … from+n-1 (prix croissants).
  // Seuls les 80 derniers comptent : les précédents sont négligeables (×1e3 au moins tous les 10 achats).
  function sumLog(costLog, from, n) {
    if (n <= 0) return -Infinity;
    const top = costLog(from + n - 1);
    let acc = 0;
    for (let j = from + n - 1; j >= Math.max(from, from + n - 80); j--) acc += Math.pow(10, costLog(j) - top);
    return top + Math.log10(acc);
  }
  // nombre d'achats possibles (au plus « limit ») avec la Poussière actuelle
  function affordable(costLog, from, limit) {
    const have = S.dust.log10();
    if (have === -Infinity || costLog(from) > have) return 0;
    let hi = 1;
    while (hi < limit && sumLog(costLog, from, Math.min(hi * 2, limit)) <= have) hi = Math.min(hi * 2, limit);
    if (hi >= limit) return limit;
    let lo = hi; hi = Math.min(hi * 2, limit); // lo achetable, hi non
    while (hi - lo > 1) { const mid = Math.floor((lo + hi) / 2); if (sumLog(costLog, from, mid) <= have) lo = mid; else hi = mid; }
    return lo;
  }
  function spend(costLog, from, n) {
    S.dust = S.dust.sub(P(sumLog(costLog, from, n))).max(Big.ZERO);
  }

  // combien un mode d'achat achète : '1' → 1, '10' → jusqu'au prochain palier de 10, 'max' → tout
  function genTarget(i, mode) {
    const b = S.gens[i].bought;
    return mode === '1' ? 1 : mode === '10' ? 10 - (b % 10) : 1e9;
  }
  // prix affiché pour un mode (pour 'max' : le prochain achat)
  // ce qu'un appui achèterait : nombre d'unités, prix total, et si on peut payer.
  // En mode Max : tout ce qui est payable (ou, si rien ne l'est, le prix de la prochaine unité).
  function offer(costLog, from, target, max) {
    if (max) {
      const n = affordable(costLog, from, 1e9);
      return n > 0 ? { n, cost: P(sumLog(costLog, from, n)), can: true } : { n: 1, cost: P(costLog(from)), can: false };
    }
    const cost = P(sumLog(costLog, from, target));
    return { n: target, cost, can: S.dust.gte(cost) };
  }
  function genOffer(i, mode) {
    return offer((b) => genCostLog(i, b), S.gens[i].bought, genTarget(i, mode), mode === 'max');
  }
  function genPrice(i, mode) { return genOffer(i, mode).cost; }

  function buyGen(i, mode) {
    if (!genUnlocked(i)) return 0;
    const g = S.gens[i];
    const f = (b) => genCostLog(i, b);
    const n = affordable(f, g.bought, genTarget(i, mode));
    if (n <= 0) return 0;
    spend(f, g.bought, n);
    g.bought += n;
    g.amount = g.amount.add(n);
    return n;
  }

  function accelCostLog(n) { return scaleLog(ACCEL.base + ACCEL.step * n * M.costPow); }
  function accelCost() { return P(accelCostLog(S.accel)); }
  function accelOffer(max) { return offer(accelCostLog, S.accel, 1, max); }
  function buyAccel(max) {
    const n = affordable(accelCostLog, S.accel, max ? 1e9 : 1);
    if (n <= 0) return 0;
    spend(accelCostLog, S.accel, n);
    S.accel += n;
    return n;
  }
  function buyAllMax() {
    for (let i = GENS.length - 1; i >= 0; i--) buyGen(i, 'max');
    buyAccel(true);
    for (let i = GENS.length - 1; i >= 0; i--) buyGen(i, 'max');
  }

  // ------------------------------------------------------------------
  // Prestige
  // ------------------------------------------------------------------
  // seuil atteint (sans tenir compte de la durée minimale)
  function reached(k) {
    const d = layerDef(k);
    if (d.blocked()) return false;
    return d.rawLog() > -Infinity;
  }
  function waitLeft(k) { return Math.max(0, MIN_RUN - lay(k).time); }
  function canReset(k) { return reached(k) && waitLeft(k) <= 0; }
  function gain(k) {
    const d = layerDef(k);
    const r = d.rawLog();
    if (r === -Infinity) return Big.ZERO;
    return P(r + (M.gainLog[k] || 0)).floor().max(Big.ONE);
  }

  // full : remise à zéro complète, sans tenir compte des paliers « garde les améliorations »
  function resetBelow(k, full) {
    for (let j = 1; j < k; j++) {
      const l = lay(j);
      l.cur = Big.ZERO;
      l.time = 0;
      if (full || keepLevel(j) < k) l.upg = {};
    }
    lay(k).time = 0;
    S.dust = startDust();
    S.gens = GENS.map(() => ({ amount: Big.ZERO, bought: 0 }));
    S.accel = 0;
    M = computeMods();
  }

  // chronologie : temps de jeu (et date réelle) de chaque première étape
  function markFirst(key) {
    const f = S.stats.firsts || (S.stats.firsts = {});
    if (!f[key]) f[key] = { t: S.stats.time, date: Date.now(), admin: !!S.stats.admin, adminRes: !!S.stats.adminRes };
  }
  function doReset(k, silent) {
    if (!canReset(k)) return false;
    let finishedChal = false;
    const g = gain(k);
    const l = lay(k);
    if (k === 3 && S.chal.active) {
      const id = S.chal.active;
      if (!S.chal.done[id]) { S.chal.done[id] = true; markFirst('défi ' + id); emit('chal', id); }
      S.chal.active = null;
      finishedChal = true;
    }
    l.cur = l.cur.add(g);
    l.total = l.total.add(g);
    if (g.gt(l.best)) l.best = g;
    l.resets++;
    if (l.resets === 1) markFirst('L' + k);
    S.seen[k] = true;
    resetBelow(k);
    if (finishedChal) restoreChalUpgrades();
    if (!silent) emit('reset', k);
    return true;
  }

  // progression (0 → 1, échelle logarithmique) vers le seuil de la couche k
  function progress(k) {
    const d = layerDef(k);
    const src = Math.max(0, d.sourceLog());
    return Math.max(0, Math.min(1, src / d.reqLog));
  }
  // le prochain objectif à afficher au joueur
  function nextGoal() {
    if (S.chal.active) {
      const c = CHALLENGES.find((x) => x.id === S.chal.active);
      return { label: 'Plan RH « ' + c.name + ' » : atteins le seuil de Genève', pct: Math.min(1, Math.max(0, S.dust.log10()) / INF_LOG), key: 'chal', src: S.dust, req: INF };
    }
    const n = layerCount();
    for (let k = 1; k <= n + 1; k++) {
      if (resets(k) > 0) continue;
      if (k === 4 && !lvl(3, 'in_break')) {
        if (chalCount() < BREAK_CHALLENGES) return { label: 'Survis à ' + BREAK_CHALLENGES + ' plans RH pour violer la Convention de Genève (' + chalCount() + '/' + BREAK_CHALLENGES + ')', pct: chalCount() / BREAK_CHALLENGES };
        const u = upgDef(3, 'in_break');
        const c = upgCost(3, u).log10();
        return { label: 'Achète « Violer la Convention de Genève » (' + fmt(upgCost(3, u)) + ' Plaintes RH)', pct: Math.max(0, Math.min(1, Math.max(0, cur(3).log10()) / c)), key: 'break', src: cur(3), req: upgCost(3, u) };
      }
      const d = layerDef(k);
      return { label: 'Prochain objectif : ' + d.verb + ' — ' + d.reqText(), pct: progress(k), key: 'L' + k, src: P(d.sourceLog()), req: P(d.reqLog) };
    }
    return null;
  }
  function chalUnlockAt(id) { return 4 + 3 * (CHALLENGES.findIndex((c) => c.id === id) + 1); }
  function chalUnlocked(id) { return resets(3) >= chalUnlockAt(id); }
  // Un défi repart vraiment de zéro (améliorations d'Éclats et de Singularités comprises).
  // Les améliorations d'avant sont mises de côté et rendues à la sortie du défi.
  function startChallenge(id) {
    if (S.chal.active || !chalUnlocked(id)) return;
    S.chal.saved = { 1: Object.assign({}, lay(1).upg), 2: Object.assign({}, lay(2).upg) };
    S.chal.active = id;
    resetBelow(3, true);
    emit('chalStart', id);
  }
  function restoreChalUpgrades() {
    const saved = S.chal.saved;
    if (!saved) return;
    for (const j of [1, 2]) {
      const upg = lay(j).upg;
      for (const id in saved[j] || {}) upg[id] = Math.max(upg[id] || 0, saved[j][id]);
    }
    S.chal.saved = null;
    M = computeMods();
  }
  function exitChallenge() {
    if (!S.chal.active) return;
    S.chal.active = null;
    resetBelow(3);
    restoreChalUpgrades();
    emit('chalExit');
  }

  // ------------------------------------------------------------------
  // Améliorations
  // ------------------------------------------------------------------
  function upgDef(k, id) { return layerDef(k).upgrades.find((u) => u.id === id); }
  // coûts arrondis à l'entier pour l'affichage et l'achat
  function costAt(u, lv) {
    // les améliorations infinies ont un coût qui accélère (évite l'emballement)
    const c = P(u.cost(lv) + (u.max === Infinity ? 0.05 * lv * lv : 0));
    return c.e < 15 ? B(Math.round(c.toNumber())) : c;
  }
  function upgCost(k, u) { return costAt(u, lvl(k, u.id)); }
  function upgAvailable(k, u) { return !u.req || u.req(); }
  function buyUpg(k, id, max) {
    const u = upgDef(k, id);
    if (!u || !upgAvailable(k, u)) return 0;
    const l = lay(k);
    let n = 0;
    while (n < 1000) {
      const lv = l.upg[id] || 0;
      if (lv >= u.max) break;
      const c = costAt(u, lv);
      if (l.cur.lt(c)) break;
      l.cur = l.cur.sub(c).max(Big.ZERO);
      l.upg[id] = lv + 1;
      n++;
      if (!max) break;
    }
    if (n) { M = computeMods(); if (id === 'in_break') markFirst('break'); }
    return n;
  }

  // ------------------------------------------------------------------
  // Boucle
  // ------------------------------------------------------------------
  function seenCheck() {
    if (S.dust.log10() >= 10) S.seen[1] = true;
    if (cur(1).log10() >= 6 || resets(1) >= 3) S.seen[2] = true;
    if (S.dust.log10() >= 150 || resets(3) > 0) S.seen[3] = true;
    if (cur(3).log10() >= ETER_REQ / 2 || resets(4) > 0) S.seen[4] = true;
    const n = layerCount();
    for (let k = 5; k <= n + 1; k++) {
      if (cur(k - 1).log10() >= metaReq(k) / 2 || resets(k) > 0) S.seen[k] = true;
    }
  }

  function autoReset(k) {
    const l = lay(k);
    if (!l.auto.on || !autoUnlocked(k) || !canReset(k)) return false;
    const v = Math.max(0, Number(l.auto.value) || 0);
    if (l.auto.mode === 'time') {
      if (l.time >= v) return doReset(k, true);
    } else {
      const g = gain(k);
      if (g.gte(l.cur.mul(Math.max(v, 1e-9))) || l.cur.isZero()) return doReset(k, true);
    }
    return false;
  }

  // avance le jeu de dt secondes (temps réel)
  function tick(dt) {
    M = computeMods();
    const t = dt * M.speed;
    S.stats.time += dt;
    const n = layerCount();
    for (let k = 1; k <= n; k++) lay(k).time += t;

    // production en chaîne
    for (let i = GENS.length - 1; i >= 1; i--) {
      const g = S.gens[i];
      if (g.amount.isZero() || !M.genOn[i]) continue;
      S.gens[i - 1].amount = S.gens[i - 1].amount.add(g.amount.mul(P(genMultLog(i) + Math.log10(t))));
    }
    const rate = dustRate();
    const add = rate.mul(t);
    S.dust = S.dust.add(add);
    S.stats.totalDust = S.stats.totalDust.add(add);
    if (!isBroken() && S.dust.gt(INF)) S.dust = INF;
    if (S.dust.gt(S.stats.bestDust)) S.stats.bestDust = S.dust;

    // gains passifs
    for (let k = 1; k <= n; k++) {
      const p = M.passive[k];
      if (p > 0 && reached(k)) {
        const g = gain(k).mul(p * t);
        lay(k).cur = lay(k).cur.add(g);
        lay(k).total = lay(k).total.add(g);
      }
    }

    // automates
    if (S.auto.gens && autoGensUnlocked()) for (let i = GENS.length - 1; i >= 0; i--) buyGen(i, 'max');
    if (S.auto.accel && autoAccelUnlocked()) buyAccel(true);
    if (S.auto.snUpg && autoSnUpgUnlocked()) autoBuySnUpgrades();
    for (let k = n; k >= 1; k--) if (autoReset(k)) break;

    seenCheck();
  }

  function dustRate() {
    const g = S.gens[0];
    if (g.amount.isZero() || !M.genOn[0]) return Big.ZERO;
    return P((g.amount.log10() + genMultLog(0)) * M.dustExp);
  }

  // simulation hors-ligne / rattrapage
  function simulate(seconds, maxSteps) {
    maxSteps = maxSteps || 6000;
    if (seconds <= 0) return;
    const steps = Math.min(maxSteps, Math.max(1, Math.ceil(seconds / 0.05)));
    const dt = seconds / steps;
    for (let i = 0; i < steps; i++) tick(dt);
  }

  // ------------------------------------------------------------------
  // Sauvegarde
  // ------------------------------------------------------------------
  const BIG_KEYS = new Set(['dust', 'amount', 'cur', 'total', 'best', 'bestDust', 'totalDust']);
  function serialize() {
    return JSON.stringify(S);
  }
  function revive(o) {
    if (Array.isArray(o)) return o.map(revive);
    if (o && typeof o === 'object') {
      const r = {};
      for (const key in o) {
        if (BIG_KEYS.has(key)) {
          const b = Big.parse(o[key]);
          // une sauvegarde modifiée ne doit pas pouvoir injecter de valeur négative ou invalide
          r[key] = b.m > 0 && isFinite(b.m) && isFinite(b.e) ? b : Big.ZERO;
        } else r[key] = revive(o[key]);
      }
      return r;
    }
    return o;
  }
  function deserialize(str) {
    const o = revive(JSON.parse(str));
    const base = newState();
    const s = Object.assign(base, o);
    s.stats = Object.assign(newState().stats, o.stats || {});
    s.options = Object.assign(newState().options, o.options || {});
    s.auto = Object.assign(newState().auto, o.auto || {});
    s.chal = Object.assign({ active: null, done: {}, saved: null }, o.chal || {});
    for (const k in s.layers) {
      s.layers[k] = Object.assign(newLayerState(), s.layers[k]);
      s.layers[k].auto = Object.assign(newLayerState().auto, s.layers[k].auto || {});
    }
    if (!Array.isArray(s.gens) || s.gens.length !== GENS.length) s.gens = newState().gens;
    // sauvegardes sans chronologie : estimation à partir du temps de jeu
    if (!(o.stats && o.stats.firsts)) {
      s.stats.firsts = {};
      for (const k in s.layers) {
        const l = s.layers[k];
        if (l.resets === 1) s.stats.firsts['L' + k] = { t: Math.max(0, s.stats.time - l.time), approx: true };
        else if (l.resets > 1) s.stats.firsts['L' + k] = { t: null, approx: true };
      }
    }
    // v2 : les achats automatiques sont désactivés par défaut (le joueur les active lui-même)
    if (!(s.version >= 2)) { s.auto.gens = false; s.auto.accel = false; s.version = 2; }
    const int = (x) => (Number.isFinite(x) && x > 0 ? Math.floor(x) : 0);
    s.gens = s.gens.map((g) => ({ amount: g && g.amount instanceof Big ? g.amount : Big.ZERO, bought: int(g && g.bought) }));
    s.accel = int(s.accel);
    for (const k in s.layers) {
      const l = s.layers[k];
      l.resets = int(l.resets);
      l.time = Number.isFinite(l.time) && l.time > 0 ? l.time : 0;
      for (const id in l.upg) l.upg[id] = int(l.upg[id]);
    }
    return s;
  }

  function init(state) {
    S = state || newState();
    M = computeMods();
  }

  // ------------------------------------------------------------------
  // Utilitaires
  // ------------------------------------------------------------------
  function fmt(x, d) { return Big.format(x, S ? S.options.notation : 'scientifique', d); }

  root.Game = {
    GENS, CHALLENGES, BREAK_CHALLENGES, INF, MIN_RUN,
    get S() { return S; }, get M() { return M; },
    init, newState, serialize, deserialize, tick, simulate, on: (f) => listeners.push(f),
    lay, lvl, cur, resets, layerDef, layerCount, keepLevel, autoUnlocked, autoGensUnlocked, autoAccelUnlocked, autoSnUpgUnlocked, SN_AUTO_AT,
    genCost, genPrice, genOffer, accelOffer, genMult, genUnlocked, criticalExponent, computeMods: () => computeMods(), buyGen, accelCost, buyAccel, buyAllMax, dustRate,
    canReset, reached, waitLeft, progress, nextGoal, gain, doReset, startChallenge, chalUnlocked, chalUnlockAt, exitChallenge, chalDone, chalCount, isBroken,
    upgDef, upgCost, upgAvailable, buyUpg, startDust, fmt,
    refresh: () => { M = computeMods(); },
  };
  if (typeof module !== 'undefined') module.exports = root.Game;
})(typeof window !== 'undefined' ? window : globalThis);
