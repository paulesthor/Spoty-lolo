"""Lit les dernières mesures de chaque page des partitions (OMR Audiveris).

Pour chaque partition de Supabase pas encore analysée :
  1. télécharge le PDF et le découpe en une page par fichier ;
  2. lance Audiveris (lecture optique de partition) sur chaque page ;
  3. extrait les notes des dernières mesures de chaque page depuis le
     MusicXML produit ;
  4. écrit le résultat dans <data>/omr/<id>.json, lu ensuite par
     l'onglet Tourne-page de l'application.

Variables d'environnement :
  SUPABASE_URL, SUPABASE_KEY  accès en lecture à la table partitions
  AUDIVERIS                   chemin de l'exécutable Audiveris
  DATA_DIR                    dossier de sortie (checkout de la branche omr-data)
  LIMIT                       nombre max de partitions par exécution
  ONLY_IDS                    liste d'ids à (re)traiter, séparés par des virgules
  TIME_BUDGET_MIN             temps max avant de s'arrêter proprement
"""

import glob
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timezone

from pypdf import PdfReader, PdfWriter

FORMAT_VERSION = 1
LAST_MEASURES = 6  # mesures conservées en fin de page (le navigateur choisit lesquelles utiliser)
STEP_SEMITONES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

SUPABASE_URL = os.environ['SUPABASE_URL'].rstrip('/')
SUPABASE_KEY = os.environ['SUPABASE_KEY']
AUDIVERIS = os.environ.get('AUDIVERIS', 'audiveris')
DATA_DIR = os.environ.get('DATA_DIR', 'data')
LIMIT = int(os.environ.get('LIMIT') or 20)
ONLY_IDS = [s.strip() for s in (os.environ.get('ONLY_IDS') or '').split(',') if s.strip()]
TIME_BUDGET = float(os.environ.get('TIME_BUDGET_MIN') or 300) * 60

OMR_DIR = os.path.join(DATA_DIR, 'omr')
INDEX_PATH = os.path.join(OMR_DIR, 'index.json')


def log(*args):
    print(*args, flush=True)


def fetch_partitions():
    """Toutes les partitions ayant un PDF (pagination par blocs de 1000)."""
    rows, offset = [], 0
    while True:
        url = f"{SUPABASE_URL}/rest/v1/partitions?select=id,titre,url_pdf&url_pdf=not.is.null&order=id.asc"
        req = urllib.request.Request(url, headers={
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Range': f'{offset}-{offset + 999}',
        })
        with urllib.request.urlopen(req, timeout=60) as r:
            batch = json.load(r)
        rows += batch
        if len(batch) < 1000:
            return rows
        offset += 1000


def download(url, path):
    parts = urllib.parse.urlsplit(url)
    safe = urllib.parse.urlunsplit(parts._replace(path=urllib.parse.quote(urllib.parse.unquote(parts.path))))
    with urllib.request.urlopen(safe, timeout=120) as r, open(path, 'wb') as f:
        f.write(r.read())


def split_pages(pdf_path, out_dir):
    reader = PdfReader(pdf_path)
    paths = []
    for i, page in enumerate(reader.pages, start=1):
        writer = PdfWriter()
        writer.add_page(page)
        p = os.path.join(out_dir, f'p{i:03d}.pdf')
        with open(p, 'wb') as f:
            writer.write(f)
        paths.append(p)
    return paths


def run_audiveris(page_paths, out_dir):
    timeout = 300 + 240 * len(page_paths)
    cmd = [AUDIVERIS, '-batch', '-export', '-output', out_dir, '--'] + page_paths
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if res.returncode != 0:
        log(res.stdout[-2000:], res.stderr[-2000:])


def read_mxl(path):
    with zipfile.ZipFile(path) as z:
        root_file = None
        if 'META-INF/container.xml' in z.namelist():
            container = ET.fromstring(z.read('META-INF/container.xml'))
            for el in container.iter():
                if el.tag.endswith('rootfile'):
                    root_file = el.get('full-path')
                    break
        if not root_file:
            root_file = next(n for n in z.namelist() if n.endswith('.xml') and not n.startswith('META-INF'))
        return ET.fromstring(z.read(root_file))


def midi_of(pitch):
    step = pitch.findtext('step')
    octave = int(pitch.findtext('octave'))
    alter = float(pitch.findtext('alter') or 0)
    return int(round(12 * (octave + 1) + STEP_SEMITONES[step] + alter))


def part_measures(part):
    """Liste par mesure : (durée en noires, [(début, durée, midi), ...]) en noires."""
    measures = []
    divisions = 1
    for measure in part.findall('measure'):
        pos = 0.0
        last_onset = 0.0
        length = 0.0
        events = []
        for el in measure:
            if el.tag == 'attributes':
                d = el.findtext('divisions')
                if d:
                    divisions = float(d)
            elif el.tag == 'backup':
                pos -= float(el.findtext('duration') or 0) / divisions
            elif el.tag == 'forward':
                pos += float(el.findtext('duration') or 0) / divisions
                length = max(length, pos)
            elif el.tag == 'note':
                if el.find('grace') is not None or el.find('cue') is not None:
                    continue
                dur = float(el.findtext('duration') or 0) / divisions
                is_chord = el.find('chord') is not None
                onset = last_onset if is_chord else pos
                pitch = el.find('pitch')
                if pitch is not None and el.find('rest') is None:
                    events.append((round(onset, 4), round(dur, 4), midi_of(pitch)))
                if not is_chord:
                    last_onset = pos
                    pos += dur
                length = max(length, pos, onset + dur)
        measures.append((length, events))
    return measures


def page_end(mxl_path):
    """Dernières mesures d'une page, toutes portées/parties fusionnées."""
    score = read_mxl(mxl_path)
    parts = [part_measures(p) for p in score.findall('part')]
    parts = [p for p in parts if p]
    if not parts:
        return None
    count = max(len(p) for p in parts)
    start = max(0, count - LAST_MEASURES)
    result = []
    for i in range(start, count):
        length = max((p[i][0] for p in parts if i < len(p)), default=0)
        events = sorted(e for p in parts if i < len(p) for e in p[i][1])
        result.append({'duree': round(length, 4), 'notes': [list(e) for e in events]})
    total_notes = sum(len(m['notes']) for m in result)
    return {'mesures': result, 'nbMesuresPage': count} if total_notes else None


def find_mxl(out_dir, stem):
    found = sorted(glob.glob(os.path.join(out_dir, '**', f'{stem}*.mxl'), recursive=True))
    # Plusieurs mouvements sur une même page : le dernier contient la fin de page
    return found[-1] if found else None


def analyze(partition):
    with tempfile.TemporaryDirectory() as tmp:
        pdf = os.path.join(tmp, 'source.pdf')
        download(partition['url_pdf'], pdf)
        pages_dir = os.path.join(tmp, 'pages')
        out_dir = os.path.join(tmp, 'out')
        os.makedirs(pages_dir)
        os.makedirs(out_dir)
        page_paths = split_pages(pdf, pages_dir)
        run_audiveris(page_paths, out_dir)
        fins, erreurs = {}, {}
        for i in range(1, len(page_paths) + 1):
            mxl = find_mxl(out_dir, f'p{i:03d}')
            if not mxl:
                erreurs[str(i)] = 'aucune musique reconnue'
                continue
            try:
                end = page_end(mxl)
            except Exception as e:  # MusicXML inattendu : on note et on continue
                end = None
                erreurs[str(i)] = f'lecture MusicXML impossible : {e}'
            if end:
                fins[str(i)] = end
            elif str(i) not in erreurs:
                erreurs[str(i)] = 'aucune note en fin de page'
        return {
            'version': FORMAT_VERSION,
            'id': partition['id'],
            'titre': partition['titre'],
            'pages': len(page_paths),
            'analyseLe': datetime.now(timezone.utc).isoformat(timespec='seconds'),
            'fins': fins,
            'erreurs': erreurs,
        }


def main():
    started = time.time()
    os.makedirs(OMR_DIR, exist_ok=True)
    index = {}
    if os.path.exists(INDEX_PATH):
        with open(INDEX_PATH) as f:
            index = json.load(f)

    partitions = fetch_partitions()
    if ONLY_IDS:
        todo = [p for p in partitions if str(p['id']) in ONLY_IDS]
    else:
        todo = [p for p in partitions if str(p['id']) not in index]
    log(f'{len(partitions)} partitions, {len(todo)} à analyser, limite {LIMIT}')

    for n, p in enumerate(todo[:LIMIT], start=1):
        if time.time() - started > TIME_BUDGET:
            log('Budget de temps atteint, la suite sera traitée au prochain passage.')
            break
        t0 = time.time()
        try:
            result = analyze(p)
            with open(os.path.join(OMR_DIR, f"{p['id']}.json"), 'w') as f:
                json.dump(result, f, ensure_ascii=False, separators=(',', ':'))
            index[str(p['id'])] = {'statut': 'ok', 'pages': result['pages'],
                                   'pagesLues': len(result['fins']), 'date': result['analyseLe']}
            log(f"[{n}] {p['id']} {p['titre']} : {len(result['fins'])}/{result['pages']} pages lues "
                f"({time.time() - t0:.0f} s) {result['erreurs'] or ''}")
        except Exception as e:
            index[str(p['id'])] = {'statut': 'echec', 'erreur': str(e)[:300],
                                   'date': datetime.now(timezone.utc).isoformat(timespec='seconds')}
            log(f"[{n}] {p['id']} {p['titre']} : ÉCHEC {e}")
        with open(INDEX_PATH, 'w') as f:
            json.dump(index, f, ensure_ascii=False, indent=0, sort_keys=True)


if __name__ == '__main__':
    sys.exit(main())
