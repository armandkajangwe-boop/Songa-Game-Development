(function () {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const canvas = $("world"), ctx = canvas.getContext("2d");
  const model = new window.SongaRunnerModel();
  const images = {}, particles = [];
  const storageKey = "songa.preview.v1";
  let soundEnabled = true, audio = null, clock = 0, scroll = 0, lastTime = 0;
  let slideLeft = 0, slideHeld = false, keyDuck = false, pointer = null;
  let lastPhase = "", lastBananas = 0, lastLives = 3, rafId = 0;
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

  try {
    const saved = JSON.parse(localStorage.getItem(storageKey) || "{}");
    if (Number.isFinite(saved.best)) model.bestDistance = Math.max(0, saved.best);
    if (typeof saved.sound === "boolean") soundEnabled = saved.sound;
  } catch (_) { /* Storage is optional, including file:// and private browsing. */ }

  function save() {
    try { localStorage.setItem(storageKey, JSON.stringify({best:model.bestDistance,sound:soundEnabled})); } catch (_) {}
  }
  function resize() {
    const scale = Math.min(innerWidth / 540, innerHeight / 960, 1);
    $("frame").style.width = (540 * scale) + "px";
    $("frame").style.height = (960 * scale) + "px";
    $("stage").style.transform = "scale(" + scale + ")";
    const ratio = Math.min(devicePixelRatio || 1, 2);
    canvas.width = Math.round(540 * ratio);
    canvas.height = Math.round(960 * ratio);
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    render();
  }
  function unlockAudio() {
    if (!soundEnabled) return;
    try {
      if (!audio) audio = new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === "suspended") audio.resume().catch(() => {});
    } catch (_) {}
  }
  function cue(kind) {
    if (!soundEnabled || !audio || audio.state !== "running") return;
    const notes = {jump:[280,490],pickup:[784,1047],hit:[145,95],start:[392,523,659,784],end:[523,392,330]}[kind];
    notes.forEach((frequency, i) => {
      const oscillator = audio.createOscillator(), gain = audio.createGain();
      const time = audio.currentTime + i * 0.065;
      oscillator.type = "sine";
      oscillator.frequency.setValueAtTime(frequency, time);
      gain.gain.setValueAtTime(0, time);
      gain.gain.linearRampToValueAtTime(0.11, time + 0.008);
      gain.gain.exponentialRampToValueAtTime(0.001, time + 0.2);
      oscillator.connect(gain); gain.connect(audio.destination);
      oscillator.start(time); oscillator.stop(time + 0.21);
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
    });
  }
  function clearInputs() {
    slideLeft = 0; slideHeld = false; keyDuck = false; pointer = null;
    model.setDucking(false);
  }
  function start(seed) {
    unlockAudio(); clearInputs();
    model.begin(Number.isFinite(seed) ? seed : Math.floor(Math.random() * 0xffffffff));
    scroll = 0; lastBananas = 0; lastLives = 3; particles.length = 0;
    cue("start"); sync();
  }
  function jump() {
    unlockAudio();
    if (model.jump()) { slideLeft = 0; cue("jump"); burst(model.playerX, model.groundY - 2, "#bbbe8b", 5); }
  }
  function pause() {
    if (model.phase !== "running" && model.phase !== "paused") return;
    save(); clearInputs(); model.togglePause(); sync();
  }
  function home() {
    save(); clearInputs(); model.resetToTitle(); particles.length = 0; sync();
  }
  function sync() {
    lastPhase = model.phase;
    $("home").hidden = model.phase !== "title";
    $("run-hud").hidden = model.phase === "title";
    $("paused").hidden = model.phase !== "paused";
    $("results").hidden = model.phase !== "game_over";
    $("jump").disabled = $("slide").disabled = model.phase !== "running";
    $("personal-best").textContent = "PERSONAL BEST " + Math.floor(model.bestDistance) + " m · PLAYABLE PROTOTYPE";
    $("result-distance").textContent = Math.floor(model.distance) + " m";
    $("result-bananas").textContent = model.bananas;
    $("result-best").textContent = "PERSONAL BEST · " + Math.floor(model.bestDistance) + " m";
    $("sound").textContent = soundEnabled ? "SOUND ON" : "SOUND OFF";
    $("sound").setAttribute("aria-pressed", String(soundEnabled));
    $("sound").setAttribute("aria-label", soundEnabled ? "Sound on; select to mute" : "Sound off; select to unmute");
    $("announcer").textContent = {title:"Welcome to Songa.",running:"Run started. Tap to jump, swipe down to slide.",paused:"Game paused.",game_over:"Run finished. " + Math.floor(model.distance) + " metres."}[model.phase];
    hud();
  }
  function hud() {
    $("distance").textContent = Math.floor(model.distance) + " m";
    $("bananas").textContent = model.bananas;
    $("hearts").textContent = "♥ ".repeat(model.lives) + "♡ ".repeat(3 - model.lives);
    $("hearts").setAttribute("aria-label", model.lives + " hearts remaining");
    $("chase-fill").style.width = model.chasePressure * 100 + "%";
    $("hint").textContent = model.elapsed < 3 ? "Let’s go, Songa! Tap to jump." :
      model.elapsed < 6 ? "Jump over rocks and fallen logs." :
      model.elapsed < 10 ? "Swipe down under low branches." : "";
  }
  function burst(x, y, color, count) {
    if (reducedMotion) return;
    for (let i = 0; i < count; i++) {
      const angle = -Math.PI + i * Math.PI / count;
      particles.push({x,y,vx:Math.cos(angle)*(55+i*8),vy:Math.sin(angle)*(55+i*8),life:0.48,color});
    }
  }
  function frame(time) {
    const dt = lastTime ? Math.min((time - lastTime) / 1000, 0.05) : 0;
    lastTime = time;
    if (model.phase === "title" || model.phase === "running") clock += dt;
    if (model.phase === "title") scroll += dt * 26;
    if (model.phase === "running") {
      slideLeft = Math.max(0, slideLeft - dt);
      model.setDucking(slideHeld || keyDuck || slideLeft > 0);
      const distance = model.distance;
      model.tick(dt);
      scroll += (model.distance - distance) * 20;
      if (model.bananas > lastBananas) { cue("pickup"); burst(model.playerX+20, model.playerY-62, "#f5ca62", 9); }
      if (model.lives < lastLives) { cue("hit"); burst(model.playerX, model.playerY-38, "#fff7df", 12); }
      lastBananas = model.bananas; lastLives = model.lives;
      if (model.phase === "game_over") { clearInputs(); cue("end"); save(); }
    }
    if (model.phase !== "paused") for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i]; p.life -= dt;
      if (p.life <= 0) particles.splice(i, 1);
      else { p.x += p.vx*dt; p.y += p.vy*dt; p.vy += 160*dt; }
    }
    if (lastPhase !== model.phase) sync();
    hud(); render();
    rafId = requestAnimationFrame(frame);
  }
  function rounded(x,y,w,h,r,color) {
    ctx.fillStyle = color; ctx.beginPath(); ctx.roundRect(x,y,w,h,r); ctx.fill();
  }
  function sprite(name, x, y, scale, animated, time) {
    const image = images[name]; if (!image) return;
    const index = animated ? ((Math.floor(time * 13 / (2*Math.PI) * 8) % 8) + 8) % 8 : 0;
    ctx.drawImage(image, index * 160, 0, 160, 160, x - 80*scale, y - 148*scale, 160*scale, 160*scale);
  }
  function render() {
    if (!images.backdrop) return;
    ctx.clearRect(0,0,540,960);
    ctx.drawImage(images.backdrop,0,0,540,960);
    // Moving stones and grass along the trail ground the scrolling action.
    for (let i=0;i<22;i++) {
      const x=((i*47-scroll*0.8)%600+600)%600-30, y=752+(i%3)*20;
      ctx.fillStyle = i%2 ? "#82915d" : "#7f7852";
      ctx.beginPath();ctx.ellipse(x,y,3.5+i%3,1.6,0,0,Math.PI*2);ctx.fill();
    }
    const title = model.phase === "title";
    if (!title) {
      for (const obstacle of model.obstacles) drawObstacle(obstacle);
      for (const pickup of model.pickups) drawBanana(pickup.x,pickup.y);
    }
    sprite("adult_run",title?99:25+model.chasePressure*63,title?731:740,title?1.51:1.14,true,clock+0.3);
    const airborne = !model.isGrounded();
    const asset = !title && model.ducking ? "hero_slide" : !title && airborne ? "hero_air" : "hero_run";
    if (model.invulnerability>0 && clock%0.16<0.08) ctx.globalAlpha=0.55;
    sprite(asset,title?324:model.playerX,title?730:model.playerY,title?1.3:0.84,asset==="hero_run",clock);
    ctx.globalAlpha=1;
    for (const p of particles) {
      ctx.globalAlpha=Math.max(0,p.life/0.48);ctx.fillStyle=p.color;
      ctx.beginPath();ctx.arc(p.x,p.y,2.8,0,Math.PI*2);ctx.fill();
    }
    ctx.globalAlpha=1;
  }
  function drawBanana(x,y) {
    const bob = reducedMotion ? 0 : Math.sin(clock*4+x*0.02)*2;
    ctx.fillStyle="#f5ca621c";ctx.beginPath();ctx.arc(x,y+bob-3,17,0,Math.PI*2);ctx.fill();
    ctx.lineCap="round";
    for (const [width,color,offset] of [[7,"#765628",0],[5,"#f5ca62",0],[1.5,"#fff0a9",-2]]) {
      ctx.strokeStyle=color;ctx.lineWidth=width;ctx.beginPath();ctx.arc(x,y+bob-9+offset,12,0.2,2.7);ctx.stroke();
    }
  }
  function drawObstacle(o) {
    const {x,y,width:w,height:h,kind}=o;
    if(kind==="rock"){
      ctx.fillStyle="#354640";ctx.beginPath();ctx.moveTo(x,y+h);ctx.lineTo(x+2,y+19);ctx.lineTo(x+16,y+2);ctx.lineTo(x+w-12,y);ctx.lineTo(x+w,y+18);ctx.lineTo(x+w+2,y+h);ctx.closePath();ctx.fill();
      ctx.fillStyle="#667568";ctx.beginPath();ctx.moveTo(x+2,y+19);ctx.lineTo(x+16,y+2);ctx.lineTo(x+w-12,y);ctx.lineTo(x+25,y+h-8);ctx.closePath();ctx.fill();
      ctx.strokeStyle="#99a079";ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(x+16,y+2);ctx.lineTo(x+w-12,y);ctx.stroke();
    }else if(kind==="log"){
      rounded(x-2,y+2,w+4,h+1,12,"#433a2b");rounded(x,y+4,w,h-4,10,"#95643b");
      ctx.strokeStyle="#5e442d";ctx.lineWidth=2;
      for(let i=0;i<3;i++){ctx.beginPath();ctx.moveTo(x+6,y+11+i*8);ctx.lineTo(x+w-10,y+8+i*9);ctx.stroke();}
      ctx.fillStyle="#ca9d61";ctx.beginPath();ctx.arc(x+w-9,y+h/2+3,h*0.37,0,Math.PI*2);ctx.fill();
      ctx.strokeStyle="#966c42";ctx.beginPath();ctx.arc(x+w-9,y+h/2+3,h*0.22,0,Math.PI*2);ctx.stroke();
    }else{
      ctx.strokeStyle="#304b35";ctx.lineWidth=13;ctx.beginPath();ctx.moveTo(x-8,y+14);ctx.lineTo(x+w+16,y+28);ctx.stroke();
      ctx.strokeStyle="#79945a";ctx.lineWidth=6;ctx.beginPath();ctx.moveTo(x-8,y+10);ctx.lineTo(x+w+16,y+24);ctx.stroke();
      for(let i=0;i<6;i++){
        const ax=x+i*w/5, ay=y+20, ex=ax+Math.sin(i*3)*12, ey=ay+h-24;
        ctx.strokeStyle="#45623d";ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(ax,ay);ctx.lineTo(ex,ey);ctx.stroke();
        for(let j=0;j<3;j++){
          const t=0.3+j*0.24,px=ax+(ex-ax)*t,py=ay+(ey-ay)*t,side=(i+j)%2?-1:1;
          ctx.fillStyle=i%2?"#658148":"#385b3c";ctx.beginPath();ctx.moveTo(px,py);ctx.lineTo(px+side*19,py-12);ctx.lineTo(px+side*16,py+9);ctx.lineTo(px,py+12);ctx.closePath();ctx.fill();
        }
      }
      rounded(x+w/2-28,y-35,56,22,6,"#fff9e5ee");
      ctx.font="800 10px Songa";ctx.textAlign="center";ctx.fillStyle="#183e33";ctx.fillText("SLIDE ↓",x+w/2,y-20);
    }
  }

  $("start").addEventListener("click",()=>start());
  $("restart").addEventListener("click",()=>start());
  $("pause").addEventListener("click",pause);
  $("resume").addEventListener("click",pause);
  $("pause-home").addEventListener("click",home);
  $("result-home").addEventListener("click",home);
  $("sound").addEventListener("click",()=>{
    soundEnabled=!soundEnabled;
    if(soundEnabled) unlockAudio();
    else if(audio) audio.suspend().catch(()=>{});
    save();sync();
  });
  $("jump").addEventListener("pointerdown",(e)=>{
    if(model.phase!=="running")return;e.preventDefault();jump();
  });
  $("jump").addEventListener("click",(e)=>{if(e.detail===0)jump();});
  $("slide").addEventListener("pointerdown",(e)=>{
    if(model.phase!=="running")return;e.preventDefault();slideHeld=true;
    $("slide").setPointerCapture(e.pointerId);
  });
  for(const name of ["pointerup","pointercancel","lostpointercapture"])
    $("slide").addEventListener(name,()=>{slideHeld=false;});
  $("slide").addEventListener("click",(e)=>{if(e.detail===0&&model.phase==="running")slideLeft=0.85;});
  const local=(e)=>{const r=canvas.getBoundingClientRect();return{x:(e.clientX-r.left)*540/r.width,y:(e.clientY-r.top)*960/r.height};};
  canvas.addEventListener("pointerdown",(e)=>{
    if(model.phase!=="running"||pointer)return;e.preventDefault();unlockAudio();
    pointer={id:e.pointerId,...local(e),swiped:false};canvas.setPointerCapture(e.pointerId);
  });
  function pointerMove(e){
    if(!pointer||pointer.id!==e.pointerId)return;
    if(local(e).y-pointer.y>44&&!pointer.swiped){pointer.swiped=true;slideLeft=0.85;}
  }
  canvas.addEventListener("pointermove",pointerMove);
  canvas.addEventListener("pointerup",(e)=>{
    if(!pointer||pointer.id!==e.pointerId)return;pointerMove(e);
    if(!pointer.swiped)jump();pointer=null;
  });
  canvas.addEventListener("pointercancel",()=>{pointer=null;});
  const shortcuts=new Set(["Space","ArrowUp","KeyW","ArrowDown","KeyS","ShiftLeft","ShiftRight","KeyP","Escape"]);
  function keyboard(e){
    if(!shortcuts.has(e.code))return;e.preventDefault();e.stopPropagation();
    if(e.repeat)return;
    const down=e.type==="keydown";
    if(["ArrowDown","KeyS","ShiftLeft","ShiftRight"].includes(e.code)){keyDuck=down;return;}
    if(!down)return;unlockAudio();
    if(e.code==="Escape"||e.code==="KeyP"){pause();return;}
    if(model.phase==="title"||model.phase==="game_over")start();else jump();
  }
  addEventListener("keydown",keyboard,true);addEventListener("keyup",keyboard,true);
  function background(){
    save();if(model.phase==="running"){clearInputs();model.togglePause();sync();}
  }
  addEventListener("blur",background);addEventListener("pagehide",save);
  document.addEventListener("visibilitychange",()=>{if(document.hidden)background();});
  addEventListener("resize",resize);
  window.SongaPreview={model,start,pause,home,render,sync,save,
    get ready(){return $("loading").hidden;},
    // Useful when testing embeds, not an additional gameplay control.
    stop(){cancelAnimationFrame(rafId);}
  };
  Promise.all(Object.entries(window.SONGA_ASSETS).map(([name,url])=>new Promise((resolve,reject)=>{
    const image=new Image();image.onload=()=>{images[name]=image;resolve();};image.onerror=reject;image.src=url;
  }))).then(()=>document.fonts.ready).then(()=>{
    $("loading").hidden=true;resize();sync();rafId=requestAnimationFrame(frame);
  }).catch(()=>{
    $("loading").innerHTML="<span>The forest could not load. Please download the complete HTML file and open it in Chrome, Edge, Firefox, or Safari.</span>";
  });
}());
