// Génère icon-192.png et icon-512.png à partir de icon.svg (node idle/tools/icons.js)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const dir = path.join(__dirname, '..');
  const svg = fs.readFileSync(path.join(dir, 'icon.svg'), 'utf8');
  const b = await chromium.launch();
  for (const s of [192, 512]) {
    const p = await b.newPage({ viewport: { width: s, height: s } });
    await p.setContent(`<style>body{margin:0}svg{width:${s}px;height:${s}px;display:block}</style>${svg}`);
    await p.screenshot({ path: path.join(dir, `icon-${s}.png`) });
  }
  await b.close();
})();
