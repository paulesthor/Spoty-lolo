// =======================================================
// |        TOURNE-PAGE AUTOMATIQUE (BÊTA) - MICRO         |
// =======================================================
// Module autonome : n'utilise ni ne modifie rien dans app.js.
// Principe : le micro produit en continu une "empreinte harmonique"
// (chromagramme : énergie de chacune des 12 notes, toutes octaves
// confondues). En mode apprentissage, on enregistre l'empreinte du
// passage de fin de page. En concert, on compare le flux du micro à
// cette empreinte (DTW, tolérant aux écarts de tempo) et on tourne la
// page quand elle est reconnue.

(() => {

    // =======================================================
    // |                 MOTEUR AUDIO / MATCHING              |
    // =======================================================

    // Même projet Supabase qu'app.js (clé publique "anon")
    const SUPABASE_URL = 'https://ikkhvkgcxvlpqejvvuot.supabase.co';
    const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlra2h2a2djeHZscHFlanZ2dW90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MDI1NDMsImV4cCI6MjA4MDM3ODU0M30.I606WGNVllQ5VI_mB1TmheediORTyNvXqpdkKSFa73o';

    // Fins de page lues automatiquement sur les PDF (workflow GitHub
    // "Lecture des fins de page", publiées sur la branche omr-data)
    const OMR_DATA_URL = 'https://raw.githubusercontent.com/paulesthor/Spoty-lolo/omr-data/omr/';

    const HOP_MS = 100;          // une empreinte toutes les 100 ms
    const FFT_SIZE = 8192;       // ~5.9 Hz de résolution à 48 kHz
    const MIN_FREQ = 60;         // ~Si0 : basses du piano / accordéon
    const MAX_FREQ = 4000;       // fondamentales + premières harmoniques
    const MAX_RECORD_FRAMES = 300; // 30 s max d'enregistrement
    const MIN_RECORD_FRAMES = 15;  // 1,5 s de son minimum
    const NOTE_NAMES = ['Do', 'Do#', 'Ré', 'Ré#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'];

    // Associe chaque case de la FFT à une classe de hauteur (0 = Do).
    // Les cases tombant entre deux demi-tons ont un poids faible.
    const buildBinMap = (sampleRate, fftSize) => {
        const bins = [];
        const kMin = Math.max(1, Math.floor(MIN_FREQ * fftSize / sampleRate));
        const kMax = Math.min(fftSize / 2 - 1, Math.ceil(MAX_FREQ * fftSize / sampleRate));
        for (let k = kMin; k <= kMax; k++) {
            const f = k * sampleRate / fftSize;
            const midi = 69 + 12 * Math.log2(f / 440);
            const nearest = Math.round(midi);
            const weight = Math.max(0, 1 - 2 * Math.abs(midi - nearest));
            if (weight > 0) bins.push({ k, pc: ((nearest % 12) + 12) % 12, weight });
        }
        return bins;
    };

    // Spectre (dB) -> vecteur de 12 valeurs centré et normalisé.
    // Centrer avant de normaliser donne un meilleur contraste entre
    // accords différents qu'une simple similarité cosinus positive.
    const chromaFromSpectrum = (freqDb, binMap) => {
        const chroma = new Float32Array(12);
        for (const { k, pc, weight } of binMap) {
            const mag = Math.pow(10, freqDb[k] / 20);
            chroma[pc] += weight * Math.log1p(1e4 * mag);
        }
        return normalizeChroma(chroma);
    };

    const normalizeChroma = (chroma) => {
        let mean = 0;
        for (let i = 0; i < 12; i++) mean += chroma[i];
        mean /= 12;
        let norm = 0;
        const out = new Float32Array(12);
        for (let i = 0; i < 12; i++) { out[i] = chroma[i] - mean; norm += out[i] * out[i]; }
        norm = Math.sqrt(norm) || 1;
        for (let i = 0; i < 12; i++) out[i] /= norm;
        return out;
    };

    const dot = (a, b) => {
        let s = 0;
        for (let i = 0; i < 12; i++) s += a[i] * b[i];
        return s;
    };

    // DTW "sous-séquence" : trouve la meilleure correspondance de la
    // référence entière avec un segment du flux live se terminant
    // maintenant. Renvoie la similarité moyenne le long du chemin
    // (1 = identique, 0 = sans rapport, < 0 = opposé).
    // Pas autorisés (1,1), (1,2), (2,1) : le tempo live peut aller de la
    // moitié au double de celui de l'enregistrement, mais le chemin ne
    // peut pas "écraser" toute la référence sur quelques trames.
    const matchEnd = (ref, live) => {
        const m = ref.length, n = live.length;
        if (m < 2 || n < Math.ceil(m / 2)) return null;
        const cost = (i, j) => (1 - dot(ref[i], live[j])) / 2; // dans [0, 1]
        // Chaque pas pèse (di + dj), d'où la normalisation finale par
        // (m + longueur du segment live).
        let D2 = new Float64Array(n).fill(Infinity), S2 = new Int32Array(n);
        let D1 = new Float64Array(n), S1 = new Int32Array(n);
        let D0 = new Float64Array(n), S0 = new Int32Array(n);
        for (let j = 0; j < n; j++) { D1[j] = 2 * cost(0, j); S1[j] = j; } // départ libre
        for (let i = 1; i < m; i++) {
            D0.fill(Infinity);
            for (let j = 1; j < n; j++) {
                const c = cost(i, j);
                let best = D1[j - 1] + 2 * c, start = S1[j - 1];
                if (j > 1 && D1[j - 2] < Infinity) {
                    const v = D1[j - 2] + 2 * cost(i, j - 1) + c;
                    if (v < best) { best = v; start = S1[j - 2]; }
                }
                if (D2[j - 1] < Infinity) {
                    const v = D2[j - 1] + 2 * cost(i - 1, j) + c;
                    if (v < best) { best = v; start = S2[j - 1]; }
                }
                D0[j] = best; S0[j] = start;
            }
            [D2, D1, D0] = [D1, D0, D2];
            [S2, S1, S0] = [S1, S0, S2];
        }
        if (!(D1[n - 1] < Infinity)) return null;
        const start = S1[n - 1];
        const liveLen = n - start;
        const avgCost = D1[n - 1] / (m + liveLen);
        return { similarity: 1 - 2 * avgCost, start };
    };

    // Empreinte théorique d'un accord : chaque note ajoute ses premières
    // harmoniques (comme un vrai instrument), puis même normalisation que
    // pour le micro.
    const notesChroma = (midis) => {
        const c = new Float32Array(12);
        for (const m of midis) {
            for (let h = 1; h <= 6; h++) c[Math.round(m + 12 * Math.log2(h)) % 12] += 1 / h;
        }
        return normalizeChroma(c);
    };

    // Construit la référence d'une fin de page à partir des mesures lues
    // par l'OMR (voir .github/scripts/omr_fins_de_page.py).
    // anticipation = nombre de mesures avant la fin où la page doit tourner.
    const templateFromMeasures = (mesures, { bpm, anticipation }) => {
        const end = mesures.length - anticipation; // exclu
        if (end < 1) return null;
        let start = end - 1;
        let beats = mesures[start].duree;
        // Au moins 2 mesures et 6 temps, au plus 4 mesures
        while (start > 0 && end - start < 4 && (end - start < 2 || beats < 6)) {
            start--;
            beats += mesures[start].duree;
        }
        const frames = framesFromMeasures(mesures.slice(start, end), bpm);
        return frames.length >= 8 ? { frames, start, end } : null;
    };

    // Empreintes attendues pour une suite de mesures jouée à `bpm` (noire)
    const framesFromMeasures = (mesures, bpm) => {
        const notes = [];
        let offset = 0;
        for (const m of mesures) {
            for (const [onset, dur, midi] of m.notes) notes.push([offset + onset, dur, midi]);
            offset += m.duree;
        }
        const step = bpm / 60 * HOP_MS / 1000; // noires par trame
        const frames = [];
        for (let t = 0; t < offset; t += step) {
            const sounding = notes.filter(([onset, dur]) => onset <= t + 1e-6 && t < onset + dur);
            if (sounding.length) frames.push(notesChroma(sounding.map(n => n[2])));
        }
        return frames;
    };

    // Suivi de partition : on reconnaît des passages de 2 mesures n'importe
    // où sur la page (des "repères"), on en déduit la position et le tempo,
    // puis on avance une horloge musicale jusqu'au moment de tourner.
    class ScoreFollower {
        constructor(mesures, { bpm, anticipation, threshold }) {
            this.threshold = threshold;
            this.nominalTempo = bpm / 60; // noires par seconde
            this.starts = [];
            let beat = 0;
            for (const m of mesures) { this.starts.push(beat); beat += m.duree; }
            this.totalBeats = beat;
            this.measureBeats = beat / Math.max(1, mesures.length);
            this.turnBeat = beat - mesures.slice(mesures.length - anticipation).reduce((a, m) => a + m.duree, 0);
            this.anchors = [];
            for (let i = 0; i + 1 < mesures.length; i++) {
                const frames = framesFromMeasures(mesures.slice(i, i + 2), bpm);
                if (frames.length >= 8) {
                    this.anchors.push({ frames, measure: i, beats: mesures[i].duree + mesures[i + 1].duree,
                                        endBeat: this.starts[i + 1] + mesures[i + 1].duree });
                }
            }
            this.maxLive = Math.ceil(Math.max(0, ...this.anchors.map(a => a.frames.length)) * 2.2) + 5;
            this.live = [];
            this.time = 0;          // secondes écoulées sur la page
            this.silence = 0;
            this.frame = 0;
            this.pos = null;        // position en noires depuis le haut de la page
            this.tempo = this.nominalTempo;
            this.last = null;       // dernière détection { beat, time }
            this.history = [];      // détections récentes { beat, time } pour lisser
            this.fitError = Infinity; // écart (en noires) des détections à une progression régulière
            this.detections = 0;
            this.lastSimilarity = null;
        }

        measureAt(beat) {
            let i = 0;
            while (i + 1 < this.starts.length && this.starts[i + 1] <= beat) i++;
            return i + 1;
        }

        push(chroma, sounding) {
            const dt = HOP_MS / 1000;
            this.time += dt;
            this.frame++;
            if (!sounding) {
                // Courte respiration : la musique continue ; longue pause : on fige l'horloge
                this.silence += dt;
                if (this.pos !== null && this.silence < 1.5) this.pos += this.tempo * dt;
                return this.status();
            }
            this.silence = 0;
            if (this.pos !== null) this.pos += this.tempo * dt;
            this.live.push(chroma);
            if (this.live.length > this.maxLive) this.live.splice(0, this.live.length - this.maxLive);
            if (this.frame % 3 === 0) this.detect();
            return this.status();
        }

        tracking() {
            // Suivi établi : au moins 3 reconnaissances récentes, bien alignées
            const recent = this.history.filter(h => this.time - h.time <= 12).length;
            return recent >= 3 && this.fitError <= 1.5 * this.measureBeats;
        }

        detect() {
            const tracking = this.tracking();
            // Toujours après la dernière reconnaissance ; en suivi, pas plus de
            // 2 mesures au-delà de la position attendue.
            const minBeat = this.last ? this.last.beat : -Infinity;
            const maxBeat = this.pos === null ? Infinity
                : this.pos + (tracking ? 2 * this.measureBeats : 16);
            let best = null, bestSim = -1;
            for (const a of this.anchors) {
                if (a.endBeat <= minBeat || a.endBeat > maxBeat) continue;
                const live = this.live.slice(-Math.ceil(a.frames.length * 2.2) - 5);
                const res = matchEnd(a.frames, live);
                if (!res || res.similarity < this.threshold) continue;
                bestSim = Math.max(bestSim, res.similarity);
                // Passage répété : en suivi, le plus proche de la position attendue ;
                // sinon le premier en avant (on avance dans la musique)
                const better = !best || (tracking
                    ? Math.abs(a.endBeat - this.pos) < Math.abs(best.a.endBeat - this.pos)
                    : a.endBeat < best.a.endBeat);
                if (better) best = { a, liveLen: live.length - res.start };
            }
            this.lastSimilarity = bestSim > -1 ? bestSim : null;
            if (!best) return;
            const { a, liveLen } = best;
            const clamp = (v) => Math.min(this.nominalTempo * 2.5, Math.max(this.nominalTempo * 0.4, v));
            this.last = { beat: a.endBeat, time: this.time };
            this.history.push(this.last);
            // Les reconnaissances trop anciennes ne décrivent plus le jeu actuel
            this.history = this.history.filter(h => this.time - h.time <= 20).slice(-8);
            this.detections++;
            if (this.history.length >= 3) {
                // Droite position = f(temps) sur les dernières détections :
                // lisse les petites erreurs de chaque reconnaissance
                const n = this.history.length;
                const mt = this.history.reduce((s, h) => s + h.time, 0) / n;
                const mb = this.history.reduce((s, h) => s + h.beat, 0) / n;
                let num = 0, den = 0;
                for (const h of this.history) { num += (h.time - mt) * (h.beat - mb); den += (h.time - mt) ** 2; }
                if (den > 0 && num > 0) {
                    const slope = num / den;
                    // Des reconnaissances au hasard sautent d'un endroit à l'autre :
                    // seules des positions alignées sur une droite (tempo régulier)
                    // sont crédibles
                    this.fitError = Math.sqrt(this.history.reduce((s, h) =>
                        s + (h.beat - (mb + slope * (h.time - mt))) ** 2, 0) / n);
                    this.tempo = clamp(slope);
                    this.pos = mb + this.tempo * (this.time - mt);
                    return;
                }
            }
            // Peu de détections : tempo d'après la durée de jeu du passage reconnu
            this.fitError = Infinity;
            this.tempo = clamp(a.beats / (Math.max(1, liveLen) * HOP_MS / 1000));
            this.pos = a.endBeat;
        }

        status() {
            const confident = this.tracking();
            // Une reconnaissance arrive un peu après la fin du passage : on
            // compense par une demi-seconde d'avance
            const margin = this.tempo * 0.5;
            const turn = this.pos !== null && confident && this.pos + margin >= this.turnBeat;
            return {
                turn,
                pos: this.pos,
                measure: this.pos === null ? null : this.measureAt(this.pos),
                measures: this.starts.length,
                bpm: Math.round(this.tempo * 60),
                secondsLeft: this.pos === null ? null : Math.max(0, (this.turnBeat - this.pos - margin) / this.tempo),
                detections: this.detections
            };
        }
    }

    class ChromaListener {
        constructor(onFrame) { this.onFrame = onFrame; this.running = false; }

        async start() {
            this.stream = await navigator.mediaDevices.getUserMedia({
                audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false }
            });
            const Ctx = window.AudioContext || window.webkitAudioContext;
            this.ctx = new Ctx();
            if (this.ctx.state === 'suspended') await this.ctx.resume();
            const src = this.ctx.createMediaStreamSource(this.stream);
            this.analyser = this.ctx.createAnalyser();
            this.analyser.fftSize = FFT_SIZE;
            this.analyser.smoothingTimeConstant = 0;
            src.connect(this.analyser);
            this.binMap = buildBinMap(this.ctx.sampleRate, FFT_SIZE);
            this.freq = new Float32Array(this.analyser.frequencyBinCount);
            this.time = new Float32Array(2048);
            this.prev = null;
            this.running = true;
            this.timer = setInterval(() => this.tick(), HOP_MS);
        }

        tick() {
            this.analyser.getFloatFrequencyData(this.freq);
            this.analyser.getFloatTimeDomainData(this.time);
            let sum = 0;
            for (let i = 0; i < this.time.length; i++) sum += this.time[i] * this.time[i];
            const rms = Math.sqrt(sum / this.time.length);
            let chroma = chromaFromSpectrum(this.freq, this.binMap);
            // Léger lissage temporel pour stabiliser l'empreinte
            if (this.prev) {
                const mixed = new Float32Array(12);
                for (let i = 0; i < 12; i++) mixed[i] = 0.5 * chroma[i] + 0.5 * this.prev[i];
                chroma = normalizeChroma(mixed);
            }
            this.prev = chroma;
            this.onFrame({ chroma, rms });
        }

        stop() {
            this.running = false;
            clearInterval(this.timer);
            if (this.stream) this.stream.getTracks().forEach(t => t.stop());
            if (this.ctx) this.ctx.close();
            this.stream = this.ctx = this.analyser = null;
        }
    }

    // Exposé pour les tests et le débogage depuis la console
    window.TournePageEngine = { buildBinMap, chromaFromSpectrum, normalizeChroma, matchEnd, notesChroma, templateFromMeasures, framesFromMeasures, ScoreFollower, ChromaListener, NOTE_NAMES };

    // =======================================================
    // |                     STOCKAGE LOCAL                   |
    // =======================================================

    const storage = {
        get(key, fallback) {
            try { const v = localStorage.getItem(key); return v ? JSON.parse(v) : fallback; }
            catch (e) { return fallback; }
        },
        set(key, value) {
            try { localStorage.setItem(key, JSON.stringify(value)); return true; }
            catch (e) { return false; }
        }
    };

    const refsKey = (docKey) => 'tp-refs:' + docKey;
    const loadRefs = (docKey) => {
        const raw = storage.get(refsKey(docKey), {});
        const refs = {};
        for (const [page, entry] of Object.entries(raw)) {
            refs[page] = { ...entry, frames: entry.frames.map(f => Float32Array.from(f)) };
        }
        return refs;
    };
    const saveRefs = (docKey, refs) => {
        const raw = {};
        for (const [page, entry] of Object.entries(refs)) {
            raw[page] = { ...entry, frames: entry.frames.map(f => Array.from(f, v => Math.round(v * 1000) / 1000)) };
        }
        return storage.set(refsKey(docKey), raw);
    };

    // =======================================================
    // |                      INTERFACE                       |
    // =======================================================

    document.addEventListener('DOMContentLoaded', () => {
        const view = document.getElementById('tournepage-view');
        if (!view) return;

        const $ = (id) => document.getElementById(id);
        const selectEl = $('tp-partition-select');
        const localFileInput = $('tp-local-file');
        const micBtn = $('tp-mic-btn');
        const autoToggle = $('tp-auto-toggle');
        const recordBtn = $('tp-record-btn');
        const deleteRefBtn = $('tp-delete-ref-btn');
        const refBadge = $('tp-ref-badge');
        const prevBtn = $('tp-prev-btn');
        const nextBtn = $('tp-next-btn');
        const pageNumEl = $('tp-page-num');
        const stage = $('tp-stage');
        const canvas = $('tp-canvas');
        const placeholder = $('tp-placeholder');
        const fullscreenBtn = $('tp-fullscreen-btn');
        const levelBar = $('tp-level-bar');
        const gateMarker = $('tp-gate-marker');
        const simBar = $('tp-sim-bar');
        const simValue = $('tp-sim-value');
        const thrMarker = $('tp-thr-marker');
        const chromaBars = $('tp-chroma-bars');
        const statusEl = $('tp-status');
        const thrInput = $('tp-threshold');
        const thrLabel = $('tp-threshold-label');
        const delayInput = $('tp-min-delay');
        const delayLabel = $('tp-min-delay-label');
        const gateInput = $('tp-gate');
        const gateLabel = $('tp-gate-label');
        const thrOmrInput = $('tp-threshold-omr');
        const thrOmrLabel = $('tp-threshold-omr-label');
        const bpmInput = $('tp-bpm');
        const bpmLabel = $('tp-bpm-label');
        const anticipInput = $('tp-anticipation');
        const anticipLabel = $('tp-anticipation-label');
        const flash = $('tp-flash');
        const followEl = $('tp-follow');

        const settings = Object.assign(
            { threshold: 0.85, thresholdOmr: 0.75, bpm: 100, anticipation: 1, minDelay: 8, gate: 0.01, auto: true },
            storage.get('tp-settings', {})
        );
        const saveSettings = () => storage.set('tp-settings', settings);

        const state = {
            supabase: null,
            partitions: [],
            docKey: null,
            pdf: null,
            page: 1,
            refs: {},            // fins enregistrées au micro (prioritaires)
            omr: null,           // fins lues sur la partition
            omrStatus: 'none',   // 'loading' | 'ok' | 'absent' | 'none'
            templates: {},       // cache des références construites depuis l'OMR
            follower: null,      // suivi de partition de la page courante
            listener: null,
            recording: null,     // tableau d'empreintes pendant l'apprentissage
            live: [],            // flux live (empreintes non silencieuses)
            pageStart: Date.now(),
            hits: 0,
            renderTask: null,
            wakeLock: null
        };

        // ---------- Barres chroma ----------
        NOTE_NAMES.forEach(name => {
            const col = document.createElement('div');
            col.className = 'tp-chroma-col';
            col.innerHTML = `<div class="tp-chroma-track"><div class="tp-chroma-fill"></div></div><span>${name}</span>`;
            chromaBars.appendChild(col);
        });
        const chromaFills = chromaBars.querySelectorAll('.tp-chroma-fill');

        const setStatus = (text) => { statusEl.textContent = text; };

        // ---------- Réglages ----------
        // Le seuil de silence est sur une échelle log : 0.001 (très sensible) à 0.1
        const gateFromSlider = (v) => Math.pow(10, -3 + 2 * v / 100);
        const sliderFromGate = (g) => Math.round((Math.log10(g) + 3) * 50);
        const rmsToPercent = (rms) => Math.max(0, Math.min(100, (Math.log10(Math.max(rms, 1e-4)) + 4) / 4 * 100));

        const refreshSettingsUI = () => {
            thrInput.value = Math.round(settings.threshold * 100);
            thrLabel.textContent = Math.round(settings.threshold * 100) + ' %';
            thrOmrInput.value = Math.round(settings.thresholdOmr * 100);
            thrOmrLabel.textContent = Math.round(settings.thresholdOmr * 100) + ' %';
            bpmInput.value = settings.bpm;
            bpmLabel.textContent = settings.bpm + ' à la noire';
            anticipInput.value = settings.anticipation;
            anticipLabel.textContent = settings.anticipation === 0 ? 'à la toute fin' : `${settings.anticipation} mesure${settings.anticipation > 1 ? 's' : ''} avant la fin`;
            delayInput.value = settings.minDelay;
            delayLabel.textContent = settings.minDelay + ' s';
            gateInput.value = sliderFromGate(settings.gate);
            gateLabel.textContent = (20 * Math.log10(settings.gate)).toFixed(0) + ' dB';
            gateMarker.style.left = rmsToPercent(settings.gate) + '%';
            autoToggle.checked = settings.auto;
        };
        thrInput.addEventListener('input', () => { settings.threshold = thrInput.value / 100; saveSettings(); refreshSettingsUI(); refreshRefUI(); });
        thrOmrInput.addEventListener('input', () => { settings.thresholdOmr = thrOmrInput.value / 100; saveSettings(); refreshSettingsUI(); refreshRefUI(); });
        const onTemplateSetting = () => { state.templates = {}; saveSettings(); refreshSettingsUI(); resetLive(); refreshRefUI(); };
        bpmInput.addEventListener('input', () => { settings.bpm = Number(bpmInput.value); onTemplateSetting(); });
        anticipInput.addEventListener('input', () => { settings.anticipation = Number(anticipInput.value); onTemplateSetting(); });
        delayInput.addEventListener('input', () => { settings.minDelay = Number(delayInput.value); saveSettings(); refreshSettingsUI(); });
        gateInput.addEventListener('input', () => { settings.gate = gateFromSlider(Number(gateInput.value)); saveSettings(); refreshSettingsUI(); });
        autoToggle.addEventListener('change', () => { settings.auto = autoToggle.checked; saveSettings(); resetLive(); });
        refreshSettingsUI();

        // ---------- Supabase (lecture seule de la liste des partitions) ----------
        // Client séparé qui réutilise la session déjà ouverte par app.js
        // sans rafraîchir le jeton lui-même (c'est app.js qui s'en charge).
        const getSupabase = () => {
            if (!state.supabase && window.supabase) {
                state.supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
                    auth: { autoRefreshToken: false, persistSession: true, detectSessionInUrl: false }
                });
            }
            return state.supabase;
        };

        const loadPartitions = async () => {
            const client = getSupabase();
            if (!client) return;
            const { data: { session } } = await client.auth.getSession();
            if (!session) return;
            const { data, error } = await client.from('partitions')
                .select('id, titre, nom_artiste, url_pdf')
                .eq('user_id', session.user.id)
                .order('titre', { ascending: true });
            if (error) { setStatus('Erreur de chargement : ' + error.message); return; }
            state.partitions = (data || []).filter(p => p.url_pdf);
            const current = selectEl.value;
            selectEl.innerHTML = '<option value="">— Choisir une partition —</option>' +
                state.partitions.map(p => `<option value="${p.id}">${escapeHtml(p.titre)}${p.nom_artiste ? ' — ' + escapeHtml(p.nom_artiste) : ''}</option>`).join('');
            if (current) selectEl.value = current;
        };

        const escapeHtml = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

        // ---------- PDF ----------
        const openDocument = async (source, docKey) => {
            try {
                setStatus('Chargement du PDF...');
                const pdf = await pdfjsLib.getDocument(source).promise;
                state.pdf = pdf;
                state.docKey = docKey;
                state.refs = loadRefs(docKey);
                state.templates = {};
                loadOmr(docKey);
                placeholder.style.display = 'none';
                canvas.style.display = 'block';
                await goToPage(1);
                setStatus(state.listener ? 'Écoute en cours' : 'Prêt. Activez le micro pour commencer.');
            } catch (e) {
                console.error(e);
                setStatus('Impossible d\'ouvrir le PDF : ' + e.message);
            }
        };

        const loadOmr = async (docKey) => {
            state.omr = null;
            if (!docKey.startsWith('id:')) { state.omrStatus = 'none'; refreshRefUI(); return; }
            state.omrStatus = 'loading';
            refreshRefUI();
            try {
                const res = await fetch(OMR_DATA_URL + docKey.slice(3) + '.json', { cache: 'no-cache' });
                const data = res.ok ? await res.json() : null;
                if (state.docKey !== docKey) return; // une autre partition a été ouverte entre-temps
                state.omr = data;
                state.omrStatus = data ? 'ok' : 'absent';
            } catch (e) {
                if (state.docKey !== docKey) return;
                state.omrStatus = 'absent';
            }
            state.templates = {};
            resetLive();
            refreshRefUI();
        };

        // Référence de la page courante : fin enregistrée au micro si elle
        // existe, sinon fin lue sur la partition.
        const omrPage = () => {
            const fin = state.omr && state.omr.fins && state.omr.fins[state.page];
            // Page où Audiveris a sauté des lignes : positions fausses, on ne s'y fie pas
            return fin && fin.fiable !== false ? fin : null;
        };

        // Suivi de partition (analyse v2 : toutes les mesures de la page)
        const currentFollower = () => {
            if (!state.pdf || state.refs[state.page] || state.page >= state.pdf.numPages) return null;
            const fin = omrPage();
            if (!fin || !(state.omr.version >= 2)) return null;
            if (!state.follower) {
                state.follower = new ScoreFollower(fin.mesures, {
                    bpm: settings.bpm, anticipation: settings.anticipation, threshold: settings.thresholdOmr
                });
            }
            return state.follower;
        };

        const currentReference = () => {
            if (!state.pdf) return null;
            const rec = state.refs[state.page];
            if (rec) return { kind: 'rec', frames: rec.frames, threshold: settings.threshold };
            const fin = omrPage();
            if (!fin) return null;
            if (!(state.page in state.templates)) {
                state.templates[state.page] = templateFromMeasures(fin.mesures, settings);
            }
            const tpl = state.templates[state.page];
            if (!tpl) return null;
            const first = fin.nbMesuresPage - fin.mesures.length + 1; // n° de la 1re mesure conservée
            return { kind: 'omr', frames: tpl.frames, threshold: settings.thresholdOmr,
                     from: first + tpl.start, to: first + tpl.end - 1, total: fin.nbMesuresPage };
        };

        selectEl.addEventListener('change', () => {
            const p = state.partitions.find(x => String(x.id) === selectEl.value);
            if (p) openDocument(p.url_pdf, 'id:' + p.id);
        });

        localFileInput.addEventListener('change', async () => {
            const file = localFileInput.files[0];
            if (!file) return;
            selectEl.value = '';
            const data = new Uint8Array(await file.arrayBuffer());
            openDocument({ data }, 'local:' + file.name);
        });

        const renderPage = async () => {
            if (!state.pdf) return;
            const page = await state.pdf.getPage(state.page);
            const base = page.getViewport({ scale: 1 });
            const availW = stage.clientWidth - 16;
            const availH = stage.clientHeight - 16;
            const scale = Math.max(0.1, Math.min(availW / base.width, availH / base.height));
            const dpr = window.devicePixelRatio || 1;
            const viewport = page.getViewport({ scale: scale * dpr });
            if (state.renderTask) { try { state.renderTask.cancel(); } catch (e) { /* déjà fini */ } }
            canvas.width = viewport.width;
            canvas.height = viewport.height;
            canvas.style.width = (viewport.width / dpr) + 'px';
            canvas.style.height = (viewport.height / dpr) + 'px';
            state.renderTask = page.render({ canvasContext: canvas.getContext('2d'), viewport });
            try { await state.renderTask.promise; } catch (e) { /* rendu annulé */ }
        };

        const goToPage = async (n) => {
            if (!state.pdf) return;
            state.page = Math.max(1, Math.min(state.pdf.numPages, n));
            pageNumEl.textContent = `${state.page} / ${state.pdf.numPages}`;
            resetLive();
            refreshRefUI();
            await renderPage();
        };

        const resetLive = () => {
            state.live = [];
            state.hits = 0;
            state.pageStart = Date.now();
            state.follower = null;
            simBar.style.width = '0%';
            simValue.textContent = '—';
            followEl.textContent = '';
        };

        prevBtn.addEventListener('click', () => goToPage(state.page - 1));
        nextBtn.addEventListener('click', () => goToPage(state.page + 1));

        let resizeTimer;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => { if (view.style.display === 'block') renderPage(); }, 200);
        });

        // Pédales Bluetooth / clavier, uniquement quand l'onglet est affiché
        document.addEventListener('keydown', (e) => {
            if (view.style.display !== 'block' || !state.pdf) return;
            if (['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) return;
            if (['ArrowRight', 'PageDown'].includes(e.key)) { e.preventDefault(); goToPage(state.page + 1); }
            else if (['ArrowLeft', 'PageUp'].includes(e.key)) { e.preventDefault(); goToPage(state.page - 1); }
        });

        fullscreenBtn.addEventListener('click', () => {
            const el = $('tp-player');
            if (document.fullscreenElement) document.exitFullscreen();
            else if (el.requestFullscreen) el.requestFullscreen().catch(() => {});
        });
        document.addEventListener('fullscreenchange', () => setTimeout(renderPage, 100));

        // ---------- Empreintes de fin de page ----------
        const refreshRefUI = () => {
            const hasPdf = !!state.pdf;
            const rec = state.refs[state.page];
            const ref = currentReference();
            const isLast = hasPdf && state.page === state.pdf.numPages;
            recordBtn.disabled = !hasPdf || isLast;
            deleteRefBtn.style.display = rec && !state.recording ? 'inline-flex' : 'none';
            if (!hasPdf) refBadge.textContent = '';
            else if (isLast) refBadge.textContent = 'Dernière page';
            else if (rec) refBadge.innerHTML = `<i class="fas fa-check-circle"></i> Fin jouée au micro (${(rec.frames.length * HOP_MS / 1000).toFixed(1)} s)`;
            else if (ref && state.omr.version >= 2) refBadge.innerHTML = `<i class="fas fa-check-circle"></i> Suivi de la partition (${ref.total} mesures lues)`;
            else if (ref) refBadge.innerHTML = `<i class="fas fa-check-circle"></i> Fin lue sur la partition (mesures ${ref.from}–${ref.to} sur ${ref.total})`;
            else if (state.omr && state.omr.fins && state.omr.fins[state.page] && state.omr.fins[state.page].fiable === false)
                refBadge.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Lecture douteuse (lignes sautées) : la page ne tournera pas seule. Jouez la fin une fois pour corriger';
            else if (state.omrStatus === 'loading') refBadge.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Recherche de la lecture automatique...';
            else if (state.omrStatus === 'ok') refBadge.innerHTML = '<i class="fas fa-exclamation-circle"></i> Fin de page non lue sur la partition : jouez-la une fois pour corriger';
            else if (state.omrStatus === 'absent') refBadge.innerHTML = '<i class="fas fa-hourglass-half"></i> Partition pas encore analysée (analyse automatique chaque nuit)';
            else refBadge.innerHTML = '<i class="fas fa-exclamation-circle"></i> PDF local : jouez la fin de page une fois pour l\'enregistrer';
            refBadge.classList.toggle('tp-ok', !!ref);
            // Le repère de seuil suit la référence utilisée sur cette page
            thrMarker.style.left = Math.max(0, (ref ? ref.threshold : settings.thresholdOmr) * 100) + '%';
        };

        recordBtn.addEventListener('click', async () => {
            if (state.recording) { stopRecording(true); return; }
            if (!state.listener) await startMic();
            if (!state.listener) return;
            state.recording = [];
            recordBtn.classList.add('tp-recording');
            recordBtn.innerHTML = '<i class="fas fa-stop"></i> Terminer l\'enregistrement';
            setStatus('Enregistrement : jouez le passage qui doit déclencher la tourne (ex. les 2 dernières mesures), puis appuyez sur Terminer.');
            refreshRefUI();
        });

        const stopRecording = (save) => {
            const frames = state.recording;
            state.recording = null;
            recordBtn.classList.remove('tp-recording');
            recordBtn.innerHTML = '<i class="fas fa-circle"></i> Corriger : jouer la fin';
            if (save && frames) {
                if (frames.length < MIN_RECORD_FRAMES) {
                    setStatus('Trop court : aucun son détecté ou moins de 1,5 s. Vérifiez le niveau du micro et recommencez.');
                } else {
                    state.refs[state.page] = { frames, recordedAt: new Date().toISOString() };
                    const ok = saveRefs(state.docKey, state.refs);
                    setStatus(ok ? `Fin de la page ${state.page} enregistrée.` : 'Enregistré pour cette session seulement (stockage du navigateur indisponible).');
                }
            }
            resetLive();
            refreshRefUI();
        };

        deleteRefBtn.addEventListener('click', () => {
            if (!confirm(`Supprimer la fin jouée au micro pour la page ${state.page} ? (la lecture automatique de la partition sera utilisée si elle existe)`)) return;
            delete state.refs[state.page];
            saveRefs(state.docKey, state.refs);
            refreshRefUI();
            setStatus(`Empreinte de la page ${state.page} supprimée.`);
        });

        // ---------- Micro ----------
        const startMic = async () => {
            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                setStatus('Micro indisponible : la page doit être ouverte en HTTPS.');
                return;
            }
            const listener = new ChromaListener(onFrame);
            try {
                await listener.start();
            } catch (e) {
                console.error(e);
                setStatus('Accès au micro refusé ou impossible : ' + e.message);
                return;
            }
            state.listener = listener;
            micBtn.classList.add('tp-active');
            micBtn.innerHTML = '<i class="fas fa-microphone"></i> Micro activé';
            resetLive();
            requestWakeLock();
            setStatus(state.pdf ? 'Écoute en cours' : 'Micro activé. Choisissez une partition.');
        };

        const stopMic = () => {
            if (state.recording) stopRecording(false);
            if (state.listener) state.listener.stop();
            state.listener = null;
            micBtn.classList.remove('tp-active');
            micBtn.innerHTML = '<i class="fas fa-microphone-slash"></i> Activer le micro';
            levelBar.style.width = '0%';
            chromaFills.forEach(f => { f.style.height = '0%'; });
            releaseWakeLock();
            resetLive();
        };

        micBtn.addEventListener('click', () => { state.listener ? stopMic() : startMic(); });

        // Garde l'écran allumé pendant l'écoute
        const requestWakeLock = async () => {
            try { if ('wakeLock' in navigator) state.wakeLock = await navigator.wakeLock.request('screen'); }
            catch (e) { /* non supporté ou refusé : sans gravité */ }
        };
        const releaseWakeLock = () => {
            if (state.wakeLock) state.wakeLock.release().catch(() => {});
            state.wakeLock = null;
        };
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible' && state.listener) requestWakeLock();
        });

        const onFrame = ({ chroma, rms }) => {
            levelBar.style.width = rmsToPercent(rms) + '%';
            const sounding = rms >= settings.gate;
            levelBar.classList.toggle('tp-sounding', sounding);
            chromaFills.forEach((f, i) => { f.style.height = (sounding ? Math.max(0, chroma[i]) * 100 : 0) + '%'; });
            if (test.active) { testOnFrame(chroma, sounding); return; }
            if (state.recording) {
                if (!sounding) return;
                state.recording.push(chroma);
                const secs = (state.recording.length * HOP_MS / 1000).toFixed(1);
                recordBtn.innerHTML = `<i class="fas fa-stop"></i> Terminer (${secs} s)`;
                if (state.recording.length >= MAX_RECORD_FRAMES) stopRecording(true);
                return;
            }

            const armed = settings.auto && (Date.now() - state.pageStart) / 1000 >= settings.minDelay;

            // Suivi de partition : position + tempo -> moment de tourner
            const follower = currentFollower();
            if (follower) {
                const st = follower.push(chroma, sounding);
                followEl.textContent = st.pos === null
                    ? 'Position : recherche…'
                    : `Position : mesure ${st.measure} / ${st.measures} · tempo ≈ ${st.bpm}` +
                      (follower.tracking() ? ` · page suivante dans ${Math.round(st.secondsLeft)} s` : ' · en cours de calage…');
                if (st.turn && armed) { autoTurn(); return; }
            }

            if (!sounding) return; // les silences sont ignorés (pauses, respiration du soufflet)
            const ref = currentReference();
            if (!ref) return;

            state.live.push(chroma);
            const maxLive = Math.ceil(ref.frames.length * 2.2) + 5;
            if (state.live.length > maxLive) state.live.splice(0, state.live.length - maxLive);

            const res = matchEnd(ref.frames, state.live);
            if (!res) return;
            const sim = res.similarity;
            simBar.style.width = Math.max(0, sim * 100) + '%';
            simValue.textContent = Math.round(sim * 100) + ' %';

            simBar.classList.toggle('tp-armed', armed);
            simBar.classList.toggle('tp-hit', sim >= ref.threshold);
            if (!armed) { state.hits = 0; return; }

            // Avec le suivi de partition, c'est lui qui décide (il vérifie la cohérence)
            if (follower && ref.kind === 'omr') return;
            // Deux trames consécutives au-dessus du seuil pour éviter les faux départs
            state.hits = sim >= ref.threshold ? state.hits + 1 : 0;
            if (state.hits >= 2 && state.page < state.pdf.numPages) autoTurn();
        };

        const autoTurn = () => {
            flash.classList.remove('tp-flash-on');
            void flash.offsetWidth; // relance l'animation
            flash.classList.add('tp-flash-on');
            setStatus(`Page tournée automatiquement (${new Date().toLocaleTimeString()}). Utilisez ◀ en cas d'erreur.`);
            goToPage(state.page + 1);
        };

        // ---------- Mode test (sans partition) ----------
        // Pour vérifier la reconnaissance au piano sans savoir lire une
        // partition : on allume les touches à jouer sur un clavier dessiné.
        const CHORD_TYPES = [
            { suffix: ' majeur', intervals: [0, 4, 7] },
            { suffix: ' mineur', intervals: [0, 3, 7] },
            { suffix: ' 7', intervals: [0, 4, 7, 10] }
        ];
        const NOTE_TARGETS = NOTE_NAMES.map((name, pc) => ({ name, midis: [60 + pc], chroma: notesChroma([60 + pc]) }));
        const ALL_CHORDS = [];
        NOTE_NAMES.forEach((root, pc) => CHORD_TYPES.forEach(({ suffix, intervals }) => {
            const midis = intervals.map(i => 60 + pc + i);
            ALL_CHORDS.push({ name: root + suffix, midis, chroma: notesChroma(midis) });
        }));
        const chordByName = (name) => ALL_CHORDS.find(c => c.name === name);
        // Touches blanches d'abord, puis les noires
        const PRACTICE_NOTES = [0, 2, 4, 5, 7, 9, 11, 1, 3, 6, 8, 10].map(pc => NOTE_TARGETS[pc]);
        const PRACTICE_CHORDS = ['Do majeur', 'Fa majeur', 'Sol majeur', 'La mineur', 'Ré mineur', 'Mi mineur',
                                 'Sol 7', 'Ré majeur', 'La majeur', 'Mi majeur'].map(chordByName);
        const SEQUENCES = [
            ['Do majeur', 'Fa majeur', 'Sol majeur', 'Do majeur'],
            ['La mineur', 'Ré mineur', 'Mi mineur', 'La mineur'],
            ['Do majeur', 'La mineur', 'Fa majeur', 'Sol 7']
        ].map(names => names.map(chordByName));
        const FRAMES_PER_SEQ_CHORD = 10; // ~1 s par accord

        const testPanel = $('tp-test');
        const testTarget = $('tp-test-target');
        const testHint = $('tp-test-hint');
        const testKeyboards = $('tp-test-keyboards');
        const testHeard = $('tp-test-heard');
        const testSimBar = $('tp-test-sim-bar');
        const testSimValue = $('tp-test-sim-value');
        const testThrMarker = $('tp-test-thr-marker');
        const testResult = $('tp-test-result');
        const testScore = $('tp-test-score');
        const testNextBtn = $('tp-test-next');
        const testModeBtns = testPanel.querySelectorAll('[data-test-mode]');

        const test = { active: false, mode: 'notes', index: 0, streak: 0, done: false, ok: 0, total: 0,
                       live: [], hits: 0, template: null, timer: null };

        // Clavier de deux octaves (Do4 à Si5), touches repérées par n° MIDI
        const buildKeyboard = (highlight, small) => {
            const kb = document.createElement('div');
            kb.className = 'tp-keyboard' + (small ? ' tp-keyboard-small' : '');
            const whites = [];
            for (let m = 60; m < 84; m++) if (![1, 3, 6, 8, 10].includes(m % 12)) whites.push(m);
            const w = 100 / whites.length;
            whites.forEach((m, i) => {
                const key = document.createElement('div');
                key.className = 'tp-key tp-key-white' + (highlight.includes(m) ? ' tp-key-on' : '');
                key.style.left = (i * w) + '%';
                key.style.width = w + '%';
                key.innerHTML = `<span>${NOTE_NAMES[m % 12]}</span>`;
                kb.appendChild(key);
            });
            whites.forEach((m, i) => {
                const black = m + 1;
                if (black >= 84 || ![1, 3, 6, 8, 10].includes(black % 12)) return;
                const key = document.createElement('div');
                key.className = 'tp-key tp-key-black' + (highlight.includes(black) ? ' tp-key-on' : '');
                key.style.left = ((i + 1) * w - w * 0.3) + '%';
                key.style.width = (w * 0.6) + '%';
                key.title = NOTE_NAMES[black % 12];
                kb.appendChild(key);
            });
            return kb;
        };

        const currentTarget = () => {
            if (test.mode === 'notes') return PRACTICE_NOTES[test.index % PRACTICE_NOTES.length];
            if (test.mode === 'chords') return PRACTICE_CHORDS[test.index % PRACTICE_CHORDS.length];
            return SEQUENCES[test.index % SEQUENCES.length];
        };

        const renderTest = () => {
            clearTimeout(test.timer);
            test.streak = 0; test.done = false; test.live = []; test.hits = 0;
            testResult.textContent = '';
            testResult.className = 'tp-test-result';
            testSimBar.style.width = '0%';
            testSimValue.textContent = '—';
            testHeard.textContent = '…';
            testKeyboards.innerHTML = '';
            testModeBtns.forEach(b => b.classList.toggle('tp-active-mode', b.dataset.testMode === test.mode));
            const target = currentTarget();
            testTarget.classList.toggle('tp-test-target-seq', test.mode === 'sequence');
            if (test.mode === 'sequence') {
                testTarget.textContent = target.map(c => c.name).join('  →  ');
                testHint.textContent = 'Jouez les 4 accords dans l\'ordre, environ 1 seconde chacun, comme une fin de page. ' +
                    'Quand l\'enchaînement est reconnu, la page aurait tourné. Essayez aussi de jouer autre chose : ça ne doit pas se déclencher.';
                target.forEach((c, i) => {
                    const box = document.createElement('div');
                    box.className = 'tp-seq-step';
                    box.innerHTML = `<strong>${i + 1}. ${c.name}</strong>`;
                    box.appendChild(buildKeyboard(c.midis, true));
                    testKeyboards.appendChild(box);
                });
                test.template = target.flatMap(c => Array(FRAMES_PER_SEQ_CHORD).fill(c.chroma));
                testThrMarker.style.left = settings.thresholdOmr * 100 + '%';
            } else {
                testTarget.textContent = target.name;
                testHint.textContent = test.mode === 'notes'
                    ? 'Appuyez sur la touche allumée et laissez-la sonner. N\'importe quelle touche du même nom convient, plus haut ou plus bas sur le piano.'
                    : 'Appuyez les touches allumées en même temps et gardez-les enfoncées.';
                testKeyboards.appendChild(buildKeyboard(target.midis, false));
                testThrMarker.style.left = '0%';
            }
        };

        const showTestSuccess = (text) => {
            test.done = true;
            test.ok++; test.total++;
            testResult.textContent = text;
            testResult.className = 'tp-test-result tp-test-ok';
            testScore.textContent = `Réussis : ${test.ok} / ${test.total}`;
        };

        const testOnFrame = (chroma, sounding) => {
            if (test.done) return;
            const target = currentTarget();
            if (!sounding) {
                if (test.mode !== 'sequence') { test.streak = 0; testHeard.textContent = '… (silence)'; }
                return;
            }
            const candidates = test.mode === 'notes' ? NOTE_TARGETS : ALL_CHORDS;
            let best = null, bestSim = -2;
            for (const c of candidates) {
                const sim = dot(chroma, c.chroma);
                if (sim > bestSim) { bestSim = sim; best = c; }
            }
            testHeard.textContent = `${best.name} (${Math.round(bestSim * 100)} %)`;

            if (test.mode === 'sequence') {
                test.live.push(chroma);
                const maxLive = Math.ceil(test.template.length * 2.2) + 5;
                if (test.live.length > maxLive) test.live.splice(0, test.live.length - maxLive);
                const res = matchEnd(test.template, test.live);
                if (!res) return;
                testSimBar.style.width = Math.max(0, res.similarity * 100) + '%';
                testSimValue.textContent = Math.round(res.similarity * 100) + ' %';
                test.hits = res.similarity >= settings.thresholdOmr ? test.hits + 1 : 0;
                if (test.hits >= 2) showTestSuccess('✓ Enchaînement reconnu : la page aurait tourné ici.');
                return;
            }

            const simTarget = dot(chroma, target.chroma);
            testSimBar.style.width = Math.max(0, simTarget * 100) + '%';
            testSimValue.textContent = Math.round(simTarget * 100) + ' %';
            test.streak = best === target ? test.streak + 1 : 0;
            if (test.streak >= 3) {
                showTestSuccess(`✓ ${target.name} reconnu !`);
                test.timer = setTimeout(() => { test.index++; renderTest(); }, 1500);
            }
        };

        testModeBtns.forEach(b => b.addEventListener('click', () => { test.mode = b.dataset.testMode; test.index = 0; renderTest(); }));
        testNextBtn.addEventListener('click', () => {
            if (!test.done) { test.total++; testScore.textContent = `Réussis : ${test.ok} / ${test.total}`; }
            test.index++;
            renderTest();
        });
        $('tp-test-retry').addEventListener('click', renderTest);
        testPanel.addEventListener('toggle', () => {
            test.active = testPanel.open;
            if (test.active) {
                renderTest();
                if (!state.listener) startMic();
            } else {
                clearTimeout(test.timer);
                resetLive();
            }
        });

        // ---------- Cycle de vie de l'onglet ----------
        // Le routeur d'app.js affiche/masque la vue : on réagit à ces changements.
        const onVisibilityChange = () => {
            const visible = view.style.display === 'block';
            if (visible) {
                loadPartitions();
                setTimeout(renderPage, 50);
            } else if (state.listener) {
                stopMic();
                setStatus('Micro coupé (onglet quitté).');
            }
        };
        new MutationObserver(onVisibilityChange).observe(view, { attributes: true, attributeFilter: ['style'] });
        onVisibilityChange();
    });
})();
