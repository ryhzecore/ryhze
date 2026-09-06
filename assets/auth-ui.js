(() => {
  // Old, writable browser flags never represent authentication.
  try { ['ryhze-access','ryhze-user','ryhze-active-playbacks','ryhzeAnalytics'].forEach(key => { localStorage.removeItem(key); sessionStorage.removeItem(key); }); } catch {}
  const form = document.querySelector('form'), error = document.querySelector('[role=alert]');
  if (!form) return;
  const activation = form.id === 'activateForm';
  const invitation = activation ? location.hash.slice(1) : '';
  if (activation) history.replaceState(null, '', location.pathname);
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const button = form.querySelector('[type=submit]');
    if (button.disabled) return;
    error.textContent = ''; button.disabled = true; button.textContent = activation ? 'Setting up…' : 'Signing in…';
    const data = new FormData(form);
    try {
      const response = await fetch(activation ? '/api/activate' : '/api/login', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(activation ? { token: invitation, password: data.get('password') } : { username: data.get('username'), password: data.get('password'), remember: data.get('remember') === 'on' }) });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Please try again.');
      if (activation) { location.replace('/login?activated=1'); return; }
      const check = await fetch('/api/session', { cache: 'no-store' });
      if (!check.ok) throw new Error('Cookies are blocked. Allow cookies for Ryhze to sign in.');
      const next = new URLSearchParams(location.search).get('next') || '/menu/';
      location.replace(/^\/(?!\/)/.test(next) && !/[\\\r\n]/.test(next) ? next : '/menu/');
    } catch (failure) { error.textContent = failure.message || 'Unable to connect. Please try again.'; }
    finally { button.disabled = false; button.textContent = activation ? 'Set password' : 'Sign in'; }
  });
  if (new URLSearchParams(location.search).has('activated')) document.querySelector('.status').textContent = 'Your password is set. Sign in to continue.';
})();
