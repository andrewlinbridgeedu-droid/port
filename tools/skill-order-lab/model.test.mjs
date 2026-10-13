import test from 'node:test';
import assert from 'node:assert/strict';
import {CARDS,PROFILES,BY_ID,permutations,simulate,finishWork} from './model.mjs';

const speed=['haste','fuse','barrage','step'];
const wrong=['step','barrage','fuse','haste'];
test('10 choose 4 ordered without replacement produces 5,040 unique choices',()=>{
  const rows=permutations(CARDS.map(c=>c.id));
  assert.equal(rows.length,5040);assert.equal(new Set(rows.map(x=>x.join(','))).size,5040);
  assert.equal(new Set(rows.map(x=>x.toSorted().join(','))).size,210);
});
test('same four cards: setup before burst changes the outcome with no random rolls',()=>{
  const a=simulate(speed),b=simulate(wrong);
  assert.equal(a.cleared,true);assert.equal(b.cleared,false);
  assert.equal(simulate(wrong,PROFILES[0],{power:1.2}).cleared,false);
  const wins=permutations(speed).filter(o=>simulate(o).cleared);
  assert.equal(wins.length,4);
});
test('haste changes fixed-channel hit count, not enemy clock or card cooldown',()=>{
  const fast=simulate(speed,PROFILES[0],{trace:true,maxTime:7000});
  const slow=simulate(wrong,PROFILES[0],{trace:true,maxTime:7000});
  assert.equal(fast.trace.filter(x=>x.kind==='hit'&&x.skill==='barrage').length,6);
  assert.equal(slow.trace.filter(x=>x.kind==='hit'&&x.skill==='barrage').length,3);
  assert.deepEqual(fast.trace.filter(x=>x.kind==='enemy').map(x=>x.ms),slow.trace.filter(x=>x.kind==='enemy').map(x=>x.ms));
  assert.deepEqual(fast.trace.filter(x=>x.kind==='cast'&&x.skill==='haste').map(x=>x.ms),[0,7000]);
  assert.equal(fast.fusesHit,7);assert.equal(slow.fusesHit,1);
  assert.ok(fast.damage>2.5*slow.damage);
});
test('speed expires during a cast; last-millisecond haste cannot accelerate an entire spell',()=>{
  assert.equal(finishWork(900,600,1000),1400);
  assert.equal(finishWork(1000,600,1000),1600);
  assert.equal(finishWork(0,600,1000),300);
});
test('expired evidence cannot be cashed in by a late conversion',()=>{
  const a=simulate(['evidence','convert','mirror','finale'],PROFILES[0],{maxTime:7000});
  const b=simulate(['evidence','finale','mirror','convert'],PROFILES[0],{maxTime:7000});
  assert.equal(a.conversions,1);assert.equal(b.conversions,0);
  assert.equal(a.empoweredFinales,1);assert.equal(b.empoweredFinales,0);
  assert.ok(a.damage>5*b.damage);
});
test('loop order remains the chosen order after its first pass',()=>{
  const r=simulate(speed,PROFILES[0],{trace:true,maxTime:16000});
  const casts=r.trace.filter(x=>x.kind==='cast').map(x=>x.skill);
  assert.deepEqual(casts.slice(0,8),[...speed,...speed]);
});
test('protection/cleanse offers a different viable plan against poison',()=>{
  const p=PROFILES.find(x=>x.id==='poison');
  assert.equal(simulate(speed,p).cleared,false);
  assert.equal(simulate(['haste','fuse','barrage','rewrite'],p).cleared,true);
});
test('fast multi-hit does not bypass a replenishing shield',()=>{
  const p=PROFILES.find(x=>x.id==='armor');
  assert.equal(simulate(speed,p).cleared,false);
  assert.equal(simulate(['haste','counter','mirror','finale'],p).cleared,true);
});
test('recording a trace does not change results',()=>{
  for(const p of PROFILES){
    const {trace,...a}=simulate(speed,p,{trace:true});
    const {trace:ignored,...b}=simulate(speed,p);
    assert.deepEqual(a,b);
  }
});
test('invalid cards and bounds are rejected without advancing combat',()=>{
  for(const order of [[],['step','step'],['unknown'],CARDS.slice(0,5).map(c=>c.id)])assert.throws(()=>simulate(order));
  assert.throws(()=>simulate(speed,PROFILES[0],{power:NaN}));
  assert.throws(()=>simulate(speed,PROFILES[0],{maxTime:-1}));
  for(const c of CARDS)assert.ok(BY_ID[c.id]&&c.cd>=c.cast+c.recovery);
});
