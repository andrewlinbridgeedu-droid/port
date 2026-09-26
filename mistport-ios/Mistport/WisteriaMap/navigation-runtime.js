import {walkableAreas,pavementObstacles} from './walkable-areas.js';
export const obstacles=pavementObstacles;
export function segmentDistance(p,a,b){const dx=b[0]-a[0],dy=b[1]-a[1],l=dx*dx+dy*dy,t=l?Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/l)):0;return Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy);}
function inside(p,poly){let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])hit=!hit;}return hit;}
const bounds=walkableAreas.map(p=>[Math.min(...p.map(v=>v[0])),Math.min(...p.map(v=>v[1])),Math.max(...p.map(v=>v[0])),Math.max(...p.map(v=>v[1]))]);
function pavement(p){return walkableAreas.some((poly,i)=>p[0]>=bounds[i][0]&&p[1]>=bounds[i][1]&&p[0]<=bounds[i][2]&&p[1]<=bounds[i][3]&&inside(p,poly));}
export function blocked(p,r=7){return obstacles.some(o=>o.circle?Math.hypot(p[0]-o.circle[0],p[1]-o.circle[1])<o.circle[2]+r:inside(p,o.polygon)||o.polygon.some((a,i)=>segmentDistance(p,a,o.polygon[(i+1)%o.polygon.length])<r));}
export function canStand(p,r=7){if(!pavement(p)||blocked(p,r))return false;for(let i=0;i<8;i++){const a=i*Math.PI/4;if(!pavement([p[0]+r*Math.cos(a),p[1]+r*Math.sin(a)]))return false;}return true;}
export function safeEdge(a,b,r=7){const steps=Math.max(1,Math.ceil(Math.hypot(a[0]-b[0],a[1]-b[1])/2));for(let i=0;i<=steps;i++){const t=i/steps;if(!canStand([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t],r))return false;}return true;}
// Raster navigation mesh over the complete pavement union, with clearance.
// Both path segments and every movement step use the same authority.
export function createNavigator(allowed=()=>true){
 const validStand=(p,r=7)=>canStand(p,r)&&allowed(p);
 const validEdge=(a,b,r=7)=>{if(!safeEdge(a,b,r))return false;const n=Math.max(1,Math.ceil(Math.hypot(a[0]-b[0],a[1]-b[1])/2));for(let i=0;i<=n;i++)if(!allowed([a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n]))return false;return true;};
 const step=5,w=410,h=230,valid=new Uint8Array(w*h);let cells=[];
 const point=id=>[(id%w)*step,Math.floor(id/w)*step];
 for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(validStand([x*step,y*step],8)){const id=y*w+x;valid[id]=1;cells.push(id);}
 function nearest(p){let best=null,d=Infinity;for(const id of cells){const q=point(id),v=(q[0]-p[0])**2+(q[1]-p[1])**2;if(v<d){d=v;best=id;}}return best===null?null:point(best);}
 function path(start,end){
  if(!validStand(start)||!validStand(end))return [];
  if(validEdge(start,end,8))return [end];
  const attach=p=>cells.filter(id=>Math.hypot(point(id)[0]-p[0],point(id)[1]-p[1])<12&&validEdge(p,point(id),8));
  const starts=attach(start),ends=new Set(attach(end));if(!starts.length||!ends.size)return [];
  const scores=new Map(),prev=new Map(),closed=new Set(),heap=[];
  const push=(id,f)=>{let i=heap.length;heap.push({id,f});while(i){let p=(i-1)>>1;if(heap[p].f<=f)break;[heap[p],heap[i]]=[heap[i],heap[p]];i=p;}};
  const pop=()=>{const top=heap[0],last=heap.pop();if(heap.length){heap[0]=last;let i=0;for(;;){let j=i*2+1;if(j>=heap.length)break;if(j+1<heap.length&&heap[j+1].f<heap[j].f)j++;if(heap[i].f<=heap[j].f)break;[heap[i],heap[j]]=[heap[j],heap[i]];i=j;}}return top.id;};
  for(const id of starts){scores.set(id,0);push(id,0);}
  while(heap.length){const id=pop();if(closed.has(id))continue;if(ends.has(id)){const raw=[end];let u=id;while(u!==undefined){raw.unshift(point(u));u=prev.get(u);}const result=[];let anchor=start;for(let i=0;i<raw.length;){let j=raw.length-1;while(j>i&&!validEdge(anchor,raw[j],8))j--;result.push(raw[j]);anchor=raw[j];i=j+1;}return result;}
   closed.add(id);const a=point(id);
   for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]){const x=id%w+dx,y=Math.floor(id/w)+dy,n=y*w+x;if(x<0||x>=w||y<0||y>=h||!valid[n]||closed.has(n))continue;const b=point(n);if(!validEdge(a,b,8))continue;const g=scores.get(id)+Math.hypot(dx,dy)*step;if(g>=(scores.get(n)??Infinity))continue;scores.set(n,g);prev.set(n,id);push(n,g+Math.hypot(b[0]-end[0],b[1]-end[1]));}
  }return [];
 }
 return {nearest,path,cells:cells.map(point)};
}
