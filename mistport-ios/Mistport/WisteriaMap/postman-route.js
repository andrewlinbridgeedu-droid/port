// Delivery rounds alternate direction, with a return to the post office
// between districts. All legs use the same pavement mesh as the player.
export const postOffice = [825,780];
export const deliveryDistricts = [
 [[825,780],[630,850],[510,925],[325,1005],[250,1045],[165,1075]],
 [[825,780],[955,720],[1030,855],[1060,930],[1130,1000],[1265,1025],[1390,980]],
 [[825,780],[1410,720],[1480,635],[1535,555],[1430,420],[1550,320]],
 [[825,780],[1760,620],[1910,700],[1740,1010]],
 [[825,780],[385,675],[250,675],[115,620],[80,525],[335,420],[540,500]],
];
export function createPostmanRoute(router){
 const home=router.nearest(postOffice);
 const districts=deliveryDistricts.map(list=>list.map(p=>router.nearest(p)));
 const stops=[];
 for(const district of districts){stops.push(...district.slice(1),home);}
 let itinerary=stops,stop=0,reverse=false,path=[],wait=4,heading=[0,-1],walking=false,position=[...home],visits=0;
 const cache=new Map();
 function nextLeg(){const target=itinerary[stop];const key=JSON.stringify([position,target]);if(!cache.has(key))cache.set(key,router.path(position,target));path=cache.get(key).map(p=>[...p]);if(!path.length)throw new Error('邮差路线不连通: '+key);}
 function tick(dt){
  if(wait>0){wait=Math.max(0,wait-dt);walking=false;return;}
  if(!path.length)nextLeg();
  // 1.15 world units/sec. Nav pixels map to an oblique ground plane.
  let budget=1.15*Math.min(dt,.05),moved=false;
  while(path.length&&budget>0){const target=path[0],dx=(target[0]-position[0])*80/2048,dz=(target[1]-position[1])*80/2048/Math.SQRT1_2,len=Math.hypot(dx,dz);if(len>.00001)heading=[dx,dz];if(len<=budget){position=[...target];path.shift();budget-=len;}else{const t=budget/len;position=[position[0]+(target[0]-position[0])*t,position[1]+(target[1]-position[1])*t];budget=0;}moved=true;}
  walking=moved;
  if(!path.length){visits++;wait=Math.hypot(position[0]-home[0],position[1]-home[1])<1?12:2.5;stop++;if(stop===itinerary.length){stop=0;reverse=!reverse;itinerary=reverse?districts.slice().reverse().flatMap(d=>[...d.slice(1).reverse(),home]):stops;}}
 }
 return {tick,pause(seconds=6){wait=Math.max(wait,seconds);walking=false;},get state(){return {position:[...position],heading:[...heading],walking,atOffice:Math.hypot(position[0]-home[0],position[1]-home[1])<1,visits};},home,districts};
}
