// « Joueur malin » : recherche automatique de la stratégie la plus rapide.
// Essaie des combinaisons (seuils de prestige par couche, mode rendement, garder le gain
// passif, améliorations prioritaires, ordre des défis…), garde les meilleures et les
// fait muter. Sert à vérifier qu'aucune façon de jouer ne casse le rythme du jeu.
//
// Usage : node idle/tools/malin.js <objectif> <essais> <mutations> [sortie.json]
//   objectif : bb (1er Big Bang, max 8 h) | eter (1re Éternité, max 48 h) | strates (couches atteintes en 150 h)
const { fork } = require('child_process');
const os = require('os');
const fs = require('fs');

const GOALS = {
  bb: { stopAt: 'L3 #1', hours: 8 },
  eter: { stopAt: 'L4 #1', hours: 48 },
  strates: { stopAt: null, hours: 150 },
};
const MULTS = [1, 3, 10, 100, 1000, 1e6, 'rate'];
const PRIOS = [null, ['co_hawking'], ['co_hawking', 'co_spaghetti'], ['co_horizon', 'co_hawking'], ['sn_gravity', 'sn_remnant', 'sn_mass'], ['sn_nova', 'sn_mass'], ['co_density', 'co_hawking'], ['in_hawk', 'in_ipmult']];
const CHAL = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6'];

const pick = (a) => a[Math.floor(Math.random() * a.length)];
function shuffle(a) { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }

function randomStrat() {
  return {
    mults: [pick(MULTS), pick(MULTS), pick(MULTS), pick(MULTS), pick(MULTS)],
    hawkHold: pick([0, 0, 1, 3, 10]),
    prio: pick(PRIOS),
    thrift: pick([0, 0, 0.1, 0.5]),
    expensiveFirst: Math.random() < 0.2,
    chalOrder: shuffle(CHAL),
    chalGiveUp: pick([1800, 3600, 7200]),
    minTime: pick([5, 10, 30]),
  };
}
function mutate(s) {
  const m = JSON.parse(JSON.stringify(s));
  const r = Math.floor(Math.random() * 7);
  if (r <= 2) m.mults[Math.floor(Math.random() * m.mults.length)] = pick(MULTS);
  else if (r === 3) m.hawkHold = pick([0, 1, 3, 10]);
  else if (r === 4) m.prio = pick(PRIOS);
  else if (r === 5) m.chalOrder = shuffle(CHAL);
  else m.thrift = pick([0, 0.1, 0.5]);
  return m;
}
const label = (s) => 'seuils ' + s.mults.map((x) => (x === 'rate' ? 'R' : x >= 1e6 ? '1e6' : x)).join('/') + (s.hawkHold ? ' passif≥' + s.hawkHold : '') + (s.prio ? ' prio ' + s.prio.join('+') : '') + (s.thrift ? ' éco' + s.thrift : '') + (s.expensiveFirst ? ' cher' : '');

// ---------------- évaluation (processus enfant) ----------------
if (process.argv[2] === '--eval') {
  const { run } = require('./sim.js');
  const G = require('../js/game.js');
  process.on('message', ({ strat, goal }) => {
    const g = GOALS[goal];
    const r = run(Object.assign({ mult: 1, name: 'malin' }, strat), g.hours, 1, { quiet: true, stopAt: g.stopAt });
    const ev = {};
    for (const e of r.events) ev[e.key] = e.t;
    let score;
    if (goal === 'strates') {
      // plus de couches = mieux ; à égalité, atteinte plus tôt
      let top = 0;
      for (const k in r.final.resets) if (r.final.resets[k] > 0) top = Math.max(top, +k);
      score = -(top * 1e7) + (ev['L' + top + ' #1'] || 0);
    } else score = ev[g.stopAt] !== undefined ? ev[g.stopAt] : g.hours * 3600 * 2;
    process.send({ score, ev, final: r.final, maxLayers: G.layerCount(), samples: r.samples.slice(-3) });
  });
  return;
}

// ---------------- orchestration ----------------
const [goal = 'bb', tries = '24', gens = '16', out] = process.argv.slice(2);
if (!GOALS[goal]) { console.log('objectif : bb | eter | strates'); process.exit(1); }
const workers = Array.from({ length: Math.max(1, os.cpus().length) }, () => fork(__filename, ['--eval']));
const results = [];
const t0 = Date.now();
const fmtT = (s) => (s >= 3600 ? (s / 3600).toFixed(2) + ' h' : Math.round(s / 60) + ' min');

function evaluate(strat) {
  return new Promise((resolve) => {
    const w = workers.find((x) => !x.busy) || null;
    if (!w) return setTimeout(() => resolve(evaluate(strat)), 50);
    w.busy = true;
    w.once('message', (res) => { w.busy = false; const r = Object.assign({ strat, label: label(strat) }, res); results.push(r); resolve(r); });
    w.send({ strat, goal });
  });
}
function show(r) {
  const what = goal === 'strates' ? 'couches ' + r.maxLayers + ' (resets ' + JSON.stringify(r.final.resets) + ')' : (r.ev[GOALS[goal].stopAt] !== undefined ? fmtT(r.ev[GOALS[goal].stopAt]) : 'non atteint');
  console.log('[' + ((Date.now() - t0) / 60000).toFixed(1) + ' min] ' + what.padEnd(14) + ' ' + r.label);
}

(async () => {
  // 1. essais aléatoires (plus quelques stratégies « humaines » de référence)
  const seeds = [
    { mults: [10, 10, 10, 10, 10], hawkHold: 0, prio: null, thrift: 0, chalOrder: CHAL, minTime: 5 },
    { mults: [1000, 100, 10, 10, 10], hawkHold: 1, prio: ['co_hawking'], thrift: 0, chalOrder: CHAL, minTime: 5 },
    { mults: ['rate', 'rate', 'rate', 'rate', 'rate'], hawkHold: 0, prio: null, thrift: 0, chalOrder: CHAL, minTime: 5 },
  ];
  const first = seeds.concat(Array.from({ length: Math.max(0, +tries - seeds.length) }, randomStrat));
  await Promise.all(first.map((s) => evaluate(s).then(show)));
  // 2. mutations des meilleures
  for (let g = 0; g < +gens; g += workers.length) {
    const best = results.slice().sort((a, b) => a.score - b.score).slice(0, 4);
    const batch = Array.from({ length: workers.length }, (_, i) => mutate(best[i % best.length].strat));
    await Promise.all(batch.map((s) => evaluate(s).then(show)));
  }
  results.sort((a, b) => a.score - b.score);
  console.log('\nMeilleures stratégies :');
  for (const r of results.slice(0, 5)) show(r);
  if (out) fs.writeFileSync(out, JSON.stringify({ goal, results }, null, 1));
  workers.forEach((w) => w.kill());
})();
