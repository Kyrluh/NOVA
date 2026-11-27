export const playlistLimit = 24 * 1024 * 1024;
const itemLimit = 60000;

export function httpsUrl(value, base) {
  if (typeof value !== 'string' || !value.trim()) return null;
  try {
    const url = new URL(value.trim(), base);
    return url.protocol === 'https:' && !url.username && !url.password ? url : null;
  } catch {
    return null;
  }
}

export function xtreamBase(value) {
  const url = httpsUrl(value);
  if (!url) throw new Error('Saisis une adresse HTTPS valide.');
  url.search = '';
  url.hash = '';
  url.pathname = url.pathname.replace(/\/+$/, '').replace(/\/(?:player_api|get)\.php$/i, '') + '/';
  return url;
}

function apiUrl(source, action, extra = {}) {
  const url = new URL('player_api.php', xtreamBase(source.url));
  url.search = new URLSearchParams({ username: source.user, password: source.password, action, ...extra });
  return url;
}

function streamUrl(source, kind, id, extension) {
  const path = [kind, source.user, source.password, id].map(encodeURIComponent).join('/');
  return new URL(`${path}.${extension}`, xtreamBase(source.url)).href;
}

async function request(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      credentials: 'omit',
      redirect: 'error',
      cache: 'no-store',
      referrerPolicy: 'no-referrer',
    });
    if (!response.ok) {
      throw new Error(response.status === 401 || response.status === 403
        ? 'Accès refusé par le fournisseur. Vérifie les identifiants.'
        : 'Le fournisseur a renvoyé une erreur.');
    }
    if (Number(response.headers.get('content-length')) > playlistLimit) {
      throw new Error('La réponse est trop volumineuse pour NOVA Web.');
    }
    if (!response.body) {
      const raw = await response.text();
      if (raw.length > playlistLimit) throw new Error('La réponse est trop volumineuse.');
      return raw;
    }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    const chunks = [];
    let size = 0;
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > playlistLimit) {
          await reader.cancel();
          throw new Error('La réponse est trop volumineuse pour NOVA Web.');
        }
        chunks.push(decoder.decode(value, { stream: true }));
      }
    } finally {
      reader.releaseLock();
    }
    chunks.push(decoder.decode());
    return chunks.join('');
  } catch (error) {
    if (error.name === 'AbortError') throw new Error('Le fournisseur met trop de temps à répondre.');
    if (error instanceof TypeError) {
      throw new Error('Safari ne peut pas charger cette source. Vérifie le HTTPS et que le fournisseur autorise les requêtes web (CORS) sans redirection.');
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function json(source, action, extra) {
  const raw = await request(apiUrl(source, action, extra));
  try {
    const result = JSON.parse(raw);
    if (String(result?.user_info?.auth) === '0') throw new Error();
    return result;
  } catch {
    throw new Error('Réponse Xtream invalide ou identifiants refusés.');
  }
}

const text = value => typeof value === 'string' ? value.trim() : '';
const providerId = value => /^[\w-]{1,100}$/.test(String(value ?? '')) ? String(value) : null;
const extension = value => /^[a-z0-9]{1,8}$/i.test(text(value)) ? text(value).toLowerCase() : 'mp4';
const safeImage = (value, base) => httpsUrl(value, base)?.href ?? '';
const yearOf = value => /^(?:19|20)\d\d/.exec(String(value ?? ''))?.[0] ?? '';

async function loadXtream(source) {
  const groups = [
    ['live', 'get_live_categories', 'get_live_streams', 'Direct'],
    ['movie', 'get_vod_categories', 'get_vod_streams', 'Films'],
    ['series', 'get_series_categories', 'get_series', 'Séries'],
  ];
  const base = xtreamBase(source.url);
  const results = await Promise.allSettled(groups.map(async ([kind, categories, streams, fallback]) => {
    const [rows, names] = await Promise.all([
      json(source, streams),
      json(source, categories).catch(() => []),
    ]);
    if (!Array.isArray(rows)) throw new Error('Le fournisseur ne renvoie pas de catalogue Xtream utilisable.');
    const categoryNames = new Map((Array.isArray(names) ? names : [])
      .filter(row => row && typeof row === 'object')
      .map(row => [String(row.category_id), text(row.category_name)]));
    const items = [];
    for (const row of rows.slice(0, itemLimit)) {
      if (!row || typeof row !== 'object') continue;
      const id = providerId(kind === 'series' ? row.series_id : row.stream_id);
      const title = text(row.name);
      if (!id || !title) continue;
      const direct = httpsUrl(row.direct_source, base)?.href;
      items.push({
        id: `${source.id}:${kind}:${id}`,
        providerId: id,
        sourceId: source.id,
        kind,
        title,
        year: yearOf(row.year ?? row.releaseDate ?? row.release_date),
        category: categoryNames.get(String(row.category_id)) || fallback,
        description: text(row.plot ?? row.description),
        image: safeImage(row.cover ?? row.stream_icon, base),
        stream: kind === 'series' ? null : direct ||
          streamUrl(source, kind, id, kind === 'live' ? 'm3u8' : extension(row.container_extension)),
      });
    }
    return items;
  }));
  const items = results.flatMap(result => result.status === 'fulfilled' ? result.value : []);
  const failure = results.find(result => result.status === 'rejected');
  if (!items.length && failure) throw failure.reason;
  return { items, warning: failure ? 'Une partie du catalogue Xtream est indisponible.' : '' };
}

function attribute(line, key) {
  const match = new RegExp(`(?:^|\\s)${key}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s,]+))`, 'i').exec(line);
  return match ? match[1] ?? match[2] ?? match[3] : '';
}

function nameAfterAttributes(line) {
  let quote = '';
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (quote) {
      if (char === quote) quote = '';
    } else if (char === '"' || char === "'") quote = char;
    else if (char === ',') return line.slice(i + 1).trim();
  }
  return '';
}

function shortId(value) {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i++) hash = Math.imul(hash ^ value.charCodeAt(i), 16777619);
  return (hash >>> 0).toString(36);
}

export function parseM3u(raw, source) {
  const lines = raw.replace(/^\uFEFF/, '').split(/\r?\n/);
  const base = source.url || undefined;
  if (base && lines.some(line => /^\s*#EXT-X-(?:TARGETDURATION|STREAM-INF|MEDIA-SEQUENCE|I-FRAME-STREAM-INF):/.test(line))) {
    return { items: [{
      id: `${source.id}:hls`, sourceId: source.id, kind: 'live',
      title: source.name, category: 'Direct', stream: httpsUrl(base)?.href,
    }], warning: '' };
  }
  const items = new Map();
  const series = new Map();
  let info = '';
  let skipped = 0;
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (line.startsWith('#EXTINF:')) {
      info = line;
      continue;
    }
    if (!line || line.startsWith('#')) continue;
    const stream = httpsUrl(line, base);
    const attributes = info;
    info = '';
    if (!stream) {
      skipped++;
      continue;
    }
    const title = nameAfterAttributes(attributes) || attribute(attributes, 'tvg-name') || 'Flux vidéo';
    const category = attribute(attributes, 'group-title');
    const image = safeImage(attribute(attributes, 'tvg-logo'), base);
    const match = /^(.*?)\s+S(\d{1,3})\s*E(\d{1,4})(?:\b|$)/i.exec(title);
    const id = `${source.id}:m3u:${shortId(stream.href)}`;
    if (match?.[1].trim()) {
      const seriesTitle = match[1].trim();
      const seriesId = `${source.id}:series:${shortId(seriesTitle.toLowerCase() + '|' + category)}`;
      if (!series.has(seriesId)) {
        series.set(seriesId, {
          id: seriesId, sourceId: source.id, title: seriesTitle, kind: 'series',
          category: category || 'Séries', image, episodes: [],
        });
      }
      if (!items.has(id)) {
        series.get(seriesId).episodes.push({
          id, title, season: Number(match[2]), number: Number(match[3]),
          stream: stream.href,
        });
        items.set(id, null);
      }
    } else {
      const movie = /\/movie\//i.test(stream.pathname) ||
        /\.(?:mp4|mkv|mov|webm)$/i.test(stream.pathname) ||
        /\b(?:vod|films?|cinéma|movies?)\b/i.test(category);
      items.set(id, {
        id, sourceId: source.id, title, image, kind: movie ? 'movie' : 'live',
        category: category || (movie ? 'Films' : 'Direct'), stream: stream.href,
      });
    }
    if (items.size >= itemLimit) break;
  }
  return {
    items: [...items.values()].filter(Boolean).concat([...series.values()]),
    warning: skipped ? `${skipped} lien(s) ignoré(s) car ils ne sont pas utilisables en HTTPS.` : '',
  };
}

export async function loadSource(source) {
  if (source.type === 'xtream') return loadXtream(source);
  if (source.type === 'hls') {
    const stream = httpsUrl(source.url);
    if (!stream) throw new Error('Le flux HLS doit utiliser une adresse HTTPS.');
    return { items: [{
      id: `${source.id}:hls`, sourceId: source.id, kind: 'live',
      title: source.name, category: 'Direct', stream: stream.href,
    }], warning: '' };
  }
  const raw = source.type === 'file' ? source.playlist : await request(httpsUrl(source.url));
  const result = parseM3u(raw, source);
  if (!result.items.length) throw new Error(result.warning || 'Playlist vide ou format M3U non reconnu.');
  return result;
}

export async function loadDetails(item, source) {
  if (source.type !== 'xtream' || item.kind === 'live') return item;
  const base = xtreamBase(source.url);
  if (item.kind === 'movie') {
    const result = await json(source, 'get_vod_info', { vod_id: item.providerId });
    const direct = httpsUrl(result?.movie_data?.direct_source, base)?.href;
    return {
      ...item,
      description: text(result?.info?.plot ?? result?.info?.description) || item.description,
      stream: direct || item.stream,
    };
  }
  const result = await json(source, 'get_series_info', { series_id: item.providerId });
  const episodes = result?.episodes;
  if (!episodes || typeof episodes !== 'object') {
    throw new Error('Les épisodes de cette série sont indisponibles.');
  }
  const groups = Array.isArray(episodes) ? [['0', episodes]] : Object.entries(episodes);
  const parsed = new Map();
  for (const [season, list] of groups) {
    if (!Array.isArray(list)) continue;
    for (const row of list) {
      const id = providerId(row?.id);
      if (!id || parsed.size >= itemLimit) continue;
      const number = Number(row.episode_num) || 0;
      parsed.set(id, {
        id: `${source.id}:episode:${id}`,
        season: Number(row.season ?? season) || 0,
        number,
        title: text(row.title) || `Épisode ${number || parsed.size + 1}`,
        description: text(row.info?.plot ?? row.info?.description),
        stream: httpsUrl(row.direct_source, base)?.href ||
          streamUrl(source, 'series', id, extension(row.container_extension)),
      });
    }
  }
  return {
    ...item,
    description: text(result?.info?.plot ?? result?.info?.description) || item.description,
    episodes: [...parsed.values()],
  };
}
