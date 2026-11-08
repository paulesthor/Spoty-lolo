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
    { name: 'Particules', base: 1, step: 3 },
    { name: 'Atomes', base: 2, step: 4 },
    { name: 'Molécules', base: 4, step: 5 },
    { name: 'Astéroïdes', base: 6, step: 6 },
    { name: 'Planètes', base: 9, step: 8 },
    { name: 'Étoiles', base: 13, step: 10 },
    { name: 'Nébuleuses', base: 18, step: 12 },
    { name: 'Galaxies', base: 24, step: 15 },
  ];
  const ACCEL = { base: 3, step: 1 };

  // Dans tous les défis, la production de Poussière est en plus mise à la puissance 0,9.
  // Le défi n°i se débloque après 2×i Big Bangs.
  const CHALLENGES = [
    { id: 'c1', name: 'Nuit noire', desc: "L'Accélérateur n'a aucun effet.", reward: 'Accélérateur +0,02 par achat.' },
    { id: 'c2', name: 'Sans étoiles', desc: 'Supernova impossible.', reward: "Effet des Éclats : exposant +0,1." },
    { id: 'c3', name: 'Quatuor', desc: 'Seuls les générateurs 1 à 4 produisent.', reward: 'Générateurs 1 à 4 ×(1 + Points d\'Infini).' },
    { id: 'c4', name: 'Inflation', desc: 'La hausse des prix est doublée.', reward: 'Hausse des prix des générateurs −10 %.' },
    { id: 'c5', name: 'Vide quantique', desc: 'Effondrement impossible.', reward: 'Gain de Singularités ×5.' },
    { id: 'c6', name: 'Racine', desc: 'La production de Poussière est mise à la racine carrée.', reward: 'Exposant de production +0,03.' },
  ];
  const BREAK_CHALLENGES = 4;

  // ------------------------------------------------------------------
  // État
  // ------------------------------------------------------------------
  let S = null;
  let M = null; // modificateurs recalculés à chaque tick
  const listeners = [];

  function newLayerState() {
    return { cur: Big.ZERO, total: Big.ZERO, best: Big.ZERO, resets: 0, time: 0, upg: {}, auto: { on: false, mode: 'mult', value: 2 } };
  }

  function newState() {
    return {
      version: 1,
      dust: B(10),
      gens: GENS.map(() => ({ amount: Big.ZERO, bought: 0 })),
      accel: 0,
      layers: {},
      chal: { active: null, done: {} },
      seen: {},
      auto: { gens: true, accel: true },
      stats: { time: 0, bestDust: B(10), totalDust: Big.ZERO, created: Date.now() },
      options: { notation: 'scientifique', buy: 'max', offline: true },
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
      name: 'Supernova', verb: 'Supernova', cur: 'Éclats', sym: '✧',
      reqLog: 15,
      reqText: () => 'Atteins 1e15 Poussière',
      sourceLog: () => S.dust.log10(),
      rawLog() {
        const l = S.dust.log10();
        if (l < 15) return -Infinity;
        return ((l - 15) / 6) * (1 + 0.1 * lvl(4, 'et_shard'));
      },
      blocked: () => inChal('c2') ? 'Bloqué par le défi « Sans étoiles »' : null,
      effectText: () => 'Production ×' + fmt(shardEffect()),
      upgrades: [
        { id: 'sn_fusion', name: 'Fusion', desc: () => 'Production ×2 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(0, Math.log10(3)), max: Infinity },
        { id: 'sn_pulsar', name: 'Pulsar', desc: () => 'Accélérateur +0,01 par achat', eff: (l) => '+' + (0.01 * l).toFixed(2), cost: R(0.5, 0.6), max: 10 },
        { id: 'sn_remnant', name: 'Reste stellaire', desc: () => 'Commence avec plus de Poussière après chaque prestige', eff: (l) => fmt(startDust()), cost: R(0.7, 0.9), max: 5 },
        { id: 'sn_gravity', name: 'Gravité', desc: () => 'Particules ×(1 + log(Poussière))^1,5', eff: () => '×' + fmt(gravityEffect()), cost: R(1.4, 0), max: 1 },
        { id: 'sn_mass', name: 'Masse critique', desc: () => 'Bonus par 10 achats +0,1', eff: (l) => '×' + (M ? M.perTen : 2).toFixed(2), cost: R(2, 1), max: 5 },
        { id: 'sn_echo', name: 'Écho', desc: () => "Gain d'Éclats ×2 par niveau", eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(3, 0.7), max: Infinity },
        { id: 'sn_nova', name: 'Hypernova', desc: () => 'Effet des Éclats : exposant +0,05', eff: (l) => '^' + shardExp().toFixed(2), cost: R(4, 2), max: 5 },
      ],
      milestones: [],
    },
    2: {
      name: 'Effondrement', verb: 'Effondrement', cur: 'Singularités', sym: '●',
      reqLog: 12,
      reqText: () => 'Atteins 1e12 Éclats',
      sourceLog: () => cur(1).log10(),
      rawLog() {
        const l = cur(1).log10();
        if (l < 12) return -Infinity;
        return (l - 12) / 8;
      },
      blocked: () => inChal('c5') ? 'Bloqué par le défi « Vide quantique »' : null,
      effectText: () => "Production et gain d'Éclats ×" + fmt(cur(2).add(1)),
      upgrades: [
        { id: 'co_horizon', name: 'Horizon', desc: () => 'Production ×5 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(5))), cost: R(0, 0.5), max: Infinity },
        { id: 'co_spaghetti', name: 'Spaghettification', desc: () => "Gain d'Éclats ×3 par niveau", eff: (l) => '×' + fmt(P(l * Math.log10(3))), cost: R(0.3, 0.6), max: Infinity },
        { id: 'co_hawking', name: 'Rayonnement de Hawking', desc: () => "Gagne passivement 1 % par seconde du gain de Supernova", eff: (l) => l + ' %/s', cost: R(0.7, 1), max: 10 },
        { id: 'co_density', name: 'Densité', desc: () => 'Exposant de production +0,01', eff: (l) => '^' + (M ? M.prodExp : 1).toFixed(2), cost: R(1, 1.4), max: 5 },
        { id: 'co_bulk', name: 'Compression', desc: () => 'Hausse des prix des générateurs −2 %', eff: (l) => '−' + 2 * l + ' %', cost: R(1.4, 1), max: 5 },
      ],
      milestones: [
        { n: 1, text: 'Achat automatique des générateurs' },
        { n: 3, text: "Achat automatique de l'Accélérateur" },
        { n: 5, text: "Garde les améliorations d'Éclats lors d'un Effondrement" },
        { n: 8, text: 'Supernova automatique' },
      ],
    },
    3: {
      name: 'Big Bang', verb: 'Big Bang', cur: "Points d'Infini", sym: '∞',
      reqLog: INF_LOG,
      reqText: () => "Atteins l'Infini (1,8e308 Poussière)",
      sourceLog: () => S.dust.log10(),
      rawLog() {
        const l = S.dust.log10();
        if (l < INF_LOG - 1e-9) return -Infinity;
        if (isBroken()) return Math.max(0, l / 308 - 0.75);
        return 0;
      },
      blocked: () => null,
      effectText: () => 'Production ×' + fmt(cur(3).add(1)),
      upgrades: [
        { id: 'in_time', name: 'Temps cosmique', desc: () => 'Production ×(1 + minutes dans ce Big Bang)^1,5', eff: () => '×' + fmt(timeEffect()), cost: R(0, 0), max: 1 },
        { id: 'in_count', name: 'Mémoire', desc: () => 'Production ×(1 + nombre de Big Bangs)²', eff: () => '×' + fmt(B(resets(3) + 1).pow(2)), cost: R(0, 0), max: 1 },
        { id: 'in_sn', name: 'Éclats éternels', desc: () => "Gain d'Éclats ×(1 + Points d'Infini)^0,5", eff: () => '×' + fmt(cur(3).add(1).pow(0.5)), cost: R(0.3, 0), max: 1 },
        { id: 'in_gen', name: 'Fusion stellaire', desc: () => 'Bonus par 10 achats +0,5', eff: () => '+0,5', cost: R(0.7, 0), max: 1 },
        { id: 'in_auto', name: 'Big Bang automatique', desc: () => 'Débloque le Big Bang automatique', eff: () => 'Débloqué', cost: R(1, 0), max: 1 },
        { id: 'in_ipmult', name: 'Résonance', desc: () => "Points d'Infini ×2 par niveau", eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(1, 0.5), max: Infinity },
        { id: 'in_hawk', name: 'Évaporation', desc: () => "Gagne passivement 1 % par seconde du gain d'Effondrement", eff: (l) => l + ' %/s', cost: R(1.5, 0.5), max: 10 },
        {
          id: 'in_break', name: "Briser l'Infini", desc: () => "La Poussière dépasse l'Infini et le Big Bang rapporte plus", eff: () => 'Brisé',
          cost: R(2, 0), max: 1,
          req: () => chalCount() >= BREAK_CHALLENGES, reqText: () => 'Termine ' + BREAK_CHALLENGES + ' défis (' + chalCount() + '/' + BREAK_CHALLENGES + ')',
        },
        { id: 'in_postcost', name: 'Courbure', desc: () => "Hausse des prix au-delà de l'Infini −10 %", eff: (l) => '−' + 10 * l + ' %', cost: R(3, 1), max: 5, req: () => lvl(3, 'in_break') > 0, reqText: () => "Brise l'Infini" },
        { id: 'in_prodpow', name: 'Expansion', desc: () => 'Exposant de production +0,02', eff: (l) => '^' + (M ? M.prodExp : 1).toFixed(2), cost: R(4, 3), max: 5, req: () => lvl(3, 'in_break') > 0, reqText: () => "Brise l'Infini" },
      ],
      milestones: [
        { n: 1, text: 'Production ×10 par défi terminé' },
        { n: 2, text: "Garde les améliorations d'Éclats lors d'un Big Bang" },
        { n: 3, text: 'Effondrement automatique' },
        { n: 5, text: 'Garde les améliorations de Singularités lors d\'un Big Bang' },
        { n: 10, text: 'Gagne passivement 10 % par seconde du gain de Supernova' },
      ],
    },
    4: {
      name: 'Éternité', verb: 'Éternité', cur: "Points d'Éternité", sym: 'Ⓔ',
      reqLog: INF_LOG,
      reqText: () => "Atteins 1,8e308 Points d'Infini",
      sourceLog: () => cur(3).log10(),
      rawLog() {
        const l = cur(3).log10();
        if (l < INF_LOG - 1e-9) return -Infinity;
        return (l - INF_LOG) / 100;
      },
      blocked: () => S.chal.active ? 'Quitte le défi en cours' : null,
      effectText: () => "Points d'Infini ×" + fmt(cur(4).add(1)) + ', production ×' + fmt(cur(4).add(1).pow(3)),
      upgrades: [
        { id: 'et_ip', name: 'Mémoire éternelle', desc: () => "Points d'Infini ×5 par niveau", eff: (l) => '×' + fmt(P(l * Math.log10(5))), cost: R(0, 0.5), max: Infinity },
        { id: 'et_prod', name: 'Inflation cosmique', desc: () => 'Exposant de production +0,01', eff: (l) => '+' + (0.01 * l).toFixed(2), cost: R(0.3, 0.7), max: 10 },
        { id: 'et_time', name: 'Dilatation', desc: () => 'Vitesse du jeu +25 %', eff: (l) => '×' + (1 + 0.25 * l).toFixed(2), cost: R(0.7, 1), max: 8 },
        { id: 'et_passive', name: 'Rémanence', desc: () => "Gagne passivement 1 % par seconde du gain de Big Bang", eff: (l) => l + ' %/s', cost: R(1, 1), max: 10 },
        { id: 'et_shard', name: 'Cristallisation', desc: () => "Gain d'Éclats : exposant +10 %", eff: (l) => '+' + 10 * l + ' %', cost: R(0.5, 0.8), max: 5 },
        { id: 'et_gens', name: 'Harmonie', desc: () => 'Bonus par 10 achats +0,25', eff: (l) => '+' + (0.25 * l).toFixed(2), cost: R(0.6, 0.6), max: 4 },
      ],
      milestones: [
        { n: 1, text: "Garde les améliorations d'Infini" },
        { n: 2, text: 'Big Bang automatique' },
        { n: 3, text: "Points d'Infini ×(1 + nombre d'Éternités)" },
        { n: 5, text: "Gagne passivement 5 % par seconde du gain de Big Bang" },
      ],
    },
  };

  const META_NAMES = ['Multivers', 'Omnivers', 'Hypervers', 'Absolu', 'Paradoxe', 'Néant', 'Origine', 'Archétype', 'Primordial', 'Ultime'];
  const META_SYMS = ['Ⓜ', 'Ⓞ', 'Ⓗ', 'Ⓐ', 'Ⓟ', 'Ⓝ', 'Ⓡ', 'Ⓚ', 'Ⓘ', 'Ⓤ'];
  const META_REQ = 30;

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
      name, verb: name, cur: 'Essence ' + (/^[AEIOUÉÈÊHaeiouéè]/.test(name) ? "d'" : 'de ') + name, sym: i < META_SYMS.length ? META_SYMS[i] : '◈',
      meta: true,
      reqLog: META_REQ,
      reqText: () => 'Atteins 1e' + META_REQ + ' ' + prev.cur,
      sourceLog: () => cur(k - 1).log10(),
      rawLog() {
        const l = cur(k - 1).log10();
        if (l < META_REQ) return -Infinity;
        return (l - META_REQ) / 6;
      },
      blocked: () => S.chal.active ? 'Quitte le défi en cours' : null,
      effectText: () => prev.cur + ' ×' + fmt(cur(k).add(1)) + ', production ×' + fmt(cur(k).add(1).pow(2)),
      upgrades: [
        { id: 'g_gain', name: 'Amplification', desc: () => 'Gain de ' + prev.cur + ' ×3 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(3))), cost: R(0, 0.5), max: Infinity },
        { id: 'g_prod', name: 'Résonance ' + (k - 4), desc: () => 'Production ×1e' + k + ' par niveau', eff: (l) => '×' + fmt(P(l * k)), cost: R(0, 0.3), max: Infinity },
        { id: 'g_self', name: 'Récursion', desc: () => 'Gain de ' + name + ' ×2 par niveau', eff: (l) => '×' + fmt(P(l * Math.log10(2))), cost: R(1, 1), max: Infinity },
        { id: 'g_speed', name: 'Chronos', desc: () => 'Vitesse du jeu +10 %', eff: (l) => '×' + (1 + 0.1 * l).toFixed(1), cost: R(0.7, 0.7), max: 10 },
        { id: 'g_passive', name: 'Écoulement', desc: () => 'Gagne passivement 1 % par seconde du gain de ' + prev.name, eff: (l) => l + ' %/s', cost: R(0.5, 0.8), max: 10 },
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
    return 0.5 + 0.05 * lvl(1, 'sn_nova') + (chalDone('c2') ? 0.1 : 0);
  }
  function shardEffect() { return cur(1).add(1).pow(shardExp()); }
  function gravityEffect() { return B(1 + Math.max(0, S.dust.log10())).pow(1.5); }
  function timeEffect() { return B(1 + lay(3).time / 60).pow(1.5); }
  function startDust() {
    return P(1 + 3 * lvl(1, 'sn_remnant'));
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
  function autoGensUnlocked() { return resets(2) >= 1 || resets(3) >= 1 || resets(4) >= 1; }
  function autoAccelUnlocked() { return resets(2) >= 3 || resets(3) >= 1 || resets(4) >= 1; }

  function computeMods() {
    const n = layerCount();
    const m = {};
    m.speed = 1 + 0.25 * lvl(4, 'et_time');
    for (let k = 5; k <= n; k++) m.speed *= 1 + 0.1 * lvl(k, 'g_speed');

    m.perTen = 2 + 0.1 * lvl(1, 'sn_mass') + (lvl(3, 'in_gen') ? 0.5 : 0) + 0.25 * lvl(4, 'et_gens');
    m.accelBase = 1.125 + 0.01 * lvl(1, 'sn_pulsar') + (chalDone('c1') ? 0.02 : 0);
    m.accelOn = !inChal('c1');
    m.prodExp = 1 + 0.01 * lvl(2, 'co_density') + 0.02 * lvl(3, 'in_prodpow') + 0.01 * lvl(4, 'et_prod') + (chalDone('c6') ? 0.03 : 0);
    // dans un défi la production est aussi affaiblie (^0,9)
    m.dustExp = m.prodExp * (inChal('c6') ? 0.5 : 1) * (S.chal.active ? 0.9 : 1);
    m.costPow = (1 - 0.02 * lvl(2, 'co_bulk') - (chalDone('c4') ? 0.1 : 0)) * (inChal('c4') ? 2 : 1);
    m.postScale = 1.5 - 0.1 * lvl(3, 'in_postcost');

    // multiplicateur global (en log10 pour rester rapide)
    let lp = 0;
    lp += lvl(1, 'sn_fusion') * Math.log10(2);
    lp += shardEffect().log10();
    lp += lvl(2, 'co_horizon') * Math.log10(5);
    lp += cur(2).add(1).log10();
    lp += cur(3).add(1).log10();
    if (lvl(3, 'in_time')) lp += timeEffect().log10();
    if (lvl(3, 'in_count')) lp += 2 * Math.log10(resets(3) + 1);
    if (resets(3) >= 1) lp += chalCount();
    lp += 3 * cur(4).add(1).log10();
    for (let k = 5; k <= n; k++) {
      lp += 2 * cur(k).add(1).log10();
      lp += k * lvl(k, 'g_prod');
    }
    m.prodLog = lp;

    m.genLog = GENS.map(() => 0);
    if (lvl(1, 'sn_gravity')) m.genLog[0] += gravityEffect().log10();
    if (chalDone('c3')) for (let i = 0; i < 4; i++) m.genLog[i] += cur(3).add(1).log10();
    m.genOn = GENS.map((_, i) => !(inChal('c3') && i >= 4));

    // multiplicateurs de gain par couche (log10)
    m.gainLog = {};
    for (let k = 1; k <= n; k++) m.gainLog[k] = 0;
    m.gainLog[1] += lvl(1, 'sn_echo') * Math.log10(2) + lvl(2, 'co_spaghetti') * Math.log10(3) + cur(2).add(1).log10();
    if (lvl(3, 'in_sn')) m.gainLog[1] += 0.5 * cur(3).add(1).log10();
    if (chalDone('c5')) m.gainLog[2] += Math.log10(5);
    m.gainLog[3] += lvl(3, 'in_ipmult') * Math.log10(2) + lvl(4, 'et_ip') * Math.log10(5) + cur(4).add(1).log10();
    if (resets(4) >= 3) m.gainLog[3] += Math.log10(resets(4) + 1);
    for (let k = 5; k <= n + 1; k++) {
      if (m.gainLog[k - 1] === undefined) continue;
      m.gainLog[k - 1] += cur(k).add(1).log10() + lvl(k, 'g_gain') * Math.log10(3);
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
  function genCostLog(i, bought) {
    const g = GENS[i];
    return scaleLog(g.base + g.step * M.costPow * Math.floor(bought / 10));
  }
  function genCost(i) { return P(genCostLog(i, S.gens[i].bought)); }
  // multiplicateur propre à un générateur (bonus par 10 achats, Accélérateur)
  function genMultLog(i) {
    let l = M.genLog[i] + Math.floor(S.gens[i].bought / 10) * Math.log10(M.perTen);
    if (i === 0) l += M.prodLog; // le multiplicateur global ne s'applique qu'à la Poussière
    if (M.accelOn) l += S.accel * Math.log10(M.accelBase);
    return l;
  }
  function genMult(i) { return P(genMultLog(i)); }
  function genUnlocked(i) {
    if (!M.genOn[i]) return false;
    return i === 0 || S.gens[i - 1].bought > 0 || S.gens[i].bought > 0;
  }

  // mode : '1' | '10' | 'max'
  function buyGen(i, mode) {
    if (!genUnlocked(i)) return 0;
    const g = S.gens[i];
    let n = 0;
    let guard = 0;
    while (guard++ < 2000) {
      const price = genCost(i);
      const left = 10 - (g.bought % 10);
      if (mode === '1') {
        if (S.dust.lt(price)) break;
        S.dust = S.dust.sub(price).max(Big.ZERO); g.bought++; g.amount = g.amount.add(1); n++;
        break;
      }
      const total = price.mul(left);
      if (S.dust.gte(total)) {
        S.dust = S.dust.sub(total).max(Big.ZERO); g.bought += left; g.amount = g.amount.add(left); n += left;
        if (mode === '10') break;
      } else {
        if (mode === 'max' && guard === 1) {
          // achète ce qu'on peut à l'unité dans le paquet en cours
          const can = Math.min(left - 1, Math.floor(S.dust.div(price).toNumber()));
          if (can > 0) {
            S.dust = S.dust.sub(price.mul(can)).max(Big.ZERO); g.bought += can; g.amount = g.amount.add(can); n += can;
          }
        }
        break;
      }
    }
    return n;
  }

  function accelCost() { return P(scaleLog(ACCEL.base + ACCEL.step * S.accel * M.costPow)); }
  function buyAccel(max) {
    let n = 0;
    while (n < 5000) {
      const c = accelCost();
      if (S.dust.lt(c)) break;
      S.dust = S.dust.sub(c).max(Big.ZERO); S.accel++; n++;
      if (!max) break;
    }
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
  function canReset(k) {
    const d = layerDef(k);
    if (d.blocked()) return false;
    return d.rawLog() > -Infinity;
  }
  function gain(k) {
    const d = layerDef(k);
    const r = d.rawLog();
    if (r === -Infinity) return Big.ZERO;
    return P(r + (M.gainLog[k] || 0)).floor().max(Big.ONE);
  }

  function resetBelow(k) {
    for (let j = 1; j < k; j++) {
      const l = lay(j);
      l.cur = Big.ZERO;
      l.time = 0;
      if (keepLevel(j) < k) l.upg = {};
    }
    lay(k).time = 0;
    S.dust = startDust();
    S.gens = GENS.map(() => ({ amount: Big.ZERO, bought: 0 }));
    S.accel = 0;
    M = computeMods();
  }

  function doReset(k, silent) {
    if (!canReset(k)) return false;
    const g = gain(k);
    const l = lay(k);
    if (k === 3 && S.chal.active) {
      const id = S.chal.active;
      if (!S.chal.done[id]) { S.chal.done[id] = true; emit('chal', id); }
      S.chal.active = null;
    }
    l.cur = l.cur.add(g);
    l.total = l.total.add(g);
    if (g.gt(l.best)) l.best = g;
    l.resets++;
    S.seen[k] = true;
    resetBelow(k);
    if (!silent) emit('reset', k);
    return true;
  }

  function chalUnlockAt(id) { return 2 * (CHALLENGES.findIndex((c) => c.id === id) + 1); }
  function chalUnlocked(id) { return resets(3) >= chalUnlockAt(id); }
  function startChallenge(id) {
    if (S.chal.active || !chalUnlocked(id)) return;
    S.chal.active = id;
    resetBelow(3);
    emit('chalStart', id);
  }
  function exitChallenge() {
    if (!S.chal.active) return;
    S.chal.active = null;
    resetBelow(3);
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
    if (n) M = computeMods();
    return n;
  }

  // ------------------------------------------------------------------
  // Boucle
  // ------------------------------------------------------------------
  function seenCheck() {
    if (S.dust.log10() >= 10) S.seen[1] = true;
    if (cur(1).log10() >= 6 || resets(1) >= 3) S.seen[2] = true;
    if (S.dust.log10() >= 150 || resets(3) > 0) S.seen[3] = true;
    if (cur(3).log10() >= 100 || resets(4) > 0) S.seen[4] = true;
    const n = layerCount();
    for (let k = 5; k <= n + 1; k++) {
      if (cur(k - 1).log10() >= META_REQ / 2 || resets(k) > 0) S.seen[k] = true;
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
      if (p > 0 && canReset(k)) {
        const g = gain(k).mul(p * t);
        lay(k).cur = lay(k).cur.add(g);
        lay(k).total = lay(k).total.add(g);
      }
    }

    // automates
    if (S.auto.gens && autoGensUnlocked()) for (let i = GENS.length - 1; i >= 0; i--) buyGen(i, 'max');
    if (S.auto.accel && autoAccelUnlocked()) buyAccel(true);
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
    maxSteps = maxSteps || 2000;
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
      for (const key in o) r[key] = BIG_KEYS.has(key) ? Big.parse(o[key]) : revive(o[key]);
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
    s.chal = Object.assign({ active: null, done: {} }, o.chal || {});
    for (const k in s.layers) {
      s.layers[k] = Object.assign(newLayerState(), s.layers[k]);
      s.layers[k].auto = Object.assign(newLayerState().auto, s.layers[k].auto || {});
    }
    if (!Array.isArray(s.gens) || s.gens.length !== GENS.length) s.gens = newState().gens;
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
    GENS, CHALLENGES, BREAK_CHALLENGES, INF,
    get S() { return S; }, get M() { return M; },
    init, newState, serialize, deserialize, tick, simulate, on: (f) => listeners.push(f),
    lay, lvl, cur, resets, layerDef, layerCount, keepLevel, autoUnlocked, autoGensUnlocked, autoAccelUnlocked,
    genCost, genMult, genUnlocked, buyGen, accelCost, buyAccel, buyAllMax, dustRate,
    canReset, gain, doReset, startChallenge, chalUnlocked, chalUnlockAt, exitChallenge, chalDone, chalCount, isBroken,
    upgDef, upgCost, upgAvailable, buyUpg, startDust, fmt,
    refresh: () => { M = computeMods(); },
  };
  if (typeof module !== 'undefined') module.exports = root.Game;
})(typeof window !== 'undefined' ? window : globalThis);
