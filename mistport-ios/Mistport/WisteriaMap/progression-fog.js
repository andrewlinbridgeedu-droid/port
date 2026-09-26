import * as THREE from 'three';
export function createProgressFog(scene,toWorld){
 const canvas=document.createElement('canvas');canvas.width=2048;canvas.height=1143;const ctx=canvas.getContext('2d');
 const texture=new THREE.CanvasTexture(canvas),material=new THREE.MeshBasicMaterial({map:texture,transparent:true,depthWrite:false,depthTest:false,side:THREE.DoubleSide});
 const mesh=new THREE.Mesh(new THREE.PlaneGeometry(80,80*1143/2048/Math.SQRT1_2),material);mesh.rotation.x=-Math.PI/2;mesh.position.y=.15;mesh.renderOrder=1000;scene.add(mesh);
 const barriers=new THREE.Group();scene.add(barriers);
 const gates=[[505,870,1],[620,870,2],[870,705,5],[1035,800,10],[1405,720,13],[1465,245,15]];
 for(const [x,y,after] of gates){const g=new THREE.Group();g.position.copy(toWorld([x,y]));g.userData.after=after;
  const wood=new THREE.MeshStandardMaterial({color:0x715743,roughness:.9});
  for(const dx of [-.5,.5]){const post=new THREE.Mesh(new THREE.BoxGeometry(.08,.7,.08),wood);post.position.set(dx,.35,0);g.add(post);}
  const bar=new THREE.Mesh(new THREE.BoxGeometry(1.15,.15,.09),wood);bar.position.y=.48;g.add(bar);bar.rotation.z=.08;
  barriers.add(g);
 }
 return {update(progress){
  mesh.visible=!progress.bypass&&progress.count<15;
  ctx.globalCompositeOperation='source-over';ctx.clearRect(0,0,2048,1143);ctx.fillStyle='rgb(197,209,224)';ctx.fillRect(0,0,2048,1143);
  for(let i=0;i<32;i++){const x=(i*613)%2048,y=(i*277)%1143,g=ctx.createRadialGradient(x,y,0,x,y,180);g.addColorStop(0,'rgba(242,246,252,.24)');g.addColorStop(1,'rgba(242,246,252,0)');ctx.fillStyle=g;ctx.fillRect(x-180,y-180,360,360);}
  // Blur the entire reveal mask, not a shadow beneath a hard polygon.
  // CPU separable blur also works in WKWebView without Canvas filter support.
  const mask=document.createElement('canvas');mask.width=2048;mask.height=1143;
  const mc=mask.getContext('2d');mc.fillStyle='#fff';mc.strokeStyle='#fff';mc.lineJoin='round';mc.lineWidth=85;
  for(const poly of progress.open){mc.beginPath();poly.forEach(([x,y],i)=>i?mc.lineTo(x,y):mc.moveTo(x,y));mc.closePath();mc.fill();mc.stroke();}
  const pixels=mc.getImageData(0,0,2048,1143),w=2048,h=1143;
  let alpha=new Float32Array(w*h),temp=new Float32Array(w*h);
  for(let i=0;i<alpha.length;i++)alpha[i]=pixels.data[i*4+3];
  const radius=18,span=radius*2+1;
  for(let pass=0;pass<3;pass++){
   for(let y=0;y<h;y++){let sum=0;for(let k=-radius;k<=radius;k++)sum+=alpha[y*w+Math.max(0,Math.min(w-1,k))];for(let x=0;x<w;x++){temp[y*w+x]=sum/span;sum+=alpha[y*w+Math.min(w-1,x+radius+1)]-alpha[y*w+Math.max(0,x-radius)];}}
   for(let x=0;x<w;x++){let sum=0;for(let k=-radius;k<=radius;k++)sum+=temp[Math.max(0,Math.min(h-1,k))*w+x];for(let y=0;y<h;y++){alpha[y*w+x]=sum/span;sum+=temp[Math.min(h-1,y+radius+1)*w+x]-temp[Math.max(0,y-radius)*w+x];}}
  }
  for(let i=0;i<alpha.length;i++)pixels.data[i*4+3]=Math.round(alpha[i]);mc.putImageData(pixels,0,0);
  ctx.globalCompositeOperation='destination-out';ctx.drawImage(mask,0,0);ctx.globalCompositeOperation='source-over';
  texture.needsUpdate=true;for(const gate of barriers.children)gate.visible=!progress.bypass&&progress.count<gate.userData.after;
 }};
}
