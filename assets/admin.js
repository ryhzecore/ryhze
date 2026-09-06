(async () => {
  const user = await window.RyhzeSession; if (!user) return;
  const list = document.querySelector('#users'), message = document.querySelector('#message');
  async function refresh() {
    const response = await fetch('/api/admin/users');
    if (!response.ok) { message.textContent = 'Administrator access is required.'; return; }
    list.replaceChildren();
    for (const account of await response.json()) {
      const row = document.createElement('div'); row.className = 'user-row';
      const label = document.createElement('span'); label.textContent = `${account.username} · ${account.role}${account.disabled ? ' · disabled' : ''}`; row.append(label);
      if (account.username !== user.username && !account.disabled) { const button = document.createElement('button'); button.textContent = 'Disable'; button.onclick = async () => { button.disabled = true; const response = await fetch('/api/admin/disable', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: account.id }) }); if (response.ok) refresh(); else { message.textContent = 'Unable to disable this account.'; button.disabled = false; } }; row.append(button); }
      list.append(row);
    }
  }
  document.querySelector('form').addEventListener('submit', async event => {
    event.preventDefault(); const button = event.target.querySelector('button'); button.disabled = true;
    try { const response = await fetch('/api/admin/invite', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: new FormData(event.target).get('username') }) }); const result = await response.json(); if (!response.ok) throw Error(result.error); const link = document.createElement('a'); link.href = result.url; link.textContent = result.url; link.className = 'invite-link'; message.replaceChildren('Share this one-time link privately with the intended user. ', link); refresh(); } catch (error) { message.textContent = error.message; } finally { button.disabled = false; }
  });
  refresh();
})();
