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
    window.TournePageEngine = { buildBinMap, chromaFromSpectrum, normalizeChroma, matchEnd, ChromaListener, NOTE_NAMES };

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
        const flash = $('tp-flash');

        const settings = Object.assign(
            { threshold: 0.85, minDelay: 8, gate: 0.01, auto: true },
            storage.get('tp-settings', {})
        );
        const saveSettings = () => storage.set('tp-settings', settings);

        const state = {
            supabase: null,
            partitions: [],
            docKey: null,
            pdf: null,
            page: 1,
            refs: {},
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
            thrMarker.style.left = Math.max(0, settings.threshold * 100) + '%';
            delayInput.value = settings.minDelay;
            delayLabel.textContent = settings.minDelay + ' s';
            gateInput.value = sliderFromGate(settings.gate);
            gateLabel.textContent = (20 * Math.log10(settings.gate)).toFixed(0) + ' dB';
            gateMarker.style.left = rmsToPercent(settings.gate) + '%';
            autoToggle.checked = settings.auto;
        };
        thrInput.addEventListener('input', () => { settings.threshold = thrInput.value / 100; saveSettings(); refreshSettingsUI(); });
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
                placeholder.style.display = 'none';
                canvas.style.display = 'block';
                await goToPage(1);
                setStatus(state.listener ? 'Écoute en cours' : 'Prêt. Activez le micro pour commencer.');
            } catch (e) {
                console.error(e);
                setStatus('Impossible d\'ouvrir le PDF : ' + e.message);
            }
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
            simBar.style.width = '0%';
            simValue.textContent = '—';
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
            const ref = state.refs[state.page];
            const isLast = hasPdf && state.page === state.pdf.numPages;
            recordBtn.disabled = !hasPdf || isLast;
            deleteRefBtn.style.display = ref && !state.recording ? 'inline-flex' : 'none';
            if (!hasPdf) refBadge.textContent = '';
            else if (isLast) refBadge.textContent = 'Dernière page';
            else if (ref) refBadge.innerHTML = `<i class="fas fa-check-circle"></i> Fin enregistrée (${(ref.frames.length * HOP_MS / 1000).toFixed(1)} s)`;
            else refBadge.innerHTML = '<i class="fas fa-exclamation-circle"></i> Pas encore de fin enregistrée';
            refBadge.classList.toggle('tp-ok', !!ref);
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
            recordBtn.innerHTML = '<i class="fas fa-circle"></i> Enregistrer la fin de cette page';
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
            if (!confirm(`Supprimer l'empreinte de fin de la page ${state.page} ?`)) return;
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
            if (!sounding) return; // les silences sont ignorés (pauses, respiration du soufflet)

            if (state.recording) {
                state.recording.push(chroma);
                const secs = (state.recording.length * HOP_MS / 1000).toFixed(1);
                recordBtn.innerHTML = `<i class="fas fa-stop"></i> Terminer (${secs} s)`;
                if (state.recording.length >= MAX_RECORD_FRAMES) stopRecording(true);
                return;
            }

            const ref = state.refs[state.page];
            if (!state.pdf || !ref) return;

            state.live.push(chroma);
            const maxLive = Math.ceil(ref.frames.length * 2.2) + 5;
            if (state.live.length > maxLive) state.live.splice(0, state.live.length - maxLive);

            const res = matchEnd(ref.frames, state.live);
            if (!res) return;
            const sim = res.similarity;
            simBar.style.width = Math.max(0, sim * 100) + '%';
            simValue.textContent = Math.round(sim * 100) + ' %';

            const armed = settings.auto && (Date.now() - state.pageStart) / 1000 >= settings.minDelay;
            simBar.classList.toggle('tp-armed', armed);
            simBar.classList.toggle('tp-hit', sim >= settings.threshold);
            if (!armed) { state.hits = 0; return; }

            // Deux trames consécutives au-dessus du seuil pour éviter les faux départs
            state.hits = sim >= settings.threshold ? state.hits + 1 : 0;
            if (state.hits >= 2 && state.page < state.pdf.numPages) autoTurn();
        };

        const autoTurn = () => {
            flash.classList.remove('tp-flash-on');
            void flash.offsetWidth; // relance l'animation
            flash.classList.add('tp-flash-on');
            setStatus(`Page tournée automatiquement (${new Date().toLocaleTimeString()}). Utilisez ◀ en cas d'erreur.`);
            goToPage(state.page + 1);
        };

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
