import {CARDS,PROFILES,permutations,simulate} from './model.mjs';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

const orders=permutations(CARDS.map(c=>c.id));
const summary=[];
const coverage=new Map(orders.map(order=>[order.join(','),[]]));
for(const profile of PROFILES){
  const rows=orders.map(order=>simulate(order,profile));
  const groups=new Map();
  for(const row of rows){const key=[...row.order].sort().join(',');if(!groups.has(key))groups.set(key,[]);groups.get(key).push(row);}
  const viable=[...groups.values()].filter(g=>g.some(r=>r.cleared));
  const sensitive=viable.filter(g=>g.filter(r=>r.cleared).length<=6);
  const wins=rows.filter(r=>r.cleared).sort((a,b)=>a.ms-b.ms||b.heroHP-a.heroHP);
  for(const row of wins)coverage.get(row.order.join(',')).push(profile.id);
  const ranked=rows.toSorted((a,b)=>b.damage-a.damage||a.ms-b.ms);
  const robust=viable.filter(g=>g.some(r=>simulate(r.order,profile,{power:.9}).cleared));
  const result={profile:profile.id,total:rows.length,wins:wins.length,winRate:wins.length/rows.length,
    viableDecks:viable.length,orderSensitiveDecks:sensitive.length,robustDecks:robust.length,
    losingOrderFractionAmongViableDecks:1-wins.length/(viable.length*24),
    winCounts:viable.map(g=>g.filter(r=>r.cleared).length).sort((a,b)=>a-b),
    best:wins.slice(0,5).map(({trace,...r})=>r),highestDamage:ranked.slice(0,1).map(({trace,...r})=>r)};
  summary.push(result);
  console.log(profile.id,JSON.stringify({wins:result.wins,viable:viable.length,sensitive:sensitive.length,robust:robust.length,best:result.best[0]?.order,max:ranked[0].damage}));
}
const maxProfileCoverage=Math.max(...[...coverage.values()].map(x=>x.length));
const cardUsage=CARDS.map(c=>({id:c.id,name:c.name,winningOrders:[...coverage].filter(([key,profiles])=>profiles.length>0&&key.split(',').includes(c.id)).length}));
const sourceModelSHA256=createHash('sha256').update(readFileSync(new URL('./model.mjs',import.meta.url))).digest('hex');
const report={candidateOnly:true,version:'2026-10-12',sourceModelSHA256,orders:orders.length,profiles:summary,maxProfileCoverage,cardUsage};
writeFileSync(new URL('./audit-results.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
if(summary.some(p=>p.viableDecks<3||p.losingOrderFractionAmongViableDecks<.7)||maxProfileCoverage===PROFILES.length||cardUsage.some(c=>c.winningOrders===0))throw new Error('Candidate diversity/order sensitivity acceptance failed');
