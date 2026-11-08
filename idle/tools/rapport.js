// Génère le rapport d'équilibrage (HTML) à partir des résultats bruts.
// Usage : node idle/tools/rapport.js <campagne.json> <tests.json> <sortie.html> [campagne-pas4.json] [notes.json]
// notes.json : fragments HTML rédigés à la main { VERDICT, STRAT }.
const fs = require('fs');
const [campFile, testsFile, outFile, coarseFile, notesFile] = process.argv.slice(2);
const camp = JSON.parse(fs.readFileSync(campFile));
const tests = JSON.parse(fs.readFileSync(testsFile));
const load = (f) => (f && fs.existsSync(f) ? JSON.parse(fs.readFileSync(f)) : null);
const coarse = load(coarseFile);
const notes = load(notesFile) || {};

const PROFILES = [
  ['actif', 'Actif'], ['patient', 'Patient'], ['econome', 'Économe'], ['cher', 'Achats chers'],
  ['spam', 'Spam de prestige'], ['defistard', 'Défis tardifs'], ['sansdefis', 'Sans défis'],
  ['idle', 'Idle 3×/jour'], ['idle1', 'Idle 1×/jour'],
].filter(([k]) => camp[k]);

const STAGES = [
  ['L1 #1', 'Supernova', 'Première Supernova'],
  ['L2 #1', 'Effondrement', 'Premier Effondrement'],
  ['L3 #1', 'Big Bang', 'Premier Big Bang (Infini)'],
  ['défi c1', 'Défi 1', 'Défi « Nuit noire »'],
  ['défi c3', 'Défi 3', 'Défi « Quatuor »'],
  ['défi c4', 'Défi 4', 'Défi « Inflation »'],
  ['défi c5', 'Défi 5', 'Défi « Vide quantique »'],
  ['défi c6', 'Défi 6', 'Défi « Racine »'],
  ['défi c2', 'Défi 2', 'Défi « Sans étoiles »'],
  ['Infini brisé', 'Infini brisé', "Briser l'Infini"],
  ['L4 #1', 'Éternité', 'Première Éternité'],
  ['L5 #1', 'Multivers', 'Strate 1 : Multivers'],
  ['L6 #1', 'Omnivers', 'Strate 2 : Omnivers'],
  ['L7 #1', 'Hypervers', 'Strate 3 : Hypervers'],
  ['L8 #1', 'Absolu', 'Strate 4 : Absolu'],
];
const MAIN = ['L1 #1', 'L2 #1', 'L3 #1', 'Infini brisé', 'L4 #1', 'L5 #1', 'L6 #1', 'L7 #1', 'L8 #1'];

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const ev = (p, key) => { const e = camp[p].events.find((x) => x.key === key); return e ? e.t : null; };
function dur(s) {
  if (s === null || s === undefined) return null;
  if (s < 3600) return Math.max(1, Math.round(s / 60)) + ' min';
  if (s < 48 * 3600) return (s / 3600).toFixed(s < 36000 ? 1 : 0).replace('.', ',') + ' h';
  return (s / 86400).toFixed(1).replace('.', ',') + ' j';
}
const hours = camp.actif ? camp.actif.hours : 300;

// ---------------- tableau des temps ----------------
let table = '<div class="scroll"><table class="times"><thead><tr><th scope="col">Étape</th>';
for (const [, label] of PROFILES) table += '<th scope="col">' + esc(label) + '</th>';
table += '</tr></thead><tbody>';
for (const [key, , long] of STAGES) {
  if (!PROFILES.some(([p]) => ev(p, key) !== null) && !MAIN.includes(key)) continue;
  table += '<tr' + (MAIN.includes(key) ? ' class="main"' : '') + '><th scope="row">' + esc(long) + '</th>';
  const ref = ev('actif', key);
  for (const [p] of PROFILES) {
    const t = ev(p, key);
    let cls = '';
    if (t === null) cls = 'none';
    else if (ref !== null && p !== 'actif') cls = t < ref * 0.8 ? 'faster' : (t > ref * 1.25 ? 'slower' : '');
    table += '<td class="' + cls + '">' + (t === null ? '—' : dur(t)) + '</td>';
  }
  table += '</tr>';
}
table += '</tbody></table></div>';

// ---------------- frise (échelle log du temps) ----------------
function timeline() {
  const W = 760, rowH = 34, left = 128, right = 40, top = 30;
  const H = top + PROFILES.length * rowH + 30;
  const t0 = Math.log10(0.05), t1 = Math.log10(hours);
  const x = (h) => left + (Math.log10(Math.max(h, 0.05)) - t0) / (t1 - t0) * (W - left - right);
  let s = '<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Frise des étapes atteintes par profil, temps en échelle logarithmique">';
  for (const h of [0.1, 0.25, 0.5, 1, 2, 5, 10, 24, 48, 100, 200].filter((v) => v <= hours)) {
    const xx = x(h).toFixed(1);
    s += '<line x1="' + xx + '" x2="' + xx + '" y1="' + (top - 6) + '" y2="' + (H - 24) + '" class="grid"/>';
    s += '<text x="' + xx + '" y="' + (H - 8) + '" class="axis" text-anchor="middle">' + (h < 1 ? Math.round(h * 60) + ' min' : h + ' h') + '</text>';
  }
  const marks = MAIN.map((k, i) => [k, i + 1]);
  PROFILES.forEach(([p, label], r) => {
    const y = top + r * rowH + rowH / 2;
    s += '<text x="' + (left - 10) + '" y="' + (y + 4) + '" class="lab" text-anchor="end">' + esc(label) + '</text>';
    s += '<line x1="' + left + '" x2="' + (W - right) + '" y1="' + y + '" y2="' + y + '" class="track"/>';
    let lastX = -99;
    for (const [k, n] of marks) {
      const t = ev(p, k);
      if (t === null) continue;
      let xx = x(t / 3600);
      // étapes atteintes presque en même temps : on les décale pour qu'elles restent lisibles
      if (xx - lastX < 17) xx = lastX + 17;
      s += '<circle cx="' + xx.toFixed(1) + '" cy="' + y + '" r="9" class="dot s' + n + '"/>';
      s += '<text x="' + xx.toFixed(1) + '" y="' + (y + 3.5) + '" class="dotn" text-anchor="middle">' + n + '</text>';
      lastX = xx;
    }
  });
  s += '<text x="' + left + '" y="14" class="axis">temps de jeu (échelle logarithmique) →</text>';
  return s + '</svg>';
}
const legend = MAIN.map((k, i) => '<li><span class="dot-l s' + (i + 1) + '">' + (i + 1) + '</span>' + esc(STAGES.find((s) => s[0] === k)[1]) + '</li>').join('');

// ---------------- tests ----------------
const results = tests.results || [];
const okN = results.filter((r) => r.ok).length;
const testRows = results.map((r) => '<tr><td><span class="pill ' + (r.ok ? 'ok' : 'ko') + '">' + (r.ok ? 'OK' : 'Échec') + '</span></td><td>' + esc(r.name) + (r.detail ? '<div class="detail">' + esc(r.detail) + '</div>' : '') + '</td></tr>').join('');

// ---------------- fins de partie ----------------
const finals = PROFILES.map(([p, label]) => {
  const f = camp[p].final;
  const top = f.layers;
  let maxL = 0;
  for (const k in f.resets) if (f.resets[k] > 0) maxL = Math.max(maxL, +k);
  const names = { 1: 'Supernova', 2: 'Effondrement', 3: 'Big Bang', 4: 'Éternité', 5: 'Multivers', 6: 'Omnivers', 7: 'Hypervers', 8: 'Absolu', 9: 'Paradoxe' };
  const totalResets = Object.values(f.resets).reduce((a, b) => a + b, 0);
  return '<tr><th scope="row">' + esc(label) + '</th><td>' + esc(names[maxL] || ('couche ' + maxL)) + '</td><td>' + totalResets.toLocaleString('fr-FR') + '</td><td>' + f.chal + '/6</td><td>' + (f.bad ? '<span class="pill ko">oui</span>' : 'non') + '</td><td>' + (camp[p].maxTickMs) + ' ms' + (camp[p].offlineMs ? ' / ' + camp[p].offlineMs + ' ms' : '') + '</td></tr>';
}).join('');

const descs = PROFILES.map(([p, label]) => '<li><b>' + esc(label) + '</b> : ' + esc(camp[p].desc) + '</li>').join('');

// comparaison pas fin
let fineNote = '';
if (coarse) {
  const cev = (p, k) => { if (!coarse[p]) return null; const e = coarse[p].events.find((x) => x.key === k); return e ? e.t : null; };
  const cols = [['actif', 'Actif'], ['patient', 'Patient']];
  const rows = MAIN.map((k) => {
    const vals = [];
    for (const [p] of cols) vals.push(ev(p, k), cev(p, k));
    if (vals.every((v) => v == null)) return '';
    return '<tr><th scope="row">' + esc(STAGES.find((s) => s[0] === k)[2]) + '</th>' + vals.map((v) => '<td>' + (dur(v) || '—') + '</td>').join('') + '</tr>';
  }).join('');
  fineNote = '<div class="scroll"><table class="times"><thead><tr><th scope="col">Étape</th><th scope="col">Actif, réagit chaque 1 s</th><th scope="col">Actif, chaque 4 s</th><th scope="col">Patient, chaque 1 s</th><th scope="col">Patient, chaque 4 s</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
}
const sens = (tests.sensitivity || []).map((s) => '<tr><td>' + String(s.dt).replace('.', ',') + ' s</td><td>' + (s.L1 ? dur(s.L1) : '—') + '</td><td>' + (s.L2 ? dur(s.L2) : '—') + '</td><td>' + (s.score || 0).toFixed(1).replace('.', ',') + '</td></tr>').join('');

const tpl = fs.readFileSync(__dirname + '/rapport.template.html', 'utf8');
const html = tpl
  .replace('{{TABLE}}', table)
  .replace('{{TIMELINE}}', timeline())
  .replace('{{LEGEND}}', legend)
  .replace('{{TESTS}}', testRows)
  .replace(/{{OKN}}/g, okN)
  .replace(/{{TESTN}}/g, results.length)
  .replace('{{FINALS}}', finals)
  .replace('{{DESCS}}', descs)
  .replace('{{FINE}}', fineNote)
  .replace('{{VERDICT}}', notes.VERDICT || '')
  .replace('{{STRAT}}', notes.STRAT || '')
  .replace('{{SENS}}', sens)
  .replace(/{{HOURS}}/g, hours)
  .replace(/{{EBASE}}/g, (tests.Ebase || 0).toFixed(2).replace('.', ','))
  .replace(/{{EMAX}}/g, (tests.Emax || 0).toFixed(2).replace('.', ','))
  .replace(/{{TICK}}/g, (tests.tickMs || 0).toFixed(2).replace('.', ','))
  .replace(/{{OFF7}}/g, tests.offline7dMs || 0);
fs.writeFileSync(outFile, html);
console.log('Rapport écrit :', outFile);
