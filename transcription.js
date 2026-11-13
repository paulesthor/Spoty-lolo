// =======================================================
// |     TRANSCRIPTION AUDIO -> PARTITION (BÊTA)          |
// =======================================================
// Module autonome : n'utilise ni ne modifie rien dans app.js.
// 1. Enregistrement au micro ou import d'un fichier audio.
// 2. Transcription des notes du piano dans le navigateur
//    (Onsets and Frames, Google Magenta).
// 3. Mise en partition : tempo et temps forts, arrondi rythmique,
//    tonalité, séparation main droite / main gauche -> MusicXML.
// 4. Affichage (OpenSheetMusicDisplay), écoute, exports MIDI /
//    MusicXML / PDF et ajout à la bibliothèque.

(() => {

    // Même projet Supabase qu'app.js (clé publique "anon")
    const SUPABASE_URL = 'https://ikkhvkgcxvlpqejvvuot.supabase.co';
    const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlra2h2a2djeHZscHFlanZ2dW90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MDI1NDMsImV4cCI6MjA4MDM3ODU0M30.I606WGNVllQ5VI_mB1TmheediORTyNvXqpdkKSFa73o';

    const LIBS = {
        magenta: 'https://cdn.jsdelivr.net/npm/@magenta/music@1.23.1/dist/magentamusic.min.js',
        magentaModel: 'https://storage.googleapis.com/magentadata/js/checkpoints/transcription/onsets_frames_uni',
        osmd: 'https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.8.9/build/opensheetmusicdisplay.min.js',
        jspdf: 'https://cdn.jsdelivr.net/npm/jspdf@2.5.2/dist/jspdf.umd.min.js',
        svg2pdf: 'https://cdn.jsdelivr.net/npm/svg2pdf.js@2.2.4/dist/svg2pdf.umd.min.js'
    };

    const loadedScripts = {};
    const loadScript = (url) => {
        if (!loadedScripts[url]) {
            loadedScripts[url] = new Promise((resolve, reject) => {
                const s = document.createElement('script');
                s.src = url;
                s.onload = resolve;
                s.onerror = () => { delete loadedScripts[url]; reject(new Error('Chargement impossible : ' + url)); };
                document.head.appendChild(s);
            });
        }
        return loadedScripts[url];
    };

    // =======================================================
    // |                 TRANSCRIPTION DES NOTES              |
    // =======================================================
    // Résultat : [{ pitch (MIDI), start (s), end (s), velocity (0-1) }]

    let magentaModel = null;
    const transcribePiano = async (blob, onStep) => {
        onStep('Chargement du modèle piano (une seule fois, environ 30 Mo)...');
        await loadScript(LIBS.magenta);
        if (!magentaModel) {
            magentaModel = new window.mm.OnsetsAndFrames(LIBS.magentaModel);
            await magentaModel.initialize();
        }
        onStep('Écoute des notes (piano)...');
        const ns = await magentaModel.transcribeFromAudioFile(blob);
        return ns.notes.map(n => ({
            pitch: n.pitch, start: n.startTime, end: n.endTime, velocity: (n.velocity || 80) / 127
        }));
    };

    // Nettoyage : notes trop courtes, trop faibles ou hors clavier
    const cleanNotes = (notes, sensitivity) => {
        const minVelocity = Math.max(0, 0.35 - sensitivity * 0.035);
        return notes
            .filter(n => n.pitch >= 21 && n.pitch <= 108 && n.end - n.start >= 0.05 && n.velocity >= minVelocity)
            .sort((a, b) => a.start - b.start || a.pitch - b.pitch);
    };

    // =======================================================
    // |                     MISE EN PARTITION                |
    // =======================================================

    // Attaques regroupées (notes jouées ensemble = une attaque)
    const onsetGroups = (notes) => {
        const groups = [];
        for (const n of notes) {
            const g = groups[groups.length - 1];
            if (g && n.start - g.time < 0.04) {
                g.weight += n.velocity;
                g.low = Math.min(g.low, n.pitch);
            } else {
                groups.push({ time: n.start, weight: n.velocity, low: n.pitch });
            }
        }
        return groups;
    };

    // Tempo global : la pulsation qui fait tomber le plus d'attaques "en
    // place" (sur les temps et demi-temps), avec une préférence pour les
    // tempos courants (autour de 100).
    const estimateTempo = (groups) => {
        let best = { score: -1, bpm: 100 };
        for (let bpm = 50; bpm <= 200; bpm += 0.5) {
            const p = 60 / bpm;
            let re1 = 0, im1 = 0, re2 = 0, im2 = 0, total = 0;
            for (const g of groups) {
                const a = 2 * Math.PI * g.time / p;
                re1 += g.weight * Math.cos(a); im1 += g.weight * Math.sin(a);
                re2 += g.weight * Math.cos(2 * a); im2 += g.weight * Math.sin(2 * a);
                total += g.weight;
            }
            const prior = Math.exp(-0.5 * (Math.log2(bpm / 100) / 0.8) ** 2);
            const score = (Math.hypot(re1, im1) + 0.5 * Math.hypot(re2, im2)) / total * prior;
            if (score > best.score) best = { score, bpm };
        }
        return best.bpm;
    };

    // Suivi des temps : part d'une pulsation régulière et se recale sur les
    // attaques proches, pour suivre un jeu qui accélère ou ralentit.
    const trackBeats = (groups, bpm, duration) => {
        let period = 60 / bpm;
        // Premier temps sur la première attaque
        let beat = groups.length ? groups[0].time : 0;
        const beats = [beat];
        let gi = 0;
        while (beat < duration + period) {
            const predicted = beat + period;
            let nearest = null;
            while (gi < groups.length && groups[gi].time < predicted - period / 2) gi++;
            for (let k = gi; k < groups.length && groups[k].time <= predicted + period / 2; k++) {
                const d = groups[k].time - predicted;
                if (Math.abs(d) <= period / 4 && (!nearest || Math.abs(d) < Math.abs(nearest))) nearest = d;
            }
            const next = nearest === null ? predicted : predicted + 0.35 * nearest;
            // La pulsation s'adapte doucement, dans des limites raisonnables
            period = Math.min(60 / bpm * 1.3, Math.max(60 / bpm * 0.77, 0.85 * period + 0.15 * (next - beat)));
            beats.push(next);
            beat = next;
        }
        return beats;
    };

    // Temps (s) -> position en pulsations, par interpolation entre les temps suivis
    const timeToPulse = (t, beats) => {
        if (t <= beats[0]) return (t - beats[0]) / (beats[1] - beats[0]);
        let lo = 0, hi = beats.length - 1;
        while (hi - lo > 1) {
            const mid = (lo + hi) >> 1;
            if (beats[mid] <= t) lo = mid; else hi = mid;
        }
        return lo + (t - beats[lo]) / (beats[hi] - beats[lo]);
    };

    // Profils de Krumhansl : quelle tonalité "explique" le mieux les notes
    const MAJOR_PROFILE = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
    const MINOR_PROFILE = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];
    const FIFTHS_OF_MAJOR = { 0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6, 1: -5, 8: -4, 3: -3, 10: -2, 5: -1 };
    const NOTE_NAMES_FR = ['Do', 'Do#', 'Ré', 'Mib', 'Mi', 'Fa', 'Fa#', 'Sol', 'Lab', 'La', 'Sib', 'Si'];

    const correlation = (a, b) => {
        const ma = a.reduce((s, v) => s + v, 0) / 12, mb = b.reduce((s, v) => s + v, 0) / 12;
        let num = 0, da = 0, db = 0;
        for (let i = 0; i < 12; i++) { num += (a[i] - ma) * (b[i] - mb); da += (a[i] - ma) ** 2; db += (b[i] - mb) ** 2; }
        return num / Math.sqrt(da * db || 1);
    };

    const detectKey = (notes) => {
        const hist = new Array(12).fill(0);
        for (const n of notes) hist[n.pitch % 12] += n.end - n.start;
        let best = { score: -2, fifths: 0, label: 'Do majeur' };
        for (let tonic = 0; tonic < 12; tonic++) {
            const rot = (profile) => hist.map((_, i) => profile[(i - tonic + 12) % 12]);
            const maj = correlation(hist, rot(MAJOR_PROFILE));
            const min = correlation(hist, rot(MINOR_PROFILE));
            if (maj > best.score) best = { score: maj, fifths: FIFTHS_OF_MAJOR[tonic], label: `${NOTE_NAMES_FR[tonic]} majeur` };
            if (min > best.score) best = { score: min, fifths: FIFTHS_OF_MAJOR[(tonic + 3) % 12], label: `${NOTE_NAMES_FR[tonic]} mineur` };
        }
        return best;
    };

    const KEY_CHOICES = [
        { fifths: 0, label: 'Do majeur / La mineur' }, { fifths: 1, label: 'Sol majeur / Mi mineur' },
        { fifths: 2, label: 'Ré majeur / Si mineur' }, { fifths: 3, label: 'La majeur / Fa# mineur' },
        { fifths: 4, label: 'Mi majeur / Do# mineur' }, { fifths: -1, label: 'Fa majeur / Ré mineur' },
        { fifths: -2, label: 'Sib majeur / Sol mineur' }, { fifths: -3, label: 'Mib majeur / Do mineur' },
        { fifths: -4, label: 'Lab majeur / Fa mineur' }
    ];

    // Orthographe des notes : dièses dans les tonalités à dièses, bémols sinon
    const SHARP_SPELLING = [['C', 0], ['C', 1], ['D', 0], ['D', 1], ['E', 0], ['F', 0], ['F', 1], ['G', 0], ['G', 1], ['A', 0], ['A', 1], ['B', 0]];
    const FLAT_SPELLING = [['C', 0], ['D', -1], ['D', 0], ['E', -1], ['E', 0], ['F', 0], ['G', -1], ['G', 0], ['A', -1], ['A', 0], ['B', -1], ['B', 0]];
    const spell = (midi, fifths) => {
        const [step, alter] = (fifths < 0 ? FLAT_SPELLING : SHARP_SPELLING)[midi % 12];
        return { step, alter, octave: Math.floor(midi / 12) - 1 };
    };

    const TIME_SIGNATURES = {
        '4/4': { beats: 4, beatType: 4, pulseQ: 1, measureQ: 4 },
        '3/4': { beats: 3, beatType: 4, pulseQ: 1, measureQ: 3 },
        '2/4': { beats: 2, beatType: 4, pulseQ: 1, measureQ: 2 },
        '2/2': { beats: 2, beatType: 2, pulseQ: 1, measureQ: 4 },
        '6/8': { beats: 6, beatType: 8, pulseQ: 1.5, measureQ: 3 }
    };

    // Notes "à la seconde" -> notes "en noires", arrondies à la grille
    const quantize = (notes, opts) => {
        const groups = onsetGroups(notes);
        const duration = notes.reduce((m, n) => Math.max(m, n.end), 0);
        const bpm = opts.bpm || estimateTempo(groups);
        const beats = trackBeats(groups, bpm, duration);
        const ts = TIME_SIGNATURES[opts.timeSignature];
        const grid = opts.grid; // en noires : 1, 0.5 ou 0.25
        const toQ = (t) => timeToPulse(t, beats) * ts.pulseQ;
        let qNotes = notes.map(n => {
            const start = Math.max(0, Math.round(toQ(n.start) / grid) * grid);
            const end = Math.max(start + grid, Math.round(toQ(n.end) / grid) * grid);
            return { pitch: n.pitch, start, end, velocity: n.velocity };
        });
        // Premier temps de la mesure : la position qui met le plus de basses
        // et d'attaques fortes sur les débuts de mesure (gère les levées)
        let bestShift = 0, bestScore = -1;
        const pulsesPerMeasure = ts.measureQ / ts.pulseQ;
        for (let shift = 0; shift < pulsesPerMeasure; shift++) {
            let score = 0;
            for (const n of qNotes) {
                const pos = (n.start / ts.pulseQ + shift) % pulsesPerMeasure;
                if (Math.abs(pos) < 1e-6) score += n.velocity * (n.pitch < 60 ? 2 : 1);
            }
            if (score > bestScore) { bestScore = score; bestShift = shift; }
        }
        const offset = bestShift * ts.pulseQ;
        qNotes = qNotes.map(n => ({ ...n, start: n.start + offset, end: n.end + offset }));
        // Doublons créés par l'arrondi (même note au même endroit)
        const seen = new Set();
        qNotes = qNotes.filter(n => {
            const k = n.pitch + ':' + n.start;
            if (seen.has(k)) return false;
            seen.add(k);
            return true;
        });
        // Tempo moyen réellement joué
        const realBpm = beats.length > 2 ? 60 / ((beats[beats.length - 1] - beats[0]) / (beats.length - 1)) * (1 / ts.pulseQ) : bpm;
        return { notes: qNotes, bpm: Math.round(realBpm), ts };
    };

    // Valeurs de notes écrivables, en seizièmes (divisions = 4 par noire)
    const DIVISIONS = 4;
    const NOTE_VALUES = [
        [16, 'whole', false], [12, 'half', true], [8, 'half', false], [6, 'quarter', true],
        [4, 'quarter', false], [3, 'eighth', true], [2, 'eighth', false], [1, '16th', false]
    ];
    const splitDuration = (units) => {
        const parts = [];
        let rest = units;
        while (rest > 0) {
            const v = NOTE_VALUES.find(([u]) => u <= rest);
            parts.push(v);
            rest -= v[0];
        }
        return parts;
    };

    // Une portée -> suite d'événements { start, dur, pitches|null } en seizièmes.
    // Les notes attaquées ensemble forment un accord ; un accord dure jusqu'à
    // la note suivante (ou moins si toutes ses notes s'arrêtent avant).
    const staffEvents = (notes, totalUnits) => {
        const byStart = new Map();
        for (const n of notes) {
            const s = Math.round(n.start * DIVISIONS);
            if (!byStart.has(s)) byStart.set(s, []);
            byStart.get(s).push(n);
        }
        const starts = [...byStart.keys()].sort((a, b) => a - b);
        const events = [];
        let cursor = 0;
        starts.forEach((s, i) => {
            if (s > cursor) events.push({ start: cursor, dur: s - cursor, pitches: null });
            const group = byStart.get(s);
            const next = i + 1 < starts.length ? starts[i + 1] : totalUnits;
            const end = Math.min(next, Math.max(...group.map(n => Math.round(n.end * DIVISIONS))));
            const dur = Math.max(1, end - s);
            events.push({ start: s, dur, pitches: [...new Set(group.map(n => n.pitch))].sort((a, b) => a - b) });
            cursor = s + dur;
        });
        if (cursor < totalUnits) events.push({ start: cursor, dur: totalUnits - cursor, pitches: null });
        return events;
    };

    const xmlEscape = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]));

    // Écrit le contenu d'une portée pour une mesure (coupe et lie aux barres)
    const measureXml = (events, mStart, mUnits, staff, voice, fifths) => {
        let xml = '';
        const mEnd = mStart + mUnits;
        const inMeasure = events.filter(e => e.start < mEnd && e.start + e.dur > mStart);
        // Mesure entièrement vide : pause entière
        if (inMeasure.every(e => !e.pitches)) {
            return `<note><rest measure="yes"/><duration>${mUnits}</duration><voice>${voice}</voice><staff>${staff}</staff></note>`;
        }
        for (const e of inMeasure) {
            const s = Math.max(e.start, mStart), end = Math.min(e.start + e.dur, mEnd);
            const tiedFromPrev = e.start < mStart;
            const tiedToNext = e.start + e.dur > mEnd;
            const parts = splitDuration(end - s);
            parts.forEach(([units, type, dotted], pi) => {
                const tieStart = e.pitches && (pi < parts.length - 1 || tiedToNext);
                const tieStop = e.pitches && (pi > 0 || tiedFromPrev);
                const ties = (tieStop ? '<tie type="stop"/>' : '') + (tieStart ? '<tie type="start"/>' : '');
                const notations = (tieStop || tieStart)
                    ? `<notations>${tieStop ? '<tied type="stop"/>' : ''}${tieStart ? '<tied type="start"/>' : ''}</notations>` : '';
                const common = `<duration>${units}</duration>${ties}<voice>${voice}</voice><type>${type}</type>${dotted ? '<dot/>' : ''}<staff>${staff}</staff>`;
                if (!e.pitches) {
                    xml += `<note><rest/>${common.replace(ties, '')}</note>`;
                    return;
                }
                e.pitches.forEach((p, ci) => {
                    const { step, alter, octave } = spell(p, fifths);
                    xml += `<note>${ci > 0 ? '<chord/>' : ''}<pitch><step>${step}</step>${alter ? `<alter>${alter}</alter>` : ''}<octave>${octave}</octave></pitch>${common}${notations}</note>`;
                });
            });
        }
        return xml;
    };

    const buildMusicXml = (quant, opts) => {
        const { ts } = quant;
        const mUnits = ts.measureQ * DIVISIONS;
        const lastEnd = quant.notes.reduce((m, n) => Math.max(m, n.end), 0);
        const measures = Math.max(1, Math.ceil(lastEnd * DIVISIONS / mUnits));
        const totalUnits = measures * mUnits;
        const fifths = opts.fifths;

        let staves;
        if (opts.staves === 'piano') {
            staves = [
                { clef: '<sign>G</sign><line>2</line>', notes: quant.notes.filter(n => n.pitch >= opts.split) },
                { clef: '<sign>F</sign><line>4</line>', notes: quant.notes.filter(n => n.pitch < opts.split) }
            ];
        } else {
            const pitches = quant.notes.map(n => n.pitch).sort((a, b) => a - b);
            const median = pitches.length ? pitches[pitches.length >> 1] : 60;
            staves = [{ clef: median >= 55 ? '<sign>G</sign><line>2</line>' : '<sign>F</sign><line>4</line>', notes: quant.notes }];
        }
        const events = staves.map(s => staffEvents(s.notes, totalUnits));

        let body = '';
        for (let m = 0; m < measures; m++) {
            body += `<measure number="${m + 1}">`;
            if (m === 0) {
                body += `<attributes><divisions>${DIVISIONS}</divisions><key><fifths>${fifths}</fifths></key>` +
                    `<time><beats>${ts.beats}</beats><beat-type>${ts.beatType}</beat-type></time>` +
                    (staves.length > 1 ? `<staves>${staves.length}</staves>` : '') +
                    staves.map((s, i) => `<clef number="${i + 1}">${s.clef}</clef>`).join('') + `</attributes>` +
                    `<direction placement="above"><direction-type><metronome><beat-unit>${ts.pulseQ === 1.5 ? 'quarter' : 'quarter'}</beat-unit>` +
                    `${ts.pulseQ === 1.5 ? '<beat-unit-dot/>' : ''}<per-minute>${quant.bpm}</per-minute></metronome></direction-type>` +
                    `<sound tempo="${Math.round(quant.bpm * ts.pulseQ)}"/></direction>`;
            }
            events.forEach((ev, i) => {
                if (i > 0) body += `<backup><duration>${mUnits}</duration></backup>`;
                body += measureXml(ev, m * mUnits, mUnits, i + 1, i === 0 ? 1 : 5, fifths);
            });
            if (m === measures - 1) body += '<barline location="right"><bar-style>light-heavy</bar-style></barline>';
            body += '</measure>';
        }

        return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
<work><work-title>${xmlEscape(opts.title)}</work-title></work>
<identification><creator type="composer">Transcription automatique</creator><encoding><software>Spoti-Lolo</software></encoding></identification>
<part-list><score-part id="P1"><part-name>${opts.staves === 'piano' ? 'Piano' : ''}</part-name></score-part></part-list>
<part id="P1">${body}</part>
</score-partwise>`;
    };

    // Fichier MIDI (format 0) à partir des notes arrondies : s'importe
    // proprement dans MuseScore, aligné sur la partition.
    const buildMidi = (quant) => {
        const PPQ = 480;
        const events = [];
        for (const n of quant.notes) {
            const vel = Math.max(1, Math.min(127, Math.round(n.velocity * 127) || 80));
            events.push({ tick: Math.round(n.start * PPQ), data: [0x90, n.pitch, vel] });
            events.push({ tick: Math.round(n.end * PPQ), data: [0x80, n.pitch, 0] });
        }
        events.sort((a, b) => a.tick - b.tick || a.data[0] - b.data[0]);
        const varLen = (v) => {
            const bytes = [v & 0x7f];
            while ((v >>= 7)) bytes.unshift((v & 0x7f) | 0x80);
            return bytes;
        };
        const usPerQuarter = Math.round(60000000 / (quant.bpm * quant.ts.pulseQ));
        const track = [0, 0xff, 0x51, 0x03, (usPerQuarter >> 16) & 0xff, (usPerQuarter >> 8) & 0xff, usPerQuarter & 0xff];
        let last = 0;
        for (const e of events) {
            track.push(...varLen(e.tick - last), ...e.data);
            last = e.tick;
        }
        track.push(0, 0xff, 0x2f, 0x00);
        const header = [0x4d, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 0, 0, 1, (PPQ >> 8) & 0xff, PPQ & 0xff];
        const len = track.length;
        const trackHeader = [0x4d, 0x54, 0x72, 0x6b, (len >> 24) & 0xff, (len >> 16) & 0xff, (len >> 8) & 0xff, len & 0xff];
        return new Blob([new Uint8Array([...header, ...trackHeader, ...track])], { type: 'audio/midi' });
    };

    // Exposé pour les tests et le débogage depuis la console
    window.TranscriptionEngine = { cleanNotes, onsetGroups, estimateTempo, trackBeats, quantize, detectKey, buildMusicXml, buildMidi };

    // =======================================================
    // |                      INTERFACE                       |
    // =======================================================

    document.addEventListener('DOMContentLoaded', () => {
        const view = document.getElementById('transcription-view');
        if (!view) return;
        const $ = (id) => document.getElementById(id);

        const listenBtn = $('tr-listen');
        const fileBtn = $('tr-file-go');
        const recPanel = $('tr-rec-panel');
        const recTime = $('tr-rec-time');
        const recLevel = $('tr-rec-level');
        const fileInput = $('tr-file');
        const sourceInfo = $('tr-source-info');
        const sourceAudio = $('tr-source-audio');
        const sensInput = $('tr-sensitivity');
        const sensLabel = $('tr-sensitivity-label');
        const tempoMode = $('tr-tempo-mode');
        const bpmInput = $('tr-bpm');
        const tsSel = $('tr-time-signature');
        const gridSel = $('tr-grid');
        const keySel = $('tr-key');
        const stavesSel = $('tr-staves');
        const splitSel = $('tr-split');
        const titleInput = $('tr-title');
        const progress = $('tr-progress');
        const results = $('tr-results');
        const summary = $('tr-summary');
        const roll = $('tr-roll');
        const playBtn = $('tr-play');
        const scoreEl = $('tr-score');
        const statusEl = $('tr-status');

        const state = { blob: null, rawNotes: null, quant: null, xml: null, recorder: null, playing: null, osmd: null };
        const setStatus = (t) => { statusEl.textContent = t; };

        // ---------- Options ----------
        KEY_CHOICES.forEach(k => keySel.insertAdjacentHTML('beforeend', `<option value="${k.fifths}">${k.label}</option>`));
        for (let m = 48; m <= 67; m++) {
            const { step, alter, octave } = spell(m, 0);
            const name = NOTE_NAMES_FR[m % 12] + (octave);
            splitSel.insertAdjacentHTML('beforeend', `<option value="${m}" ${m === 60 ? 'selected' : ''}>${name}${m === 60 ? ' (Do du milieu)' : ''}</option>`);
        }
        titleInput.value = 'Transcription du ' + new Date().toLocaleDateString('fr-FR');
        const refreshOptions = () => {
            sensLabel.textContent = sensInput.value;
            bpmInput.disabled = tempoMode.value !== 'manual';
            splitSel.disabled = stavesSel.value !== 'piano';
        };
        [sensInput, tempoMode, stavesSel].forEach(el => el.addEventListener('input', refreshOptions));
        refreshOptions();
        // Les réglages d'écriture se rappliquent sans tout re-transcrire
        [tempoMode, bpmInput, tsSel, gridSel, keySel, stavesSel, splitSel, titleInput].forEach(el =>
            el.addEventListener('change', () => { if (state.rawNotes) renderScore(); }));
        sensInput.addEventListener('change', () => { if (state.rawNotes) renderScore(); });

        // ---------- Source audio ----------
        const setSource = (blob, label) => {
            state.blob = blob;
            sourceInfo.textContent = label;
            sourceAudio.src = URL.createObjectURL(blob);
            sourceAudio.style.display = 'block';
            fileBtn.disabled = false;
        };

        fileInput.addEventListener('change', () => {
            const f = fileInput.files[0];
            if (!f) return;
            setSource(f, `Fichier : ${f.name}`);
            if (titleInput.value.startsWith('Transcription du ')) titleInput.value = f.name.replace(/\.[^.]+$/, '');
        });
        fileBtn.addEventListener('click', () => runTranscription());

        // Le bouton écoute, puis transcrit dès qu'on l'arrête
        let recTimer = null, levelTimer = null, busy = false;
        const btn = listenBtn;
        listenBtn.addEventListener('click', async () => {
            if (state.recorder) { state.recorder.stop(); return; }
            if (busy) return;
            let stream;
            try {
                stream = await navigator.mediaDevices.getUserMedia({
                    audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false }
                });
            } catch (e) {
                setStatus('Micro inaccessible : ' + e.message);
                return;
            }
            stopPlayback();
            const chunks = [];
            const recorder = new MediaRecorder(stream);
            state.recorder = recorder;
            recorder.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
            // Niveau du micro pendant l'écoute
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            const analyser = ctx.createAnalyser();
            ctx.createMediaStreamSource(stream).connect(analyser);
            const buf = new Float32Array(analyser.fftSize);
            levelTimer = setInterval(() => {
                analyser.getFloatTimeDomainData(buf);
                const rms = Math.sqrt(buf.reduce((s, v) => s + v * v, 0) / buf.length);
                recLevel.style.width = Math.min(100, Math.max(0, (Math.log10(rms + 1e-4) + 4) / 4 * 100)) + '%';
            }, 100);
            const started = Date.now();
            recTime.textContent = '0:00';
            recTimer = setInterval(() => {
                const sec = Math.floor((Date.now() - started) / 1000);
                recTime.textContent = `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
            }, 250);
            fileBtn.disabled = true;
            btn.classList.add('tr-recording');
            const idleHtml = btn.innerHTML;
            btn.innerHTML = '<i class="fas fa-stop"></i> J\'ai fini : écrire la partition';
            recPanel.style.display = 'flex';
            setStatus('J\'écoute… Jouez le morceau puis appuyez sur « J\'ai fini ».');
            recorder.onstop = () => {
                clearInterval(recTimer); clearInterval(levelTimer);
                stream.getTracks().forEach(t => t.stop());
                ctx.close();
                recLevel.style.width = '0%';
                recPanel.style.display = 'none';
                state.recorder = null;
                btn.classList.remove('tr-recording');
                btn.innerHTML = idleHtml;
                const blob = new Blob(chunks, { type: recorder.mimeType || 'audio/webm' });
                setSource(blob, `Enregistrement de ${recTime.textContent}`);
                runTranscription();
            };
            recorder.start();
        });

        // ---------- Transcription ----------
        const runTranscription = async () => {
            if (!state.blob || busy) return;
            busy = true;
            listenBtn.disabled = fileBtn.disabled = true;
            results.style.display = 'none';
            stopPlayback();
            const t0 = Date.now();
            const onStep = (text) => { progress.textContent = text; };
            progress.style.display = 'block';
            const tick = setInterval(() => {
                const base = progress.textContent.replace(/ \(\d+ s\)$/, '');
                progress.textContent = `${base} (${Math.round((Date.now() - t0) / 1000)} s)`;
            }, 1000);
            try {
                const notes = await transcribePiano(state.blob, onStep);
                state.rawNotes = notes;
                window.TranscriptionEngine.lastNotes = notes; // pour le débogage depuis la console
                onStep('Écriture de la partition...');
                await renderScore();
                setStatus(`Partition écrite en ${Math.round((Date.now() - t0) / 1000)} s.`);
                results.scrollIntoView({ behavior: 'smooth', block: 'start' });
            } catch (e) {
                console.error(e);
                setStatus('La transcription a échoué : ' + e.message);
            } finally {
                clearInterval(tick);
                progress.style.display = 'none';
                busy = false;
                listenBtn.disabled = false;
                fileBtn.disabled = !state.blob;
            }
        };

        const currentOptions = () => ({
            bpm: tempoMode.value === 'manual' ? Number(bpmInput.value) || 100 : null,
            timeSignature: tsSel.value,
            grid: Number(gridSel.value),
            staves: stavesSel.value,
            split: Number(splitSel.value),
            title: titleInput.value.trim() || 'Transcription'
        });

        const renderScore = async () => {
            const notes = cleanNotes(state.rawNotes, Number(sensInput.value));
            results.style.display = 'block';
            if (!notes.length) {
                summary.innerHTML = '<strong>Aucune note trouvée.</strong> Vérifiez que le son est assez fort, rapprochez le téléphone ou montez la sensibilité.';
                scoreEl.innerHTML = '';
                drawRoll([]);
                return;
            }
            const opts = currentOptions();
            const key = detectKey(notes);
            opts.fifths = keySel.value === 'auto' ? key.fifths : Number(keySel.value);
            state.quant = quantize(notes, opts);
            state.xml = buildMusicXml(state.quant, opts);
            state.cleanNotes = notes;
            const duration = notes[notes.length - 1].end;
            const lowest = Math.min(...notes.map(n => n.pitch)), highest = Math.max(...notes.map(n => n.pitch));
            summary.innerHTML =
                `<span><strong>${notes.length}</strong> notes</span>` +
                `<span>Durée <strong>${Math.floor(duration / 60)}:${String(Math.round(duration % 60)).padStart(2, '0')}</strong></span>` +
                `<span>Tempo ${opts.bpm ? 'choisi' : 'détecté'} <strong>≈ ${state.quant.bpm}</strong></span>` +
                `<span>Tonalité ${keySel.value === 'auto' ? 'détectée' : 'choisie'} <strong>${keySel.value === 'auto' ? key.label : keySel.selectedOptions[0].text}</strong></span>` +
                `<span>Notes de <strong>${NOTE_NAMES_FR[lowest % 12]}${Math.floor(lowest / 12) - 1}</strong> à <strong>${NOTE_NAMES_FR[highest % 12]}${Math.floor(highest / 12) - 1}</strong></span>`;
            drawRoll(notes);
            await loadScript(LIBS.osmd);
            scoreEl.innerHTML = '';
            state.osmd = new window.opensheetmusicdisplay.OpenSheetMusicDisplay(scoreEl, {
                autoResize: true, drawTitle: true, drawComposer: true, autoBeam: true,
                drawPartNames: false, backend: 'svg'
            });
            await state.osmd.load(state.xml);
            state.osmd.render();
        };

        // ---------- Rouleau de piano (vue des notes trouvées) ----------
        const drawRoll = (notes, cursorTime = null) => {
            const dpr = window.devicePixelRatio || 1;
            const w = roll.clientWidth, h = roll.clientHeight;
            roll.width = w * dpr; roll.height = h * dpr;
            const g = roll.getContext('2d');
            g.scale(dpr, dpr);
            g.clearRect(0, 0, w, h);
            if (!notes.length) return;
            const lo = Math.min(...notes.map(n => n.pitch)) - 2, hi = Math.max(...notes.map(n => n.pitch)) + 2;
            const dur = notes[notes.length - 1].end;
            const rowH = h / (hi - lo + 1);
            const styles = getComputedStyle(document.documentElement);
            for (let p = lo; p <= hi; p++) {
                if ([1, 3, 6, 8, 10].includes(p % 12)) {
                    g.fillStyle = 'rgba(128,128,128,0.12)';
                    g.fillRect(0, h - (p - lo + 1) * rowH, w, rowH);
                }
            }
            g.fillStyle = styles.getPropertyValue('--accent-color').trim() || '#1abc9c';
            for (const n of notes) {
                const x = n.start / dur * w, x2 = n.end / dur * w;
                g.globalAlpha = 0.4 + 0.6 * Math.min(1, n.velocity);
                g.fillRect(x, h - (n.pitch - lo + 1) * rowH, Math.max(2, x2 - x), Math.max(2, rowH - 1));
            }
            g.globalAlpha = 1;
            if (cursorTime !== null) {
                g.fillStyle = styles.getPropertyValue('--primary-color').trim() || '#3498db';
                g.fillRect(cursorTime / dur * w, 0, 2, h);
            }
        };
        window.addEventListener('resize', () => { if (state.cleanNotes && results.style.display === 'block') drawRoll(state.cleanNotes); });

        // ---------- Écoute de la transcription (petit synthé) ----------
        const stopPlayback = () => {
            if (!state.playing) return;
            cancelAnimationFrame(state.playing.raf);
            state.playing.ctx.close();
            state.playing = null;
            playBtn.innerHTML = '<i class="fas fa-play"></i> Écouter la transcription';
            if (state.cleanNotes) drawRoll(state.cleanNotes);
        };
        playBtn.addEventListener('click', () => {
            if (state.playing) { stopPlayback(); return; }
            const notes = state.cleanNotes;
            if (!notes || !notes.length) return;
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            const master = ctx.createGain();
            master.gain.value = 0.25;
            master.connect(ctx.destination);
            const t0 = ctx.currentTime + 0.1;
            for (const n of notes) {
                const osc = ctx.createOscillator();
                const env = ctx.createGain();
                osc.type = 'triangle';
                osc.frequency.value = 440 * Math.pow(2, (n.pitch - 69) / 12);
                const start = t0 + n.start, end = t0 + Math.max(n.end, n.start + 0.15);
                env.gain.setValueAtTime(0, start);
                env.gain.linearRampToValueAtTime(0.3 + 0.5 * Math.min(1, n.velocity), start + 0.01);
                env.gain.exponentialRampToValueAtTime(0.05, end);
                env.gain.linearRampToValueAtTime(0, end + 0.08);
                osc.connect(env); env.connect(master);
                osc.start(start); osc.stop(end + 0.1);
            }
            const total = notes[notes.length - 1].end + 0.5;
            const frame = () => {
                const t = ctx.currentTime - t0;
                if (t > total) { stopPlayback(); return; }
                drawRoll(notes, Math.max(0, t));
                state.playing.raf = requestAnimationFrame(frame);
            };
            state.playing = { ctx, raf: requestAnimationFrame(frame) };
            playBtn.innerHTML = '<i class="fas fa-stop"></i> Arrêter';
        });

        // ---------- Exports ----------
        const safeName = () => (titleInput.value.trim() || 'transcription').replace(/[^a-z0-9àâçéèêëîïôûùüÿñæœ -]/gi, '_');
        const download = (blob, name) => {
            const a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = name;
            document.body.appendChild(a);
            a.click();
            a.remove();
            setTimeout(() => URL.revokeObjectURL(a.href), 5000);
        };

        $('tr-export-midi').addEventListener('click', () => {
            if (state.quant) download(buildMidi(state.quant), safeName() + '.mid');
        });
        $('tr-export-xml').addEventListener('click', () => {
            if (state.xml) download(new Blob([state.xml], { type: 'application/vnd.recordare.musicxml+xml' }), safeName() + '.musicxml');
        });

        // PDF : on refait la mise en page au format A4 dans un bloc caché,
        // puis chaque page SVG est convertie en page PDF.
        const buildPdf = async () => {
            await Promise.all([loadScript(LIBS.jspdf), loadScript(LIBS.svg2pdf)]);
            const holder = document.createElement('div');
            holder.style.cssText = 'position:absolute; left:-10000px; top:0; width:1000px; background:white;';
            document.body.appendChild(holder);
            try {
                const osmd = new window.opensheetmusicdisplay.OpenSheetMusicDisplay(holder, {
                    autoResize: false, drawTitle: true, drawComposer: true, autoBeam: true, backend: 'svg', pageFormat: 'A4_P'
                });
                osmd.setPageFormat('A4_P');
                await osmd.load(state.xml);
                osmd.render();
                const pages = holder.querySelectorAll('svg');
                const { jsPDF } = window.jspdf;
                const pdf = new jsPDF({ orientation: 'portrait', unit: 'pt', format: 'a4' });
                const W = pdf.internal.pageSize.getWidth(), H = pdf.internal.pageSize.getHeight();
                for (let i = 0; i < pages.length; i++) {
                    if (i > 0) pdf.addPage();
                    const svg = pages[i];
                    const w = parseFloat(svg.getAttribute('width')), h = parseFloat(svg.getAttribute('height'));
                    const scale = Math.min(W / w, H / h);
                    await pdf.svg(svg, { x: 0, y: 0, width: w * scale, height: h * scale });
                }
                return pdf.output('blob');
            } finally {
                holder.remove();
            }
        };

        $('tr-export-pdf').addEventListener('click', async () => {
            if (!state.xml) return;
            setStatus('Création du PDF...');
            try {
                download(await buildPdf(), safeName() + '.pdf');
                setStatus('PDF créé.');
            } catch (e) {
                console.error(e);
                setStatus('Création du PDF impossible : ' + e.message);
            }
        });

        // Ajout à la bibliothèque (comme un import de PDF dans app.js)
        let supabaseClient = null;
        $('tr-save').addEventListener('click', async () => {
            if (!state.xml) return;
            if (!supabaseClient) {
                supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
                    auth: { autoRefreshToken: false, persistSession: true, detectSessionInUrl: false }
                });
            }
            const { data: { session } } = await supabaseClient.auth.getSession();
            if (!session) { setStatus('Connectez-vous pour enregistrer dans la bibliothèque.'); return; }
            setStatus('Enregistrement dans la bibliothèque...');
            try {
                const pdf = await buildPdf();
                const fileName = `${Date.now()}_${safeName().replace(/[^a-z0-9.]/gi, '_')}.pdf`;
                const { error: upErr } = await supabaseClient.storage.from('pdfs').upload(fileName, pdf, { contentType: 'application/pdf' });
                if (upErr) throw upErr;
                const { data: urlData } = supabaseClient.storage.from('pdfs').getPublicUrl(fileName);
                const { error } = await supabaseClient.from('partitions').insert([{
                    titre: titleInput.value.trim() || 'Transcription', nom_artiste: 'Transcription',
                    url_pdf: urlData.publicUrl, url_cover: null, style: null, annee: null,
                    date_ajout: new Date(), user_id: session.user.id, is_flagged: false
                }]);
                if (error) throw error;
                setStatus('Partition ajoutée à la bibliothèque ✓');
            } catch (e) {
                console.error(e);
                setStatus('Enregistrement impossible : ' + e.message);
            }
        });

        // Le routeur d'app.js masque la vue : on coupe le son en partant
        new MutationObserver(() => {
            if (view.style.display !== 'block') {
                stopPlayback();
                if (state.recorder) state.recorder.stop();
            }
        }).observe(view, { attributes: true, attributeFilter: ['style'] });
    });
})();
