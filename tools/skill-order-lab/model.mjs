// Candidate combat rules, 2026-10-12. NOT the shipped Swift battle runtime.
// Integer milliseconds, no random rolls, no order whitelist or artificial loss flag.
// This module also runs unchanged in the inline comparison. Node is used only by audit.mjs.
export const CARDS = [
  {id:'step', legacy:'fool_skill_01', name:'错步穿行', unlock:1, cast:850, recovery:350, cd:7000, role:'群攻', text:'65%攻击，最多3目标；加速时变为150%。'},
  {id:'evidence', legacy:'fool_skill_05', name:'伪证烙印', unlock:2, cast:550, recovery:350, cd:7000, role:'铺垫', text:'20%攻击；目标获得4层误认，持续4秒。'},
  {id:'haste', legacy:'fool_skill_11', name:'抢拍开幕', unlock:4, cast:450, recovery:250, cd:7000, role:'加速', text:'10%攻击；施法速度+100%，持续3.2秒，不缩短技能CD。'},
  {id:'barrage', legacy:'fool_skill_12', name:'碎镜连弹', unlock:4, cast:1800, recovery:300, cd:7000, role:'命中次数', text:'引导固定1.8秒；每0.6秒一发36%攻击，加速时0.3秒一发；每发+1误认。'},
  {id:'rewrite', legacy:'fool_skill_09', name:'后手改写', unlock:5, cast:650, recovery:300, cd:7000, role:'净化／续时', text:'20%攻击；清除中毒，240护盾持续4秒；已有加速和当前目标印记延长1.3秒。'},
  {id:'counter', legacy:'fool_skill_08', name:'反客为主', unlock:6, cast:650, recovery:400, cd:7000, role:'驱散／防御', text:'35%攻击；有盾时驱散盾、追加240%攻击并施加2层错位4秒；否则+2误认。下一次攻击减伤60%，持续4秒。'},
  {id:'convert', legacy:'fool_skill_04', name:'张冠李戴', unlock:7, cast:950, recovery:400, cd:7000, role:'转化／破甲', text:'30%攻击；消耗4误认追加80%，施加2层错位和70%穿甲窗口，持续4秒。未满4层时只+1误认。'},
  {id:'mirror', legacy:'fool_skill_06', name:'双影追猎', unlock:8, cast:1150, recovery:400, cd:7000, role:'错位连击', text:'两段40%攻击；施法开始有错位时两段各180%，命中仍需处于错位窗口；结尾消耗1层。'},
  {id:'finale', legacy:'fool_skill_07', name:'荒谬归结', unlock:10, cast:1800, recovery:550, cd:7000, role:'终结', text:'60%攻击；命中有错位时+500%，错位窗口内此前每次命中再+80%（最多3次），80%穿甲；消耗错位。'},
  {id:'fuse', legacy:'fool_skill_13', name:'延时落款', unlock:12, cast:550, recovery:250, cd:7000, role:'命中兑现', text:'20%攻击，2.6秒后引爆：50%+期间每次法术命中70%（最多8次）；旁边最多2目标受一半爆炸伤害。'}
];
export const BY_ID = Object.fromEntries(CARDS.map(c=>[c.id,c]));

// Candidate encounter stress fixtures, not Q1–30's authored objectives/rosters.
// HP is fixed here before enumeration; audit never invents a threshold per ordering.
export const PROFILES = [
  {id:'duel', name:'单体短窗口', hp:[4100], armor:.12, interval:2400, hit:68, first:1800},
  {id:'armor', name:'重甲与真盾', hp:[3100], armor:.52, interval:2600, hit:70, first:2000, shield:650},
  {id:'swarm', name:'三目标围攻', hp:[1800,1800,1800], armor:.08, interval:2400, hit:31, first:2200},
  {id:'poison', name:'毒雾消耗', hp:[3550], armor:.12, interval:2500, hit:46, first:1900, poison:true},
  {id:'heavy', name:'重击压力', hp:[3200], armor:.20, interval:5200, hit:215, first:3600},
  {id:'mixed', name:'带盾双目标', hp:[2000,2100], armor:.24, interval:2700, hit:47, first:2100, shield:450}
];
export function permutations(items, count=4) {
  if(count===0) return [[]];
  return items.flatMap((x,i)=>permutations(items.filter((_,j)=>i!==j),count-1).map(t=>[x,...t]));
}

// A deadline is half-open [start,end): an impact at exactly end does NOT qualify.
// Enemy attacks resolve first at ties. Delayed explosions resolve before new impacts.
const PRIORITY = {enemy:0, poison:1, explosion:2, impact:3, pulse:3, end:4, dispatch:5};
export function finishWork(start, work, hasteUntil) {
  if(start>=hasteUntil) return Math.round(start+work);
  const accelerated=Math.min(work,(hasteUntil-start)*2);
  return Math.round(start+accelerated/2+(work-accelerated));
}
export function simulate(order, profile=PROFILES[0], options={}) {
  if(order.length<1 || order.length>4 || new Set(order).size!==order.length || order.some(id=>!BY_ID[id])) throw new Error('Select 1–4 distinct ordinary skills');
  if(!Number.isFinite(options.power??1)||(options.power??1)<=0||!Number.isFinite(options.maxTime??45000)||(options.maxTime??45000)<0)throw new Error('Invalid simulation bounds');
  const attack=100*(options.power??1), maxTime=options.maxTime??45000;
  let heroHP=1000, shield=0, shieldUntil=0, wardUntil=0, hasteUntil=0, poison=0;
  let now=0, cursor=0, serial=0, finished=false, basicAt=-2400, nextActor=0;
  let damage=0, totalHits=0, conversions=0, empoweredFinales=0, acceleratedPulses=0, explosions=0, fusesHit=0;
  const ready={}, events=[], trace=[], damageByCard={};
  const targets=profile.hp.map((hp,i)=>({id:i,hp,maxHP:hp,shield:profile.shield??0,illusion:0,illusionUntil:0,
    misalignment:0,misalignmentUntil:0,chainHits:0,breakUntil:0,fuse:null}));
  const live=()=>targets.filter(t=>t.hp>0);
  const log=(kind,text,extra={})=>{ if(options.trace) trace.push({ms:now,kind,text,...extra}); };
  const queue=(at,kind,data={})=>events.push({at:Math.round(at),kind,serial:serial++,...data});
  const fastAt=(at)=>at<hasteUntil;
  // Integrates speed across expiry, rather than snapshotting a whole long spell
  // at the last millisecond of the buff. Cast speed never changes combat clock.
  function spendWork(start, work) {
    return finishWork(start,work,hasteUntil);
  }
  const targetFor=(id)=>targets.find(t=>t.id===id&&t.hp>0)??live()[0];
  function expire(t) {
    if(now>=t.illusionUntil) t.illusion=0;
    if(now>=t.misalignmentUntil) {t.misalignment=0;t.chainHits=0;}
  }
  function mark(t,n) {expire(t);t.illusion=Math.min(4,t.illusion+n);t.illusionUntil=now+4000;}
  function misalign(t) {t.misalignment=2;t.misalignmentUntil=now+4000;t.chainHits=0;t.breakUntil=now+4000;}
  function hit(t,coefficient,source,penetration=0,counts=true) {
    if(!t || t.hp<=0) return;
    expire(t);
    const pierce=Math.max(penetration,now<t.breakUntil?.7:0);
    let raw=Math.round(attack*coefficient*(1-profile.armor*(1-pierce)));
    // Status applications can still land on a shield, but absorbed hits do not
    // contribute to the timed contract: choose a dispel or break through first.
    const absorbed=Math.min(t.shield,raw);t.shield-=absorbed;raw-=absorbed;
    const dealt=Math.min(t.hp,raw);t.hp-=dealt;damage+=dealt;
    damageByCard[source]=(damageByCard[source]??0)+dealt;
    if(counts&&dealt>0) {
      totalHits++;
      if(t.fuse&&now<t.fuse.at) t.fuse.hits=Math.min(8,t.fuse.hits+1);
      if(t.misalignment>0) t.chainHits=Math.min(3,t.chainHits+1);
    }
    log('hit',`${source==='basic'?'普攻':BY_ID[source].name} · ${dealt}`,{skill:source,target:t.id,damage:dealt});
    if(!live().length) finished=true;
  }
  function receive(value) {
    if(now>=shieldUntil) shield=0;
    const covered=Math.min(shield,value);shield-=covered;heroHP=Math.max(0,heroHP-value+covered);
    if(heroHP===0) finished=true;
  }
  function impact(id,targetID,empowered=false) {
    const t=targetFor(targetID);if(!t)return;expire(t);
    switch(id) {
      case 'haste': hit(t,.1,id);hasteUntil=now+3200;log('buff','施法速度 +100% · 3.2秒');break;
      case 'evidence': hit(t,.2,id);mark(t,4);break;
      case 'convert': {
        const valid=t.illusion>=4;
        hit(t,valid?1.1:.3,id);
        if(valid){t.illusion=0;misalign(t);conversions++;log('combo','4误认 → 2错位 / 破甲');}else mark(t,1);
        break;
      }
      case 'mirror': hit(t,empowered&&t.misalignment>0?1.8:.4,id);break;
      case 'finale': {
        const valid=t.misalignment>0, chain=t.chainHits;
        hit(t,.6+(valid?5+.8*chain:0),id,valid?.8:0);
        if(valid){empoweredFinales++;log('combo',`归结兑现 · ${chain}次铺垫命中`);}
        t.misalignment=0;t.chainHits=0;break;
      }
      case 'step': for(const x of live().slice(0,3))hit(x,fastAt(now)?1.5:.65,id);break;
      case 'barrage': hit(t,.36,id);mark(t,1);if(fastAt(now))acceleratedPulses++;break;
      case 'fuse': hit(t,.2,id);t.fuse={at:now+2600,hits:0};queue(now+2600,'explosion',{target:t.id,stamp:now+2600});break;
      case 'counter': {
        const dispelled=t.shield>0;
        t.shield=0;hit(t,dispelled?2.75:.35,id);
        if(dispelled)misalign(t);else mark(t,2);
        wardUntil=now+4000;break;
      }
      case 'rewrite':
        hit(t,.2,id);poison=0;shield=Math.max(shield,240);shieldUntil=now+4000;
        if(hasteUntil>now)hasteUntil+=1300;
        if(t.illusion>0)t.illusionUntil+=1300;
        if(t.misalignment>0){t.misalignmentUntil+=1300;t.breakUntil+=1300;}
        break;
    }
  }
  queue(0,'dispatch');queue(profile.first,'enemy');
  if(profile.poison)queue(1000,'poison');
  while(events.length&&!finished) {
    events.sort((a,b)=>a.at-b.at||PRIORITY[a.kind]-PRIORITY[b.kind]||a.serial-b.serial);
    const e=events.shift();if(e.at>maxTime){now=maxTime;break;}now=e.at;
    switch(e.kind) {
      case 'enemy': {
        const count=live().length;
        let incoming=profile.hit*count;
        if(now<wardUntil){incoming=Math.round(incoming*.4);wardUntil=0;}
        receive(incoming);if(profile.poison)poison++;
        if(profile.shield && now>=profile.first+profile.interval*2) {
          for(const t of live()) t.shield=Math.max(t.shield,profile.shield);
        }
        log('enemy',`敌人出手 · ${incoming}，生命 ${heroHP}`);
        queue(now+profile.interval,'enemy');break;
      }
      case 'poison': if(poison>0)receive(poison*4);queue(now+1000,'poison');break;
      case 'explosion': {
        const t=targets[e.target];
        if(t.hp>0&&t.fuse?.at===e.stamp){
          const count=t.fuse.hits;t.fuse=null;explosions++;fusesHit+=count;
          const coefficient=.5+.7*count;
          hit(t,coefficient,'fuse',0,false);
          for(const x of live().filter(x=>x!==t).slice(0,2))hit(x,coefficient*.5,'fuse',0,false);
          log('combo',`延时落款 · 记录 ${count} 次命中`);
        }
        break;
      }
      case 'impact': impact(e.skill,e.target,e.empowered);break;
      case 'pulse':
        impact('barrage',e.target);
        {const next=spendWork(now,600);if(next<=e.channelEnd)queue(next,'pulse',{target:e.target,channelEnd:e.channelEnd});}
        break;
      case 'end':
        if(e.skill==='mirror') {const t=targets[e.target];expire(t);if(e.empowered)t.misalignment=Math.max(0,t.misalignment-1);}
        queue(spendWork(now,BY_ID[e.skill].recovery),'dispatch');break;
      case 'dispatch': {
        const id=order[cursor], card=BY_ID[id], t=live()[0];if(!t)break;
        if((ready[id]??0)>now) {
          if(basicAt+2400<=now){hit(t,.32,'basic',0,false);basicAt=now;queue(now+450,'dispatch');}
          else queue(Math.min(ready[id],basicAt+2400),'dispatch');
          break;
        }
        ready[id]=now+card.cd;cursor=(cursor+1)%order.length;nextActor++;
        expire(t);
        log('cast',`${nextActor} · ${card.name}`,{skill:id,slot:(cursor+order.length-1)%order.length+1});
        const end=id==='barrage'?now+1800:spendWork(now,card.cast);
        if(id==='barrage')queue(spendWork(now,600),'pulse',{target:t.id,channelEnd:end});
        else if(id==='mirror'){
          const empowered=t.misalignment>0;
          queue(spendWork(now,card.cast/2),'impact',{skill:id,target:t.id,empowered});
          queue(end,'impact',{skill:id,target:t.id,empowered});
        }else queue(end,'impact',{skill:id,target:t.id});
        queue(end,'end',{skill:id,target:t.id,empowered:id==='mirror'&&t.misalignment>0});break;
      }
    }
  }
  return {order:[...order],cleared:heroHP>0&&live().length===0,ms:now,heroHP,damage,remaining:targets.reduce((a,t)=>a+t.hp,0),
    totalHits,conversions,empoweredFinales,acceleratedPulses,explosions,fusesHit,damageByCard,trace};
}
