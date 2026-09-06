(() => {
  const watch = document.querySelector('#watch');
  const video = document.querySelector('#video');
  const ui = document.querySelector('#playerUi');
  document.body.append(ui);
  const status = document.createElement('p');
  status.className = 'status';
  status.setAttribute('role', 'status');
  watch.after(status);
  const availability = () => {
    watch.disabled = !streams.length;
    watch.textContent = streams.length ? 'Watch now' : 'Coming soon';
    status.textContent = streams.length ? '' : 'This title’s video is not available yet.';
  };
  availability();
  document.querySelector('#exitPlayer').addEventListener('click', async event => {
    if (embeddedPlayer) return;
    event.stopImmediatePropagation();
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch { status.textContent = 'Full screen is unavailable in this browser.'; }
  }, { capture: true });
  document.addEventListener('fullscreenchange', () => {
    const button = document.querySelector('#exitPlayer');
    button.textContent = document.fullscreenElement ? '×' : '⛶';
    button.setAttribute('aria-label', document.fullscreenElement ? 'Exit full screen' : 'Enter full screen');
  });
  document.querySelectorAll('.series-options').forEach(menu => menu.addEventListener('click', availability));
  const pause = document.createElement('button');
  pause.className = 'back';
  pause.textContent = 'Pause';
  ui.prepend(pause);
  pause.addEventListener('click', () => video.paused ? video.play().catch(() => {}) : video.pause());
  video.addEventListener('play', () => { pause.textContent = 'Pause'; });
  video.addEventListener('pause', () => { pause.textContent = 'Play'; });
  video.addEventListener('ended', () => {
    video.style.display = 'none';
    ui.hidden = true;
    document.body.classList.remove('playing');
    watch.textContent = 'Watch again';
  });
  addEventListener('keydown', event => {
    if (event.key === 'Escape' && embeddedPlayer) parent.postMessage({ type: 'ryhze-close-player' }, '*');
  });
})();
