// Tests de robustesse : tente de « casser » le jeu.
// Usage : node idle/tools/tests.js [sortie.json]
require('../js/big.js');
const G = require('../js/game.js');
const { run } = require('./sim.js');
const Big = globalThis.Big;

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok: !!ok, detail: detail || '' });
  console.log((ok ? 'OK   ' : 'ÉCHEC') + ' ' + name + (detail ? ' — ' + detail : ''));
}
const valid = (b) => b instanceof Big && isFinite(b.m) && !Number.isNaN(b.e) && b.m >= 0;
function allValid() {
  const S = G.S;
  if (!valid(S.dust)) return false;
  for (const g of S.gens) if (!valid(g.amount) || !Number.isFinite(g.bought)) return false;
  for (const k in S.layers) { const l = S.layers[k]; if (!valid(l.cur) || !valid(l.total)) return false; }
  return true;
}

// Partie « avancée » de référence : on fait jouer le bot actif N heures.
function advanced(hours) {
  run('actif', hours, 2, { quiet: true });
  return G.serialize();
}

// ---------------------------------------------------------------
// 1. Prestige instantané : après un reset, la couche est-elle de nouveau
//    disponible sans rien faire ? (sinon : clics infinis = monnaie infinie)
// ---------------------------------------------------------------
let advanced0;

// ---------------------------------------------------------------
// 2. Sensibilité au pas de temps (un grand pas ne doit pas avantager)
// ---------------------------------------------------------------
function sensitivity() {
  const out = [];
  for (const dt of [0.25, 1, 4, 16]) {
    const r = run('actif', 6, dt, { quiet: true });
    let score = 0; for (let k = 1; k <= G.layerCount(); k++) score += Math.max(0, G.lay(k).total.log10());
    out.push({ dt, score, dust: r.final.dustLog, L1: (r.events.find((e) => e.key === 'L1 #1') || {}).t, L2: (r.events.find((e) => e.key === 'L2 #1') || {}).t, resets: r.final.resets });
  }
  return out;
}

// ---------------------------------------------------------------
// 3. Hors-ligne vs en ligne : 8 h d'absence ne doivent pas rapporter plus
//    que 8 h en ligne avec les mêmes automates.
// ---------------------------------------------------------------
function offlineVsOnline(save, hours) {
  const prep = () => {
    G.init(G.deserialize(save));
    for (let k = 1; k <= G.layerCount(); k++) { const l = G.lay(k); if (G.autoUnlocked(k)) { l.auto.on = true; l.auto.mode = 'mult'; l.auto.value = 1; } }
  };
  prep();
  // référence : le vrai rythme du jeu (un tick toutes les 50 ms)
  for (let i = 0; i < hours * 3600 / 0.05; i++) G.tick(0.05);
  const score = () => { let sc = 0; for (let k = 1; k <= G.layerCount(); k++) sc += Math.max(0, G.lay(k).total.log10()) * Math.pow(10, k); return sc; };
  const on = { dust: G.S.dust.log10(), score: score(), L: [1, 2, 3, 4, 5].map((k) => G.lay(k).total.log10()) };
  prep();
  const t0 = Date.now();
  G.simulate(hours * 3600, 6000);
  const ms = Date.now() - t0;
  const off = { dust: G.S.dust.log10(), score: score(), L: [1, 2, 3, 4, 5].map((k) => G.lay(k).total.log10()) };
  return { on, off, ms };
}

// ---------------------------------------------------------------
// main
// ---------------------------------------------------------------
const report = {};
console.log('Préparation des parties de référence…');
advanced0 = advanced(30); // ~ après la 1re Éternité
const mid = (() => { run('actif', 8, 2, { quiet: true }); return G.serialize(); })(); // avant Infini brisé
const early = (() => { run('actif', 1.5, 1, { quiet: true }); return G.serialize(); })();

// 1 (relancé maintenant que les parties existent)
results.length = 0;
{
  G.init();
  G.lay(1).upg.sn_remnant = 5; G.refresh();
  const start = G.startDust();
  check('Poussière de départ max < seuil de Supernova', start.lt(Big.pow10(15)), 'départ ' + G.fmt(start) + ' vs seuil 1e15');
  for (const [label, save] of [['début', early], ['milieu', mid], ['avancée', advanced0]]) {
    for (let k = 1; k <= 5; k++) {
      G.init(G.deserialize(save));
      for (let i = 0; i < 600; i++) G.tick(0.5); // on laisse produire 5 min
      if (!G.canReset(k)) continue;
      G.doReset(k, true);
      check('[' + label + '] couche ' + k + ' : seuil non atteint juste après son reset', !G.reached(k), G.reached(k) ? 'gain immédiat ' + G.fmt(G.gain(k)) : '');
    }
  }
}

console.log('Sensibilité au pas de temps…');
report.sensitivity = sensitivity();
{
  const d = report.sensitivity.map((s) => s.score);
  const spread = Math.max(...d) - Math.min(...d);
  check('Pas de temps 0,25 s → 16 s : écart de progression < 25 %', spread < 0.25 * Math.max(...d), 'somme des log10 des totaux : ' + d.map((x) => x.toFixed(1)).join(' / ') + ' ; 1re Supernova : ' + report.sensitivity.map((s) => (s.L1 / 60).toFixed(0) + ' min').join(' / '));
}

console.log('Hors-ligne vs en ligne…');
report.offline = {};
for (const [label, save] of [['début', early], ['milieu', mid], ['avancée', advanced0]]) {
  const r = offlineVsOnline(save, 8);
  report.offline[label] = r;
  const fmtL = (L) => L.map((x) => x > -Infinity ? x.toFixed(1) : '–').join('/');
  check('[' + label + '] 8 h hors-ligne ne rapporte pas plus que 8 h en ligne à 50 ms/tick (+5 %)', r.off.score <= r.on.score * 1.05 + 1, 'log10 des totaux par couche — en ligne ' + fmtL(r.on.L) + ', hors-ligne ' + fmtL(r.off.L) + ' (calcul ' + r.ms + ' ms)');
}

console.log('Valeurs extrêmes…');
{
  G.init(G.deserialize(advanced0));
  G.S.dust = Big.pow10(1e300);
  for (let k = 1; k <= 5; k++) G.lay(k).cur = Big.pow10(1e200);
  let err = null;
  try { for (let i = 0; i < 50; i++) { G.tick(1); G.buyAllMax(); } G.fmt(G.S.dust); } catch (e) { err = e.message; }
  check('Nombres gigantesques (1e1e300) : pas de plantage ni de NaN', !err && allValid(), err || G.fmt(G.S.dust));
  let t0 = Date.now();
  G.buyAllMax();
  check('Achat max avec 1e1e300 Poussière reste rapide', Date.now() - t0 < 200, (Date.now() - t0) + ' ms');
  t0 = Date.now();
  for (let k = 1; k <= 5; k++) for (const u of G.layerDef(k).upgrades) G.buyUpg(k, u.id, true);
  check('Achat max des améliorations avec monnaie gigantesque reste rapide', Date.now() - t0 < 500, (Date.now() - t0) + ' ms');
  check('Format des nombres extrêmes', /e/.test(G.fmt(Big.pow10(1e300))) && G.fmt(Big.pow10(1e300)).length < 20, G.fmt(Big.pow10(1e300)));
}

console.log('Sauvegardes corrompues…');
{
  const cases = {
    'JSON vide': '{}',
    'gens manquants': JSON.stringify({ dust: '1e10' }),
    'nombres invalides': JSON.stringify({ dust: 'abc', layers: { 1: { cur: 'NaNeNaN', upg: { sn_fusion: 3 } } } }),
    'valeur négative': JSON.stringify({ dust: '-5e10' }),
    'infini': JSON.stringify({ dust: 'Infinity' }),
  };
  for (const name in cases) {
    let err = null;
    try {
      G.init(G.deserialize(cases[name]));
      for (let i = 0; i < 100; i++) { G.tick(0.1); G.buyAllMax(); }
    } catch (e) { err = e.message; }
    check('Sauvegarde « ' + name + ' » : le jeu repart sans planter', !err && allValid(), err || 'Poussière ' + G.fmt(G.S.dust));
  }
}

console.log('Horloge…');
{
  G.init(G.deserialize(mid));
  const before = G.S.dust;
  let err = null;
  try { G.simulate(-3600 * 24); } catch (e) { err = e.message; }
  check('Temps négatif (horloge reculée) ignoré', !err && G.S.dust.eq(before));
  G.init(G.deserialize(mid));
  const t0 = Date.now();
  G.simulate(7 * 24 * 3600, 6000);
  const ms = Date.now() - t0;
  check('Rattrapage 7 jours hors-ligne en moins de 5 s (PC)', ms < 5000, ms + ' ms');
  report.offline7dMs = ms;
}

console.log('Contournement des défis…');
{
  G.init(G.deserialize(mid));
  G.lay(2).upg.co_hawking = 10; G.lay(3).upg.in_hawk = 10; G.lay(3).resets = Math.max(G.lay(3).resets, 20);
  G.startChallenge('c2');
  if (G.S.chal.active === 'c2') {
    for (let i = 0; i < 2000; i++) { G.tick(0.5); G.buyAllMax(); }
    check('Défi « Sans étoiles » : aucun Éclat gagné (même en passif)', G.cur(1).isZero(), 'Éclats ' + G.fmt(G.cur(1)));
    G.exitChallenge();
  } else check('Défi c2 démarrable', false, 'non débloqué');
  G.init(G.deserialize(mid)); G.lay(3).resets = Math.max(G.lay(3).resets, 20);
  G.startChallenge('c3');
  if (G.S.chal.active === 'c3') {
    G.S.dust = Big.pow10(200);
    G.buyAllMax();
    check('Défi « Quatuor » : générateurs 5-8 non achetables', G.S.gens.slice(4).every((g) => g.bought === 0));
    G.exitChallenge();
  }
  G.init(G.deserialize(mid)); G.lay(3).resets = Math.max(G.lay(3).resets, 20);
  G.startChallenge('c5');
  if (G.S.chal.active === 'c5') {
    G.lay(1).cur = Big.pow10(100);
    check('Défi « Vide quantique » : Effondrement bloqué', !G.canReset(2));
    G.exitChallenge();
  }
  G.init(G.deserialize(advanced0));
  const id = G.CHALLENGES[0].id;
  G.startChallenge(id);
  G.lay(3).cur = Big.pow10(400);
  check("Éternité impossible pendant un défi", !G.canReset(4));
  // terminer un défi ne doit pas pouvoir se faire sans atteindre l'Infini
  G.init(G.deserialize(mid));
  G.startChallenge('c1');
  const done0 = G.chalDone('c1');
  G.doReset(3);
  check("Un défi ne se valide pas sans atteindre l'Infini", G.chalDone('c1') === done0);
}

console.log('Automates réglés à 0 (spam)…');
{
  G.init(G.deserialize(advanced0));
  for (let k = 1; k <= 4; k++) { const l = G.lay(k); l.auto.on = true; l.auto.mode = 'time'; l.auto.value = 0; }
  let err = null;
  const t0 = Date.now();
  try { for (let i = 0; i < 2000; i++) G.tick(0.05); } catch (e) { err = e.message; }
  const ms = (Date.now() - t0) / 2000;
  check('Automates à 0 s : pas de plantage, tick < 5 ms', !err && ms < 5 && allValid(), ms.toFixed(2) + ' ms/tick');
}

console.log('Performance d\'un tick…');
{
  G.init(G.deserialize(advanced0));
  for (let k = 1; k <= G.layerCount(); k++) { const l = G.lay(k); if (G.autoUnlocked(k)) l.auto.on = true; }
  const t0 = Date.now();
  for (let i = 0; i < 2000; i++) G.tick(0.05);
  const ms = (Date.now() - t0) / 2000;
  report.tickMs = ms;
  check('Tick en partie avancée < 2 ms (PC)', ms < 2, ms.toFixed(3) + ' ms');
}

console.log('Exposant critique…');
{
  G.init();
  report.Ebase = G.criticalExponent();
  for (let k = 1; k <= 4; k++) for (const u of G.layerDef(k).upgrades) if (u.max !== Infinity) G.lay(k).upg[u.id] = u.max;
  G.S.chal.done = { c1: 1, c2: 1, c3: 1, c4: 1, c5: 1, c6: 1 }; G.refresh();
  report.Emax = G.criticalExponent();
  check('Exposant critique < 1 même avec toutes les améliorations (pas d\'emballement)', report.Emax < 1, 'E départ ' + report.Ebase.toFixed(3) + ', E max ' + report.Emax.toFixed(3));
  for (const c of G.CHALLENGES) { G.S.chal.active = c.id; G.refresh(); if (G.criticalExponent() >= 1) check('E < 1 dans le défi ' + c.id, false); }
  G.S.chal.active = null;
}

console.log('Big : arithmétique…');
{
  const a = Big.from(123456789);
  check('x − x = 0', a.sub(a).isZero());
  check('1e308 × 10 ne déborde pas', Big.INF.mul(10).log10() > 309);
  check('pow / log cohérents', Math.abs(Big.from(2).pow(1000).log10() - 1000 * Math.log10(2)) < 1e-9);
  check('Big.parse aller-retour', Big.parse(Big.pow10(12345.678).toJSON()).eq(Big.pow10(12345.678)));
}

report.results = results;
const failed = results.filter((r) => !r.ok).length;
console.log('\n' + (results.length - failed) + '/' + results.length + ' tests OK');
if (process.argv[2]) require('fs').writeFileSync(process.argv[2], JSON.stringify(report, null, 1));
