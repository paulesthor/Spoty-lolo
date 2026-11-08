/*
 * Big Odeur : sprites en pixel art (aucun emoji dans le jeu).
 * Chaque sprite est une grille de caractères ; chaque caractère est une couleur de la palette,
 * « . » = transparent. Rendu une seule fois en image (canvas), affiché en image-rendering: pixelated.
 */
(function (root) {
  'use strict';
  const PAL = {
    k: '#0d0f08', // contour
    g: '#a6e22e', G: '#5f8a12', // bile
    y: '#e6db74', Y: '#a89a3a', // sueur
    w: '#eef2d8', W: '#9aa184', // blanc sale, gris
    b: '#8a6236', B: '#4e3519', // carton, café
    r: '#f92672', o: '#fd971f', // alerte
    s: '#d9a77c', S: '#9b6c48', // peau
    c: '#5fa8d3', C: '#2b5672', // écran
  };

  const SPRITES = {
    sweat: [
      '............',
      '.....kk.....',
      '....kyyk....',
      '....kyyk....',
      '...kyyyyk...',
      '..kyywyyyk..',
      '..kywyyyyk..',
      '..kyyyyyYk..',
      '..kyyyyYYk..',
      '...kyyYYk...',
      '....kkkk....',
      '............',
    ],
    sock: [
      '....kkkkk...',
      '....kgggk...',
      '....kGGGk...',
      '....kwwwk...',
      '....kwYwk...',
      '....kwwwk...',
      '....kwwwkk..',
      '...kwwwwwwk.',
      '..kwwYwwwwk.',
      '..kwwwwwYWk.',
      '..kkkkkkkk..',
      '............',
    ],
    mug: [
      '............',
      '...g...g....',
      '..g...g.....',
      '...g...g....',
      '.kkkkkkkk...',
      '.kBBBBBBkkk.',
      '.kwwwwwwk.k.',
      '.kwwwwwwk.k.',
      '.kwwgwwwkkk.',
      '.kwwwwwWk...',
      '..kkkkkk....',
      '............',
    ],
    pizza: [
      '............',
      '...g....g...',
      '.kkkkkkkkkk.',
      'kbbbbbbbbbbk',
      'kkkkkkkkkkkk',
      'kbbbbbbbbbbk',
      'kbbYbbbbbbbk',
      'kbYYbbbbobbk',
      'kbbbbbbooobk',
      'kbbbbbbbbbbk',
      'kkkkkkkkkkkk',
      '............',
    ],
    hoodie: [
      '...kkkkkk...',
      '..kGGGGGGk..',
      '.kGGkkkkGGk.',
      '.kGk....kGk.',
      'kGGGkkkkGGGk',
      'kGGGGwwGGGGk',
      'kGkGGwwGGkGk',
      'kGkGGGGGGkGk',
      'kGkGGYGGGkGk',
      'kkkGGGGGGkkk',
      '..kkkkkkkk..',
      '............',
    ],
    keyboard: [
      '............',
      '............',
      '............',
      'kkkkkkkkkkkk',
      'kWwWwWwWwWwk',
      'kwWwWwYwWwWk',
      'kWwWYwWwWyWk',
      'kwwWWWWWWwwk',
      'kkkkkkkkkkkk',
      '..Y.....Y...',
      '............',
      '............',
    ],
    office: [
      '....g..g....',
      '...g..g.....',
      '..kkkkkkkk..',
      '..kWWWWWWk..',
      '..kWyWyWyk..',
      '..kWWWWWWk..',
      '..kWyWkWyk..',
      '..kWWWWWWk..',
      '..kWyWkkWk..',
      '..kWWWkkWk..',
      'kkkkkkkkkkkk',
      '............',
    ],
    rack: [
      '..kkkkkkkk..',
      '..kWWWWWWk..',
      '..kWgWWWrk..',
      '..kkkkkkkk..',
      '..kWWWWWWk..',
      '..kWgWWWgk..',
      '..kkkkkkkk..',
      '..kWWWWWWk..',
      '..kWrWWWgk..',
      '..kkkkkkkk..',
      '...k....k...',
      '............',
    ],
    laptop: [
      '............',
      '..kkkkkkkk..',
      '..kcccccck..',
      '..kcgcgcck..',
      '..kccgccck..',
      '..kcccccck..',
      '..kkkkkkkk..',
      '.kWWWWWWWWk.',
      'kWWWWWWWWWWk',
      'kkkkkkkkkkkk',
      '..o......o..',
      '............',
    ],
    bug: [
      '............',
      '...k....k...',
      '....k..k....',
      '...kkkkkk...',
      '..kggggggk..',
      'k.kgkggkgk.k',
      '.kkggggggkk.',
      'k.kgggggGk.k',
      '..kggGggGk..',
      '.kkgggggGkk.',
      'k..kkkkkk..k',
      '............',
    ],
    skull: [
      '...kkkkkk...',
      '..kwwwwwwk..',
      '.kwwwwwwwwk.',
      '.kwkkwwkkwk.',
      '.kwkkwwkkwk.',
      '.kwwwkkwwwk.',
      '..kwwwwwwk..',
      '...kwkwkwk..',
      '...kkkkkk...',
      '............',
      '..g......g..',
      '............',
    ],
    alarm: [
      '....kkkk....',
      '...krrrrk...',
      '..krrrrrrk..',
      '..krwrrrrk..',
      '..krrrrrrk..',
      '.krrrrrrrrk.',
      '.kkkkkkkkkk.',
      '.....kk.....',
      '............',
      '.o..o..o..o.',
      '..o......o..',
      '............',
    ],
    form: [
      '...kkkkk....',
      '.kkWWWWWkk..',
      '.kwwwwwwwwk.',
      '.kwkkkkkwwk.',
      '.kwwwwwwwwk.',
      '.kwkkkkkkwk.',
      '.kwwwwwwwwk.',
      '.kwkkkkwwwk.',
      '.kwwwwwrrrk.',
      '.kwwwwwrrrk.',
      '.kkkkkkkkkk.',
      '............',
    ],
    carton: [
      '............',
      '.....gg.....',
      '....gGGg....',
      '.kkkkkkkkkk.',
      'kbbbbbbbbbbk',
      'kkkkkkkkkkkk',
      '.kbbbbbbbbk.',
      '.kbbbBBbbbk.',
      '.kbbbBBbbbk.',
      '.kbbbbbbbbk.',
      '.kkkkkkkkkk.',
      '............',
    ],
    cloud: [
      '............',
      '....kkkk....',
      '...kggggk...',
      '.kkggggggkk.',
      'kgggggggggGk',
      'kggGgggggGGk',
      'kgggggggGGGk',
      '.kGGGGGGGGk.',
      '..kkkkkkkk..',
      '...g...g....',
      '..g...g.....',
      '............',
    ],
    chart: [
      '............',
      '........kkk.',
      '........kyk.',
      '....kkk.kyk.',
      '....kgk.kyk.',
      'kkk.kgk.kyk.',
      'kWk.kgk.kyk.',
      'kWk.kgk.kyk.',
      'kWk.kgk.kyk.',
      'kkkkkkkkkkkk',
      '............',
      '............',
    ],
    gear: [
      '....kkkk....',
      '.kk.kWWk.kk.',
      '.kWkkWWkkWk.',
      '..kWWWWWWk..',
      'kkkWWkkWWkkk',
      'kWWWk..kWWWk',
      'kWWWk..kWWWk',
      'kkkWWkkWWkkk',
      '..kWWWWWWk..',
      '.kWkkWWkkWk.',
      '.kk.kWWk.kk.',
      '....kkkk....',
    ],
    lock: [
      '............',
      '....kkkk....',
      '...kWWWWk...',
      '...kW..Wk...',
      '...kW..Wk...',
      '..kkkkkkkk..',
      '..kyyyyyyk..',
      '..kyyYYyyk..',
      '..kyyYYyyk..',
      '..kyyyyyyk..',
      '..kkkkkkkk..',
      '............',
    ],
    fly: [
      '............',
      '............',
      '..ww....ww..',
      '.wWWw..wWWw.',
      '..wWWkkWWw..',
      '....kkkk....',
      '...kkrrkk...',
      '...kkkkkk...',
      '....kkkk....',
      '...k....k...',
      '............',
      '............',
    ],
    dev: [
      '................',
      '.....kkkkkk.....',
      '....kGGGGGGk....',
      '...kGGsssSGGk...',
      '...kGskssksGk...',
      '...kGsssssSGk...',
      '...kGSsrrSSGk...',
      '..kkGGGkkGGGkk..',
      '.kGGGGGGGGGGGGk.',
      '.kGGGkkkkkkGGGk.',
      '.kGGkcccccckGGk.',
      '.kGGkcgcgcckGGk.',
      '.kssSkcccccksssk',
      'kkkkkkkkkkkkkkkk',
      '.kWWWWWWWWWWWWk.',
      '................',
    ],
  };

  const cache = {};
  function url(name) {
    if (cache[name]) return cache[name];
    const grid = SPRITES[name];
    if (!grid || typeof document === 'undefined') return '';
    const hgt = grid.length, wid = grid[0].length;
    const cv = document.createElement('canvas');
    cv.width = wid; cv.height = hgt;
    const cx = cv.getContext('2d');
    for (let y = 0; y < hgt; y++) {
      for (let x = 0; x < wid; x++) {
        const c = PAL[grid[y][x]];
        if (!c) continue;
        cx.fillStyle = c;
        cx.fillRect(x, y, 1, 1);
      }
    }
    cache[name] = cv.toDataURL('image/png');
    return cache[name];
  }
  // <img> pixelisé ; size = taille affichée en pixels CSS
  function el(name, size, cls) {
    const img = document.createElement('img');
    img.src = url(name);
    img.alt = '';
    img.className = 'px' + (cls ? ' ' + cls : '');
    const n = SPRITES[name] ? SPRITES[name][0].length : 12;
    const s = size || n * 2;
    img.width = s; img.height = s;
    img.setAttribute('aria-hidden', 'true');
    return img;
  }
  // SVG (pour l'icône de l'appli)
  function svg(name, px) {
    const grid = SPRITES[name];
    let r = '';
    grid.forEach((row, y) => { for (let x = 0; x < row.length; x++) { const c = PAL[row[x]]; if (c) r += '<rect x="' + x * px + '" y="' + y * px + '" width="' + px + '" height="' + px + '" fill="' + c + '"/>'; } });
    return r;
  }

  root.Sprites = { SPRITES, PAL, url, el, svg };
  if (typeof module !== 'undefined') module.exports = root.Sprites;
})(typeof window !== 'undefined' ? window : globalThis);
