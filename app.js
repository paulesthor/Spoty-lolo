document.addEventListener('DOMContentLoaded', async () => {

    // =======================================================
    // |               CONFIGURATION SUPABASE                |
    // =======================================================

    const SUPABASE_URL = 'https://ikkhvkgcxvlpqejvvuot.supabase.co';
    const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlra2h2a2djeHZscHFlanZ2dW90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MDI1NDMsImV4cCI6MjA4MDM3ODU0M30.I606WGNVllQ5VI_mB1TmheediORTyNvXqpdkKSFa73o';

    const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

    // =======================================================
    // |             ÉLÉMENTS DU DOM & VARIABLES             |
    // =======================================================
    
    // Auth & Layout
    const appHeader = document.getElementById('app-header');
    const authView = document.getElementById('auth-view');
    const appContainer = document.getElementById('app-container');
    const logoutBtn = document.getElementById('logout-btn');
    const googleLoginBtn = document.getElementById('google-login-btn');
    const authMessage = document.getElementById('auth-message');

    // UI Globale
    const loadingOverlay = document.getElementById('loading-overlay');
    const loadingText = document.getElementById('loading-text');
    const modal = document.getElementById('generic-modal');
    const modalBody = document.getElementById('modal-body');
    const modalCloseBtn = modal.querySelector('.modal-close');
    
    // Navigation
    const navLinks = document.querySelectorAll('.nav-link');
    const appViews = document.querySelectorAll('.app-view');
    
    // Vue Bibliothèque
    const searchInput = document.getElementById('search-input');
    const sortSelect = document.getElementById('sort-select');
    const btnListView = document.getElementById('btn-view-list');
    const btnGridView = document.getElementById('btn-view-grid');
    const musicTableBody = document.getElementById('music-table-body');
    const gridViewContainer = document.getElementById('grid-view-container');
    const listViewContainer = document.getElementById('list-view-container');
    const detailsPanel = document.getElementById('details-view-panel');

    // Import Multiple
    const btnMassImport = document.getElementById('btn-mass-import');
    const hiddenFileInput = document.getElementById('hidden-file-input');

    // Vue Ajout Simple
    const addForm = document.getElementById('add-partition-form');
    const searchCoverBtn = document.getElementById('search-cover-btn');
    const coverPreview = document.getElementById('cover-preview');
    const urlCoverInput = document.getElementById('url_cover');

    // Playlists & Stats
    const createPlaylistForm = document.getElementById('create-playlist-form');
    const playlistsListUl = document.getElementById('playlists-list-ul');
    const playlistContentContainer = document.getElementById('playlist-content-container');
    const playlistDetailsPanel = document.getElementById('playlist-details-panel');
    const statsTotalPartitions = document.getElementById('stats-total-partitions');
    const statsTotalArtistes = document.getElementById('stats-total-artistes');
    const statsTotalPlaylists = document.getElementById('stats-total-playlists');
    let topArtistsChart = null;

    let allPartitions = [];
    let currentSort = 'titre_asc';
    let currentViewMode = 'grid'; 
    let currentPlaylistViewMode = 'grid'; // NOUVEAU : État de la vue playlist
    let currentUser = null; 

    // =======================================================
    // |                 FONCTIONS UTILITAIRES               |
    // =======================================================

    const showLoading = (text = 'Chargement...') => {
        loadingText.textContent = text;
        loadingOverlay.style.display = 'flex';
    };
    const hideLoading = () => loadingOverlay.style.display = 'none';

    const guessArtistTitle = (filename) => {
        let cleaned = filename.replace(/\.pdf$/i, '').trim();
        const underscoreMatch = cleaned.match(/^(.+)_(.+)_\d+$/);
        if (underscoreMatch) return [underscoreMatch[1].replace(/_/g, ' ').trim(), underscoreMatch[2].replace(/_/g, ' ').trim()];
        if (cleaned.includes('_') && !cleaned.includes(' - ')) {
            const parts = cleaned.split('_');
            if (parts.length >= 2) return [parts[0].trim(), parts[1].trim()];
        }
        cleaned = cleaned.replace(/^\d+[\.\s-]+\s*/, '').replace(/\s*(\(|\[)(official|video|lyrics|hq|hd|remastered|live|audio)(\)|\])/gi, '');
        if (cleaned.includes(' - ') || cleaned.includes(' – ')) {
            const parts = cleaned.split(/ [–-] /);
            return [parts[0].trim(), parts[1].trim()];
        }
        return ['', cleaned.replace(/_/g, ' ').trim()];
    };

    const performDeezerSearch = (query, callback) => {
        const callbackName = 'deezerCallback_' + Date.now() + Math.floor(Math.random() * 1000);
        window[callbackName] = (data) => {
            if (data.data && data.data.length > 0) {
                const item = data.data[0];
                callback({
                    cover: item.album.cover_xl,
                    title: item.title,
                    artist: item.artist.name,
                    album: item.album.title
                });
            } else {
                callback(null);
            }
            delete window[callbackName];
            if(document.body.contains(script)) document.body.removeChild(script);
        };
        const script = document.createElement('script');
        script.src = `https://api.deezer.com/search?q=${encodeURIComponent(query)}&limit=1&output=jsonp&callback=${callbackName}`;
        document.body.appendChild(script);
    };

    // =======================================================
    // |             GESTION AUTHENTIFICATION (GOOGLE)       |
    // =======================================================

    const checkSession = async () => {
        const { data: { session } } = await supabase.auth.getSession();
        handleSession(session);
    };

    const handleSession = (session) => {
        if (session) {
            currentUser = session.user;
            authView.style.display = 'none';
            appHeader.style.display = 'flex'; 
            appContainer.style.display = 'block';
            
            const hash = window.location.hash.substring(1) || 'library';
            showView(hash + '-view');
            
            fetchLibrary(); 
        } else {
            currentUser = null;
            appHeader.style.display = 'none';
            appContainer.style.display = 'none';
            document.querySelectorAll('.app-view').forEach(v => v.style.display = 'none');
            authView.style.display = 'block';
        }
    };

    googleLoginBtn.addEventListener('click', async () => {
        authMessage.textContent = 'Redirection vers Google...';
        
        // MODIFICATION POUR GITHUB PAGES :
        // On définit explicitement l'URL de retour sur l'adresse actuelle du site
        const redirectUrl = window.location.origin + window.location.pathname;

        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: redirectUrl
            }
        });
        if (error) authMessage.textContent = "Erreur : " + error.message;
    });

    logoutBtn.addEventListener('click', async (e) => {
        e.preventDefault();
        await supabase.auth.signOut();
        window.location.reload(); 
    });

    supabase.auth.onAuthStateChange((event, session) => {
        handleSession(session);
    });

    // =======================================================
    // |             LOGIQUE SUPABASE & DONNÉES              |
    // =======================================================

    const fetchLibrary = async () => {
        if (!currentUser) return;
        const { data, error } = await supabase.from('partitions').select('*').eq('user_id', currentUser.id);
        if (error) {
            console.error(error);
        } else {
            allPartitions = data;
            sortAndDisplayPartitions();
            if(document.getElementById('stats-view').style.display === 'block') renderStatsView();
        }
    };

    supabase.channel('custom-all-channel')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'partitions' }, () => {
        fetchLibrary();
    })
    .subscribe();

    // =======================================================
    // |               AFFICHAGE BIBLIOTHEQUE                |
    // =======================================================

    const sortAndDisplayPartitions = () => {
        let sorted = [...allPartitions];
        
        let column = 'titre';
        let order = 'asc';

        if (currentSort === 'artiste_asc') {
            column = 'nom_artiste'; 
            order = 'asc';
        } else if (currentSort === 'annee_desc') {
            column = 'annee';
            order = 'desc';
        } else if (currentSort === 'date_ajout_desc') {
            column = 'date_ajout';
            order = 'desc';
        } else {
            column = 'titre';
            order = 'asc';
        }

        sorted.sort((a, b) => {
            let valA = a[column];
            let valB = b[column];

            if (valA == null) valA = '';
            if (valB == null) valB = '';

            if (column === 'annee') {
                valA = Number(valA) || 0;
                valB = Number(valB) || 0;
            }
            else if (column === 'date_ajout') {
                valA = new Date(valA).getTime() || 0;
                valB = new Date(valB).getTime() || 0;
            }
            else {
                valA = valA.toString().toLowerCase();
                valB = valB.toString().toLowerCase();
            }

            if (valA < valB) return order === 'asc' ? -1 : 1;
            if (valA > valB) return order === 'asc' ? 1 : -1;
            return 0;
        });

        const searchTerm = searchInput.value.toLowerCase();
        const filtered = sorted.filter(p =>
            (p.titre && p.titre.toLowerCase().includes(searchTerm)) ||
            (p.nom_artiste && p.nom_artiste.toLowerCase().includes(searchTerm))
        );

        displayPartitions(filtered);
    };

    const displayPartitions = (partitions) => {
        musicTableBody.innerHTML = '';
        gridViewContainer.innerHTML = '';
        
        if (partitions.length === 0) {
            detailsPanel.innerHTML = `<h3>Vide...</h3><p>Aucune partition trouvée.</p>`;
            return;
        }

        partitions.forEach(p => {
            const tr = document.createElement('tr');
            tr.className = 'music-item';
            tr.dataset.id = p.id;
            tr.innerHTML = `<td>${p.titre}</td><td>${p.nom_artiste}</td><td>${p.style || ''}</td><td>${p.annee || ''}</td>`;
            
            const div = document.createElement('div');
            div.className = 'grid-item music-item';
            div.dataset.id = p.id;
            div.innerHTML = `
                <img src="${p.url_cover || 'https://placehold.co/150/2a3f54/FFF?text=...'}" alt="Pochette">
                <div class="title">${p.titre}</div>
                <div class="artist">${p.nom_artiste}</div>
            `;
            
            const handleSelect = () => {
                document.querySelectorAll('.music-item.selected').forEach(sel => sel.classList.remove('selected'));
                document.querySelectorAll(`.music-item[data-id="${p.id}"]`).forEach(i => i.classList.add('selected'));
                renderDetailsPanel(p.id);
            };
            const handleOpen = () => { if(p.url_pdf) window.open(p.url_pdf, '_blank'); };

            tr.addEventListener('click', handleSelect);
            tr.addEventListener('dblclick', handleOpen);
            musicTableBody.appendChild(tr);

            div.addEventListener('click', handleSelect);
            div.addEventListener('dblclick', handleOpen);
            gridViewContainer.appendChild(div);
        });
        
        if (!document.querySelector('.music-item.selected') && partitions.length > 0) {
             renderDetailsPanel(partitions[0].id);
             document.querySelectorAll(`.music-item[data-id="${partitions[0].id}"]`).forEach(i => i.classList.add('selected'));
        }
    };

    const renderDetailsPanel = (id) => {
        const p = allPartitions.find(x => x.id == id);
        if (!p) return;

        detailsPanel.innerHTML = `
            <div class="cover-art"><img src="${p.url_cover || 'https://placehold.co/600/2a3f54/FFF?text=Pochette'}" alt="Jaquette"></div>
            <div class="info">
                <h2>${p.titre}</h2>
                <div class="artist">${p.nom_artiste}</div>
                <div class="meta"><span>Style: ${p.style || '-'}</span><br><span>Année: ${p.annee || '-'}</span></div>
            </div>
            <div class="actions">
                <a href="${p.url_pdf}" target="_blank" class="btn btn-accent" style="text-align:center; display:block;"><i class="fas fa-file-pdf"></i> Ouvrir le PDF</a>
                <button class="btn" id="edit-btn"><i class="fas fa-edit"></i> Modifier</button>
                <button class="btn" id="add-pl-btn"><i class="fas fa-plus"></i> Playlist</button>
                <button class="btn btn-danger" id="del-btn"><i class="fas fa-trash"></i> Supprimer</button>
            </div>
        `;

        document.getElementById('del-btn').addEventListener('click', () => deletePartition(p.id, p.url_pdf));
        document.getElementById('edit-btn').addEventListener('click', () => openEditModal(p));
        document.getElementById('add-pl-btn').addEventListener('click', () => openPlaylistModal(p.id));
    };

    // =======================================================
    // |                  IMPORT MULTIPLE                    |
    // =======================================================

    btnMassImport.addEventListener('click', () => hiddenFileInput.click());

    hiddenFileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) handleMassImport(e.target.files);
        e.target.value = ''; 
    });

    const handleMassImport = (files) => {
        const pdfFiles = Array.from(files).filter(f => f.type === 'application/pdf');
        if (pdfFiles.length === 0) { alert("Aucun PDF trouvé."); return; }
        
        showLoading('Analyse des fichiers...');
        let filesData = [];
        
        pdfFiles.forEach((file, index) => {
            let [artiste, titre] = guessArtistTitle(file.name);
            filesData.push({ 
                originalFile: file, 
                titre: titre, 
                nom_artiste: artiste, 
                url_cover: null, 
                tempId: index 
            });
        });
        
        hideLoading();
        showImportInterface(filesData);
    };

    const showImportInterface = (filesData) => {
        const listHTML = filesData.map((file, index) => `
            <div class="import-card" id="row-${index}">
                <div class="import-card-cover">
                    <img id="preview-${index}" src="https://placehold.co/150/2a3f54/FFF?text=..." alt="Cover">
                    <button type="button" class="search-trigger" id="btn-search-${index}" data-index="${index}"><i class="fas fa-search"></i></button>
                    <input type="hidden" id="cover-${index}" value="">
                </div>
                <div class="import-card-details">
                    <div style="position:relative; padding-right: 50px;"> 
                        <div class="import-field-group">
                            <label>Titre</label>
                            <input type="text" id="titre-${index}" value="${file.titre}" style="width:100%;">
                        </div>
                        <div style="height: 15px;"></div>
                        <div class="import-field-group">
                            <label>Artiste</label>
                            <input type="text" id="artiste-${index}" value="${file.nom_artiste}" style="width:100%;">
                        </div>
                        <button type="button" class="swap-btn swap-btn-custom" data-index="${index}" title="Inverser Titre et Artiste">
                            <i class="fas fa-exchange-alt fa-rotate-90"></i>
                        </button>
                    </div>
                    <div>
                        <div class="import-field-group" style="margin-bottom:10px;">
                            <label>Style</label>
                            <input type="text" id="style-${index}" style="width:100%;">
                        </div>
                        <div class="import-field-group">
                            <label>Année</label>
                            <input type="number" id="annee-${index}" style="width:100%;">
                        </div>
                    </div>
                </div>
                <button type="button" class="import-remove-btn remove-import-row" data-index="${index}"><i class="fas fa-times-circle"></i></button>
            </div>
        `).join('');

        document.querySelector('.modal-content').classList.add('large-modal');
        
        modalBody.innerHTML = `
            <form id="global-import-form">
                <div class="import-header-panel">
                    <h2><i class="fas fa-cloud-upload-alt"></i> Importation de masse</h2>
                    <span style="color:var(--text-muted); font-size:0.9rem;">${filesData.length} fichiers détectés</span>
                </div>
                <div class="import-scroll-area">
                    ${listHTML}
                </div>
                <div class="import-footer-panel">
                    <button type="button" class="btn" id="cancel-import" style="background:transparent; border:1px solid var(--highlight-color);">Annuler</button>
                    <button type="submit" class="btn btn-accent" style="padding: 12px 30px; font-weight:bold;"><i class="fas fa-check"></i> CONFIRMER</button>
                </div>
            </form>
        `;
        
        modal.style.display = 'flex';

        document.getElementById('cancel-import').addEventListener('click', () => {
            modal.style.display = 'none';
            document.querySelector('.modal-content').classList.remove('large-modal');
        });

        modalBody.querySelectorAll('.remove-import-row').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const row = document.getElementById(`row-${e.currentTarget.dataset.index}`);
                row.classList.add('removed'); row.dataset.removed = "true";
            });
        });

        modalBody.querySelectorAll('.swap-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const idx = e.currentTarget.dataset.index;
                const t = document.getElementById(`titre-${idx}`);
                const a = document.getElementById(`artiste-${idx}`);
                const temp = t.value; t.value = a.value; a.value = temp;
            });
        });

        modalBody.querySelectorAll('.search-trigger').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const idx = e.currentTarget.dataset.index;
                const titre = document.getElementById(`titre-${idx}`).value;
                const artiste = document.getElementById(`artiste-${idx}`).value;
                const query = prompt("Recherche Deezer :", `${artiste} ${titre}`);
                if(query) {
                   btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
                   performDeezerSearch(query, (res) => {
                       if(res) {
                           document.getElementById(`preview-${idx}`).src = res.cover;
                           document.getElementById(`cover-${idx}`).value = res.cover;
                           document.getElementById(`titre-${idx}`).value = res.title;
                           document.getElementById(`artiste-${idx}`).value = res.artist;
                       }
                       btn.innerHTML = '<i class="fas fa-search"></i>';
                   });
                }
            });
        });

        document.getElementById('global-import-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const rows = Array.from(document.querySelectorAll('.import-card')).filter(row => row.dataset.removed !== "true");
            if(rows.length === 0) {
                modal.style.display = 'none'; document.querySelector('.modal-content').classList.remove('large-modal'); return;
            }

            showLoading(`Traitement de ${rows.length} partitions...`);

            for (const row of rows) {
                const index = row.id.split('-')[1]; 
                const item = filesData[index];
                const fTitre = document.getElementById(`titre-${index}`).value;
                const fArtiste = document.getElementById(`artiste-${index}`).value;
                const fStyle = document.getElementById(`style-${index}`).value;
                const fAnnee = document.getElementById(`annee-${index}`).value;
                const fCover = document.getElementById(`cover-${index}`).value;

                loadingText.textContent = `Envoi : ${fTitre}`;

                try {
                    const fileName = `${Date.now()}_${item.originalFile.name.replace(/[^a-z0-9.]/gi, '_')}`;
                    const { error: upErr } = await supabase.storage.from('pdfs').upload(fileName, item.originalFile);
                    if (upErr) { console.error("Erreur upload", upErr); continue; }
                    
                    const { data: urlData } = supabase.storage.from('pdfs').getPublicUrl(fileName);

                    await supabase.from('partitions').insert([{
                        titre: fTitre, nom_artiste: fArtiste, url_pdf: urlData.publicUrl,
                        url_cover: fCover || null, style: fStyle || null, annee: fAnnee || null,
                        date_ajout: new Date(),
                        user_id: currentUser.id
                    }]);
                } catch (err) { console.error("Erreur globale", err); }
            }
            hideLoading();
            modal.style.display = 'none';
            document.querySelector('.modal-content').classList.remove('large-modal');
            fetchLibrary();
        });

        filesData.forEach((file, index) => {
            const btnSearch = document.getElementById(`btn-search-${index}`);
            setTimeout(() => {
                if(btnSearch) btnSearch.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
                const query = file.nom_artiste && file.titre ? `${file.nom_artiste} ${file.titre}` : file.titre || file.originalFile.name.replace('.pdf','');
                
                performDeezerSearch(query, (res) => {
                    const img = document.getElementById(`preview-${index}`);
                    const inputCover = document.getElementById(`cover-${index}`);
                    const inputTitre = document.getElementById(`titre-${index}`);
                    const inputArtiste = document.getElementById(`artiste-${index}`);

                    if(res && img && inputCover) {
                        img.src = res.cover; inputCover.value = res.cover;
                        if(inputTitre && !inputTitre.value) inputTitre.value = res.title; 
                        if(inputArtiste && !inputArtiste.value) inputArtiste.value = res.artist;
                        if(btnSearch) btnSearch.innerHTML = '<i class="fas fa-check" style="color:#2ecc71"></i>';
                    } else {
                        if(btnSearch) btnSearch.innerHTML = '<i class="fas fa-question" style="color:orange"></i>';
                    }
                });
            }, index * 600);
        });
    };

    // =======================================================
    // |              AJOUT SIMPLE (UNITAIRE)                |
    // =======================================================

    addForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const pdfFile = e.target.pdf.files[0];
        if (!pdfFile) return;

        showLoading('Upload en cours...');
        const fileName = `${Date.now()}_${pdfFile.name.replace(/[^a-z0-9.]/gi, '_')}`;
        const { error: storageError } = await supabase.storage.from('pdfs').upload(fileName, pdfFile);

        if (storageError) { hideLoading(); alert(storageError.message); return; }

        const { data: urlData } = supabase.storage.from('pdfs').getPublicUrl(fileName);

        const { error: dbError } = await supabase.from('partitions').insert([{
            titre: e.target.titre.value,
            nom_artiste: e.target.artiste.value,
            style: e.target.style.value,
            annee: e.target.annee.value || null,
            url_cover: e.target.url_cover.value,
            url_pdf: urlData.publicUrl,
            date_ajout: new Date(),
            user_id: currentUser.id
        }]);

        hideLoading();
        if (dbError) alert(dbError.message);
        else {
            addForm.reset();
            coverPreview.src = 'https://via.placeholder.com/100x100.png?text=?';
            window.location.hash = 'library';
            fetchLibrary();
        }
    });

    searchCoverBtn.addEventListener('click', () => {
        const titre = document.getElementById('add-titre').value;
        const artiste = document.getElementById('add-artiste').value;
        if (!titre || !artiste) { alert('Remplissez titre et artiste.'); return; }
        performDeezerSearch(`${artiste} ${titre}`, (res) => {
            if(res) {
                coverPreview.src = res.cover; urlCoverInput.value = res.cover; 
            }
        });
    });

    // =======================================================
    // |             GESTION PLAYLISTS                       |
    // =======================================================

    const deletePartition = async (id, urlPdf) => {
        if (!confirm("Supprimer définitivement ?")) return;
        showLoading('Suppression...');

        if (urlPdf && urlPdf.includes('/pdfs/')) {
            const path = urlPdf.split('/pdfs/')[1];
            if (path) await supabase.storage.from('pdfs').remove([decodeURIComponent(path)]);
        }

        const { error } = await supabase.from('partitions').delete().eq('id', id);
        hideLoading();
        if (error) alert(error.message);
    };

    const openEditModal = (p) => {
        modalBody.innerHTML = `
            <h3>Modifier</h3>
            <form id="edit-form">
                <div class="form-group"><label>Titre</label><input type="text" name="titre" value="${p.titre}" required></div>
                <div class="form-group"><label>Artiste</label><input type="text" name="nom_artiste" value="${p.nom_artiste}" required></div>
                <div class="form-group"><label>Style</label><input type="text" name="style" value="${p.style || ''}"></div>
                <div class="form-group"><label>Année</label><input type="number" name="annee" value="${p.annee || ''}"></div>
                <button type="submit" class="btn btn-accent" style="width:100%">Sauvegarder</button>
            </form>
        `;
        modal.style.display = 'flex';
        document.getElementById('edit-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            showLoading('Mise à jour...');
            const { error } = await supabase.from('partitions').update({
                titre: formData.get('titre'),
                nom_artiste: formData.get('nom_artiste'),
                style: formData.get('style'),
                annee: formData.get('annee')
            }).eq('id', p.id);
            hideLoading();
            modal.style.display = 'none';
            if (error) alert(error.message);
        });
    };

    const fetchPlaylists = async () => {
        const { data } = await supabase.from('playlists').select('*').eq('user_id', currentUser.id);
        if (data) {
            playlistsListUl.innerHTML = data.map(p => `<li data-id="${p.id}" class="playlist-item">${p.nom_playlist}</li>`).join('');
            
            // MODIFICATION: Logique pour mémoriser la playlist active
            const savedPlaylistId = localStorage.getItem('lastPlaylistId');
            
            playlistsListUl.querySelectorAll('li').forEach(li => li.addEventListener('click', () => {
                playlistsListUl.querySelectorAll('.active').forEach(i => i.classList.remove('active'));
                li.classList.add('active');
                localStorage.setItem('lastPlaylistId', li.dataset.id); // Sauvegarde
                loadPlaylistContent(li.dataset.id, data);
            }));

            // Sélection par défaut : Soit celle sauvegardée, soit la première
            if(data.length > 0) {
                let activeLi = null;
                if (savedPlaylistId) {
                    activeLi = playlistsListUl.querySelector(`li[data-id="${savedPlaylistId}"]`);
                }
                
                if (!activeLi) {
                    activeLi = playlistsListUl.querySelector('li'); // Repli sur le premier
                }
                
                if (activeLi) {
                    activeLi.classList.add('active');
                    localStorage.setItem('lastPlaylistId', activeLi.dataset.id);
                    loadPlaylistContent(activeLi.dataset.id, data);
                }
            }
        }
    };

    const loadPlaylistContent = async (pid, allData) => {
        const pl = allData.find(x => x.id == pid);
        const ids = pl.partitions || [];
        
        // MODIFICATION: Préparation des vues (Grille et Liste)
        let gridHtml = '';
        let listHtml = '';
        
        if(ids.length > 0) {
            const { data: parts } = await supabase.from('partitions').select('*').in('id', ids);
            if(parts && parts.length > 0) {
                
                // Construction Vue Grille
                gridHtml = `<div id="pl-grid-view" class="playlist-grid-container" style="display:${currentPlaylistViewMode === 'grid' ? 'grid' : 'none'};">` + parts.map(p => `
                    <div class="grid-item music-item playlist-item-grid" data-id="${p.id}">
                        <img src="${p.url_cover || 'https://placehold.co/150/2a3f54/FFF?text=...'}" alt="Pochette">
                        <div class="title">${p.titre}</div>
                        <div class="artist">${p.nom_artiste}</div>
                    </div>
                `).join('') + `</div>`;

                // Construction Vue Liste (Tableau)
                listHtml = `
                    <div id="pl-list-view" class="music-list" style="display:${currentPlaylistViewMode === 'list' ? 'block' : 'none'}; margin-top:20px;">
                        <table>
                            <thead><tr><th>Titre</th><th>Artiste</th><th>Style</th><th>Année</th></tr></thead>
                            <tbody>
                                ${parts.map(p => `
                                    <tr class="music-item playlist-item-list" data-id="${p.id}">
                                        <td>${p.titre}</td><td>${p.nom_artiste}</td><td>${p.style || ''}</td><td>${p.annee || ''}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                `;
            } else {
                gridHtml = '<p style="padding:20px;">Cette playlist est vide.</p>';
            }
        } else {
            gridHtml = '<p style="padding:20px;">Cette playlist est vide.</p>';
        }

        playlistContentContainer.innerHTML = `
            <div class="playlist-actions-header">
                <h2>${pl.nom_playlist}</h2>
                <div style="display:flex; align-items:center; gap:10px;">
                    <div class="view-switcher" style="margin-right:15px;">
                        <button id="pl-btn-view-list" class="btn-icon ${currentPlaylistViewMode === 'list' ? 'active' : ''}" title="Liste"><i class="fas fa-list"></i></button>
                        <button id="pl-btn-view-grid" class="btn-icon ${currentPlaylistViewMode === 'grid' ? 'active' : ''}" title="Grille"><i class="fas fa-th-large"></i></button>
                    </div>
                    <div class="actions">
                        <button class="btn btn-accent" id="add-music-to-playlist-btn"><i class="fas fa-plus"></i> Ajouter des titres</button>
                        <button class="btn btn-danger" id="delete-playlist-btn"><i class="fas fa-trash"></i> Supprimer la Playlist</button>
                    </div>
                </div>
            </div>
            ${gridHtml}
            ${listHtml}
        `;

        // MODIFICATION: Listeners pour Switcher Vue
        document.getElementById('pl-btn-view-list').addEventListener('click', () => {
            currentPlaylistViewMode = 'list';
            document.getElementById('pl-list-view').style.display = 'block';
            if(document.getElementById('pl-grid-view')) document.getElementById('pl-grid-view').style.display = 'none';
            document.getElementById('pl-btn-view-list').classList.add('active');
            document.getElementById('pl-btn-view-grid').classList.remove('active');
        });

        document.getElementById('pl-btn-view-grid').addEventListener('click', () => {
            currentPlaylistViewMode = 'grid';
            if(document.getElementById('pl-list-view')) document.getElementById('pl-list-view').style.display = 'none';
            if(document.getElementById('pl-grid-view')) document.getElementById('pl-grid-view').style.display = 'grid';
            document.getElementById('pl-btn-view-grid').classList.add('active');
            document.getElementById('pl-btn-view-list').classList.remove('active');
        });

        document.getElementById('delete-playlist-btn').addEventListener('click', async () => {
             if(confirm(`Supprimer la playlist "${pl.nom_playlist}" ?`)) {
                 await supabase.from('playlists').delete().eq('id', pid);
                 localStorage.removeItem('lastPlaylistId'); // MODIFICATION: Reset memory on delete
                 fetchPlaylists(); 
                 playlistContentContainer.innerHTML='<p style="padding:20px;">Sélectionnez une playlist.</p>';
                 if(playlistDetailsPanel) {
                     playlistDetailsPanel.innerHTML = '<div style="text-align:center; padding-top:50px; color:#bdc3c7;"><i class="fas fa-compact-disc" style="font-size:3rem; margin-bottom:20px;"></i><p>Sélectionnez un titre</p></div>';
                 }
             }
        });
        document.getElementById('add-music-to-playlist-btn').addEventListener('click', () => openPlaylistModal(pid, true));

        // MODIFICATION: Logic Selection (Applique aux éléments Grille ET Liste)
        const setupSelection = (item) => {
            item.addEventListener('click', () => {
                // Remove selected from both lists
                playlistContentContainer.querySelectorAll('.selected').forEach(i => i.classList.remove('selected'));
                // Highlight clicked one
                item.classList.add('selected');
                // Also highlight counterpart (if I click in list, highlight in grid too)
                const id = item.dataset.id;
                playlistContentContainer.querySelectorAll(`[data-id="${id}"]`).forEach(el => el.classList.add('selected'));
                renderPlaylistDetailsPanel(id, pid, allData);
            });
            item.addEventListener('dblclick', async () => {
                const { data: p } = await supabase.from('partitions').select('*').eq('id', item.dataset.id).single();
                if(p && p.url_pdf) window.open(p.url_pdf, '_blank');
            });
        };

        playlistContentContainer.querySelectorAll('.playlist-item-grid').forEach(setupSelection);
        playlistContentContainer.querySelectorAll('.playlist-item-list').forEach(setupSelection);
    };

    const renderPlaylistDetailsPanel = async (partitionId, playlistId, allPlaylistsData) => {
        const { data: p } = await supabase.from('partitions').select('*').eq('id', partitionId).single();
        if(!p || !playlistDetailsPanel) return;

        playlistDetailsPanel.innerHTML = `
            <div class="cover-art"><img src="${p.url_cover || 'https://placehold.co/600/2a3f54/FFF?text=Pochette'}" alt="Jaquette"></div>
            <div class="info">
                <h2>${p.titre}</h2>
                <div class="artist">${p.nom_artiste}</div>
                <div class="meta"><span>Style: ${p.style || '-'}</span><br><span>Année: ${p.annee || '-'}</span></div>
            </div>
            <div class="actions">
                <a href="${p.url_pdf}" target="_blank" class="btn btn-accent" style="text-align:center; display:block;"><i class="fas fa-file-pdf"></i> Ouvrir le PDF</a>
                <button class="btn btn-danger" id="remove-from-pl-btn"><i class="fas fa-minus-circle"></i> Retirer de la playlist</button>
            </div>
        `;

        document.getElementById('remove-from-pl-btn').addEventListener('click', async () => {
            const pl = allPlaylistsData.find(x => x.id == playlistId);
            const currentIds = pl.partitions || [];
            const newIds = currentIds.filter(id => String(id) !== String(partitionId));
            
            await supabase.from('playlists').update({ partitions: newIds }).eq('id', playlistId);
            
            const { data: updatedData } = await supabase.from('playlists').select('*');
            loadPlaylistContent(playlistId, updatedData);
            playlistDetailsPanel.innerHTML = '<div style="text-align:center; padding-top:50px; color:#bdc3c7;"><i class="fas fa-compact-disc" style="font-size:3rem; margin-bottom:20px;"></i><p>Sélectionnez un titre</p></div>';
        });
    };

    createPlaylistForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        await supabase.from('playlists').insert([{ 
            nom_playlist: e.target.nom_playlist.value, 
            partitions: [],
            user_id: currentUser.id
        }]);
        e.target.reset(); fetchPlaylists();
    });

    const openPlaylistModal = async (targetId, isAddingToPlaylist = false) => {
        if(isAddingToPlaylist) {
            modalBody.innerHTML = `
                <h3 style="margin-bottom:15px; color:var(--primary-color);">Ajouter des morceaux</h3>
                <div style="max-height:60vh; overflow-y:auto; padding-right:5px;">
                    ${allPartitions.map(p => `
                        <label class="playlist-checkbox-item">
                            <input type="checkbox" class="add-partition-checkbox" value="${p.id}">
                            <div>
                                <div style="font-weight:bold;">${p.titre}</div>
                                <div style="font-size:0.8em; color:var(--text-muted);">${p.nom_artiste}</div>
                            </div>
                        </label>
                    `).join('')}
                </div>
                <button id="confirm-add-to-playlist" class="btn btn-accent" style="margin-top:20px; width:100%;">Ajouter la sélection</button>`;
            
            modal.style.display = 'flex';
            
            document.getElementById('confirm-add-to-playlist').addEventListener('click', async () => {
                const selectedIds = Array.from(document.querySelectorAll('.add-partition-checkbox:checked')).map(cb => cb.value);
                if (selectedIds.length > 0) {
                    const { data: currentPl } = await supabase.from('playlists').select('*').eq('id', targetId).single();
                    let currentParts = currentPl.partitions || [];
                    const newSet = new Set([...currentParts, ...selectedIds]);
                    await supabase.from('playlists').update({ partitions: Array.from(newSet) }).eq('id', targetId);
                    
                    const {data} = await supabase.from('playlists').select('*');
                    loadPlaylistContent(targetId, data);
                }
                modal.style.display = 'none';
            });

        } else {
            // UPDATE : Filtre par user_id
            const { data: pls } = await supabase.from('playlists').select('*').eq('user_id', currentUser.id);
            if(!pls.length) { alert('Créez une playlist d\'abord.'); return; }
            
            modalBody.innerHTML = `
                <h3 style="margin-bottom:15px; color:var(--primary-color);">Ajouter à une playlist...</h3>
                <div class="playlist-selection-container">
                    ${pls.map(pl => `
                        <div class="playlist-option" data-id="${pl.id}">
                            <span>${pl.nom_playlist}</span>
                            <i class="fas fa-plus"></i>
                        </div>
                    `).join('')}
                </div>
            `;
            modal.style.display = 'flex';
            
            modalBody.querySelectorAll('.playlist-option').forEach(d => {
                d.addEventListener('click', async () => {
                    const pl = pls.find(x => x.id == d.dataset.id);
                    const ids = pl.partitions || [];
                    if(!ids.map(String).includes(String(targetId))) {
                        ids.push(String(targetId));
                        await supabase.from('playlists').update({partitions: ids}).eq('id', pl.id);
                    }
                    modal.style.display = 'none';
                });
            });
        }
    };
    
    const renderStatsView = async () => {
        if(!allPartitions) return;
        statsTotalPartitions.textContent = allPartitions.length;
        statsTotalArtistes.textContent = new Set(allPartitions.map(p => p.nom_artiste)).size;
        // UPDATE : Filtre par user_id
        const { count } = await supabase.from('playlists').select('*', { count: 'exact', head: true }).eq('user_id', currentUser.id);
        statsTotalPlaylists.textContent = count || 0;
        
        const artistCounts = {};
        allPartitions.forEach(p => { artistCounts[p.nom_artiste] = (artistCounts[p.nom_artiste] || 0) + 1; });
        const sortedArtists = Object.entries(artistCounts).sort((a,b) => b[1] - a[1]).slice(0, 5);

        if (topArtistsChart) topArtistsChart.destroy();
        const ctx = document.getElementById('topArtistsChart');
        topArtistsChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: sortedArtists.map(x => x[0]),
                datasets: [{ label: 'Partitions', data: sortedArtists.map(x => x[1]), backgroundColor: '#3498db' }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { color: 'white', stepSize:1 } }, x: { ticks: { color: 'white' } } },
                plugins: { legend: { display: false } }
            }
        });
    };

    // ROUTER
    const showView = (viewId) => {
        appViews.forEach(v => {
            if(v.id !== 'auth-view') v.style.display = 'none';
        });
        const target = document.getElementById(viewId);
        if(target) target.style.display = 'block';
        
        navLinks.forEach(l => l.classList.toggle('active', l.dataset.view === viewId));
        if(viewId==='playlists-view') fetchPlaylists();
        if(viewId==='stats-view') renderStatsView();
    };
    
    // CORRECTION NAVIGATION
    navLinks.forEach(l => l.addEventListener('click', (e) => { 
        e.preventDefault(); 
        const viewId = e.currentTarget.dataset.view;
        window.location.hash = viewId.replace('-view','');
        showView(viewId);
    }));
    
    // Toggle View Mode
    btnListView.addEventListener('click', () => { 
        currentViewMode='list'; 
        listViewContainer.style.display='block'; 
        gridViewContainer.style.display='none'; 
        btnListView.classList.add('active'); 
        btnGridView.classList.remove('active'); 
    });
    btnGridView.addEventListener('click', () => { 
        currentViewMode='grid'; 
        listViewContainer.style.display='none'; 
        gridViewContainer.style.display='grid'; 
        btnGridView.classList.add('active'); 
        btnListView.classList.remove('active'); 
    });

    modalCloseBtn.addEventListener('click', () => modal.style.display = 'none');
    window.addEventListener('click', (e) => { if(e.target === modal) modal.style.display = 'none'; });

    // START
    sortSelect.addEventListener('change', (e) => { currentSort = e.target.value; sortAndDisplayPartitions(); });
    searchInput.addEventListener('input', sortAndDisplayPartitions);
    checkSession();
});
