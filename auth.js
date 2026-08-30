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

  const grant = user => {
    localStorage.setItem(accessKey, 'granted');
    localStorage.setItem(userKey, user);
    gate.classList.add('hidden');
  };

  const savedUser = localStorage.getItem(userKey);
  if (localStorage.getItem(accessKey) === 'granted' && accounts.has(savedUser)) {
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
    gate.classList.remove('hidden');
    userInput.focus();
  });
})();
