import * as THREE from 'three';
export const clownPosition=[660,845];
export const clownApproach=[685,865];
// A small fixed performance at the shop-side edge of the promenade.
export async function createStreetClown(loader,scene,toWorld){
 const gltf=await loader.loadAsync('./characters/clown.gltf');
 const holder=new THREE.Group(),body=gltf.scene;holder.name='街头发条小丑';
 body.scale.setScalar(2.15/1.7);holder.add(body);holder.position.copy(toWorld(clownPosition));holder.rotation.y=.15;scene.add(holder);
 const arms=['ShowLeft','ShowRight'].map(n=>body.getObjectByName(n));
 const rest=arms.map(b=>b.quaternion.clone());
 const sockets=['JuggleLeft','JuggleRight'].map(n=>body.getObjectByName(n));
 const rug=new THREE.Mesh(new THREE.CircleGeometry(.88,48),new THREE.MeshStandardMaterial({color:0x472841,roughness:.95,side:THREE.DoubleSide}));rug.rotation.x=-Math.PI/2;rug.position.y=.025;holder.add(rug);
 const trim=new THREE.Mesh(new THREE.RingGeometry(.84,.88,64),new THREE.MeshStandardMaterial({color:0xd0a754,metalness:.5,roughness:.6,side:THREE.DoubleSide}));trim.rotation.x=-Math.PI/2;trim.position.y=.03;holder.add(trim);
 const balls=[0xe4b846,0xcf548c,0x60bdcb].map(color=>{const b=new THREE.Mesh(new THREE.SphereGeometry(.10,16,12),new THREE.MeshStandardMaterial({color,metalness:.42,roughness:.26}));holder.add(b);return b;});
 const label=document.createElement('div');label.className='npc';label.textContent='发条小丑 · 三球戏法';document.body.append(label);
 const q=new THREE.Quaternion(),axis=new THREE.Vector3(0,0,1),left=new THREE.Vector3(),right=new THREE.Vector3();let time=0;
 function update(dt){
  time+=dt;body.rotation.z=Math.sin(time*2.6)*.035;body.position.y=.025*(1+Math.sin(time*5.2));
  for(let i=0;i<arms.length;i++)arms[i].quaternion.copy(rest[i]).multiply(q.setFromAxisAngle(axis,Math.sin(time*Math.PI/1.2+i*Math.PI)*.12));
  holder.updateMatrixWorld(true);sockets[0].getWorldPosition(left);sockets[1].getWorldPosition(right);holder.worldToLocal(left);holder.worldToLocal(right);
  balls.forEach((ball,i)=>{const cycle=(time/2.4+i/3)%1,forward=cycle<.5,t=(cycle% .5)*2;ball.position.lerpVectors(forward?left:right,forward?right:left,t);ball.position.y+=1.15*4*t*(1-t)+.08;ball.position.z+=.14;ball.rotation.y=time*3;});
 }
 update(0);
 return {name:'发条小丑',text:'嘘，看清楚了吗？金球从左手离开，蓝球却从右手回来。雾港的秘密，也爱这样换个口袋。',holder,body,label,mixer:{update},approach:clownApproach};
}
