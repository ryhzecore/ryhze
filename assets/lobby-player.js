// Keep the source card mounted while the player is open so returning never jumps.
(() => {
  document.body.insertAdjacentHTML('beforeend', '<div class="menu-player-backdrop" id="menuPlayerBackdrop"></div><section class="menu-player" id="menuPlayer" role="dialog" aria-modal="true" aria-label="Ryhze player"><iframe id="menuPlayerFrame" title="Ryhze player" allow="autoplay; fullscreen"></iframe></section>');
  const panel = document.querySelector('#menuPlayer');
  const frame = document.querySelector('#menuPlayerFrame');
  const backdrop = document.querySelector('#menuPlayerBackdrop');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const lobbyRegions = [...document.querySelectorAll('body > nav, body > main, body > footer, .video-status-stack')];
  let source, artwork, transition, busy = false, ready = false, openingDone = false, fallback;
  const delay = ms => new Promise(resolve => setTimeout(resolve, reduced.matches ? 0 : ms));
  const rectStyle = rect => ({ left: `${rect.left}px`, top: `${rect.top}px`, width: `${rect.width}px`, height: `${rect.height}px` });
  function stageRect() {
    try {
      const stage = frame.contentDocument?.querySelector('#stage');
      if (stage) {
        const rect = stage.getBoundingClientRect(), outer = frame.getBoundingClientRect();
        return { left: outer.left + rect.left, top: outer.top + rect.top, width: rect.width, height: rect.height };
      }
    } catch {}
    return panel.getBoundingClientRect();
  }
  function makeTransition(rect, radius) {
    const node = document.createElement('div');
    node.className = 'menu-player-transition';
    Object.assign(node.style, rectStyle(rect), { backgroundImage: artwork, borderRadius: radius, transition: 'none' });
    document.body.append(node);
    return node;
  }
  async function reveal() {
    if (!ready || !openingDone || !transition || !busy) return;
    const node = transition;
    transition = null;
    clearTimeout(fallback);
    node.style.transition = reduced.matches ? 'none' : 'opacity .25s ease';
    node.style.opacity = '0';
    await delay(260);
    node.remove();
    busy = false;
    try { frame.contentDocument?.querySelector('#backToRyhze, .back, button')?.focus(); } catch {}
  }
  async function open(item, exclusive = false, game = false) {
    if (busy || panel.classList.contains('open')) return;
    busy = true; ready = false; openingDone = false;
    source = exclusive ? document.querySelector('.hero') : item;
    const data = exclusive ? item : item.dataset;
    artwork = exclusive ? getComputedStyle(document.querySelector('.hero-image')).backgroundImage : getComputedStyle(item).backgroundImage;
    pauseSlideshow();
    menuMusic.pause();
    document.body.classList.add('player-open');
    const start = source.getBoundingClientRect();
    transition = makeTransition(start, getComputedStyle(source).borderRadius);
    const query = new URLSearchParams({ embedded: '1', title: data.title || '', image: data.image || '', synopsis: exclusive ? data.synopsis || '' : decodeURIComponent(data.synopsis || ''), type: data.mediaType || data.type || 'Movie', streams: exclusive ? JSON.stringify(data.streams || []) : data.streams || '[]', seasons: exclusive ? JSON.stringify(data.seasons || []) : data.seasons || '[]', categories: data.meta || '', release: decodeURIComponent(data.release || 'Coming soon'), installer: decodeURIComponent(data.installer || 'null'), licensor: decodeURIComponent(data.licensor || 'Not specified') });
    frame.src = `${game ? 'game' : 'player'}.html?${query}`;
    panel.classList.add('open');
    lobbyRegions.forEach(region => { region.inert = true; });
    backdrop.classList.add('open');
    source.classList.add('player-source-active');
    const node = transition;
    void node.offsetWidth;
    node.style.transition = reduced.matches ? 'none' : 'left .5s ease,top .5s ease,width .5s ease,height .5s ease,border-radius .5s ease';
    Object.assign(node.style, rectStyle(panel.getBoundingClientRect()), { borderRadius: getComputedStyle(panel).borderRadius });
    fallback = setTimeout(() => { ready = true; reveal(); }, 4000);
    await delay(520);
    openingDone = true;
    reveal();
  }
  async function close() {
    if (busy || !panel.classList.contains('open')) return;
    busy = true;
    clearTimeout(fallback);
    try { frame.contentDocument?.querySelector('video')?.pause(); } catch {}
    const node = makeTransition(stageRect(), '24px');
    node.style.opacity = '0';
    void node.offsetWidth;
    node.style.transition = reduced.matches ? 'none' : 'opacity .18s ease';
    node.style.opacity = '1';
    await delay(180);
    panel.classList.remove('open');
    backdrop.classList.remove('open');
    const target = source?.isConnected ? source.getBoundingClientRect() : null;
    node.style.transition = reduced.matches ? 'none' : 'left .55s cubic-bezier(.2,.8,.2,1),top .55s cubic-bezier(.2,.8,.2,1),width .55s cubic-bezier(.2,.8,.2,1),height .55s cubic-bezier(.2,.8,.2,1),border-radius .55s ease,opacity .2s ease';
    if (target && target.width && target.height) Object.assign(node.style, rectStyle(target), { borderRadius: getComputedStyle(source).borderRadius });
    else node.style.opacity = '0';
    await delay(570);
    source?.classList.remove('player-source-active');
    node.style.opacity = '0';
    await delay(200);
    node.remove();
    panel.classList.remove('fullscreen');
    frame.src = 'about:blank';
    document.body.classList.remove('player-open');
    lobbyRegions.forEach(region => { region.inert = false; });
    source?.querySelector('button')?.focus({ preventScroll: true });
    if (source?.matches('button')) source.focus({ preventScroll: true });
    busy = false;
    resumeSlideshow();
    if (musicStarted) menuMusic.play().catch(() => {});
  }
  frame.addEventListener('load', () => { if (panel.classList.contains('open')) { ready = true; reveal(); } });
  addEventListener('message', event => {
    if (event.source !== frame.contentWindow) return;
    if (['ryhze-player-ready', 'ryhze-game-ready'].includes(event.data?.type)) { ready = true; reveal(); }
    if (event.data?.type === 'ryhze-close-player') close();
    if (event.data?.type === 'ryhze-toggle-player-fullscreen' && !busy) {
      panel.classList.toggle('fullscreen');
      frame.contentWindow.postMessage({ type: 'ryhze-embed-fullscreen', fullscreen: panel.classList.contains('fullscreen') }, '*');
    }
  });
  backdrop.addEventListener('click', close);
  addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
  openFilm = item => open(item);
  openGame = item => open(item, false, true);
  openExclusive = item => open(item, true);
})();
