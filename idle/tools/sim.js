// Simulation d'équilibrage : un bot « joueur actif » joue au jeu.
// Usage : node idle/tools/sim.js [heures] [dt]
require('../js/big.js');
const G = require('../js/game.js');
const Big = globalThis.Big;

const HOURS = parseFloat(process.argv[2] || '48');
const DT = parseFloat(process.argv[3] || '1');
G.init();
const S = () => G.S;

const firsts = {};
let t = 0;
const skipChal = {};
let chalStart = 0;
let lastChalBB = -1;
const hh = (s) => (s / 3600).toFixed(2) + 'h';

function mark(key) {
  if (!firsts[key]) { firsts[key] = t; console.log(hh(t).padStart(8), key, '| dust', G.fmt(S().dust)); }
}

function buyUpgrades() {
  const n = G.layerCount();
  for (let k = 1; k <= n; k++) {
    const d = G.layerDef(k);
    for (let guard = 0; guard < 200; guard++) {
      let best = null;
      for (const u of d.upgrades) {
        if (!G.upgAvailable(k, u) || G.lvl(k, u.id) >= u.max) continue;
        const c = G.upgCost(k, u);
        if (G.cur(k).gte(c) && (!best || c.lt(best.c))) best = { u, c };
      }
      if (!best) break;
      G.buyUpg(k, best.u.id);
    }
  }
}

const end = HOURS * 3600;
let lastLog = 0;
while (t < end) {
  G.tick(DT);
  t += DT;
  G.buyAllMax();
  buyUpgrades();
  const n = G.layerCount();
  for (let k = n + 1; k >= 1; k--) {
    if (!G.canReset(k)) continue;
    const l = G.lay(k);
    const g = G.gain(k);
    let go = false;
    if (k === 3 && (!G.isBroken() || S().chal.active)) go = true;
    else go = l.time > 5 && g.gte(l.cur.max(Big.ONE));
    if (go) {
      const wasChal = S().chal.active;
      G.doReset(k, true);
      if ([1, 5, 10, 50].includes(G.resets(k)) || (k >= 5 && G.resets(k) % 10 === 0)) mark('reset L' + k + ' #' + G.resets(k));
      if (wasChal && k === 3) mark('défi ' + wasChal + ' (' + hh(t - chalStart) + ')');
      break;
    }
  }
  // défis
  if (!S().chal.active && G.resets(3) % 2 === 0 && G.resets(3) !== lastChalBB && !G.lvl(3, 'in_break')) {
    lastChalBB = G.resets(3);
    const c = G.CHALLENGES.find((c) => G.chalUnlocked(c.id) && !G.chalDone(c.id) && !(skipChal[c.id] > t));
    if (c) { G.startChallenge(c.id); chalStart = t; }
  }
  if (S().chal.active && t - chalStart > 3600) {
    console.log(hh(t).padStart(8), 'abandon', S().chal.active);
    skipChal[S().chal.active] = t + 2 * 3600;
    G.exitChallenge();
  }
  if (G.lvl(3, 'in_break')) mark('Infini brisé');
  if (process.env.DBG && G.lvl(3, 'in_break') && G.resets(4) < 1 && Math.floor(t) % 60 === 0) {
    const L = (k) => G.cur(k).log10().toFixed(0);
    const up = [];
    for (let k = 1; k <= 4; k++) for (const u of G.layerDef(k).upgrades) if (u.max === Infinity) up.push(u.id + '=' + G.lvl(k, u.id));
    console.log('DBG', hh(t), 'dust', S().dust.log10().toFixed(0), 'L1', L(1), 'L2', L(2), 'L3', L(3), 'prod', G.M.prodLog.toFixed(0), 'accel', S().accel, 'gen0', S().gens[0].bought, up.join(' '));
  }
  if (t - lastLog >= (t < 4 * 3600 ? 900 : 3600 * 4)) {
    lastLog = t;
    const parts = [];
    for (let k = 1; k <= G.layerCount(); k++) parts.push('L' + k + '=' + G.fmt(G.cur(k)) + '(' + G.resets(k) + ')');
    console.log(hh(t).padStart(8), 'dust', G.fmt(S().dust), parts.join(' '), 'chal', G.chalCount(), S().chal.active || '');
  }
}
