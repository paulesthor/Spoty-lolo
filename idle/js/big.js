/*
 * Big : nombres géants (mantisse × 10^exposant).
 * L'exposant est un nombre JS, donc on peut monter jusqu'à ~10^(1.8e308).
 * Immuable : chaque opération renvoie un nouveau Big.
 */
(function (root) {
  'use strict';

  class Big {
    constructor(m, e) {
      this.m = m || 0;
      this.e = e || 0;
      this._norm();
    }

    _norm() {
      if (!isFinite(this.m) || !isFinite(this.e)) {
        if (Number.isNaN(this.m) || Number.isNaN(this.e)) { this.m = 0; this.e = 0; return; }
        this.m = this.m < 0 ? -1 : 1; this.e = Number.MAX_VALUE; return;
      }
      if (this.m === 0) { this.e = 0; return; }
      const k = Math.floor(Math.log10(Math.abs(this.m)));
      if (k !== 0) { this.m /= Math.pow(10, k); this.e += k; }
      // corrige les erreurs d'arrondi (9.9999999 -> 10)
      if (Math.abs(this.m) >= 10) { this.m /= 10; this.e += 1; }
      if (Math.abs(this.m) < 1) { this.m *= 10; this.e -= 1; }
      if (Number.isInteger(this.e) === false && Math.abs(this.e) < 1e15) {
        const f = this.e - Math.floor(this.e);
        this.e = Math.floor(this.e);
        this.m *= Math.pow(10, f);
        if (Math.abs(this.m) >= 10) { this.m /= 10; this.e += 1; }
      }
    }

    static from(x) {
      if (x instanceof Big) return x;
      if (typeof x === 'number') return new Big(x, 0);
      if (typeof x === 'string') return Big.parse(x);
      if (x && typeof x === 'object' && 'm' in x) return new Big(x.m, x.e);
      return new Big(0, 0);
    }

    static parse(s) {
      s = String(s).trim();
      const i = s.toLowerCase().indexOf('e');
      if (i < 0) return new Big(parseFloat(s) || 0, 0);
      const ms = s.slice(0, i);
      const m = ms === '' ? 1 : parseFloat(ms);
      return new Big(m, parseFloat(s.slice(i + 1)) || 0);
    }

    static pow10(l) {
      if (l === -Infinity) return new Big(0, 0);
      const e = Math.floor(l);
      return new Big(Math.pow(10, l - e), e);
    }

    toJSON() { return this.m + 'e' + this.e; }

    clone() { return new Big(this.m, this.e); }
    isZero() { return this.m === 0; }
    sign() { return Math.sign(this.m); }
    neg() { return new Big(-this.m, this.e); }
    abs() { return new Big(Math.abs(this.m), this.e); }

    add(b) {
      b = Big.from(b);
      if (this.m === 0) return b;
      if (b.m === 0) return this;
      const d = this.e - b.e;
      if (d > 17) return this;
      if (d < -17) return b;
      if (d >= 0) return new Big(this.m + b.m * Math.pow(10, -d), this.e);
      return new Big(this.m * Math.pow(10, d) + b.m, b.e);
    }
    sub(b) { return this.add(Big.from(b).neg()); }
    mul(b) {
      b = Big.from(b);
      if (this.m === 0 || b.m === 0) return Big.ZERO;
      return new Big(this.m * b.m, this.e + b.e);
    }
    div(b) {
      b = Big.from(b);
      if (b.m === 0) return new Big(1, Number.MAX_VALUE);
      if (this.m === 0) return Big.ZERO;
      return new Big(this.m / b.m, this.e - b.e);
    }
    log10() {
      if (this.m <= 0) return -Infinity;
      return Math.log10(this.m) + this.e;
    }
    pow(n) {
      if (this.m === 0) return n === 0 ? Big.ONE : Big.ZERO;
      if (n === 1) return this;
      return Big.pow10(this.log10() * n);
    }
    sqrt() { return this.pow(0.5); }

    cmp(b) {
      b = Big.from(b);
      if (this.m === 0 && b.m === 0) return 0;
      const sa = Math.sign(this.m), sb = Math.sign(b.m);
      if (sa !== sb) return sa > sb ? 1 : -1;
      if (this.m === 0) return -sb;
      if (b.m === 0) return sa;
      let r;
      if (this.e !== b.e) r = this.e > b.e ? 1 : -1;
      else r = this.m === b.m ? 0 : (this.m > b.m ? 1 : -1);
      return sa > 0 ? r : -r;
    }
    gt(b) { return this.cmp(b) > 0; }
    gte(b) { return this.cmp(b) >= 0; }
    lt(b) { return this.cmp(b) < 0; }
    lte(b) { return this.cmp(b) <= 0; }
    eq(b) { return this.cmp(b) === 0; }
    max(b) { b = Big.from(b); return this.gte(b) ? this : b; }
    min(b) { b = Big.from(b); return this.lte(b) ? this : b; }

    floor() {
      if (this.e >= 16) return this;
      if (this.e < 0) return this.m < 0 ? new Big(-1, 0) : Big.ZERO;
      return new Big(Math.floor(this.toNumber()), 0);
    }
    toNumber() {
      if (this.e > 308) return this.m > 0 ? Infinity : -Infinity;
      if (this.e < -324) return 0;
      return this.m * Math.pow(10, this.e);
    }
  }

  Big.ZERO = new Big(0, 0);
  Big.ONE = new Big(1, 0);
  Big.INF = new Big(1.7976931348623157, 308); // « l'Infini » du jeu

  // ---------- Affichage ----------
  const SUFFIXES = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc'];

  function fmtExp(e, notation) {
    // exposant lui-même énorme
    if (e >= 1e6) return format(new Big(e, 0), notation, 2);
    return Math.round(e).toLocaleString('fr-FR').replace(/ | /g, ' ');
  }

  function format(x, notation, digits) {
    x = Big.from(x);
    digits = digits === undefined ? 2 : digits;
    if (x.m === 0) return '0';
    if (x.m < 0) return '-' + format(x.abs(), notation, digits);
    if (x.e < 3) {
      const n = x.toNumber();
      if (n < 10 && !Number.isInteger(n)) return n.toFixed(Math.min(digits, 2)).replace('.', ',');
      if (n < 100 && !Number.isInteger(n)) return n.toFixed(1).replace('.', ',');
      return String(Math.floor(n));
    }
    if (x.e < 6) return Math.floor(x.toNumber()).toLocaleString('fr-FR').replace(/ | /g, ' ');
    if (x.e >= 1e6) {
      // e1,23e45 : on affiche le logarithme
      return 'e' + format(new Big(x.e, 0), notation, digits);
    }
    if (notation === 'mixte' && x.e < SUFFIXES.length * 3) {
      const g = Math.floor(x.e / 3);
      const v = x.m * Math.pow(10, x.e - g * 3);
      return v.toFixed(digits).replace('.', ',') + ' ' + SUFFIXES[g];
    }
    if (notation === 'ingenieur') {
      const g = Math.floor(x.e / 3) * 3;
      const v = x.m * Math.pow(10, x.e - g);
      return v.toFixed(digits).replace('.', ',') + 'e' + fmtExp(g, notation);
    }
    let m = x.m.toFixed(digits);
    let e = x.e;
    if (parseFloat(m) >= 10) { m = (1).toFixed(digits); e += 1; }
    return m.replace('.', ',') + 'e' + fmtExp(e, notation);
  }

  Big.format = format;
  root.Big = Big;
  if (typeof module !== 'undefined') module.exports = Big;
})(typeof window !== 'undefined' ? window : globalThis);
