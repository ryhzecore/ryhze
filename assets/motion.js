(() => {
  // Smooth motion is the site's requested default; visitors can explicitly reduce it.
  const key = 'ryhze-motion';
  let mode = 'smooth';
  try { if (localStorage.getItem(key) === 'reduced') mode = 'reduced'; } catch {}
  const apply = () => {
    document.documentElement.dataset.motion = mode;
    document.querySelectorAll('[data-motion-toggle]').forEach(button => {
      button.textContent = mode === 'smooth' ? 'Smooth animations on' : 'Reduced animations on';
      button.setAttribute('aria-pressed', String(mode === 'smooth'));
    });
  };
  window.RyhzeMotion = { get reduced() { return mode === 'reduced'; } };
  apply();
  document.addEventListener('DOMContentLoaded', apply);
  document.addEventListener('click', event => {
    if (!event.target.closest('[data-motion-toggle]')) return;
    mode = mode === 'smooth' ? 'reduced' : 'smooth';
    try { localStorage.setItem(key, mode); } catch {}
    apply(); window.dispatchEvent(new Event('ryhze-motion-changed'));
  });
  window.addEventListener('storage', event => {
    if (event.key !== key) return;
    mode = event.newValue === 'reduced' ? 'reduced' : 'smooth';
    apply(); window.dispatchEvent(new Event('ryhze-motion-changed'));
  });
})();
