/* Big Odeur : interface mobile. */
(function () {
  'use strict';
  const G = window.Game;
  const Big = window.Big;
  const SAVE_KEY = 'cosmos-infini-save';
  const OFFLINE_MAX = 7 * 24 * 3600;
  const fmt = (x, d) => G.fmt(x, d);
  const $ = (id) => document.getElementById(id);

  // ------------------------------------------------------------------
  // Mini-outils DOM
  // ------------------------------------------------------------------
  let updaters = [];
  function h(tag, props, ...kids) {
    const el = document.createElement(tag);
    if (props) {
      for (const k in props) {
        const v = props[k];
        if (k === 'class') el.className = v;
        else if (k === 'text') el.textContent = v;
        else if (k === 'html') el.innerHTML = v;
        else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
        else el.setAttribute(k, v);
      }
    }
    for (const c of kids.flat()) if (c != null && c !== false) el.append(c.nodeType ? c : String(c));
    return el;
  }
  // texte mis à jour à chaque image
  function live(fn, tag, cls) {
    const el = h(tag || 'span', cls ? { class: cls } : null);
    updaters.push(() => { const v = fn(); if (el._v !== v) { el._v = v; el.textContent = v; } });
    return el;
  }
  function liveClass(el, cls, fn) {
    updaters.push(() => { const v = !!fn(); if (el['_c' + cls] !== v) { el['_c' + cls] = v; el.classList.toggle(cls, v); } });
    return el;
  }
  // bouton qui se répète quand on garde le doigt dessus
  // Bouton d'achat : un tap achète une fois ; un appui long (sans bouger) achète en continu.
  // Rien n'est acheté si le doigt glisse (défilement de la liste) ou si le navigateur
  // reprend la main (pointercancel), pour éviter les achats involontaires.
  function holdButton(el, action) {
    let timer = null, rep = null, startX = 0, startY = 0, active = false, repeated = false;
    const stop = () => { clearTimeout(timer); clearInterval(rep); timer = rep = null; };
    el.addEventListener('pointerdown', (e) => {
      if (e.button !== undefined && e.button !== 0) return;
      active = true; repeated = false; startX = e.clientX; startY = e.clientY;
      stop();
      timer = setTimeout(() => { if (!active) return; repeated = true; action(); rep = setInterval(action, 80); }, 450);
    });
    el.addEventListener('pointermove', (e) => {
      if (active && Math.hypot(e.clientX - startX, e.clientY - startY) > 10) { active = false; stop(); }
    });
    el.addEventListener('pointerup', () => {
      if (active && !repeated) action();
      active = false; stop();
    });
    ['pointercancel', 'pointerleave'].forEach((ev) => el.addEventListener(ev, () => { active = false; stop(); }));
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); action(); } });
    return el;
  }

  // barre de progression (0 → 1) avec pourcentage
  function progressBar(fn, labelFn) {
    const fill = h('div', { class: 'fill' });
    const pct = h('span', { class: 'pct' });
    const box = h('div', { class: 'goal' });
    if (labelFn) box.append(live(labelFn, 'div', 'goal-label'));
    box.append(h('div', { class: 'goal-row' }, h('div', { class: 'bar' }, fill), pct));
    updaters.push(() => {
      const v = Math.max(0, Math.min(1, fn() || 0));
      const t = pctText(v);
      if (pct._v !== t) { pct._v = t; pct.textContent = t; fill.style.width = (v * 100).toFixed(2) + '%'; }
    });
    return box;
  }
  function pctText(v) { return v >= 1 ? '100 %' : (v < 0.1 ? (v * 100).toFixed(1) : Math.floor(v * 100)).toString().replace('.', ',') + ' %'; }

  function toast(msg) {
    const t = h('div', { class: 'toast', text: msg });
    $('toasts').append(t);
    setTimeout(() => t.remove(), 3300);
  }

  function modal(body, actions) {
    const m = $('modal');
    const b = $('modal-body');
    b.innerHTML = '';
    b.append(body);
    const a = $('modal-actions');
    a.innerHTML = '';
    (actions || [{ label: 'OK' }]).forEach((ac) => {
      a.append(h('button', { class: ac.cls || '', onclick: () => { if (ac.fn && ac.fn() === false) return; m.classList.add('hidden'); } }, ac.label));
    });
    m.classList.remove('hidden');
  }

  function duration(s) {
    s = Math.floor(s);
    const d = Math.floor(s / 86400), hh = Math.floor((s % 86400) / 3600), mm = Math.floor((s % 3600) / 60), ss = s % 60;
    if (d) return d + ' j ' + hh + ' h';
    if (hh) return hh + ' h ' + mm + ' min';
    if (mm) return mm + ' min ' + ss + ' s';
    return ss + ' s';
  }

  // ------------------------------------------------------------------
  // Onglets
  // ------------------------------------------------------------------
  let tab = 'gens';
  let layerSel = 1;      // couche affichée dans l'onglet Prestiges
  let menuSel = 'stats'; // Stats ou Options dans l'onglet Menu

  // couches visibles (déjà vues ou déjà faites)
  function seenLayers() {
    const out = [];
    const n = G.layerCount();
    for (let k = 1; k <= n; k++) if (G.S.seen[k] || G.resets(k)) out.push(k);
    return out;
  }

  function tabs() {
    const list = [{ id: 'gens', ic: 'sock', label: 'Puer' }];
    if (seenLayers().length) list.push({ id: 'prest', ic: 'bug', label: 'Prestiges' });
    if (G.resets(3) >= 1) list.push({ id: 'chal', ic: 'form', label: 'Plans RH' });
    list.push({ id: 'menu', ic: 'gear', label: 'Menu' });
    return list;
  }

  // une amélioration achetable dans une couche ?
  function layerHasNews(k) {
    return G.layerDef(k).upgrades.some((u) => G.upgAvailable(k, u) && G.lvl(k, u.id) < u.max && G.cur(k).gte(G.upgCost(k, u)));
  }
  function tabHasNews(t) {
    if (t.id === 'prest') return seenLayers().some(layerHasNews);
    return false;
  }

  let navKey = '';
  function renderNav() {
    const list = tabs();
    const key = list.map((t) => t.id).join(',') + '|' + tab;
    if (key === navKey) return;
    navKey = key;
    if (!list.find((t) => t.id === tab)) tab = 'gens';
    const nav = $('tabs');
    nav.innerHTML = '';
    for (const t of list) {
      const dot = h('span', { class: 'dot hidden' });
      const b = h('button', { class: t.id === tab ? 'on' : '', onclick: () => { tab = t.id; viewKey = ''; navKey = ''; window.scrollTo(0, 0); } },
        Sprites.el(t.ic, 24, 'ic'), h('span', { text: t.label }), dot);
      b._dot = dot;
      b._tab = t;
      nav.append(b);
    }
  }
  function updateNavDots() {
    for (const b of $('tabs').children) {
      if (!b._tab) continue;
      b._dot.classList.toggle('hidden', !tabHasNews(b._tab));
    }
  }

  // ------------------------------------------------------------------
  // Vue : Générateurs
  // ------------------------------------------------------------------
  function buyLabel(i) {
    const mode = G.S.options.buy;
    const o = G.genOffer(i, mode);
    const top = mode === 'max' ? (o.can ? 'Max : ×' + fmt(o.n) : 'Max') : '×' + o.n;
    return { top, cost: o.cost, can: o.can };
  }
  function accelLabel() {
    const max = G.S.options.buy === 'max';
    const o = G.accelOffer(max);
    return { top: max ? (o.can ? 'Max : ×' + fmt(o.n) : 'Max') : 'Acheter', cost: o.cost, can: o.can };
  }

  function prestigeButton(k, compact) {
    const d = G.layerDef(k);
    const btn = h('button', { class: 'primary', onclick: () => confirmReset(k) });
    btn.append(live(() => {
      const blocked = d.blocked();
      if (blocked) return blocked;
      if (!G.reached(k)) return d.verb + ' — ' + d.reqText();
      if (!G.canReset(k)) return d.verb + ' : +' + fmt(G.gain(k)) + ' ' + d.cur + ' (dans ' + Math.ceil(G.waitLeft(k)) + ' s)';
      if (k === 3 && G.S.chal.active) return 'Valider le plan RH (' + d.verb + ')';
      return d.verb + ' : +' + fmt(G.gain(k)) + ' ' + d.cur + ratio(k);
    }));
    liveClass(btn, 'can', () => G.canReset(k));
    liveClass(btn, 'off', () => !G.canReset(k));
    if (compact) liveClass(btn, 'hidden', () => !G.reached(k) || (G.lay(k).auto.on && G.autoUnlocked(k)));
    return btn;
  }

  // combien de fois le total actuel ce prestige rapporterait (aide à choisir le bon moment)
  function ratio(k) {
    const c = G.cur(k);
    if (c.isZero() || (k === 3 && !G.isBroken())) return '';
    const r = G.gain(k).div(c);
    return ' (×' + (r.lt(10) ? r.toNumber().toFixed(1).replace('.', ',') : fmt(r)) + ')';
  }

  function confirmReset(k) {
    if (!G.canReset(k)) return;
    const d = G.layerDef(k);
    if (G.resets(k) === 0 && !G.S.chal.active) {
      const below = [];
      for (let j = 1; j < k; j++) below.push(G.layerDef(j).cur);
      modal(h('div', null,
        h('h2', { text: d.verb + ' ?' }),
        h('p', { text: 'Tu vas remettre à zéro tes Relents, tes générateurs' + (below.length ? ', ' + below.join(', ') : '') + '. En échange : +' + fmt(G.gain(k)) + ' ' + d.cur + '.' })),
      [{ label: 'Annuler' }, { label: d.verb, cls: 'can', fn: () => { G.doReset(k); } }]);
      return;
    }
    G.doReset(k);
  }

  // ligne compacte : sprite, nom, une ligne de chiffres, bouton ; un appui sur la ligne ouvre le détail
  function compactRow(sprite, name, statsFn, detailNodes, btn) {
    const detail = h('div', { class: 'detail' }, ...detailNodes);
    const row = h('div', { class: 'line' },
      h('div', { class: 'line-main', onclick: () => row.classList.toggle('open') },
        h('span', { class: 'gen-ic' }, Sprites.el(sprite, 24)),
        h('div', { class: 'grow' }, h('div', { class: 'name', text: name }), live(statsFn, 'div', 'amt num'))),
      btn, detail);
    return row;
  }

  function buildGens(root) {
    const S = G.S;
    const seg = h('div', { class: 'seg' });
    for (const [m, label] of [['1', '×1'], ['10', '×10'], ['max', 'Max']]) {
      const b = h('button', { onclick: () => { S.options.buy = m; } }, label);
      liveClass(b, 'on', () => S.options.buy === m);
      seg.append(b);
    }
    root.append(h('div', { class: 'row toolbar' }, h('div', { class: 'grow' }, seg),
      h('button', { class: 'small', onclick: () => G.buyAllMax() }, 'Tout max')));

    const list = h('div', { class: 'list' });
    // laptop (accélérateur)
    const accBtn = holdButton(h('button', { class: 'buy' }, live(() => fmt(accelLabel().cost), 'b'), live(() => accelLabel().top)), () => G.buyAccel(S.options.buy === 'max'));
    liveClass(accBtn, 'can', () => accelLabel().can);
    list.append(compactRow('laptop', 'Laptop qui chauffe',
      () => S.accel + ' · ' + (G.M.accelOn ? '×' + fmt(Big.pow10(S.accel * Math.log10(G.M.accelBase))) + ' sur les Relents' : 'mort (plan RH)'),
      [h('div', { class: 'flavor', text: "Posé sur tes cuisses depuis 9 h. Le ventilo hurle et crache ta crasse dans tout l'étage." }),
        live(() => '×' + G.M.accelBase.toFixed(3).replace('.', ',') + ' par achat', 'div', 'sub')],
      accBtn));
    G.GENS.forEach((gd, i) => {
      if (!G.genUnlocked(i)) return;
      const btn = holdButton(h('button', { class: 'buy' }, live(() => fmt(buyLabel(i).cost), 'b'), live(() => buyLabel(i).top)), () => G.buyGen(i, S.options.buy));
      liveClass(btn, 'can', () => buyLabel(i).can);
      list.append(compactRow(gd.icon, gd.name,
        () => fmt(S.gens[i].amount) + ' · ×' + fmt(G.genMult(i)),
        [h('div', { class: 'flavor', text: gd.flavor || '' }),
          live(() => S.gens[i].bought + ' achetés' + (i === 0 ? ' · produisent les Relents' : ' · ' + fmt(S.gens[i].amount.mul(G.genMult(i))) + '/s de ' + G.GENS[i - 1].name), 'div', 'sub')],
        btn));
    });
    root.append(list);

    if (G.autoGensUnlocked() || G.autoAccelUnlocked()) {
      const a = h('div', { class: 'card compact' }, h('div', { class: 'title' }, 'Automates'));
      if (G.autoGensUnlocked()) a.append(toggleRow('Acheter les générateurs', () => S.auto.gens, (v) => { S.auto.gens = v; }));
      if (G.autoAccelUnlocked()) a.append(toggleRow('Acheter le Laptop qui chauffe', () => S.auto.accel, (v) => { S.auto.accel = v; }));
      root.append(a);
    }
  }

  function toggleRow(label, get, set) {
    const cb = h('input', { type: 'checkbox' });
    cb.checked = get();
    cb.addEventListener('change', () => set(cb.checked));
    updaters.push(() => { if (document.activeElement !== cb && cb.checked !== get()) cb.checked = get(); });
    return h('label', { class: 'toggle' }, h('span', { text: label }), cb);
  }

  function gensKey() {
    const S = G.S;
    return [G.GENS.map((_, i) => G.genUnlocked(i) ? 1 : 0).join(''), G.autoGensUnlocked(), G.autoAccelUnlocked(), S.chal.active].join('|');
  }

  // ------------------------------------------------------------------
  // Vue : une couche de prestige
  // ------------------------------------------------------------------
  function buildLayer(root, k) {
    const d = G.layerDef(k);
    const L = G.lay(k);

    const head = h('div', { class: 'card big-cur' },
      h('div', { class: 'cur-row' }, Sprites.el(d.sym, 36, 'cur-ic'),
        h('div', { class: 'grow' }, h('div', { class: 'layer-name', text: d.name }),
          h('div', { class: 'amount num' }, live(() => fmt(L.cur)), h('span', { class: 'cur-name', text: ' ' + d.cur })))),
      live(() => d.effectText(), 'div', 'sub'));
    if (d.flavor) {
      const fl = h('div', { class: 'flavor clamp', text: d.flavor, onclick: () => fl.classList.toggle('clamp') });
      head.append(fl);
    }
    root.append(head);

    root.append(prestigeButton(k));
    const bar = progressBar(() => G.progress(k), () => 'Seuil : ' + d.reqText());
    liveClass(bar, 'hidden', () => G.reached(k));
    root.append(bar);
    root.append(h('div', { class: 'muted', style: 'margin:6px 2px 0' },
      live(() => d.verb + ' : ' + G.resets(k) + ' fois — temps actuel ' + duration(L.time) + (G.M.passive[k] ? ' — passif ' + Math.round(G.M.passive[k] * 100) + ' %/s' : ''))));

    if (G.autoUnlocked(k)) root.append(autoBox(k));
    if (k === 1 && G.autoSnUpgUnlocked()) {
      root.append(h('div', { class: 'card auto-box', style: 'margin-top:8px' },
        toggleRow('Achat automatique des améliorations', () => G.S.auto.snUpg, (v) => { G.S.auto.snUpg = v; }),
        h('div', { class: 'muted', text: 'Achète la moins chère dès que possible. Désactive-le pour garder tes Bugs en prod (leur bonus dépend de ce que tu gardes).' })));
    }

    root.append(h('h3', { text: 'Améliorations' }));
    const ul = h('div', { class: 'list' });
    for (const u of d.upgrades) ul.append(upgradeCard(k, u));
    root.append(ul);

    if (d.milestones.length) {
      root.append(h('h3', { text: 'Jalons (nombre de ' + d.verb + ')' }));
      const box = h('div', { class: 'card' });
      for (const ms of d.milestones) {
        const row = h('div', { class: 'milestone' }, h('span', { class: 'n', text: ms.n + '×' }), h('span', { text: ms.text }));
        liveClass(row, 'ok', () => G.resets(k) >= ms.n);
        box.append(row);
      }
      root.append(box);
    }
  }

  function upgradeCard(k, u) {
    if (!G.upgAvailable(k, u)) {
      return h('div', { class: 'line locked' }, h('div', { class: 'line-main' },
        h('span', { class: 'gen-ic' }, Sprites.el('lock', 20)),
        h('div', { class: 'grow' }, h('div', { class: 'name', text: u.name }), h('div', { class: 'amt', text: u.reqText ? u.reqText() : 'Verrouillé' }))));
    }
    const maxed = () => G.lvl(k, u.id) >= u.max;
    const btn = holdButton(h('button', { class: 'buy' },
      live(() => maxed() ? 'Max' : fmt(G.upgCost(k, u)), 'b'),
      live(() => maxed() ? '' : G.layerDef(k).cur)), () => G.buyUpg(k, u.id));
    liveClass(btn, 'can', () => !maxed() && G.cur(k).gte(G.upgCost(k, u)));
    liveClass(btn, 'off', () => maxed());
    const detail = h('div', { class: 'detail' },
      u.flavor ? h('div', { class: 'flavor', text: u.flavor }) : null,
      live(() => G.lvl(k, u.id) > 0 ? 'Actuel : ' + u.eff(G.lvl(k, u.id)) : 'Pas encore acheté', 'div', 'sub'));
    const lvlTxt = () => u.max === 1 ? '' : (u.max === Infinity ? ' · niv. ' + G.lvl(k, u.id) : ' · ' + G.lvl(k, u.id) + '/' + u.max);
    const row = h('div', { class: 'line' },
      h('div', { class: 'line-main', onclick: () => row.classList.toggle('open') },
        h('div', { class: 'grow' }, h('div', { class: 'name' }, u.name, live(lvlTxt, 'span', 'muted')), h('div', { class: 'amt', text: u.desc() }))),
      btn, detail);
    liveClass(row, 'done', maxed);
    return row;
  }

  function autoBox(k) {
    const L = G.lay(k);
    const d = G.layerDef(k);
    const box = h('div', { class: 'card auto-box', style: 'margin-top:8px' });
    box.append(toggleRow(d.verb + ' automatique', () => L.auto.on, (v) => { L.auto.on = v; }));
    const sel = h('select', null,
      h('option', { value: 'mult' }, 'Quand gain ≥ X × actuel'),
      h('option', { value: 'time' }, 'Toutes les X secondes'));
    sel.value = L.auto.mode;
    sel.addEventListener('change', () => { L.auto.mode = sel.value; });
    const inp = h('input', { type: 'number', min: '0', step: 'any', inputmode: 'decimal' });
    inp.value = L.auto.value;
    inp.addEventListener('change', () => { const v = parseFloat(inp.value); L.auto.value = isFinite(v) && v >= 0 ? v : 1; inp.value = L.auto.value; });
    box.append(h('div', { class: 'row' }, h('div', { class: 'grow' }, sel), h('span', { text: 'X =' }), inp));
    box.append(h('div', { class: 'muted', text: 'Conseil : attendre un gain d\'au moins ×10 rapporte bien plus que prestiger dès que le gain double.' }));
    return box;
  }

  function layerKey(k) {
    const d = G.layerDef(k);
    return [k, d.upgrades.map((u) => G.upgAvailable(k, u) ? 1 : 0).join(''), G.autoUnlocked(k), k === 1 && G.autoSnUpgUnlocked()].join('|');
  }

  // ------------------------------------------------------------------
  // Vue : Défis
  // ------------------------------------------------------------------
  function buildChal(root) {
    const S = G.S;
    root.append(h('div', { class: 'card' },
      h('div', { class: 'sub', text: "Les RH t'imposent un « plan d'amélioration personnelle » : tout repart de zéro (améliorations comprises) avec une contrainte. Atteins quand même le seuil de la Convention de Genève pour le valider : la récompense est permanente. Tu retrouves tes améliorations à la fin." }),
      live(() => 'Plans RH survécus : ' + G.chalCount() + '/' + G.CHALLENGES.length + ' — ' + G.BREAK_CHALLENGES + ' requis pour violer la Convention de Genève', 'div', 'sub')));
    const exit = h('button', { class: 'primary danger', onclick: () => G.exitChallenge() }, 'Abandonner le plan RH (les RH notent ta lâcheté)');
    liveClass(exit, 'hidden', () => !S.chal.active);
    root.append(exit);
    for (const c of G.CHALLENGES) {
      const card = h('div', { class: 'card' });
      liveClass(card, 'done', () => G.chalDone(c.id));
      const btn = h('button', { class: 'small', onclick: () => {
        if (S.chal.active) return;
        modal(h('div', null, h('h2', { text: c.name }), h('p', { text: c.desc }), h('p', { class: 'muted', text: 'Tout repart de zéro : Relents, générateurs, Bugs en prod, Points de cynisme et leurs améliorations. Tu les retrouveras à la fin du plan RH.' })),
          [{ label: 'Annuler' }, { label: 'Commencer', cls: 'can', fn: () => G.startChallenge(c.id) }]);
      } }, 'Commencer');
      liveClass(btn, 'hidden', () => !!S.chal.active || !G.chalUnlocked(c.id));
      const lockTxt = live(() => G.chalUnlocked(c.id) ? '' : 'Verrouillé : ' + G.chalUnlockAt(c.id) + ' Évacuations', 'span', 'muted');
      card.append(h('div', { class: 'row' },
        h('div', { class: 'grow' },
          h('div', { class: 'title' }, c.name, ' ', live(() => G.chalDone(c.id) ? '(survécu)' : (S.chal.active === c.id ? '(en cours)' : ''), 'span', 'muted')),
          h('div', { class: 'sub', text: c.desc }),
          h('div', { class: 'sub', text: 'Récompense : ' + c.reward })),
        btn, lockTxt));
      root.append(card);
    }
  }

  // ------------------------------------------------------------------
  // Vue : Prestiges (toutes les couches, avec un sélecteur)
  // ------------------------------------------------------------------
  function buildPrest(root) {
    const avail = seenLayers();
    if (!avail.includes(layerSel)) layerSel = avail[avail.length - 1] || 1;
    const chips = h('div', { class: 'chips' });
    for (const k of avail) {
      const d = G.layerDef(k);
      const b = h('button', { class: k === layerSel ? 'on' : '', onclick: () => { layerSel = k; viewKey = ''; window.scrollTo(0, 0); } },
        Sprites.el(d.sym, 18, 'inline'), k <= 4 ? d.verb : d.name);
      const dot = h('span', { class: 'chip-dot hidden' });
      liveClass(dot, 'hidden', () => !layerHasNews(k));
      b.append(dot);
      chips.append(b);
    }
    root.append(chips);
    if (layerSel >= 5) root.append(h('p', { class: 'muted intro', text: "Contagion : ton odeur ne connaît plus de frontières. Chaque niveau se nourrit du précédent et le renforce. Il n'y a pas de dernier niveau. Il n'y a pas d'issue de secours." }));
    buildLayer(root, layerSel);
  }

  // ------------------------------------------------------------------
  // Vue : Menu (Stats et Options)
  // ------------------------------------------------------------------
  function buildMenu(root) {
    const seg = h('div', { class: 'seg', style: 'margin-bottom:10px' });
    for (const [id, label] of [['stats', 'Stats'], ['opts', 'Options']]) {
      seg.append(h('button', { class: menuSel === id ? 'on' : '', onclick: () => { menuSel = id; viewKey = ''; } }, label));
    }
    root.append(seg);
    if (menuSel === 'stats') buildStats(root); else buildOpts(root);
  }

  // ------------------------------------------------------------------
  // Vue : Statistiques
  // ------------------------------------------------------------------
  function buildStats(root) {
    const S = G.S;
    const t = h('table', { class: 'stats' });
    const row = (label, fn) => t.append(h('tr', null, h('td', { text: label }), h('td', null, live(fn))));
    row('Temps de jeu', () => duration(S.stats.time));
    row('Record de Relents', () => fmt(S.stats.bestDust));
    row('Relents produits (total)', () => fmt(S.stats.totalDust));
    row('Vitesse du jeu', () => '×' + G.M.speed.toFixed(2));
    row('Mode admin utilisé', () => S.stats.admin ? 'oui' : 'non');
    row('Ressources admin (×1000) utilisées', () => S.stats.adminRes ? 'oui' : 'non');
    row('Exposant de production', () => '^' + G.M.dustExp.toFixed(3));
    row('Bonus par 10 achats', () => '×' + G.M.perTen.toFixed(2));
    root.append(h('div', { class: 'card' }, t));

    // chronologie des premières fois
    const f = S.stats.firsts || {};
    const keys = Object.keys(f).sort((a, b) => (f[a].t ?? -1) - (f[b].t ?? -1));
    if (keys.length) {
      const names = (key) => {
        if (key === 'break') return 'Convention de Genève violée';
        if (key.startsWith('défi ')) { const c = G.CHALLENGES.find((x) => x.id === key.slice(5)); return 'Plan RH « ' + (c ? c.name : key) + ' »'; }
        return G.layerDef(+key.slice(1)).verb + ' (1re fois)';
      };
      const tl = h('table', { class: 'stats' });
      for (const key of keys) {
        const e = f[key];
        const when = e.t == null ? 'avant la chronologie' : (e.approx ? '≈ ' : '') + duration(e.t) + (e.adminRes ? ' (ressources admin)' : e.admin ? ' (accéléré)' : '');
        tl.append(h('tr', null, h('td', { text: names(key) }), h('td', { text: when })));
      }
      root.append(h('h3', { text: 'Chronologie (temps de jeu)' }), h('div', { class: 'card' }, tl));
    }
    const n = G.layerCount();
    for (let k = 1; k <= n; k++) {
      if (!G.resets(k) && !S.seen[k]) continue;
      const d = G.layerDef(k);
      const tt = h('table', { class: 'stats' });
      const r2 = (label, fn) => tt.append(h('tr', null, h('td', { text: label }), h('td', null, live(fn))));
      r2('Nombre de ' + d.verb, () => String(G.resets(k)));
      r2(d.cur + ' (total)', () => fmt(G.lay(k).total));
      r2('Meilleur gain', () => fmt(G.lay(k).best));
      root.append(h('h3', { text: d.name }), h('div', { class: 'card' }, tt));
    }
  }

  // ------------------------------------------------------------------
  // Vue : Options
  // ------------------------------------------------------------------
  function buildOpts(root) {
    const S = G.S;
    const box = h('div', { class: 'card opts' });
    const sel = h('select', null,
      h('option', { value: 'scientifique' }, 'Scientifique (1,23e45)'),
      h('option', { value: 'ingenieur' }, 'Ingénieur (123,45e43)'),
      h('option', { value: 'mixte' }, 'Lettres puis scientifique (1,23 Qa)'));
    sel.value = S.options.notation;
    sel.addEventListener('change', () => { S.options.notation = sel.value; });
    box.append(h('div', { class: 'toggle' }, h('span', { text: 'Notation' }), sel));
    box.append(toggleRow('Progression hors-ligne', () => S.options.offline, (v) => { S.options.offline = v; }));
    box.append(toggleRow('Mode admin (tests)', () => S.options.admin, (v) => {
      S.options.admin = v;
      if (!v) S.options.adminSpeed = 1;
      viewKey = '';
    }));
    root.append(box);
    if (S.options.admin) root.append(adminBox());

    const save = h('div', { class: 'card' });
    save.append(h('div', { class: 'row', style: 'flex-wrap:wrap' },
      h('button', { onclick: () => { saveGame(); toast('Partie sauvegardée'); } }, 'Sauvegarder'),
      h('button', { onclick: exportSave }, 'Exporter'),
      h('button', { onclick: importSave }, 'Importer')));
    save.append(h('div', { class: 'muted', style: 'margin-top:6px' }, 'Sauvegarde automatique toutes les 10 s et quand tu quittes l\'appli.'));
    root.append(save);
    const share = h('div', { class: 'card' }, h('div', { class: 'title', text: 'Partage avec Claude' }),
      live(syncText, 'div', 'sub'),
      h('div', { class: 'sub', text: 'Ta partie (temps de jeu, couches, strates, chronologie) est envoyée toutes les 2 minutes et après chaque prestige, pour que Claude puisse l\'analyser.' }));
    const now = h('button', { class: 'small', style: 'margin-top:6px', onclick: () => { pushParty(true); toast('Partie envoyée'); } }, 'Envoyer maintenant');
    liveClass(now, 'hidden', () => !sync.ref);
    share.append(now);
    root.append(share);

    root.append(h('button', { class: 'primary danger', style: 'margin-top:16px', onclick: hardReset }, 'Tout effacer'));
    root.append(h('p', { class: 'muted', style: 'margin-top:16px' }, 'Astuce : ajoute le jeu à ton écran d\'accueil (menu du navigateur → « Ajouter à l\'écran d\'accueil ») pour y jouer comme une appli, même hors connexion. Garde le doigt appuyé sur un bouton d\'achat pour acheter en continu.'));
  }

  // ------------------------------------------------------------------
  // Mode admin : accélérer le jeu et se donner des ressources pour tester
  // ------------------------------------------------------------------
  const ADMIN_SPEEDS = [1, 2, 5, 10, 100, 1000];
  function adminBox() {
    const S = G.S;
    const box = h('div', { class: 'card admin' }, h('div', { class: 'title', text: 'Mode admin' }),
      h('div', { class: 'sub', text: 'Pour tester. La vitesse et l\'avance rapide gardent le rythme réel du jeu (le temps de jeu compte normalement) ; les boutons ×1000 le faussent. La chronologie des Stats indique ce qui a été utilisé.' }));

    box.append(h('h3', { text: 'Vitesse du jeu' }));
    const seg = h('div', { class: 'seg' });
    for (const v of ADMIN_SPEEDS) {
      const b = h('button', { onclick: () => { S.options.adminSpeed = v; S.stats.admin = true; } }, '×' + v);
      liveClass(b, 'on', () => S.options.adminSpeed === v);
      seg.append(b);
    }
    box.append(seg);

    box.append(h('h3', { text: 'Avancer le temps' }));
    const skip = h('div', { class: 'row wrap' });
    for (const [label, sec] of [['+1 min', 60], ['+1 h', 3600], ['+8 h', 8 * 3600], ['+24 h', 86400]]) {
      skip.append(h('button', { class: 'small', onclick: () => { S.stats.admin = true; const was = S.options.offline; S.options.offline = true; catchUp(sec, sec >= 3600, 'Avance rapide'); S.options.offline = was; if (sec < 3600) toast(label + ' de jeu'); } }, label));
    }
    box.append(skip);
    box.append(h('div', { class: 'sub', text: 'Calculé comme une absence : les automates activés tournent pendant ce temps.' }));

    box.append(h('h3', { text: 'Ressources' }));
    const res = h('div', { class: 'row wrap' });
    res.append(h('button', { class: 'small', onclick: () => { S.stats.admin = true; S.stats.adminRes = true; S.dust = S.dust.max(10).mul(1000); } }, 'Relents ×1000'));
    const n = G.layerCount();
    for (let k = 1; k <= n; k++) {
      if (!G.resets(k) && !S.seen[k]) continue;
      const d = G.layerDef(k);
      res.append(h('button', { class: 'small', onclick: () => { S.stats.admin = true; S.stats.adminRes = true; const l = G.lay(k); const add = l.cur.max(1).mul(999); l.cur = l.cur.add(add); l.total = l.total.add(add); } }, d.cur + ' ×1000'));
    }
    box.append(res);
    return box;
  }

  function exportSave() {
    saveGame();
    const code = btoa(unescape(encodeURIComponent(G.serialize())));
    const ta = h('textarea', { readonly: '' });
    ta.value = code;
    modal(h('div', null, h('h2', { text: 'Exporter' }), h('p', { class: 'muted', text: 'Copie ce code et garde-le en lieu sûr.' }), ta), [
      { label: 'Copier', cls: 'can', fn: () => { (navigator.clipboard ? navigator.clipboard.writeText(code) : Promise.reject()).then(() => toast('Copié !'), () => { ta.select(); document.execCommand('copy'); toast('Copié !'); }); return false; } },
      { label: 'Fermer' },
    ]);
  }

  function importSave() {
    const ta = h('textarea', { placeholder: 'Colle ton code ici' });
    modal(h('div', null, h('h2', { text: 'Importer' }), ta), [
      { label: 'Annuler' },
      { label: 'Importer', cls: 'can', fn: () => {
        try {
          const json = decodeURIComponent(escape(atob(ta.value.trim())));
          const st = G.deserialize(json);
          G.init(st);
          st.lastTick = Date.now();
          saveGame();
          viewKey = ''; navKey = '';
          toast('Partie importée');
        } catch (e) { toast('Code invalide'); return false; }
      } },
    ]);
  }

  function hardReset() {
    modal(h('div', null, h('h2', { text: 'Tout effacer ?' }), h('p', { text: 'Toute ta progression sera perdue définitivement. Comme ta dignité, mais en plus rapide.' })), [
      { label: 'Annuler' },
      { label: 'Effacer', cls: 'danger', fn: () => {
        G.init(G.newState());
        saveGame();
        viewKey = ''; navKey = ''; tab = 'gens';
        toast('Nouvelle partie');
      } },
    ]);
  }

  // ------------------------------------------------------------------
  // Rendu
  // ------------------------------------------------------------------
  let viewKey = '';
  function currentKey() {
    switch (tab) {
      case 'gens': return 'gens|' + gensKey();
      case 'prest': return 'prest|' + seenLayers().join(',') + '|' + layerSel + '|' + layerKey(layerSel);
      case 'chal': return 'chal';
      case 'menu': return 'menu|' + menuSel + '|' + G.S.options.admin + '|' + G.layerCount();
      default: return tab;
    }
  }

  function renderView() {
    const key = currentKey();
    if (key === viewKey) return;
    viewKey = key;
    updaters = [];
    const root = $('view');
    root.innerHTML = '';
    switch (tab) {
      case 'gens': buildGens(root); break;
      case 'prest': buildPrest(root); break;
      case 'chal': buildChal(root); break;
      case 'menu': buildMenu(root); break;
    }
  }

  // niveau olfactif affiché sous la production (selon l'ordre de grandeur des Relents)
  const SMELL = [
    [0, 'Moite (déjà, bravo)'], [3, 'Réunion de 9 h sans fenêtre'], [6, 'Vestiaire après le match'],
    [10, 'Open space en août'], [15, 'Salle serveur, clim crevée'], [25, 'Benne à ordures au soleil'],
    [50, 'Morgue en panne de frigo'], [100, 'Station d\'épuration en grève'], [200, 'Incident diplomatique'],
    [308, 'Arme chimique (Convention de Genève)'], [1000, 'Trou noir olfactif'], [1e4, 'Extinction de masse'],
    [1e5, 'Les dieux se bouchent le nez'], [1e6, 'Au-delà de la biologie, gros dégueulasse'],
  ];
  function smellLevel(l) { let t = SMELL[0][1]; for (const [n, txt] of SMELL) if (l >= n) t = txt; return t; }
  // mouches : une de plus tous les 40 ordres de grandeur, jusqu'à 8
  let flyCount = -1;
  function renderFlies() {
    const l = Math.max(0, G.S.dust.log10());
    const n = Math.min(8, l < 2 ? 0 : 1 + Math.floor(l / 40));
    if (n === flyCount) return;
    flyCount = n;
    const box = $('flies');
    box.innerHTML = '';
    for (let i = 0; i < n; i++) {
      const f = Sprites.el('fly', 20, 'fly');
      const r = (a, b) => (a + Math.random() * (b - a)).toFixed(0) + 'px';
      f.style.cssText = 'left:' + (10 + Math.random() * 75).toFixed(0) + '%;top:' + (6 + Math.random() * 40).toFixed(0) + 'px;--d:' + (4 + Math.random() * 5).toFixed(1) + 's;--delay:-' + (Math.random() * 5).toFixed(1) + 's;--x1:' + r(-60, 60) + ';--y1:' + r(-10, 30) + ';--x2:' + r(-60, 60) + ';--y2:' + r(-10, 30) + ';--x3:' + r(-60, 60) + ';--y3:' + r(-10, 30);
      box.append(f);
    }
  }

  // insultes qui défilent dans l'en-tête (une nouvelle toutes les 25 s)
  const INSULTS = [
    'Même ChatGPT refuse de répondre à tes prompts.',
    'Ta mère a bloqué ton numéro et ton adresse IP.',
    'Ton code compile. Personne ne sait comment. Personne ne veut savoir.',
    'Stack Overflow a marqué ton existence comme doublon.',
    'Tu sens le serveur Windows 2003 qui a pris l\'eau.',
    'Le stagiaire est mort en t\'apportant ton café. On a gardé son badge.',
    'Tes collègues ont un canal Slack sans toi. Il s\'appelle #masque-a-gaz.',
    'Tu pues tellement que ton antivirus t\'a mis en quarantaine.',
    'Ton dernier commit s\'appelle « fix ». Le précédent aussi. Tous, en fait.',
    'Même Linux ne veut pas de toi. Et pourtant il accepte n\'importe quel matériel pourri.',
    'Ton manager te félicite par mail. Depuis l\'autre bâtiment. Avec un masque.',
    'Les mouches ont plus d\'amis que toi sur LinkedIn.',
    'Viré de Discord pour « odeur perceptible à travers le micro ».',
    'Ton hoodie a son propre ticket Jira. Priorité : bloquante.',
    'Le recruteur a raccroché en pleine visio. Ça passait à travers l\'écran.',
    'Ta douche a déposé une main courante pour abandon.',
    'Tu fais du Java. C\'est déjà une odeur en soi.',
    'git blame te désigne pour tout. Surtout pour ce que tu n\'as pas fait.',
    'L\'IA de recrutement t\'a classé « risque biologique ».',
    'T\'es une erreur 500 sur pattes, putain.',
    'Ton clavier a demandé une mutation. Refusée : personne ne veut de lui non plus.',
    'Le médecin du travail a mis « inopérable » sur ton dossier. Il parlait de l\'odeur.',
    'Ce jeu te méprise. Les mouches aussi, mais elles, elles restent.',
    'Tu as fait pleurer le détecteur de fumée.',
    'Kubernetes a refusé de te scheduler : « pod contaminé ».',
    'Ton rubber duck a demandé à être noyé.',
  ];
  let insultAt = 0, insultIdx = Math.floor(Math.random() * INSULTS.length);
  function renderInsult() {
    const now = Date.now();
    if (now - insultAt < 25000) return;
    insultAt = now;
    insultIdx = (insultIdx + 1 + Math.floor(Math.random() * (INSULTS.length - 1))) % INSULTS.length;
    $('insult').textContent = INSULTS[insultIdx];
  }

  function renderHeader() {
    const S = G.S;
    renderInsult();
    const sm = 'Niveau olfactif : ' + smellLevel(S.dust.log10());
    if ($('smell')._v !== sm) { $('smell')._v = sm; $('smell').textContent = sm; }
    renderFlies();
    const d = fmt(S.dust);
    if ($('dust')._v !== d) { $('dust')._v = d; $('dust').textContent = d; }
    let r = G.isBroken() || S.dust.lt(G.INF) ? fmt(G.dustRate().mul(G.M.speed)) + '/s' : 'Seuil de Genève : évacue !';
    if (S.options.admin) r += ' · admin ×' + (S.options.adminSpeed || 1);
    const alert = !(G.isBroken() || S.dust.lt(G.INF));
    if ($('rate')._a !== alert) { $('rate')._a = alert; $('rate').classList.toggle('alert', alert); }
    if ($('rate')._v !== r) { $('rate')._v = r; $('rate').textContent = r; }
    const ban = $('chal-banner');
    const c = S.chal.active && G.CHALLENGES.find((x) => x.id === S.chal.active);
    const bt = c ? 'Plan RH : ' + c.name + ' — ' + c.desc : '';
    if (ban._v !== bt) { ban._v = bt; ban.textContent = bt; ban.classList.toggle('hidden', !c); }
    const goal = G.nextGoal();
    const gl = goal ? goal.label : '';
    if ($('goal-label')._v !== gl) { $('goal-label')._v = gl; $('goal-label').textContent = gl; $('goal').classList.toggle('hidden', !goal); }
    if (goal) {
      const t = pctText(goal.pct) + goalExtra(goal);
      if ($('goal-pct')._v !== t) { $('goal-pct')._v = t; $('goal-pct').textContent = t; $('goal-fill').style.width = (goal.pct * 100).toFixed(2) + '%'; }
    }
  }

  // « ×N restant » et estimation du temps restant au rythme actuel (mesuré sur ~1 min de jeu)
  const goalHist = { key: null, pts: [] };
  function goalExtra(goal) {
    if (!goal.src || !goal.req || goal.src.gte(goal.req)) return '';
    const S = G.S;
    if (goalHist.key !== goal.key) { goalHist.key = goal.key; goalHist.pts = []; }
    const now = S.stats.time;
    const pts = goalHist.pts;
    // on suit le maximum atteint (les achats font baisser la monnaie sans que ce soit un recul) ;
    // une chute de plus de ×100 est un prestige : la mesure repart de zéro
    const top = pts.length ? pts[pts.length - 1].v : null;
    if (top && goal.src.mul(100).lt(top)) { goalHist.pts = []; }
    const p2 = goalHist.pts;
    const v = p2.length ? goal.src.max(p2[p2.length - 1].v) : goal.src;
    if (!p2.length || now - p2[p2.length - 1].t >= 1) p2.push({ t: now, v });
    else p2[p2.length - 1].v = v;
    while (p2.length > 2 && now - p2[1].t > 60) p2.shift();
    const left = goal.req.div(goal.src.max(1));
    let txt = ' · ×' + fmt(left) + ' restant';
    const a = p2[0], b = p2[p2.length - 1];
    if (b.t - a.t >= 10) {
      // croissance mesurée en ordres de grandeur par seconde (fonctionne pour une croissance rapide ou une accumulation lente)
      const la = a.v.max(1).log10(), lb = b.v.max(1).log10();
      const lin = b.v.sub(a.v).div(b.t - a.t); // par seconde de jeu
      let eta = null;
      if (lin.gt(0)) eta = goal.req.sub(b.v).div(lin).toNumber();
      // estimation linéaire (pessimiste si ça accélère) et logarithmique (optimiste) : on prend leur moyenne géométrique
      if (lb > la) { const etaLog = (goal.req.log10() - lb) / ((lb - la) / (b.t - a.t)); eta = eta === null ? etaLog : Math.sqrt(eta * etaLog); }
      const speed = S.options.admin ? S.options.adminSpeed || 1 : 1; // temps réel = temps de jeu ÷ vitesse admin
      if (eta !== null && isFinite(eta) && eta > 0) txt += ' · ≈ ' + (eta / speed > 30 * 86400 ? 'plus de 30 j' : duration(eta / speed));
    }
    return txt;
  }

  // ------------------------------------------------------------------
  // Barre de prestiges fixe (au-dessus des onglets)
  // ------------------------------------------------------------------
  const SHORT = { 1: 'Mise en prod', 2: 'Burn-out', 3: 'Évacuer', 4: 'Licencié' };
  let pbarKey = '';
  function renderPBar() {
    const S = G.S;
    const ks = seenLayers();
    const bar = $('pbar');
    const key = ks.join(',');
    if (key !== pbarKey) {
      pbarKey = key;
      bar.innerHTML = '';
      bar.classList.toggle('hidden', !ks.length);
      document.body.classList.toggle('with-pbar', ks.length > 0);
      for (const k of ks) {
        const d = G.layerDef(k);
        const val = h('span', { class: 'pb-v' });
        const b = h('button', { class: 'pb', onclick: () => confirmReset(k) },
          Sprites.el(d.sym, 20), h('span', { class: 'pb-t', text: SHORT[k] || d.name }), val);
        b._k = k; b._v = val;
        bar.append(b);
      }
    }
    for (const b of bar.children) {
      const k = b._k;
      const d = G.layerDef(k);
      const auto = G.lay(k).auto.on && G.autoUnlocked(k);
      let t;
      if (d.blocked()) t = 'bloqué';
      else if (G.canReset(k)) t = (k === 3 && S.chal.active ? 'valider' : '+' + fmt(G.gain(k)));
      else if (G.reached(k)) t = Math.ceil(G.waitLeft(k)) + ' s';
      else t = pctText(G.progress(k));
      if (auto) t += ' · auto';
      if (b._v._t !== t) { b._v._t = t; b._v.textContent = t; }
      const can = G.canReset(k);
      if (b._can !== can) { b._can = can; b.classList.toggle('can', can); }
    }
  }

  let frame = 0;
  function render() {
    renderNav();
    renderView();
    renderHeader();
    renderPBar();
    for (const u of updaters) u();
    if (frame++ % 5 === 0) updateNavDots();
  }

  // ------------------------------------------------------------------
  // Sauvegarde / boucle
  // ------------------------------------------------------------------
  function saveGame() {
    try {
      G.S.lastTick = Date.now();
      localStorage.setItem(SAVE_KEY, G.serialize());
    } catch (e) { /* stockage plein ou indisponible */ }
  }

  function loadGame() {
    let st = null;
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw) st = G.deserialize(raw);
    } catch (e) { st = null; }
    G.init(st);
  }

  function catchUp(seconds, showSummary, title) {
    const S = G.S;
    if (!S.options.offline) return;
    seconds = Math.min(seconds, OFFLINE_MAX);
    const before = S.dust;
    const beforeRes = {};
    for (let k = 1; k <= G.layerCount(); k++) beforeRes[k] = G.cur(k);
    G.simulate(seconds, 6000);
    if (!showSummary) return;
    const lines = [h('p', { text: (title ? 'Temps avancé : ' : 'Absent pendant ') + duration(seconds) + '.' })];
    lines.push(h('p', { text: 'Relents : ' + fmt(before) + ' → ' + fmt(S.dust) }));
    for (let k = 1; k <= G.layerCount(); k++) {
      const a = beforeRes[k] || Big.ZERO;
      const b = G.cur(k);
      if (!a.eq(b)) lines.push(h('p', { text: G.layerDef(k).cur + ' : ' + fmt(a) + ' → ' + fmt(b) }));
    }
    modal(h('div', null, h('h2', { text: title || 'Te revoilà, putain. On t\'a senti depuis le parking.' }), ...lines));
  }

  let last = Date.now();
  function loop() {
    const now = Date.now();
    const dt = (now - last) / 1000;
    last = now;
    if (dt > 2) catchUp(dt, dt > 60);
    else if (dt > 0) {
      const sp = G.S.options.admin ? (G.S.options.adminSpeed || 1) : 1;
      const total = dt * sp;
      const steps = Math.min(400, Math.max(1, Math.ceil(total / 0.25)));
      for (let i = 0; i < steps; i++) G.tick(total / steps);
    }
    G.S.lastTick = now;
  }

  // ------------------------------------------------------------------
  // Partage de la partie avec Claude (base de données de l'artifact).
  // Uniquement quand le jeu est ouvert sur claude.ai : ailleurs, rien n'est envoyé.
  // ------------------------------------------------------------------
  const sync = { db: null, ref: null, busy: false, last: 0, lastTime: -1, error: null, state: 'off' };
  function partySummary() {
    const S = G.S;
    const n = G.layerCount();
    const couches = [];
    for (let k = 1; k <= n; k++) {
      const d = G.layerDef(k);
      const l = G.lay(k);
      if (!l.resets && !S.seen[k]) continue;
      couches.push({ couche: k, nom: d.name, monnaie: d.cur, actuel: l.cur.toJSON(), total: l.total.toJSON(), prestiges: l.resets, ameliorations: l.upg });
    }
    const chrono = {};
    for (const key in (S.stats.firsts || {})) {
      const e = S.stats.firsts[key];
      chrono[key] = { tempsDeJeuH: e.t == null ? null : +(e.t / 3600).toFixed(3), estime: !!e.approx, accelere: !!e.admin, ressourcesAdmin: !!e.adminRes, date: e.date ? new Date(e.date).toISOString() : null };
    }
    return {
      tempsDeJeuH: +(S.stats.time / 3600).toFixed(3),
      poussiere: S.dust.toJSON(),
      meilleurePoussiere: S.stats.bestDust.toJSON(),
      coucheMax: couches.length ? couches[couches.length - 1].nom : null,
      couches,
      defisTermines: Object.keys(S.chal.done).filter((k) => S.chal.done[k]),
      defiEnCours: S.chal.active,
      infiniBrise: G.lvl(3, 'in_break') > 0,
      chronologie: chrono,
      admin: { utilise: !!S.stats.admin, ressources: !!S.stats.adminRes, vitesse: S.options.admin ? S.options.adminSpeed : 1 },
      automates: S.auto,
      modeAchat: S.options.buy,
      creeLe: S.stats.created ? new Date(S.stats.created).toISOString() : null,
    };
  }
  async function pushParty(force) {
    if (!sync.ref || sync.busy) return;
    const t = G.S.stats.time;
    if (!force && t === sync.lastTime) return; // rien n'a changé
    sync.busy = true;
    try {
      await sync.ref.set({ majLe: new Date().toISOString(), version: 1, resume: partySummary(), sauvegarde: G.serialize() });
      sync.last = Date.now(); sync.lastTime = t; sync.error = null; sync.state = 'ok';
    } catch (e) {
      sync.error = (e && e.code) || 'erreur';
      if (sync.error === 'invalid_argument' || sync.error === 'revoked' || sync.error === 'not_granted') { sync.state = 'refused'; sync.ref = null; }
    } finally { sync.busy = false; }
  }
  async function initSync() {
    if (!window.claude || typeof window.claude.use !== 'function') return;
    try {
      const [db, user] = await Promise.all([window.claude.use('db'), window.claude.use('user')]);
      if (!db || !user) { sync.state = 'unavailable'; return; }
      const id = await user.id();
      if (!id) { sync.state = 'unavailable'; return; }
      sync.db = db;
      sync.ref = db.collection('parties').doc(id);
      sync.state = 'ready';
      pushParty(true);
      setInterval(() => pushParty(false), 120000);
      document.addEventListener('visibilitychange', () => { if (document.hidden) pushParty(false); });
    } catch (e) { sync.state = 'unavailable'; }
  }
  function syncText() {
    switch (sync.state) {
      case 'ok': return 'Partie partagée avec Claude — dernière mise à jour il y a ' + duration((Date.now() - sync.last) / 1000) + '.';
      case 'ready': return 'Partage avec Claude : envoi en cours…';
      case 'refused': return 'Partage avec Claude impossible pour ce compte (accès en lecture seule).';
      case 'unavailable': return 'Partage avec Claude indisponible ici (ouvre le jeu depuis claude.ai, connecté).';
      default: return 'Partage avec Claude : uniquement quand le jeu est ouvert sur claude.ai.';
    }
  }

  const FIRST_TOASTS = {
    1: 'Le canal #incidents ne s\'éteindra plus jamais. Bravo, déchet.',
    2: 'Ton médecin du travail a démissionné. Puis il est mort. Coïncidence ?',
    3: 'Les pompiers ont classé l\'étage en zone rouge. Le stagiaire n\'a pas été retrouvé.',
    4: 'Le vigile t\'a sorti avec une perche de 3 mètres. Il est en arrêt maladie depuis.',
    5: 'Les investisseurs ont signé sans retirer leur masque. Deux sont restés au parking.',
  };
  G.on((type, data) => {
    if (type === 'reset') pushParty(true);
    if (type === 'chal') {
      const c = G.CHALLENGES.find((x) => x.id === data);
      toast('Plan RH survécu : ' + c.name + '. Les RH sont dégoûtés, au sens propre.');
    }
    if (type === 'reset' && G.resets(data) === 1) toast(G.layerDef(data).verb + ' : première fois ! ' + (FIRST_TOASTS[data] || ''));
    if (type === 'reset' && data === 3 && G.resets(3) === G.SN_AUTO_AT) toast('Débloqué : achat automatique des améliorations de Mise en prod (onglet Mise en prod)');
  });

  function start() {
    loadGame();
    const away = (Date.now() - (G.S.lastTick || Date.now())) / 1000;
    if (away > 10) catchUp(away, away > 60);
    last = Date.now();
    setInterval(loop, 50);
    (function raf() { render(); setTimeout(() => requestAnimationFrame(raf), 100); })();
    setInterval(saveGame, 10000);
    document.addEventListener('visibilitychange', () => { if (document.hidden) saveGame(); else { loop(); } });
    window.addEventListener('pagehide', saveGame);
    initSync();
    $('avatar').append(Sprites.el('dev', 48));
    if ('serviceWorker' in navigator && location.protocol !== 'file:') {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    }
  }

  start();
})();
