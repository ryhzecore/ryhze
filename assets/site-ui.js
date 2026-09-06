window.RyhzeSession = fetch('/api/session', { cache: 'no-store' }).then(async response => {
  if (!response.ok) { location.replace('/login?next=' + encodeURIComponent(location.pathname + location.search)); return null; }
  return (await response.json()).user;
}).catch(() => { document.querySelector('#connectionStatus')?.replaceChildren('Connection lost. Reload to try again.'); return null; });
document.addEventListener('click', async event => {
  const button = event.target.closest('[data-logout]');
  if (!button) return;
  button.disabled = true;
  try { const result = await fetch('/api/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }); if (!result.ok) throw Error(); location.replace('/login'); }
  catch { button.disabled = false; button.textContent = 'Retry sign out'; }
});
if (new URLSearchParams(location.search).get('embedded') === '1') document.addEventListener('keydown', event => {
  if (event.key !== 'Tab') return;
  const targets = [...document.querySelectorAll('button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled)')].filter(node => node.getBoundingClientRect().width > 0);
  const first = targets[0], last = targets[targets.length - 1];
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
});
