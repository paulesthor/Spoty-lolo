// Lance tous les profils de joueurs en parallèle et regroupe les résultats.
// Usage : node idle/tools/campaign.js <heures> <pas> <dossier-sortie> [profil1,profil2,…]
const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { STRATS } = require('./sim.js');

const [hours = '240', dt = '2', outDir = '.', only] = process.argv.slice(2);
const names = only ? only.split(',') : Object.keys(STRATS);
fs.mkdirSync(outDir, { recursive: true });
const queue = names.slice();
const par = Math.max(1, os.cpus().length);
let running = 0;
const t0 = Date.now();

function next() {
  if (!queue.length) { if (!running) done(); return; }
  const name = queue.shift();
  running++;
  const out = path.join(outDir, name + '.json');
  execFile('node', [path.join(__dirname, 'sim.js'), name, hours, dt, out], { maxBuffer: 1 << 26 }, (err, stdout) => {
    running--;
    console.log('[' + ((Date.now() - t0) / 60000).toFixed(1) + ' min] ' + name + (err ? ' ERREUR ' + err.message : ' ' + stdout.trim().split('\n').pop()));
    next();
  });
}
function done() {
  const all = {};
  for (const n of names) { try { all[n] = JSON.parse(fs.readFileSync(path.join(outDir, n + '.json'))); } catch (e) { /* profil échoué */ } }
  fs.writeFileSync(path.join(outDir, 'campagne.json'), JSON.stringify(all));
  console.log('Terminé en ' + ((Date.now() - t0) / 60000).toFixed(1) + ' min');
}
for (let i = 0; i < par; i++) next();
