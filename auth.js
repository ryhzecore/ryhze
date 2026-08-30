(() => {
  const gate = document.querySelector('#accessGate');
  if (!gate) return;

  const form = document.querySelector('#accessForm');
  const error = document.querySelector('#accessError');
  const userInput = document.querySelector('#accessUser');
  const accounts = new Map([
    ['Leo', 'AndruDummy0199'],
    ['Yassine', 'AndruDummy0199']
  ]);
  const accessKey = 'ryhze-access';
  const userKey = 'ryhze-user';
  const cookieKey = 'ryhze_access=granted';
  const cookieUserKey = 'ryhze_user=';
  const setAccess = user => {
    localStorage.setItem(accessKey, 'granted');
    localStorage.setItem(userKey, user);
    document.cookie = `${cookieKey}; Max-Age=31536000; Path=/; SameSite=Lax`;
    document.cookie = `${cookieUserKey}${encodeURIComponent(user)}; Max-Age=31536000; Path=/; SameSite=Lax`;
  };

  const grant = user => {
    setAccess(user);
    gate.classList.add('hidden');
  };

  const savedUser = localStorage.getItem(userKey) || decodeURIComponent(document.cookie.split('; ').find(item => item.startsWith(cookieUserKey))?.slice(cookieUserKey.length) || '');
  const cookieGranted = document.cookie.split('; ').includes(cookieKey);
  if ((localStorage.getItem(accessKey) === 'granted' || cookieGranted) && accounts.has(savedUser)) {
    grant(savedUser);
  }

  form.addEventListener('submit', event => {
    event.preventDefault();
    const user = userInput.value.trim();
    const credential = document.querySelector('#accessPassword').value;
    if (accounts.get(user) === credential) {
      error.textContent = '';
      grant(user);
    } else {
      error.textContent = 'Incorrect user ID or password.';
    }
  });

  document.querySelector('.join').addEventListener('click', () => {
    localStorage.removeItem(accessKey);
    localStorage.removeItem(userKey);
    document.cookie = `${cookieKey}; Max-Age=0; Path=/; SameSite=Lax`;
    document.cookie = `${cookieUserKey}; Max-Age=0; Path=/; SameSite=Lax`;
    gate.classList.remove('hidden');
    userInput.focus();
  });
})();
