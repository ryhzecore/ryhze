// One surface travels between the source thumbnail and player in both directions.
(() => {
  document.body.insertAdjacentHTML('beforeend', '<div class="menu-player-backdrop" id="menuPlayerBackdrop"></div><section class="menu-player" id="menuPlayer" tabindex="-1" role="dialog" aria-modal="true" aria-label="Ryhze player"><iframe id="menuPlayerFrame" title="Ryhze player" allow="autoplay; fullscreen"></iframe></section>');
  const panel = document.querySelector('#menuPlayer'), frame = document.querySelector('#menuPlayerFrame'), backdrop = document.querySelector('#menuPlayerBackdrop');
  const regions = [...document.querySelectorAll('body > nav, body > main, body > footer, .video-status-stack')];
  const duration = 850, easing = 'cubic-bezier(.22,.68,.18,1)';
  let source, artwork, sourceRadius, busy = false, opened = false, resolveReady, keyboardInput = false, closeQueued = false;
  addEventListener('keydown', () => { keyboardInput = true; }, true);
  addEventListener('pointerdown', () => { keyboardInput = false; }, true);
  const animate = async (node, keyframes, options = {}) => {
    const animation = node.animate(keyframes, { duration, easing, fill: 'forwards', ...options, ...(window.RyhzeMotion.reduced ? { duration: 0 } : {}) });
    await animation.finished.catch(() => {});
    return animation;
  };
  function surface(rect) {
    const node = document.createElement('div');
    node.className = 'menu-player-transition';
    Object.assign(node.style, { left: `${rect.left}px`, top: `${rect.top}px`, width: `${rect.width}px`, height: `${rect.height}px`, backgroundImage: artwork, borderRadius: getComputedStyle(panel).borderRadius });
    document.body.append(node);
    return node;
  }
  function thumbnailFrame(rect, base) {
    const sx = rect.width / base.width, sy = rect.height / base.height;
    return { transform: `translate(${rect.left - base.left}px, ${rect.top - base.top}px) scale(${sx}, ${sy})`, borderRadius: `${sourceRadius / sx}px / ${sourceRadius / sy}px` };
  }
  const playerFrame = () => ({ transform: 'translate(0px, 0px) scale(1, 1)', borderRadius: getComputedStyle(panel).borderRadius });
  async function open(item, exclusive = false, game = false) {
    if (busy || opened) return;
    busy = true; opened = true;
    source = exclusive ? document.querySelector('.hero') : item;
    const data = exclusive ? item : item.dataset;
    artwork = getComputedStyle(exclusive ? document.querySelector('.hero-image') : source).backgroundImage;
    if (!artwork || artwork === 'none') artwork = 'radial-gradient(circle at 20% 10%,#513487,transparent 65%),linear-gradient(145deg,#26164b,#0b0719)';
    sourceRadius = parseFloat(getComputedStyle(source).borderTopLeftRadius) || 0;
    pauseSlideshow(); menuMusic.pause();
    document.body.classList.add('player-open');
    const start = source.getBoundingClientRect(), destination = panel.getBoundingClientRect();
    const node = surface(destination), first = thumbnailFrame(start, destination);
    Object.assign(node.style, first);
    source.classList.add('player-source-active');
    regions.forEach(region => { region.inert = true; });
    backdrop.classList.add('open');
    const ready = new Promise(resolve => { resolveReady = resolve; });
    const query = new URLSearchParams({ embedded: '1', title: data.title || '', image: data.image || '', synopsis: exclusive ? data.synopsis || '' : decodeURIComponent(data.synopsis || ''), type: data.mediaType || data.type || 'Movie', streams: exclusive ? JSON.stringify(data.streams || []) : data.streams || '[]', seasons: exclusive ? JSON.stringify(data.seasons || []) : data.seasons || '[]', categories: data.meta || '', release: decodeURIComponent(data.release || 'Coming soon'), installer: decodeURIComponent(data.installer || 'null'), licensor: decodeURIComponent(data.licensor || 'Not specified') });
    query.set('v', window.RyhzeSiteVersion || 'smooth-player');
    frame.src = `/${game ? 'game' : 'player'}.html?${query}`;
    const motion = await animate(node, [first, playerFrame()]);
    let timeout;
    await Promise.race([ready, new Promise(resolve => { timeout = setTimeout(resolve, 3000); })]);
    clearTimeout(timeout);
    // Do not expose a full-size player behind the travelling thumbnail.
    panel.classList.add('open');
    await animate(node, [{ opacity: 1 }, { opacity: 0 }], { duration: 240, easing: 'ease-out' });
    motion.cancel(); node.remove(); busy = false;
    try { if (keyboardInput) frame.contentDocument?.querySelector('#back, button')?.focus({ preventScroll: true }); else panel.focus({ preventScroll: true }); } catch {}
    if (closeQueued) { closeQueued = false; close(); }
  }
  async function close() {
    if (!opened) return;
    if (busy) { closeQueued = true; return; }
    busy = true;
    try { frame.contentDocument?.querySelector('video')?.pause(); } catch {}
    const base = panel.getBoundingClientRect(), node = surface(base), full = playerFrame();
    await animate(node, [{ opacity: 0 }, { opacity: 1 }], { duration: 180 });
    panel.classList.remove('open'); backdrop.classList.remove('open');
    const target = source?.isConnected ? source.getBoundingClientRect() : null;
    if (target?.width && target?.height) await animate(node, [full, thumbnailFrame(target, base)]);
    else await animate(node, [{ opacity: 1 }, { opacity: 0 }], { duration: 250 });
    source?.classList.remove('player-source-active');
    await animate(node, [{ opacity: 1 }, { opacity: 0 }], { duration: 160 });
    node.remove(); panel.classList.remove('fullscreen'); frame.src = 'about:blank';
    document.body.classList.remove('player-open');
    regions.forEach(region => { region.inert = false; });
    const focus = source?.matches('button') ? source : source?.querySelector('button');
    focus?.focus({ preventScroll: true });
    busy = false; opened = false; closeQueued = false; resumeSlideshow();
    dispatchEvent(new Event('ryhze-player-closed'));
    if (musicStarted) menuMusic.play().catch(() => {});
  }
  frame.addEventListener('load', () => { if (opened) resolveReady?.(); });
  addEventListener('message', event => {
    if (event.source !== frame.contentWindow || event.origin !== location.origin) return;
    if (['ryhze-player-ready', 'ryhze-game-ready'].includes(event.data?.type)) resolveReady?.();
    if (event.data?.type === 'ryhze-close-player') close();
    if (event.data?.type === 'ryhze-toggle-player-fullscreen' && !busy) {
      panel.classList.toggle('fullscreen');
      frame.contentWindow.postMessage({ type: 'ryhze-embed-fullscreen', fullscreen: panel.classList.contains('fullscreen') }, location.origin);
    }
  });
  backdrop.addEventListener('click', close);
  addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
  openFilm = item => open(item);
  openGame = item => open(item, false, true);
  openExclusive = item => open(item, true);
})();
