const library = window.RyhzeLibrary || { films: [], games: [] };
const state = { mode: new URLSearchParams(location.search).get('mode') === 'games' ? 'games' : 'films' };
const menuMusic = document.querySelector('#menuMusic'); let musicStarted = false, timer, featuredIndex = 0, currentExclusive, listKey = 'ryhze-list';
menuMusic.volume = .25;
const unique = groups => [...new Map(groups.flatMap(group => group.items || []).map(item => [item.title,item])).values()];
const readList = () => { try { const value = JSON.parse(localStorage.getItem(listKey) || '[]'); return Array.isArray(value) ? value : []; } catch { return []; } };
const notify = message => { const node = document.querySelector('#toast'); node.textContent = message; node.classList.add('show'); clearTimeout(node.timer); node.timer = setTimeout(() => node.classList.remove('show'), 2500); };
const safeImage = value => { try { const url = new URL(value, location.origin); return value && url.origin === location.origin && /^\/(Films|Games|assets)\//.test(url.pathname) ? url.href : ''; } catch { return ''; } };
function card(item, game = state.mode === 'games') {
  const button = document.createElement('button'); button.className = 'card';
  Object.assign(button.dataset, { title: item.title, image: safeImage(item.image), synopsis: encodeURIComponent(item.synopsis || ''), type: item.mediaType || 'Movie', streams: encodeURIComponent(JSON.stringify(item.streams || [])), seasons: encodeURIComponent(JSON.stringify(item.seasons || [])), meta: (item.categories || []).join(', '), release: encodeURIComponent(item.release || 'Coming soon'), installer: encodeURIComponent(JSON.stringify(item.installer || null)), licensor: encodeURIComponent(item.licensor || '') });
  if (safeImage(item.image)) button.style.backgroundImage = `url("${safeImage(item.image)}")`;
  const info = document.createElement('span'); info.className = 'card-info'; const name = document.createElement('strong'); name.className = 'card-title'; name.textContent = item.title; info.append(name); button.append(info);
  button.addEventListener('click', () => game ? openGame(button) : openFilm(button)); return button;
}
function pauseSlideshow() { clearTimeout(timer); }
function resumeSlideshow() { pauseSlideshow(); if (document.body.classList.contains('player-open') || document.hidden || matchMedia('(prefers-reduced-motion: reduce)').matches) return; timer = setTimeout(() => { featuredIndex++; renderHero(); resumeSlideshow(); }, 12000); }
function openFilm() {} function openGame() {} function openExclusive() {}
function featured() { const groups = library[state.mode] || []; return groups.find(group => group.title.toLowerCase() === 'exclusives')?.items || unique(groups).slice(0,5); }
function renderHero() {
  const items = featured(), hero = document.querySelector('#heroCopy'), dots = document.querySelector('#exclusiveDots');
  currentExclusive = items[featuredIndex % items.length]; hero.replaceChildren(); dots.replaceChildren();
  if (!currentExclusive) { const heading = document.createElement('h1'); heading.textContent = 'More to discover, soon.'; hero.append(heading); return; }
  const item = currentExclusive, art = safeImage(item.exclusiveImages?.[0] || item.image);
  document.querySelector('.hero-image').style.backgroundImage = art ? `url("${art}")` : 'none';
  const label = document.createElement('p'); label.className = 'eyebrow'; label.textContent = 'Featured on Ryhze';
  const title = document.createElement('h1'); title.textContent = item.title;
  const description = document.createElement('p'); description.textContent = item.synopsis || 'Details coming soon.';
  const actions = document.createElement('div'); actions.className = 'actions';
  const watch = document.createElement('button'); watch.className = 'primary'; watch.textContent = state.mode === 'games' ? 'Explore game' : 'View film'; watch.onclick = () => { if (state.mode === 'games') { const match = [...document.querySelectorAll('.card')].find(node => node.dataset.title === item.title); if (match) openGame(match); } else openExclusive(item); };
  const list = document.createElement('button'); const sync = () => list.textContent = readList().includes(item.title) ? 'Remove from My List' : 'Add to My List'; sync(); list.onclick = () => { let titles = readList(); titles = titles.includes(item.title) ? titles.filter(title => title !== item.title) : [...titles,item.title]; try { localStorage.setItem(listKey,JSON.stringify(titles)); } catch { notify('Browser storage is unavailable.'); return; } sync(); renderRows(); };
  actions.append(watch,list); hero.append(label,title,description,actions);
  items.forEach((item,index) => { const dot = document.createElement('button'); dot.className = 'exclusive-dot' + (index === featuredIndex % items.length ? ' active' : ''); dot.setAttribute('aria-label',item.title); dot.setAttribute('aria-pressed',String(index === featuredIndex % items.length)); dot.onclick = () => { featuredIndex=index;renderHero();resumeSlideshow(); }; dots.append(dot); });
  if (!matchMedia('(prefers-reduced-motion: reduce)').matches) hero.animate([{opacity:0,transform:'translateY(10px)'},{opacity:1,transform:'none'}],{duration:450,easing:'ease-out'});
}
let pendingRows = false;
addEventListener('ryhze-player-closed', () => { if (pendingRows) { pendingRows = false; renderRows(); } });
function renderRows() {
  if (document.body.classList.contains('player-open')) { pendingRows = true; return; }
  const content = document.querySelector('#content'); content.replaceChildren();
  const groups = [...(library[state.mode] || [])], saved = unique(groups).filter(item => readList().includes(item.title));
  if (saved.length) groups.unshift({title:'My List',items:saved});
  groups.forEach(group => { const section=document.createElement('section');section.className='section'; const heading=document.createElement('h2');heading.className='section-head';heading.textContent=group.title==='Uncategorized'?'Explore titles':group.title;const row=document.createElement('div');row.className='row'+(state.mode==='games'?' games-row':'');(group.items||[]).forEach(item=>row.append(card(item)));section.append(heading,row);content.append(section); });
  if (!groups.length) { const message=document.createElement('p');message.className='empty-state';message.textContent='New titles will appear here when they are ready.';content.append(message); }
}
function render() { document.querySelectorAll('.tab').forEach(tab => { const active=tab.dataset.mode===state.mode;tab.classList.toggle('active',active);tab.setAttribute('aria-pressed',String(active)); });document.querySelector('#search').placeholder=`Search ${state.mode}`;renderHero();renderRows();resumeSlideshow(); }
document.querySelectorAll('.tab').forEach(tab => tab.addEventListener('click',()=>{if(state.mode===tab.dataset.mode)return;state.mode=tab.dataset.mode;featuredIndex=0;document.querySelector('#search').value='';document.querySelector('#searchResults').hidden=true;render();history.replaceState(null,'',`/menu/?mode=${state.mode}`);}));
document.querySelector('#search').addEventListener('input', event => { const text=event.target.value.trim().toLowerCase(),results=document.querySelector('#searchResults');results.replaceChildren();results.hidden=!text;if(!text)return;const matches=unique(library[state.mode]||[]).filter(item=>[item.title,...(item.categories||[])].join(' ').toLowerCase().includes(text)).slice(0,12);if(!matches.length){results.textContent='No matching titles';return;}matches.forEach(item=>{const button=document.createElement('button');button.className='search-result';button.textContent=item.title;button.onclick=()=>{results.hidden=true;const target=[...document.querySelectorAll('.card')].find(node=>node.dataset.title===item.title);if(target){target.scrollIntoView({block:'center',behavior:'smooth'});target.focus({preventScroll:true});}};results.append(button);}); });
document.querySelector('#profile').addEventListener('click',event=>{const menu=document.querySelector('#accountMenu');menu.hidden=!menu.hidden;event.currentTarget.setAttribute('aria-expanded',String(!menu.hidden));});
document.addEventListener('click',event=>{if(!event.target.closest('.search-wrap'))document.querySelector('#searchResults').hidden=true;if(!event.target.closest('#profile,#accountMenu')){document.querySelector('#accountMenu').hidden=true;document.querySelector('#profile').setAttribute('aria-expanded','false');}});
document.addEventListener('keydown',event=>{if(event.key==='Escape'){document.querySelector('#searchResults').hidden=true;document.querySelector('#accountMenu').hidden=true;}});
document.querySelector('#musicToggle').onclick=async event=>{musicStarted=!musicStarted;try{if(musicStarted)await menuMusic.play();else menuMusic.pause();}catch{musicStarted=false;}event.target.textContent=musicStarted?'Music on':'Music off';event.target.setAttribute('aria-pressed',String(musicStarted));};
document.addEventListener('visibilitychange',()=>{if(document.hidden){pauseSlideshow();menuMusic.pause();}else{resumeSlideshow();if(musicStarted&&!document.body.classList.contains('player-open'))menuMusic.play().catch(()=>{});}});
window.addEventListener('storage',event=>{if(event.key===listKey)renderRows();});
window.addEventListener('message',event=>{if(event.origin===location.origin&&event.source===document.querySelector('#menuPlayerFrame')?.contentWindow&&event.data?.type==='ryhze-list-updated')renderRows();});
RyhzeSession.then(user=>{if(!user)return;listKey='ryhze-list:'+user.username;document.querySelector('#accountName').textContent=user.username;document.querySelector('#adminLink').hidden=user.role!=='admin';renderRows();});
fetch('/api/health').then(response=>{document.querySelector('#connectionStatus').textContent=response.ok?'Cloud streaming · '+(window.RyhzeSiteVersion||''):'Cloud connection unavailable';}).catch(()=>document.querySelector('#connectionStatus').textContent='Connection unavailable');
render();
