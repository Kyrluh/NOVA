import { httpsUrl, loadDetails, loadSource, playlistLimit, xtreamBase } from './catalog.js?v=5';

const $ = id => document.getElementById(id);
const sourcesDialog = $('sources-dialog');
const detailsDialog = $('details-dialog');
const playerDialog = $('player-dialog');
const sourceForm = $('source-form');
const video = $('video');
const tabs = { live: 'En direct', movie: 'Films', series: 'Séries', favorites: 'Favoris', resume: 'Reprendre' };
const pageSize = 60;
const collator = new Intl.Collator('fr', { sensitivity: 'base', numeric: true });
let sources = [];
let cards = [];
let favorites = new Set();
let progress = {};
let database;
let tab = 'live';
let visible = pageSize;
let editing = null;
let activeVideo = null;
let hlsPlayer = null;
let requestNumber = 0;
let detailsNumber = 0;
let lastRecordedAt = 0;
let seekPending = false;
const detailsCache = new Map();

function openStorage() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('nova-iptv-web', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('local');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function storage(key, ...value) {
  return new Promise((resolve, reject) => {
    if (!database) return reject(new Error('Le stockage local est indisponible.'));
    const transaction = database.transaction('local', value.length ? 'readwrite' : 'readonly');
    const store = transaction.objectStore('local');
    const request = value.length ? store.put(value[0], key) : store.get(key);
    transaction.oncomplete = () => resolve(request.result);
    transaction.onabort = () => reject(transaction.error);
    transaction.onerror = () => reject(transaction.error);
  });
}

function element(tag, className, content) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (content != null) node.textContent = content;
  return node;
}

function button(label, action, primary = false) {
  const node = element('button', primary ? 'button primary' : 'button', label);
  node.type = 'button';
  node.addEventListener('click', action);
  return node;
}

function searchable(value) {
  return value.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase();
}

function resumeFor(id) {
  return Object.values(progress)
    .filter(entry => entry.parentId === id && !entry.completed && entry.position > 0)
    .sort((a, b) => b.date - a.date)[0];
}

function playableCard(item) {
  const node = element('button', 'card');
  node.type = 'button';
  const art = element('div', 'artwork', item.title.trim()[0]?.toUpperCase() || 'N');
  art.setAttribute('aria-hidden', 'true');
  if (item.image) {
    const image = document.createElement('img');
    image.alt = '';
    image.loading = 'lazy';
    image.referrerPolicy = 'no-referrer';
    image.addEventListener('error', () => image.remove(), { once: true });
    image.src = item.image;
    art.append(image);
  }
  const meta = element('span', 'card-meta');
  meta.append(element('span', 'card-title', item.title),
    element('span', 'category', [item.year, item.category].filter(Boolean).join(' · ')));
  node.append(art, meta);
  node.addEventListener('click', () => openDetails(item));
  return node;
}

function tabCards() {
  if (tab === 'favorites') return cards.filter(item => favorites.has(item.id));
  if (tab === 'resume') {
    const dates = new Map();
    for (const entry of Object.values(progress)) {
      if (!entry.completed && entry.position > 0) {
        dates.set(entry.parentId, Math.max(dates.get(entry.parentId) || 0, entry.date));
      }
    }
    return cards.filter(item => dates.has(item.id)).sort((a, b) => dates.get(b.id) - dates.get(a.id));
  }
  return cards.filter(item => item.kind === tab);
}

function renderCatalogue(resetCategory = false) {
  const items = tabCards();
  const category = resetCategory ? '' : $('categories').value;
  const categories = [...new Set(items.map(item => item.category).filter(Boolean))].sort(collator.compare);
  const optionList = document.createDocumentFragment();
  optionList.append(new Option('Toutes les catégories', ''));
  for (const value of categories) optionList.append(new Option(value, value));
  $('categories').replaceChildren(optionList);
  if (categories.includes(category)) $('categories').value = category;
  const query = searchable($('search').value.trim());
  const selection = $('categories').value;
  const filtered = items.filter(item => (!selection || item.category === selection) &&
    (!query || searchable(`${item.title} ${item.category}`).includes(query)));
  $('section-title').textContent = tabs[tab];
  $('result-count').textContent = filtered.length ? `${filtered.length} résultat(s)` : 'Aucun résultat';
  const grid = $('cards');
  grid.classList.toggle('channels', tab === 'live');
  grid.replaceChildren(...filtered.slice(0, visible).map(playableCard));
  $('more').hidden = filtered.length <= visible;
}

async function refreshCatalogue() {
  const request = ++requestNumber;
  detailsCache.clear();
  $('welcome').hidden = !!sources.length;
  $('library').hidden = !sources.length;
  cards = [];
  renderCatalogue(true);
  if (!sources.length) return;
  $('catalog-status').textContent = 'Chargement des sources…';
  const notices = [];
  for (const source of sources) {
    try {
      const result = await loadSource(source);
      if (request !== requestNumber) return;
      cards = cards.concat(result.items);
      if (result.warning) notices.push(`${source.name} : ${result.warning}`);
    } catch (error) {
      if (request !== requestNumber) return;
      notices.push(`${source.name} : ${error.message}`);
    }
    renderCatalogue();
  }
  $('catalog-status').textContent = notices.join(' ');
}

function toggleSourceFields() {
  const type = $('source-type').value;
  $('source-url-field').hidden = type === 'file';
  $('source-file-field').hidden = type !== 'file';
  $('xtream-fields').hidden = type !== 'xtream';
  $('source-url').required = type !== 'file';
  $('source-file').required = type === 'file' && !editing?.playlist;
  $('source-user').required = type === 'xtream';
  $('source-pass').required = type === 'xtream';
}

function editSource(source = null) {
  editing = source;
  sourceForm.reset();
  $('form-title').textContent = source ? 'Modifier la source' : 'Ajouter une source';
  $('cancel-edit').hidden = !source;
  $('source-status').textContent = '';
  if (source) {
    $('source-name').value = source.name;
    $('source-type').value = source.type;
    $('source-url').value = source.url || '';
    $('source-user').value = source.user || '';
    $('source-pass').value = source.password || '';
  }
  toggleSourceFields();
}

function renderSources() {
  $('sources-list').replaceChildren(...sources.map(source => {
    const row = element('div', 'source-row');
    const actions = element('div', 'form-actions');
    actions.append(
      button('Modifier', () => editSource(source)),
      button('Supprimer', async () => {
        if (!window.confirm(`Supprimer la source « ${source.name} » de cet appareil ?`)) return;
        const next = sources.filter(entry => entry.id !== source.id);
        try {
          await storage('sources', next);
          sources = next;
          editSource();
          renderSources();
          void refreshCatalogue();
        } catch {
          $('source-status').textContent = 'La source n’a pas pu être supprimée du stockage local.';
        }
      }),
    );
    row.append(element('strong', '', source.name), actions);
    return row;
  }));
}

sourceForm.addEventListener('submit', async event => {
  event.preventDefault();
  const submit = sourceForm.querySelector('[type="submit"]');
  submit.disabled = true;
  $('source-status').textContent = '';
  try {
    const type = $('source-type').value;
    const name = $('source-name').value.trim();
    if (!name) throw new Error('Donne un nom à ta source.');
    const previous = editing;
    const source = { id: previous?.id ?? crypto.randomUUID(), type, name };
    if (type === 'file') {
      const file = $('source-file').files[0];
      if (file?.size > playlistLimit) throw new Error('Ce fichier M3U est trop volumineux.');
      source.playlist = file ? await file.text() : previous?.playlist;
      if (!source.playlist) throw new Error('Choisis un fichier M3U.');
    } else {
      const url = httpsUrl($('source-url').value);
      if (!url) throw new Error('L’adresse doit commencer par https://, sans identifiants devant le nom du serveur.');
      source.url = type === 'xtream' ? xtreamBase(url.href).href : url.href;
      if (type === 'xtream') {
        source.user = $('source-user').value.trim();
        source.password = $('source-pass').value;
        if (!source.user || !source.password) throw new Error('Renseigne les identifiants Xtream.');
      }
    }
    const next = previous ? sources.map(entry => entry.id === previous.id ? source : entry) : [...sources, source];
    await storage('sources', next);
    sources = next;
    navigator.storage?.persist?.().catch(() => {});
    editSource();
    renderSources();
    sourcesDialog.close();
    void refreshCatalogue();
  } catch (error) {
    $('source-status').textContent = error?.name === 'QuotaExceededError'
      ? 'Il n’y a plus assez de place dans le stockage de NOVA.'
      : error.message || 'L’enregistrement local a échoué.';
  } finally {
    submit.disabled = false;
  }
});

function openSources() {
  editSource();
  renderSources();
  sourcesDialog.showModal();
}

function episodeList(item) {
  const box = $('episodes');
  box.replaceChildren();
  const episodes = [...(item.episodes || [])].filter(episode => httpsUrl(episode.stream))
    .sort((a, b) => a.season - b.season || a.number - b.number);
  if (!episodes.length) return;
  const groups = new Map();
  for (const entry of episodes) {
    if (!groups.has(entry.season)) groups.set(entry.season, []);
    groups.get(entry.season).push(entry);
  }
  const select = document.createElement('select');
  select.setAttribute('aria-label', 'Saison');
  for (const season of groups.keys()) select.add(new Option(season ? `Saison ${season}` : 'Épisodes', String(season)));
  const resumed = episodes.find(entry => entry.id === resumeFor(item.id)?.id);
  if (resumed) select.value = String(resumed.season);
  const list = element('div');
  let count = pageSize;
  const render = () => {
    const entries = groups.get(Number(select.value)) || [];
    list.replaceChildren(...entries.slice(0, count).map(episode => {
      const row = element('div', 'episode');
      const saved = progress[episode.id];
      row.append(element('span', '', episode.title),
        button(saved?.position && !saved.completed ? 'Reprendre' : 'Lire',
          () => playVideo(episode, item.id)));
      return row;
    }));
    if (entries.length > count) list.append(button('Afficher plus d’épisodes', () => {
      count += pageSize;
      render();
    }));
  };
  select.addEventListener('change', () => { count = pageSize; render(); });
  box.append(select, list);
  render();
}

function showDetailActions(item, playable) {
  const box = $('details-actions');
  box.replaceChildren();
  const saved = favorites.has(item.id);
  box.append(button(saved ? 'Retirer des favoris' : 'Ajouter aux favoris', async () => {
    const next = new Set(favorites);
    if (saved) next.delete(item.id);
    else next.add(item.id);
    try {
      await storage('favorites', [...next]);
      favorites = next;
      showDetailActions(item, playable);
      renderCatalogue();
    } catch {
      $('details-status').textContent = 'Les favoris n’ont pas pu être enregistrés localement.';
    }
  }));
  const resume = resumeFor(item.id);
  if (playable) box.prepend(button(resume ? 'Reprendre' : 'Lire', () => playVideo(item, item.id), true));
  if (item.kind === 'series' && resume && item.episodes) {
    const episode = item.episodes.find(entry => entry.id === resume.id);
    if (episode) box.prepend(button('Reprendre l’épisode', () => playVideo(episode, item.id), true));
  }
}

async function openDetails(item) {
  const request = ++detailsNumber;
  $('details-title').textContent = item.title;
  $('details-category').textContent = [item.year, item.category].filter(Boolean).join(' · ');
  $('details-summary').textContent = item.description || '';
  $('details-status').textContent = '';
  $('episodes').replaceChildren();
  showDetailActions(item, !!httpsUrl(item.stream));
  detailsDialog.showModal();
  const source = sources.find(entry => entry.id === item.sourceId);
  if (!source) return;
  if (item.kind === 'live' && item.stream) {
    playVideo(item, item.id, true);
    return;
  }
  try {
    const cached = detailsCache.get(item.id);
    if (!cached && source.type === 'xtream') $('details-status').textContent = 'Chargement de la fiche…';
    const detailed = cached || await loadDetails(item, source);
    if (request !== detailsNumber || !detailsDialog.open) return;
    if (detailsCache.size >= 64) detailsCache.delete(detailsCache.keys().next().value);
    detailsCache.set(item.id, detailed);
    $('details-summary').textContent = detailed.description || '';
    $('details-status').textContent = detailed.kind === 'series' && !detailed.episodes?.length ? 'Aucun épisode disponible.' : '';
    showDetailActions(detailed, !!httpsUrl(detailed.stream));
    episodeList(detailed);
  } catch (error) {
    if (request === detailsNumber && detailsDialog.open) $('details-status').textContent = error.message;
  }
}

function recordVideo(completed = false) {
  if (!activeVideo || activeVideo.live || seekPending || !Number.isFinite(video.duration) || video.duration <= 0) return;
  const position = Math.floor(video.currentTime);
  if (!completed && position < 2) return;
  lastRecordedAt = Date.now();
  const { id, parentId } = activeVideo;
  progress[id] = { id, parentId, position, completed, date: lastRecordedAt };
  void storage('progress', progress).catch(() => {
    $('player-status').textContent = 'La position n’a pas pu être enregistrée sur cet appareil.';
  });
}

function playVideo(item, parentId, live = false) {
  const url = httpsUrl(item.stream);
  if (!url) return;
  if (activeVideo) recordVideo();
  activeVideo = { id: item.id, parentId, live, item, url: url.href, triedHls: false };
  lastRecordedAt = 0;
  seekPending = true;
  $('player-title').textContent = item.title;
  $('player-status').textContent = '';
  $('retry-video').hidden = true;
  if (!playerDialog.open) playerDialog.showModal();
  video.src = url.href;
  video.load();
  startPlayback();
}

function startPlayback() {
  const session = activeVideo;
  video.play().catch(error => {
    if (session === activeVideo && error.name === 'NotAllowedError') {
      $('player-status').textContent = 'Touche ▶ pour lancer la vidéo.';
    }
  });
}

function stopHls() {
  hlsPlayer?.destroy();
  hlsPlayer = null;
}

function streamHttpError(status) {
  if (status === 401 || status === 403) {
    return `Le fournisseur refuse l’accès au flux vidéo HTTPS (HTTP ${status}). Si le catalogue s’affiche, demande au fournisseur l’adresse HTTPS destinée à la lecture web.`;
  }
  return `Le serveur a répondu HTTP ${status} lors du chargement du flux.`;
}

function playbackFailed(code, detail) {
  const reason = detail || (code === 3
    ? 'Le navigateur a rencontré une erreur de décodage vidéo ou audio.'
    : 'Le navigateur n’a pas pu ouvrir ce flux. La cause exacte reste inconnue.');
  $('player-status').textContent = `${reason} (NOVA Web 5)`;
  $('retry-video').hidden = false;
}

async function inspectStream(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 6000);
  try {
    const response = await fetch(url, {
      headers: { Range: 'bytes=0-511' }, credentials: 'omit', referrerPolicy: 'no-referrer',
      cache: 'no-store', signal: controller.signal,
    });
    if (!response.ok) return { status: response.status, detail: streamHttpError(response.status) };
    const type = response.headers.get('Content-Type') || '';
    const reader = response.body?.getReader();
    const first = reader && (await reader.read()).value;
    const prefix = first ? new TextDecoder().decode(first.subarray(0, 512)).trimStart() : '';
    if (/^#EXTM3U/.test(prefix) || /mpegurl/i.test(type)) return { hls: true };
    if (/^(?:<!doctype html|<html)/i.test(prefix) || /text\/html/i.test(type)) {
      return { detail: 'Le fournisseur renvoie une page web à la place de la vidéo.' };
    }
    return {};
  } catch {
    return { detail: 'Le navigateur ne peut pas vérifier le flux. La connexion, une redirection ou les règles d’accès web du fournisseur peuvent en être la cause.' };
  } finally {
    controller.abort();
    clearTimeout(timeout);
  }
}

async function recoverPlayback() {
  const session = activeVideo;
  if (!playerDialog.open || !session || !video.error || hlsPlayer) return;
  let alternate = httpsUrl(session.item.providerStream)?.href;
  if (!alternate && session.live) {
    const candidate = httpsUrl(session.item.stream);
    if (candidate && /\/live\/[^/]+\/[^/]+\/\d+(?:\.ts)?$/i.test(candidate.pathname)) {
      candidate.pathname = candidate.pathname.replace(/(?:\.ts)?$/i, '.m3u8');
      alternate = candidate.href;
    }
  }
  if (alternate && alternate !== session.url) {
    session.url = alternate;
    video.src = alternate;
    video.load();
    startPlayback();
    return;
  }
  const code = video.error.code;
  if (session.triedHls) return;
  session.triedHls = true;
  $('player-status').textContent = 'Vérification du flux…';
  const probe = await inspectStream(session.url);
  if (activeVideo !== session || !playerDialog.open) return;
  if (probe.status === 401 || probe.status === 403) return playbackFailed(code, probe.detail);
  if (!probe.hls && !(/\.m3u8(?:$|[?#])/i.test(session.url) || session.live)) {
    return playbackFailed(code, probe.detail);
  }
  try {
    await import('./vendor/hls.light.min.js');
    if (activeVideo !== session) return;
    const Hls = window.Hls;
    if (!Hls?.isSupported()) return playbackFailed(code, probe.detail);
    const player = new Hls();
    hlsPlayer = player;
    player.on(Hls.Events.ERROR, (_event, data) => {
      if (!data.fatal || hlsPlayer !== player) return;
      stopHls();
      const status = data.response?.code;
      const network = data.type === Hls.ErrorTypes.NETWORK_ERROR;
      const detail = status >= 400 ? streamHttpError(status)
        : network ? probe.detail || 'Le navigateur ne peut pas charger la playlist HLS ou un de ses segments.' : null;
      playbackFailed(network ? 2 : 3, detail);
    });
    player.on(Hls.Events.MANIFEST_PARSED, startPlayback);
    player.loadSource(session.url);
    if ('disableRemotePlayback' in video) video.disableRemotePlayback = true;
    player.attachMedia(video);
  } catch {
    if (activeVideo === session) playbackFailed(code);
  }
}

$('retry-video').addEventListener('click', () => {
  if (!activeVideo) return;
  stopHls();
  playVideo(activeVideo.item, activeVideo.parentId, activeVideo.live);
});

video.addEventListener('loadedmetadata', () => {
  const saved = activeVideo && !activeVideo.live && progress[activeVideo.id];
  if (saved && !saved.completed && Number.isFinite(video.duration) && saved.position < video.duration) {
    video.currentTime = saved.position;
  }
  seekPending = false;
});
video.addEventListener('timeupdate', () => {
  if (Date.now() - lastRecordedAt > 5000) recordVideo();
});
video.addEventListener('pause', () => recordVideo(video.ended));
video.addEventListener('ended', () => recordVideo(true));
video.addEventListener('error', recoverPlayback);
video.addEventListener('playing', () => {
  $('player-status').textContent = '';
  $('retry-video').hidden = true;
});
playerDialog.addEventListener('close', () => {
  recordVideo(video.ended);
  activeVideo = null;
  stopHls();
  if ('disableRemotePlayback' in video) video.disableRemotePlayback = false;
  video.pause();
  video.removeAttribute('src');
  video.load();
  renderCatalogue();
});
detailsDialog.addEventListener('close', () => detailsNumber++);
window.addEventListener('pagehide', () => recordVideo(video.ended));
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') recordVideo(video.ended);
});

document.querySelectorAll('[data-close]').forEach(node => {
  node.addEventListener('click', () => node.closest('dialog').close());
});
document.querySelectorAll('[data-tab]').forEach(node => node.addEventListener('click', () => {
  tab = node.dataset.tab;
  visible = pageSize;
  document.querySelectorAll('[data-tab]').forEach(entry => {
    const selected = entry === node;
    entry.classList.toggle('selected', selected);
    entry.setAttribute('aria-pressed', String(selected));
  });
  renderCatalogue(true);
}));
$('search').addEventListener('input', () => { visible = pageSize; renderCatalogue(); });
$('categories').addEventListener('change', () => { visible = pageSize; renderCatalogue(); });
$('more').addEventListener('click', () => { visible += pageSize; renderCatalogue(); });
$('source-type').addEventListener('change', toggleSourceFields);
$('cancel-edit').addEventListener('click', () => editSource());
$('open-sources').addEventListener('click', openSources);
$('add-first').addEventListener('click', openSources);
$('install-hint').hidden = navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;

async function start() {
  try {
    database = await openStorage();
    const [savedSources, savedFavorites, savedProgress] = await Promise.all([
      storage('sources'), storage('favorites'), storage('progress'),
    ]);
    sources = savedSources ?? [];
    favorites = new Set(savedFavorites ?? []);
    progress = savedProgress ?? {};
    $('open-sources').disabled = false;
    $('add-first').disabled = false;
    void refreshCatalogue();
  } catch {
    $('welcome').append(element('p', 'status', 'Le stockage local est indisponible. Ouvre NOVA hors de la navigation privée et autorise les données du site.'));
  }
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(() => {});
}
void start();
