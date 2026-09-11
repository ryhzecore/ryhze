import originals from './catalog.json' with { type: 'json' };
import internal from './internal-catalog.json' with { type: 'json' };
export const launcherAdmin = user => user?.role === 'admin' && ['andru', 'leo'].includes(user.username?.toLowerCase());

export async function catalogue(env, base, { includeHidden = false, includeInternal = false } = {}) {
  const records = (await env.DB.prepare('SELECT id,document,revision,hidden FROM game_catalog').all()).results;
  const titles = new Map(base.map(t => [t.id, { ...t, revision: 0 }]));
  for (const r of records) {
    const document = JSON.parse(r.document);
    if (document.internal && !includeInternal) { titles.delete(r.id); continue; }
    if (r.hidden && !includeHidden) titles.delete(r.id);
    else titles.set(r.id, { ...document, revision: r.revision, hidden: !!r.hidden });
  }
  return [...titles.values()];
}

export function gameDocument(body) {
  const text = (key, max, required = false) => {
    const v = body[key] ?? '';
    if (typeof v !== 'string' || v.length > max || (required && !v.trim())) throw Error(`Invalid ${key}.`);
    return v.trim();
  };
  const id = text('id', 100, true);
  if (!/^[a-z0-9][a-z0-9-]*$/.test(id)) throw Error('Use lowercase letters, numbers and hyphens for the game ID.');
  const image = text('image', 500);
  if (image && !/^\/art\/[a-zA-Z0-9_./-]+$/.test(image)) throw Error('Artwork must use a Ryhze /art/ path.');
  if (image.includes('..')) throw Error('Invalid artwork path.');
  const storeId = text('storeId', 20);
  if (storeId && !/^\d+$/.test(storeId)) throw Error('Steam app ID must contain digits only.');
  if (!Array.isArray(body.categories) || body.categories.length > 10 || body.categories.some(v => typeof v !== 'string' || v.length > 60)) throw Error('Invalid categories.');
  return { id, kind: 'game', title: text('title', 160, true), label: text('label', 100), status: text('status', 120), description: text('description', 2400), image, imageNote: text('imageNote', 200), categories: body.categories.map(v => v.trim()).filter(Boolean), storeId, streams: [], facts: [] };
}

export async function saveGame(env, user, body) {
  const document = gameDocument(body);
  const stored = await env.DB.prepare('SELECT document FROM game_catalog WHERE id=?').bind(document.id).first();
  const original = stored ? JSON.parse(stored.document) : [...originals, ...internal].find(t => t.id === document.id);
  if (original && original.kind !== 'game') throw Error('This ID belongs to a film. Choose a different game ID.');
  if (original) {
    for (const key of ['facts', 'streams', 'availability', 'internal']) {
      if (key in original) document[key] = original[key];
    }
  }
  if (!Number.isSafeInteger(body.revision) || body.revision < 0) throw Error('Reload the game before saving.');
  const hidden = body.hidden === true ? 1 : 0;
  const query = body.revision === 0
    ? env.DB.prepare('INSERT OR IGNORE INTO game_catalog(id,document,revision,hidden,updated_by,updated_at) VALUES(?,?,1,?,?,?)').bind(document.id, JSON.stringify(document), hidden, user.id, Math.floor(Date.now()/1000))
    : env.DB.prepare('UPDATE game_catalog SET document=?,revision=revision+1,hidden=?,updated_by=?,updated_at=? WHERE id=? AND revision=?').bind(JSON.stringify(document), hidden, user.id, Math.floor(Date.now()/1000), document.id, body.revision);
  const result = await query.run();
  return result.meta.changes === 1;
}
