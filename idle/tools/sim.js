// Simulation d'équilibrage : un bot joue au jeu selon un profil (stratégie).
// Usage : node idle/tools/sim.js <profil> [heures] [pas] [sortie.json]
// Profils : voir STRATS ci-dessous. Sans argument : liste les profils.
require('../js/big.js');
const G = require('../js/game.js');
const Big = globalThis.Big;

const STRATS = {
  actif: { desc: 'Joue en continu, prestige dès que le gain double sa monnaie, achète les améliorations les moins chères.', mult: 1 },
  patient: { desc: 'Joue en continu, prestige seulement quand le gain vaut 10× sa monnaie.', mult: 10 },
  spam: { desc: 'Prestige dès que possible (aucun seuil), pour tester les abus de reset.', mult: 0, minTime: 0 },
  econome: { desc: "N'achète une amélioration répétable que si elle coûte ≤ 10 % de la monnaie (garde les bonus de monnaie non dépensée).", mult: 1, thrift: 0.1 },
  cher: { desc: "Achète d'abord l'amélioration la plus chère qu'il peut payer.", mult: 1, expensiveFirst: true },
  sansdefis: { desc: 'Ne fait jamais de défi.', mult: 1, noChal: true },
  defistard: { desc: "Ne commence les défis qu'après 30 Big Bangs.", mult: 1, chalAfter: 30 },
  idle: { desc: '3 sessions de 15 min par jour (actif), le reste hors-ligne avec seulement les automates du jeu.', mult: 1, sessions: { every: 8 * 3600, length: 15 * 60 } },
  idle1: { desc: '1 session de 10 min par jour, le reste hors-ligne.', mult: 1, sessions: { every: 24 * 3600, length: 10 * 60 } },
};

function run(name, hours, dt, opts) {
  opts = opts || {};
  const st = STRATS[name];
  G.init();
  const S = () => G.S;
  const ev = [];
  const firsts = {};
  let t = 0;
  let chalStart = 0, lastChalBB = -1;
  const skipChal = {};
  const hh = (s) => (s / 3600).toFixed(2) + 'h';
  const log = opts.quiet ? () => {} : (...a) => console.log(...a);
  function mark(key) {
    if (firsts[key] !== undefined) return;
    firsts[key] = t;
    ev.push({ key, t });
    log(hh(t).padStart(9), key);
  }

  function buyUpgrades() {
    const n = G.layerCount();
    for (let k = 1; k <= n; k++) {
      const d = G.layerDef(k);
      for (let guard = 0; guard < 300; guard++) {
        let best = null;
        for (const u of d.upgrades) {
          if (!G.upgAvailable(k, u) || G.lvl(k, u.id) >= u.max) continue;
          const c = G.upgCost(k, u);
          if (G.cur(k).lt(c)) continue;
          if (st.thrift && u.max === Infinity && c.gt(G.cur(k).mul(st.thrift))) continue;
          // un joueur économise pour « Briser l'Infini » plutôt que de tout dépenser ailleurs
          if (k === 3 && u.id !== 'in_break') {
            const br = G.upgDef(3, 'in_break');
            if (G.upgAvailable(3, br) && !G.lvl(3, 'in_break') && c.gt(G.upgCost(3, br).mul(0.1))) continue;
          }
          if (!best || (st.expensiveFirst ? c.gt(best.c) : c.lt(best.c))) best = { u, c };
        }
        if (!best) break;
        G.buyUpg(k, best.u.id);
      }
    }
  }

  // configure les automates du jeu comme le ferait un joueur idle
  function setupAutos() {
    G.S.auto.gens = true; G.S.auto.accel = true;
    for (let k = 1; k <= G.layerCount(); k++) {
      const l = G.lay(k);
      if (G.autoUnlocked(k) && !l.auto.on) { l.auto.on = true; l.auto.mode = 'mult'; l.auto.value = Math.max(1, st.mult); }
    }
  }

  function activeStep() {
    G.buyAllMax();
    buyUpgrades();
    const n = G.layerCount();
    for (let k = n + 1; k >= 1; k--) {
      if (!G.canReset(k)) continue;
      const l = G.lay(k);
      const g = G.gain(k);
      let go;
      if (k === 3 && (!G.isBroken() || S().chal.active)) go = true;
      else {
        const minT = st.minTime !== undefined ? st.minTime : 5;
        go = l.time >= minT && g.gte(l.cur.mul(st.mult));
        // joueur qui stagne : prestige quand même après 10 min si le gain vaut ≥ 10 % du total
        if (!go && st.mult > 0 && l.time >= 600 && g.gte(l.cur.mul(0.1))) go = true;
      }
      if (go) {
        const wasChal = S().chal.active;
        G.doReset(k, true);
        if (wasChal && k === 3) mark('défi ' + wasChal);
        break;
      }
    }
    // défis
    const chalOk = !st.noChal && G.resets(3) >= (st.chalAfter || 0);
    if (chalOk && !S().chal.active && G.resets(3) % 2 === 0 && G.resets(3) !== lastChalBB && !G.lvl(3, 'in_break')) {
      lastChalBB = G.resets(3);
      const c = G.CHALLENGES.find((c) => G.chalUnlocked(c.id) && !G.chalDone(c.id) && !(skipChal[c.id] > t));
      if (c) { G.startChallenge(c.id); chalStart = t; }
    }
    if (S().chal.active && t - chalStart > 3600) {
      skipChal[S().chal.active] = t + 2 * 3600;
      G.exitChallenge();
    }
  }

  function checkMarks() {
    for (let k = 1; k <= G.layerCount(); k++) {
      for (const n of [1, 10, 100]) if (G.resets(k) >= n) mark('L' + k + ' #' + n);
    }
    if (G.lvl(3, 'in_break')) mark('Infini brisé');
    for (const c of G.CHALLENGES) if (G.chalDone(c.id)) mark('défi ' + c.id);
    if (S().dust.log10() >= G.INF.log10()) mark('Infini atteint');
  }

  const end = hours * 3600;
  const samples = [];
  let lastSample = -1e9;
  let maxTickMs = 0, offlineMs = 0;
  let bad = false;
  while (t < end) {
    if (st.sessions) {
      const phase = t % st.sessions.every;
      if (phase >= st.sessions.length) {
        // hors-ligne jusqu'à la prochaine session, comme le jeu le fait au retour
        setupAutos();
        const away = st.sessions.every - phase;
        const t0 = Date.now();
        G.simulate(away, 6000);
        offlineMs = Math.max(offlineMs, Date.now() - t0);
        t += away;
        checkMarks();
        continue;
      }
    }
    const t0 = Date.now();
    G.tick(dt);
    const dtMs = Date.now() - t0;
    if (dtMs > maxTickMs) maxTickMs = dtMs;
    t += dt;
    activeStep();
    checkMarks();
    if (t - lastSample >= 1800) {
      lastSample = t;
      const s = { t, dust: S().dust.log10() };
      for (let k = 1; k <= G.layerCount(); k++) s['L' + k] = G.cur(k).log10();
      samples.push(s);
    }
    // garde-fous : aucune valeur ne doit devenir NaN / négative
    if (!isFinite(S().dust.m) || Number.isNaN(S().dust.e) || S().dust.m < 0) { mark('ERREUR valeur invalide'); bad = true; break; }
  }
  const final = { dustLog: S().dust.log10(), layers: G.layerCount(), resets: {}, chal: G.chalCount(), bad };
  for (let k = 1; k <= G.layerCount(); k++) final.resets[k] = G.resets(k);
  return { name, desc: st.desc, hours, dt, events: ev, samples, final, maxTickMs, offlineMs };
}

if (require.main === module) {
  const [name, hours, dt, out] = process.argv.slice(2);
  if (!STRATS[name]) {
    console.log('Profils :');
    for (const k in STRATS) console.log(' ', k.padEnd(10), STRATS[k].desc);
    process.exit(0);
  }
  const r = run(name, parseFloat(hours || '48'), parseFloat(dt || '2'));
  console.log('final', JSON.stringify(r.final), 'maxTickMs', r.maxTickMs, 'offlineMs', r.offlineMs);
  if (out) require('fs').writeFileSync(out, JSON.stringify(r));
}
module.exports = { run, STRATS };
