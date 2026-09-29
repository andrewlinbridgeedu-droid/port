import {createProgression} from './map-progression.js';
import {createProgressFog} from './progression-fog.js';
import {createStreetClown} from './street-clown.js';
import {createPostmanRoute} from './postman-route.js';
import {walkableAreas,pavementObstacles} from './walkable-areas.js';
import {blocked,safeEdge,canStand,segmentDistance,createNavigator} from './navigation-runtime.js';
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {clone} from 'three/addons/utils/SkeletonUtils.js';
const $=id=>document.getElementById(id), scene=new THREE.Scene();
const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setSize(innerWidth,innerHeight);renderer.setClearColor(0xc9d1dc);renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.NoToneMapping;document.body.prepend(renderer.domElement);
scene.add(new THREE.HemisphereLight(0xfff5e2,0x7785a8,2.5));let sun=new THREE.DirectionalLight(0xfff2df,2);sun.position.set(-10,25,18);scene.add(sun);
const camera=new THREE.OrthographicCamera(), C=Math.SQRT1_2;
let postOfficeLabel,postOfficePosition,navigator,nav,env,hero,run,idle,mixer,queue=[],currentNode=0,auto=false,debug=false,showPaths=false,drag=null,zoom=innerWidth<600?17:22;
let pendingNeighbor=null;
const center=new THREE.Vector3(),npcs=[],ground=new THREE.Plane(new THREE.Vector3(0,1,0),0),ray=new THREE.Raycaster();
const toWorld=p=>new THREE.Vector3((p[0]-1024)*80/2048,0,(p[1]-571.5)*80/2048/C);
const originalMaterials=new Map(),routeGroup=new THREE.Group();scene.add(routeGroup);
function updateCamera(){const a=innerWidth/innerHeight;zoom=Math.min(zoom,44);const hx=zoom*a/2,hy=zoom/2;center.x=THREE.MathUtils.clamp(center.x,-40+Math.min(hx,40),40-Math.min(hx,40));center.z=THREE.MathUtils.clamp(center.z*C,-22.32+hy,22.32-hy)/C;camera.left=-zoom*a/2;camera.right=zoom*a/2;camera.top=zoom/2;camera.bottom=-zoom/2;camera.near=.1;camera.far=300;camera.position.copy(center).add(new THREE.Vector3(debug?12:0,40,40));camera.lookAt(center);camera.updateProjectionMatrix();}
function message(text){$('hint').textContent=text;}
// WKWebView image-bitmap decoding is unreliable for large embedded textures.
self.createImageBitmap = undefined;
const loader=new GLTFLoader();
const previewProgress=new URLSearchParams(location.search).get('progress');
let progression=createProgression(window.__mapProgress??previewProgress??0,window.__mapBypass??(location.protocol!=='mistport-map:'&&previewProgress===null));
let playerNavigator=createNavigator(progression.allows);const fog=createProgressFog(scene,toWorld);fog.update(progression);
window.setMapProgress=(count,bypass=false)=>{
 if(progression.count===count&&progression.bypass===bypass)return;
 progression=createProgression(count,bypass);playerNavigator=createNavigator(progression.allows);fog.update(progression);queue=[];
 if(hero&&!progression.allows(toPixel(hero.position)))hero.position.copy(toWorld(playerNavigator.nearest(toPixel(hero.position))));
 message('街区已随剧情进度更新');
};
try{
nav=await fetch('./navigation.json').then(r=>r.json());
// Stable citizen identities come from the authored harbour population. Reuse the
// shipped character meshes for citizens absent from the older 12-person street.
const citizens=(await fetch('./harbor-pedestrians.json').then(r=>r.json())).citizens;
for(const entry of nav.npcs)entry.id=entry.model;
const citizenModels={'west-lane':'scholar','cafe-lane':'cafe_keeper','market-lane':'florist','clock-square':'visitor','east-houses':'street_warden','upper-road':'street_warden','south-quay':'merchant','cathedral-road':'courier','flower-seller-walk':'florist','sailor-walk':'dockworker','archive-apprentice-walk':'scholar'};
for(const citizen of citizens){
 if(nav.npcs.some(n=>n.id===citizen.id))continue;
 const route=citizen.routes[0],position=route[Math.min(route.length-1,Math.floor((citizen.phase||0)*route.length))];
 nav.npcs.push({id:citizen.id,name:citizen.name,model:citizenModels[citizen.id]||'visitor',position,text:citizen.dialogue});
}

navigator=createNavigator();nav.nodes=nav.nodes.map(p=>navigator.nearest(p));
const modelNames=[...new Set(nav.npcs.map(n=>n.model))];
const [world,model,standing,...crowdModels]=await Promise.all([loader.loadAsync('./wisteria-environment.gltf'),loader.loadAsync('./characters/hero-user-running.gltf'),loader.loadAsync('./characters/hero-user-idle.gltf'),...modelNames.map(name=>loader.loadAsync('./characters/'+(name==='postman'?'postman-user':name)+'-idle.gltf'))]);
const walkFiles=await Promise.all(['postman','courier'].map(n=>loader.loadAsync('./characters/'+(n==='postman'?'postman-user':n)+'-walking.gltf')));
const walks={postman:walkFiles[0],courier:walkFiles[1]};
for(const m of walkFiles)for(const clip of m.animations)for(const tr of clip.tracks)if(/Hips\.position$/.test(tr.name))for(let i=0;i<tr.values.length;i+=3){tr.values[i]=0;tr.values[i+2]=0;}
const crowdByName=Object.fromEntries(modelNames.map((name,i)=>[name,crowdModels[i]]));
// Keep locomotion under collision control; animation contributes vertical gait only.
for(const clip of model.animations){for(const track of clip.tracks){if(/Hips\.position$/.test(track.name)){for(let i=0;i<track.values.length;i+=3){track.values[i]=0;track.values[i+2]=0;}}}}
env=world.scene;scene.add(env);env.traverse(o=>{if(o.isMesh){originalMaterials.set(o,o.material);o.material.side=THREE.DoubleSide;}});
function actor(source,height){let body=clone(source),box=new THREE.Box3().setFromObject(body),size=box.getSize(new THREE.Vector3()),holder=new THREE.Group();body.scale.setScalar(height/1.7);body.position.y=0;holder.add(body);scene.add(holder);return {holder,body};}
const h=actor(model.scene,2.2);hero=h.holder;hero.name='Fool player';hero.position.copy(toWorld(nav.nodes[0]));mixer=new THREE.AnimationMixer(h.body);run=mixer.clipAction(model.animations[0]);idle=mixer.clipAction(standing.animations[0]);idle.play();
function shadow(holder){let canvas=document.createElement('canvas');canvas.width=64;canvas.height=64;let ctx=canvas.getContext('2d'),g=ctx.createRadialGradient(32,32,0,32,32,32);g.addColorStop(0,'rgba(27,24,41,.38)');g.addColorStop(1,'rgba(27,24,41,0)');ctx.fillStyle=g;ctx.fillRect(0,0,64,64);let mesh=new THREE.Mesh(new THREE.PlaneGeometry(1.5,1.5),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas),transparent:true,depthWrite:false}));mesh.rotation.x=-Math.PI/2;mesh.position.y=.025;holder.add(mesh);}
shadow(hero);
for(const entry of nav.npcs){
 const npcModel=crowdByName[entry.model],a=actor(npcModel.scene,2.05);
 a.holder.position.copy(toWorld(navigator.nearest(entry.position||nav.nodes[entry.node])));a.holder.rotation.y=.5;shadow(a.holder);
 const mx=new THREE.AnimationMixer(a.body),idleAction=mx.clipAction(npcModel.animations[0]);idleAction.play();mx.update(Math.random()*2);
 const label=document.createElement('div');label.className='npc';label.textContent=entry.name;document.body.append(label);
 const walker=walks[entry.model],walkAction=walker?mx.clipAction(walker.animations[0]):null;let patrol=null,delivery=null;
 if(entry.model==='postman'){
  delivery=createPostmanRoute(navigator);a.holder.position.copy(toWorld(delivery.home));
  postOfficePosition=toWorld(delivery.home);postOfficeLabel=document.createElement('div');postOfficeLabel.className='npc';postOfficeLabel.textContent='紫藤邮局';postOfficeLabel.style.pointerEvents='auto';postOfficeLabel.onclick=()=>goPoint(delivery.home);document.body.append(postOfficeLabel);
 }else if(walker&&entry.position){
  const edge=[...nav.edges].sort(([a,b],[c,d])=>segmentDistance(entry.position,nav.nodes[a],nav.nodes[b])-segmentDistance(entry.position,nav.nodes[c],nav.nodes[d]))[0];
  const u=nav.nodes[edge[0]],v=nav.nodes[edge[1]],len=Math.hypot(v[0]-u[0],v[1]-u[1]);const delta=[(v[0]-u[0])/len*10,(v[1]-u[1])/len*10];const ends=[-1,1].map(sign=>entry.position.map((x,i)=>x+sign*delta[i]));
  if(safeEdge(ends[0],ends[1])){patrol={from:toWorld(ends[0]),to:toWorld(ends[1]),phase:Math.random()*6};idleAction.stop();walkAction.play();}
 }
 npcs.push({...entry,...a,mixer:mx,label,patrol,delivery,idleAction,walkAction,isWalking:false});
}
npcs.push(await createStreetClown(loader,scene,toWorld));
for(const poly of walkableAreas){const geometry=new THREE.BufferGeometry().setFromPoints([...poly,poly[0]].map(p=>toWorld(p).add(new THREE.Vector3(0,.08,0))));routeGroup.add(new THREE.Line(geometry,new THREE.LineBasicMaterial({color:0x71ffb7,depthTest:false})));}
for(const o of pavementObstacles){const poly=o.polygon||Array.from({length:32},(_,i)=>[o.circle[0]+(o.circle[2]+7)*Math.cos(i*Math.PI/16),o.circle[1]+(o.circle[2]+7)*Math.sin(i*Math.PI/16)]);const geometry=new THREE.BufferGeometry().setFromPoints([...poly,poly[0]].map(p=>toWorld(p).add(new THREE.Vector3(0,.1,0))));routeGroup.add(new THREE.Line(geometry,new THREE.LineBasicMaterial({color:0xff5c59,depthTest:false})));}
routeGroup.visible=false;center.copy(toWorld(innerWidth<600?[350,940]:[500,840]));updateCamera();$('loading').style.display='none';window.webkit?.messageHandlers.mapReady?.postMessage('ready');window.mapPrototype={scene,camera,hero,nav,get state(){return {currentNode,queue:[...queue],moving:queue.length>0,debug};},travel:go};
}catch(e){$('status').textContent='载入失败：'+e.message;console.error(e);}
const toPixel=p=>[p.x/(80/2048)+1024,p.z*C/(80/2048)+571.5];
function go(to){return goPoint(nav.nodes[to]);}
function goPoint(target){pendingNeighbor=null;if(!hero||!target)return;auto=false;$('tour').classList.remove('active');$('dialog').style.display='none';if(!progression.allows(target)){message('前方仍被浓雾封住，请先完成当前剧情关卡');return;}const path=playerNavigator.path(toPixel(hero.position),target);if(!path.length){message('这里没有可达的平地，请选择街道');return;}queue=path;message('正在沿街道前往目的地');}
let destination=new THREE.Mesh(new THREE.RingGeometry(.32,.38,48),new THREE.MeshBasicMaterial({color:0xe6c47e,transparent:true,opacity:.8,side:THREE.DoubleSide,depthWrite:false}));destination.rotation.x=-Math.PI/2;destination.visible=false;scene.add(destination);
renderer.domElement.addEventListener('pointerdown',e=>{drag={x:e.clientX,y:e.clientY,lastX:e.clientX,lastY:e.clientY,moved:false};renderer.domElement.setPointerCapture(e.pointerId);});
renderer.domElement.addEventListener('pointermove',e=>{if(!drag)return;const dx=e.clientX-drag.lastX,dy=e.clientY-drag.lastY;if(Math.hypot(e.clientX-drag.x,e.clientY-drag.y)>7)drag.moved=true;if(drag.moved){center.x-=dx*zoom/innerHeight;center.z-=dy*zoom/innerHeight/C;updateCamera();}drag.lastX=e.clientX;drag.lastY=e.clientY;});
renderer.domElement.addEventListener('pointerup',e=>{if(!drag)return;const wasDrag=drag.moved;drag=null;if(wasDrag||!hero)return;const mouse=new THREE.Vector2(e.clientX/innerWidth*2-1,1-e.clientY/innerHeight*2);ray.setFromCamera(mouse,camera);for(const npc of npcs){if(!npc.holder.visible)continue;const screen=npc.holder.position.clone().add(new THREE.Vector3(0,1,0)).project(camera);if(Math.hypot((screen.x-mouse.x)*innerWidth/2,(screen.y-mouse.y)*innerHeight/2)<35){npc.delivery?.pause(60);goPoint(navigator.nearest(npc.approach||toPixel(npc.holder.position)));pendingNeighbor=npc;return;}}
let point=new THREE.Vector3();if(!ray.ray.intersectPlane(ground,point))return;const target=toPixel(point);if(!progression.allows(target)){message('前方仍被浓雾封住，请先完成当前剧情关卡');return;}if(!canStand(target)){message('这里只能看，不能走；请点击街道或空地');return;}goPoint(target);destination.position.copy(toWorld(target));destination.position.y=.04;destination.visible=queue.length>0;});
$('clown').onclick=()=>{const clown=npcs.find(n=>n.approach);if(!clown)return;center.copy(clown.holder.position);zoom=12;updateCamera();message('发条小丑正在表演三球戏法 · 点击他可以交谈');};
$('home').onclick=()=>{if(!hero)return;queue=[];currentNode=0;auto=false;hero.position.copy(toWorld(nav.nodes[0]));center.copy(toWorld(innerWidth<600?[350,940]:[500,840]));updateCamera();$('tour').classList.remove('active');destination.visible=false;};
$('tour').onclick=()=>{if(!hero)return;auto=!auto;$('tour').classList.toggle('active',auto);if(auto){go(nav.tourNode??8);auto=true;message('沿街漫游中 · 点击街道可接管');}};
$('paths').onclick=()=>{showPaths=!showPaths;routeGroup.visible=showPaths;$('paths').classList.toggle('active',showPaths);};
$('geometry').onclick=()=>{debug=!debug;$('geometry').classList.toggle('active',debug);let index=0;env.traverse(o=>{if(o.isMesh)o.material=debug?new THREE.MeshStandardMaterial({color:new THREE.Color().setHSL((index++*.13)%1,.2,.62),roughness:1,side:THREE.DoubleSide}):originalMaterials.get(o);});routeGroup.visible=debug||showPaths;updateCamera();};
function changeZoom(v){zoom=THREE.MathUtils.clamp(zoom*v,12,60);updateCamera();}$('zoomIn').onclick=()=>changeZoom(.85);$('zoomOut').onclick=()=>changeZoom(1.15);renderer.domElement.addEventListener('wheel',e=>{e.preventDefault();changeZoom(e.deltaY>0?1.06:.94);},{passive:false});
addEventListener('resize',()=>{renderer.setSize(innerWidth,innerHeight);updateCamera();});
let clock=new THREE.Clock(),moving=false;
renderer.setAnimationLoop(()=>{const dt=Math.min(clock.getDelta(),.04);if(hero){let walking=queue.length>0;if(walking!==moving){moving=walking;if(moving){idle.fadeOut(.15);run.reset().fadeIn(.15).play();}else{run.fadeOut(.18);idle.reset().fadeIn(.18).play();message('点击街道跑动 · 点击人物交谈');destination.visible=false;}}
if(queue.length&&innerWidth<600){const follow=hero.position.clone().add(new THREE.Vector3(0,0,-4));center.lerp(follow,Math.min(1,dt*2));updateCamera();}
if(queue.length){const p=toWorld(queue[0]),d=p.clone().sub(hero.position),step=3.2*dt;const next=d.length()<=step?p:hero.position.clone().addScaledVector(d.clone().normalize(),step);if(safeEdge(toPixel(hero.position),toPixel(next))&&progression.edge(toPixel(hero.position),toPixel(next))){hero.position.copy(next);if(next.distanceTo(p)<.0001){queue.shift();if(!queue.length&&auto){const tourNode=nav.tourNode??8;const target=hero.position.distanceTo(toWorld(nav.nodes[tourNode]))<.1?0:tourNode;go(target);auto=true;}}}else{queue=[];auto=false;message('前方有障碍，请重新选择街道');}const angle=Math.atan2(d.x,d.z);hero.rotation.y+=Math.atan2(Math.sin(angle-hero.rotation.y),Math.cos(angle-hero.rotation.y))*Math.min(1,dt*12);}mixer.update(dt);for(const npc of npcs){if(npc.delivery){
 npc.delivery.tick(dt);const state=npc.delivery.state;
 npc.holder.position.copy(toWorld(state.position));
 if(state.walking){const angle=Math.atan2(...state.heading);npc.holder.rotation.y+=Math.atan2(Math.sin(angle-npc.holder.rotation.y),Math.cos(angle-npc.holder.rotation.y))*Math.min(1,dt*8);}
 if(state.walking!==npc.isWalking){npc.isWalking=state.walking;if(state.walking){npc.idleAction.fadeOut(.2);npc.walkAction.reset().fadeIn(.2).play();}else{npc.walkAction.fadeOut(.2);npc.idleAction.reset().fadeIn(.2).play();}}
 npc.label.textContent=state.atOffice?'邮差 · 邮局取信':'邮差';
 }npc.mixer.update(dt);if(npc.patrol){npc.patrol.phase+=dt*.6;const t=(Math.sin(npc.patrol.phase)+1)/2;npc.holder.position.lerpVectors(npc.patrol.from,npc.patrol.to,t);const d=npc.patrol.to.clone().sub(npc.patrol.from).multiplyScalar(Math.cos(npc.patrol.phase)>=0?1:-1);npc.holder.rotation.y=Math.atan2(d.x,d.z);}const p=npc.holder.position.clone().add(new THREE.Vector3(0,2.4,0)).project(camera);npc.label.style.left=`${(p.x*.5+.5)*innerWidth}px`;npc.label.style.top=`${(-p.y*.5+.5)*innerHeight}px`;npc.holder.visible=progression.allows(toPixel(npc.holder.position));npc.label.style.display=!npc.holder.visible||p.z>1||npc.holder.position.distanceTo(hero.position)>5?'none':'block';}}

if(postOfficeLabel&&hero){const p=postOfficePosition.clone().add(new THREE.Vector3(0,3.1,0)).project(camera);postOfficeLabel.style.left=`${(p.x*.5+.5)*innerWidth}px`;postOfficeLabel.style.top=`${(-p.y*.5+.5)*innerHeight}px`;postOfficeLabel.style.display=!progression.allows(toPixel(postOfficePosition))||Math.abs(p.x)>1||Math.abs(p.y)>1||postOfficePosition.distanceTo(hero.position)>8?'none':'block';}
if(pendingNeighbor&&hero){
 const npc=pendingNeighbor,distance=hero.position.distanceTo(npc.holder.position);
 if(npc.holder.visible&&distance<=2.5){
  pendingNeighbor=null;queue=[];auto=false;
  if(npc.id&&window.webkit?.messageHandlers?.neighborArrival){
   window.webkit.messageHandlers.neighborArrival.postMessage({id:npc.id,distance});
  }else{
   $('dialog').replaceChildren();const title=document.createElement('strong');title.textContent=npc.name;
   $('dialog').append(title,document.createElement('br'),document.createTextNode(npc.text||''));$('dialog').style.display='block';
  }
 }else if(!queue.length){pendingNeighbor=null;message('还没走到对方身边，请再靠近一些。');}
}
renderer.render(scene,camera);});

window.addEventListener("pagehide",()=>renderer.setAnimationLoop(null));

// An explicit native DEBUG fixture uses the same pathfinder and proximity callback.
// No teleport, no direct native completion, and no helper enabled in normal launches.
if(window.__neighborWalkTarget){
 window.webkit?.messageHandlers?.neighborArrival?.postMessage({kind:'ready',ids:npcs.map(n=>n.id).filter(Boolean)});
 setTimeout(()=>{
  const npc=npcs.find(n=>n.id===window.__neighborWalkTarget);
  if(npc){npc.delivery?.pause(120);goPoint(navigator.nearest(npc.approach||toPixel(npc.holder.position)));pendingNeighbor=npc;}
 },3500);
}
