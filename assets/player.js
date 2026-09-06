(async () => {
  const user = await RyhzeSession; if (!user) return;
  const params=new URLSearchParams(location.search),embedded=params.get('embedded')==='1',title=params.get('title')||'Ryhze';
  const read=key=>{try{return JSON.parse(params.get(key)||'[]');}catch{try{return JSON.parse(decodeURIComponent(params.get(key)||'[]'));}catch{return [];}}};
  const video=document.querySelector('#video'),watch=document.querySelector('#watch'),poster=document.querySelector('#poster'),message=document.querySelector('#message'),controls=document.querySelector('#controls'),seek=document.querySelector('#seek'),playPause=document.querySelector('#playPause');
  let streams=read('streams'),seasons=read('seasons'),loading=false,dragging=false,playbackGeneration=0;
  if(!Array.isArray(streams))streams=[];if(!Array.isArray(seasons))seasons=[];
  const mediaUrl=stream=>{try{const url=new URL(stream.url||stream.publicUrl,location.origin);return url.origin===location.origin&&/^\/media\/(Films|Games)\//.test(url.pathname)?url.href:null;}catch{return null;}};
  const image=params.get('image');if(image){try{const url=new URL(image,location.origin);if(url.origin===location.origin&&/^\/(Films|Games|assets)\//.test(url.pathname))document.querySelector('#stage').style.backgroundImage=`url("${url.href}")`;}catch{}}
  document.title=title+' — Ryhze';document.querySelector('#title').textContent=title;
  const syncAvailability=()=>{const available=streams.some(mediaUrl);watch.disabled=!available;watch.textContent=available?'Watch now':'Coming soon';message.textContent=available?'':'The video for this title has not been added yet.';};
  const stop=()=>{playbackGeneration++;video.pause();video.removeAttribute('src');video.load();video.hidden=true;poster.hidden=false;controls.hidden=true;loading=false;dragging=false;seek.value=0;watch.disabled=!streams.some(mediaUrl);};
  if(seasons.length){document.querySelector('#series').hidden=false;const season=document.querySelector('#season'),episode=document.querySelector('#episode');seasons.forEach((item,index)=>season.add(new Option(item.title||`Season ${index+1}`,index)));const episodes=()=>{episode.replaceChildren();(seasons[Number(season.value)]?.episodes||[]).forEach((item,index)=>episode.add(new Option(item.title||`Episode ${index+1}`,index)));select();};const select=()=>{stop();streams=seasons[Number(season.value)]?.episodes?.[Number(episode.value)]?.streams||[];syncAvailability();};season.onchange=episodes;episode.onchange=select;episodes();}
  syncAvailability();
  const fmt=value=>Number.isFinite(value)?`${Math.floor(value/60)}:${String(Math.floor(value%60)).padStart(2,'0')}`:'0:00';
  const time=()=>{if(!dragging)seek.value=Number.isFinite(video.duration)?video.currentTime/video.duration*100:0;document.querySelector('#time').textContent=`${fmt(dragging?video.duration*Number(seek.value)/100:video.currentTime)} / ${fmt(video.duration)}`;};
  async function start(){
    if(loading)return;
    const generation=++playbackGeneration;
    loading=true;watch.disabled=true;message.textContent='Loading video…';
    const sources=streams.map(mediaUrl).filter(Boolean);let played=false;
    for(const source of sources){
      if(generation!==playbackGeneration)return;
      video.src=source;
      try{await video.play();if(generation!==playbackGeneration)return;played=true;break;}catch{if(generation!==playbackGeneration)return;}
    }
    loading=false;
    if(played){video.hidden=false;poster.hidden=true;controls.hidden=false;}
    else{stop();syncAvailability();message.textContent='Unable to play this video. Try again or choose another episode.';}
    watch.disabled=!streams.some(mediaUrl);
  }
  watch.onclick=start;
  playPause.onclick=()=>video.paused?video.play().catch(()=>{message.textContent='Playback could not resume.';}):video.pause();
  video.onplay=()=>{playPause.textContent='Ⅱ';playPause.setAttribute('aria-label','Pause');};video.onpause=()=>{playPause.textContent='▶';playPause.setAttribute('aria-label','Play');};
  video.ontimeupdate=time;video.onloadedmetadata=time;video.onended=()=>{stop();watch.textContent='Watch again';};video.onerror=()=>{if(!loading&&video.getAttribute('src')){stop();message.textContent='The stream stopped. Select Watch now to retry.';}};
  seek.addEventListener('pointerdown',()=>{dragging=true;});seek.addEventListener('input',()=>{dragging=true;time();});const commit=()=>{if(Number.isFinite(video.duration))video.currentTime=Number(seek.value)/100*video.duration;dragging=false;time();};seek.addEventListener('change',commit);seek.addEventListener('pointerup',commit);seek.addEventListener('pointercancel',()=>{dragging=false;time();});
  document.querySelector('#mute').onclick=event=>{video.muted=!video.muted;event.currentTarget.textContent=video.muted?'×♪':'♪';event.currentTarget.setAttribute('aria-label',video.muted?'Unmute':'Mute');};
  const back=()=>{stop();if(embedded)parent.postMessage({type:'ryhze-close-player'},location.origin);else location.href='/menu/';};document.querySelector('#back').onclick=back;
  document.querySelector('#fullscreen').onclick=async()=>{if(embedded)parent.postMessage({type:'ryhze-toggle-player-fullscreen'},location.origin);else{try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen();}catch{}}};
  addEventListener('message',event=>{if(event.source!==parent||event.origin!==location.origin)return;if(event.data?.type==='ryhze-embed-fullscreen'){const button=document.querySelector('#fullscreen');button.textContent=event.data.fullscreen?'×':'⛶';button.setAttribute('aria-label',event.data.fullscreen?'Exit full screen':'Enter full screen');}});
  addEventListener('keydown',event=>{if(event.key==='Escape'&&embedded)back();});
  const key='ryhze-list:'+user.username,list=document.querySelector('#list');const saved=()=>{try{const value=JSON.parse(localStorage.getItem(key)||'[]');return Array.isArray(value)?value:[];}catch{return [];}};const syncList=()=>list.textContent=saved().includes(title)?'Remove from My List':'Add to My List';list.onclick=()=>{let titles=saved();titles=titles.includes(title)?titles.filter(value=>value!==title):[...titles,title];try{localStorage.setItem(key,JSON.stringify(titles));syncList();if(embedded)parent.postMessage({type:'ryhze-list-updated'},location.origin);}catch{message.textContent='Browser storage is unavailable.';}};syncList();
  if(embedded)parent.postMessage({type:'ryhze-player-ready'},location.origin);
})();
