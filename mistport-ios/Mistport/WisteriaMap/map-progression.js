import {walkableAreas} from './walkable-areas.js';
// District 1: opening lessons, shop lanes, clock square, east road, cathedral.
export const revealAfter=[0,1,2,5,5,10,10,13,15,13,15,0,5,5];
function inside(p,poly){let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])hit=!hit;}return hit;}
export function createProgression(completed=0,bypass=false){
 const count=Math.max(0,Math.min(20,Math.floor(Number(completed)||0)));
 const open=walkableAreas.filter((_,i)=>bypass||count>=revealAfter[i]);
 const allows=p=>open.some(poly=>inside(p,poly));
 const edge=(a,b)=>{const steps=Math.max(1,Math.ceil(Math.hypot(a[0]-b[0],a[1]-b[1])/2));for(let i=0;i<=steps;i++)if(!allows([a[0]+(b[0]-a[0])*i/steps,a[1]+(b[1]-a[1])*i/steps]))return false;return true;};
 return {count,bypass,open,allows,edge};
}
