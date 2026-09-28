'use strict';
let defaults, params, result, audit, tab='decision', dirty=false;
const recommended=()=>({...defaults,kit_price:60,launch_guard:true,public_a:.85,public_b:.85});
const $=id=>document.getElementById(id);
const num=(x,d=0)=>Number(x).toLocaleString('zh-CN',{maximumFractionDigits:d});
const pct=x=>(x*100).toFixed(1)+'%';
const signed=x=>(x>0?'+':'')+num(x,1);
const controls={
 event:[['参与规模'],['participants','本次实际参战账号',0,2000,10],['share_a','联合会人数占比',0,1,.05,'pct'],['公共行动 · 每账号一次'],['public_a','联合会普通成功率',0,1,.05,'pct'],['public_b','灰帆普通成功率',0,1,.05,'pct'],['hard_a','联合会选择高难比例',0,1,.1,'pct'],['hard_b','灰帆选择高难比例',0,1,.1,'pct'],['hard_success_a','联合会高难成功率',0,1,.05,'pct'],['hard_success_b','灰帆高难成功率',0,1,.05,'pct'],['最终突破 · 三节点后决战'],['node_a','联合会节点成功率',0,1,.05,'pct'],['boss_a','联合会人物战成功率',0,1,.05,'pct'],['node_b','灰帆节点成功率',0,1,.05,'pct'],['boss_b','灰帆人物战成功率',0,1,.05,'pct'],['attendance','最终机会实际到场率',0,1,.05,'pct'],['工程资格'],['supply_a','联合会可用组具',0,12,1],['supply_b','灰帆可用组具',0,12,1]],
 project:[['工程与资金'],['funding_a','联合会实际筹资 / 铜',0,1200,40],['funding_b','灰帆实际筹资 / 铜',0,1200,40],['supply_a','联合会可用组具',0,12,1],['supply_b','灰帆可用组具',0,12,1],['kit_price','每套组具成交价 / 铜',1,150,1],['kit_cost','每套经济成本 / 铜',0,200,1],['craft_minutes','每套主动生产时间 / 分钟',.5,20,.5],['30日经营 · 两方各自获胜时'],['orders_a','联合会每日付费需求 / 单',0,100,1],['orders_b','灰帆每日付费需求 / 单',0,100,1],['buyer_budget','客户合计可支付钱包 / 铜',0,12000,200],['raw_capacity','每日客户原料上限 / 单',0,50,1],['战斗消耗 · 单独估计'],['public_doses','公共行动平均实际用药 / 瓶',0,3,.1],['core_doses','核心开战平均实际用药 / 瓶',0,3,.1]],
 money:[['注册与每日活跃'],['players','服务器注册账号',100,10000,100],['dau','账号每日活跃概率',0,1,.05,'pct'],['monthly','月卡账号比例',0,1,.05,'pct'],['base','免费日补给 / 铜',0,30,1],['bonus','月卡额外日补给 / 铜',0,30,1],['重复与新增现金'],['q_participation','活跃日选择Q30的概率',0,1,.05,'pct'],['q_runs','选择Q30当日重玩次数',1,20,1],['q_minutes','一场Q30耗时 / 分钟',1,30,1],['q_cost','一场Q30现金成本 / 铜',0,105,1],['other_cash','其它重复现金 / 活跃人日',0,100,1],['fresh','真正新账号 / 日',0,20,1],['生产与真实回收'],['craft_participation','活跃工艺参与率',0,1,.05,'pct'],['crafts','每工艺玩家日产量 / 件',0,5,.1],['sale_rate','成品实际售出比例',0,1,.05,'pct'],['sale_price','每件实际成交额 / 铜',1,150,1],['craft_sink','每制作件外部材料支付 / 铜',0,50,1],['fee','交易销毁手续费',0,.2,.01,'pct'],['other_sink','其它销毁 / 活跃人日',0,30,.1],['external_sink','材料款退出本服','bool'],['newcomer_sink','新人三材1080退出本服','bool']]
};
controls.project.push(['launch_guard','启动前检查7日确认订单','bool']);
controls.money.push(['fixed_active_cohort','每日固定同一批活跃账号','bool']);
function buildControls(){
 const fields=controls[tab]||[];
 $('advanced').hidden=tab==='decision';
 $('controls').innerHTML=fields.map(c=>{
   if(c.length===1)return `<div class="group-title">${c[0]}</div>`;
   let [key,label,min,max,step,format]=c;
   if(min==='bool')return `<label class="field check"><input type="checkbox" data-key="${key}" ${params[key]?'checked':''}>${label}</label>`;
   let value=params[key];
   return `<label class="field" for="${key}"><span class="field-head"><span>${label}</span><output id="value-${key}">${format==='pct'?pct(value):num(value,2)}</output></span><input id="${key}" data-key="${key}" type="range" min="${min}" max="${max}" step="${step}" value="${value}"></label>`;
 }).join('');
 $('controls').querySelectorAll('input').forEach(input=>input.addEventListener('input',()=>{
   const key=input.dataset.key;params[key]=input.type==='checkbox'?input.checked:Number(input.value);
   const c=controls[tab].find(c=>c[0]===key);if($('value-'+key))$('value-'+key).textContent=c[5]==='pct'?pct(params[key]):num(params[key],2);
   markDirty();
 }));
}
function markDirty(){dirty=true;$('status').textContent='参数已改，点击“复算当前情景”更新结果。';$('status').className='';$('export').disabled=true;}
function stat(label,value,detail){return `<div class="stat"><span>${label}</span><strong>${value}</strong><p>${detail}</p></div>`;}
function bar(label,value,cls=''){return `<div class="bar-row"><div class="bar-title"><span>${label}</span><span>${pct(value)}</span></div><div class="track"><div class="bar ${cls}" style="width:${Math.max(0,Math.min(100,value*100))}%"></div></div></div>`;}
function table(head,rows){return '<div class="table-wrap"><table><thead><tr>'+head.map(s=>`<th>${s}</th>`).join('')+'</tr></thead><tbody>'+rows.map(r=>'<tr>'+r.map(s=>`<td>${s}</td>`).join('')+'</tr>').join('')+'</tbody></table></div>';}
function chart(series,labels,unit){
 const w=Math.max(260,$('results').clientWidth-48),h=250,left=75,right=20,top=20,bottom=40;
 const all=series.flatMap(s=>s.map(d=>d[1])),lo=Math.min(0,...all),hi=Math.max(1,...all),maxX=Math.max(...series[0].map(d=>d[0]));
 const x=v=>left+v/maxX*(w-left-right),y=v=>top+(hi-v)/(hi-lo)*(h-top-bottom);
 let svg=`<svg class="chart" viewBox="0 0 ${w} ${h}" role="img" aria-label="${labels.join('、')}，单位${unit}">`;
 for(let i=0;i<4;i++){let v=lo+(hi-lo)*i/3;svg+=`<line x1="${left}" y1="${y(v)}" x2="${w-right}" y2="${y(v)}" stroke="var(--line)"/><text x="${left-9}" y="${y(v)+4}" text-anchor="end">${Math.abs(v)>=10000?num(v/10000,1)+'万':num(v)}</text>`;}
 for(const v of [0,Math.round(maxX/2),maxX])svg+=`<text x="${x(v)}" y="${h-13}" text-anchor="middle">${v}日</text>`;
 if(lo<0)svg+=`<line x1="${left}" y1="${y(0)}" x2="${w-right}" y2="${y(0)}" stroke="var(--muted)" stroke-dasharray="4 4"/>`;
 const colors=['var(--green)','var(--amber)','var(--violet)'];series.forEach((s,i)=>{svg+=`<path d="${s.map((d,j)=>(j?'L':'M')+x(d[0])+','+y(d[1])).join(' ')}" fill="none" stroke="${colors[i]}" stroke-width="2.5"/>`;});
 return svg+'</svg><div class="legend">'+labels.map((l,i)=>`<span><i class="${['','b','c'][i]}"></i>${l}</span>`).join('')+`<span>单位：${unit}</span></div>`;
}
function render(){
 if(!result)return;
 const r=result,p=r.params,e=r.event,projects=r.projects;
 $('view-label').textContent={decision:'REVIEWED / FIRST PLAYTEST',event:'WORLD OUTCOME',project:'PRODUCTION & INVESTMENT',money:'CURRENCY ACCOUNTING'}[tab];
 $('view-title').textContent={decision:'规则先收敛，数值留出修正余地',event:'谁取得下一段城市的未来',project:'有人需要，生意才成立',money:'把铸币、转移与销毁分开'}[tab];
 let html='';
 if(tab==='decision'){
  html='<p class="intro">建议按“有预算的物资采购＋公共成果决定合同＋有限核心突破＋真实经营分配”进入首轮内容与玩法试做。共享自由市场和银行继续等待货币验证；它们不阻碍先做好这一场事件。</p>';
  html+='<div class="stats">'+stat('阵营对照',num(audit.events)+' 组','人数、组织、准备与缺料')+stat('项目账对照',num(audit.projects)+' 组','客户钱包、价格、产能与停工')+stat('货币观察',num(audit.currency_observations)+' 项','180 / 365 / 730日，三种重复规则')+'</div>';
  html+='<div class="panel"><h3>我建议首测采用的规则</h3>'+table(['部分','首测方案','为何保留'],[
    ['公共行动','普通1点 / 高难2点，每账号一次','多数人的行动有真实权重'],
    ['核心机会','领先6 / 落后4，同分5 / 5','三节点后决战，同轮双边结算'],
    ['合同归属','无死亡时按合格公共成果决定','不让大多数事件停在无结果'],
    ['采购','每方12套，预算1200铜内','有用途才购买，不无限回收'],
    ['工匠收益','组具60铜首测报价，成本待实测','成本34、主动6分钟假设下约4.33铜/分'],
    ['启动经营','先核7日已付款且原料齐备订单','预订经营净额须覆盖120铜调试'],
    ['经营分配','仅分已履约经营净额的50%','先保退款、采购承诺和运营资金']])+'<p class="note">60铜替代旧40铜仅用于首测候选，不修改现行奖励；客户订单和配方成本尚需真人验证。右侧各视角显示所选情景，以上表格始终是建议方案。</p></div>';
  const base=audit.presets.recommended,minority=audit.presets.recommended_minority;
  html+=`<div class="reading"><p><b>相近实力时，多数派明显占优；更好准备可以翻盘。</b> 70:30基准中多数派合同率 ${pct(base.outcomes.A)}；提高少数派高难、节点与决战成功率后，少数派为 ${pct(minority.outcomes.B)}。这是输入假设下的结果，不是真人胜率。</p><p><b>经营成功与货币稳定分开验收。</b> 基准14日一次Q30仍有约 ${num(base.money365.find(x=>x.interval===14).recurring_net/10000)} 万铜年度经常性净投放，不能宣布共享经济已经平衡。</p></div>`;
  html+='<div class="panel"><h3>上线后怎样修正，而不伤害已结算权益</h3>'+table(['出现的问题','立即处理','下一版本再调整'],[
    ['物资滞销','停止新增无预算订单，保留玩家库存','减少采购批量或调整真实用途'],
    ['没有付费客户','不付调试费、不启动亏损批次','调产品与需求，不发虚构利润'],
    ['一方无人 / 工程未齐','按资格及公共成果结算或临时接管','改下轮招募、准备期和物料要求'],
    ['胜率长期过低或单边碾压','保留当前已发票据与规则','改下一事件版本的遭遇和名额'],
    ['货币增量持续过大','共享市场入口保持关闭','试验有限现金预算；不追扣旧余额'],
    ['重复或冲突结算','冻结异常回执，核对唯一事件ID','服务端幂等、回放、对账再放行']])+'<p class="note">这些是接入规格与运营处理办法，尚未成为正式服自动开关。首测判断数据至少要有成交、实际用药、钱物回执和真人战斗记录。</p></div>';
 }else if(tab==='event'){
  html=`<p class="intro">${num(p.participants)}个参战账号，联合会 ${num(e.roster[0])} 人、灰帆 ${num(e.roster[1])} 人。两派争夺30日经营权；普通行动决定优先权，最终突破可以改变人物命运与归属。</p>`;
  html+='<div class="stats">'+stat('联合会取得合同',pct(e.outcomes.A),'公共成果与核心突破合并结算')+stat('灰帆取得合同',pct(e.outcomes.B),'少数派仍可凭准备与操作翻盘')+stat('临时公共接管',pct(e.outcomes.interim),'同分、无资格或双死')+'</div>';
  html+=`<div class="panel split"><section><h3>最终合同归属</h3>${bar('联合会',e.outcomes.A)}${bar('灰帆',e.outcomes.B,'b')}${bar('临时接管',e.outcomes.interim,'c')}</section><section><h3>人物命运 · 与合同分开</h3>${bar('双方均存活',e.mortality.neither)}${bar('仅罗文死亡',e.mortality.A,'b')}${bar('仅艾妲死亡',e.mortality.B,'b')}${bar('两人均死亡',e.mortality.both,'c')}</section></div>`;
  html+=`<div class="reading"><p><b>无人死亡，也能有结果。</b> 公共领先方可取得经营权，核心战不是普通玩家贡献生效的唯一入口。</p><p>这组假设下，双方存活概率为 ${pct(e.mortality.neither)}，临时接管为 ${pct(e.outcomes.interim)}。两者不能混为“没有赢家”。</p></div>`;
  html+='<div class="panel"><h3>准备是否真正落地</h3>'+table(['条件','联合会','灰帆'],[
    ['已安装组具',e.engineering[0].installed+'/12',e.engineering[1].installed+'/12'],
    ['公共贡献平均点数',num(e.scores[0],1),num(e.scores[1],1)],
    ['取得完整工程及行动资格',pct(e.qualified[0]),pct(e.qualified[1])],
    ['平均获分配最终机会',num(e.opportunities[0],2),num(e.opportunities[1],2)]])+
   `<p class="note">普通成功1点，高难成功2点；至少4个不同成功账号及12处工程验收。领先6/落后4、同分5/5，名额不超过可用成功账号。各候选本事件只有一次核心机会。</p></div>`;
  html+=`<div class="timeline"><div><b>准备 · 7日</b><span>新闻、采购、工程安装</span></div><div><b>公共行动 · 48小时</b><span>普通与高难贡献</span></div><div><b>最终突破 · 24小时</b><span>三节点之后才签人物战</span></div><div><b>经营 · 30日</b><span>真实订单与投资清算</span></div></div>`;
 }else if(tab==='project'){
  html='<p class="intro">分别推演两派拿到合同时的30日生意。客户钱包有限、原料有限、每日最多50单；没有足额订单就停工。所有客户数均为假设，并未证明真人愿意购买。</p>';
  html+='<div class="stats">'+stat('已安装工程部件',num(e.components_installed)+' 件','每套由2布＋2绑带＋2锡罐组成')+stat('每套组具经济净收益',signed(r.craft.margin)+' 铜','主动时间收益 '+num(r.craft.rpm,2)+' 铜/分钟')+stat('每次事件预计用药',num(e.doses,1)+' 瓶','由输入的平均实际用药量推算')+'</div>';
  html+='<div class="panel"><h3>项目账 · 经营分配不等于已经回本</h3>'+table(['项目','联合会','灰帆'],[
    ['当前实际出资 / 铜',num(p.funding_a),num(p.funding_b)],
    ['建造支付 / 铜',...projects.map(x=>num(x.construction))],
    ['落败可退本金 / 铜',...projects.map(x=>num(x.refund_if_loses))],
    ['获胜且能启动经营',...projects.map(x=>x.can_start?'是':'否：工程、资金或确认订单不足')],
    ['7日确认订单经营净额 / 铜',...projects.map(x=>num(x.prebook_net))],
    ['获胜时真实履约订单 / 单',...projects.map(x=>num(x.fulfilled))],
    ['经营现金分配 / 铜',...projects.map(x=>num(x.dividends))],
    ['合同到期可退现金 / 铜',...projects.map(x=>num(x.refund_if_wins))],
    ['获胜时投资总盈亏 / 铜',...projects.map(x=>signed(x.net_if_wins))],
    ['含阵营胜负的期望盈亏 / 铜',...projects.map(x=>signed(x.expected_net))]
  ])+`<p class="note">亏损已扣实际施工成本。调试120铜，服务每单4铜，每营业日组具1套＋燃料60铜，经营净额50%分配。开机检查${p.launch_guard?'开启：前7日输入视为已付款、原料已落实的订单，经营净额须覆盖120铜':'关闭：旧算例，获合同即付调试费'}。后续需求仍是假设。临时接管按未获合同清算，不救助本金。</p></div>`;
  html+='<div class="panel"><h3>若取得合同：累计回收价值减出资</h3>'+chart(projects.map(x=>x.rows.map(d=>[d.day,d.investor_net])),['联合会获胜情景','灰帆获胜情景'],'铜')+'<p class="note">可退现金包含剩余本金与留存经营净额；再加已分配现金，减原始出资。曲线小于0表示仍未回本。两条线是互斥情景，相同输入时重合。</p></div>';
  html+=`<div class="reading"><p><b>当前每批至少 ${projects[0].break_even_orders} 单才能覆盖运营成本。</b> 工艺生产也必须算材料机会成本，不能因为材料是自己刷的就当作免费。</p><p>本次工程需求只有 ${num(e.components_installed)} 件部件，后续维护组具期望 ${num(e.expected_service_kits,1)} 套。这一场事件无法直接证明2000人的持续生产都有买家。</p></div>`;
 }else{
  let yearly=r.money.filter(x=>x.days===365);
  html='<p class="intro">并排比较每次重玩105铜、每7日一次、每14日一次。周期限额按账号实际领取概率计算；这里只核系统收支，不模拟物价、财富分布或银行信用。</p>';
  html+='<div class="stats">'+yearly.map((x,i)=>stat(['每次105 · 年经常性净投放','每7日一次 · 年经常性净投放','每14日一次 · 年经常性净投放'][i],signed(x.recurring_net/10000)+' 万铜','不含真正新账号的一次性权益')).join('')+'</div>';
  html+='<div class="panel"><h3>累计系统净投放 · 包含所设新人流量</h3>'+chart([0,1,2].map(i=>r.chart.map(x=>[x.day,x.values[i]])),['每次105','每7日一次','每14日一次'],'铜')+'<p class="note">这不是物价涨幅，也不是服务器余额。未计迁入迁出已有余额；人口固定，新增账号只计算新增权益对货币的影响。</p></div>';
  html+='<div class="panel"><h3>180 / 365 / 730 日对照</h3>'+table(['周期规则','观察日数','Q30发行 / 万铜','总销毁 / 万铜','系统净投放 / 万铜'],r.money.map(x=>[x.interval===1?'每次105':x.interval+'日一次',x.days,num(x.q/10000,2),num(x.sinks/10000,2),signed(x.net/10000)]))+'</div>';
  html+='<div class="panel"><h3>每活跃玩家日：维持经常性收支所需回收</h3>'+table(['规则','实际回收 / 铜','收支相抵需回收 / 铜'],yearly.map(x=>[x.interval===1?'每次105':x.interval+'日一次',x.actual_sink_per_active_day===null?'无活跃账号':num(x.actual_sink_per_active_day,2),x.break_even_sink_per_active_day===null?'无活跃账号':num(x.break_even_sink_per_active_day,2)]))+'</div>';
  html+=`<div class="reading"><p><b>${yearly.every(x=>x.recurring_net>0)?'三种规则在当前假设下都仍有经常性净投放。':'净投放的符号随规则变化，仍不能据此判断物价稳定。'}</b></p><p>Q30的输入净收益为 ${num(r.q_rpm,2)} 铜/分钟，每个选择Q30的活跃日需 ${num(p.q_runs*p.q_minutes)} 分钟。成本${num(p.q_cost)}铜只用于收益比较，未自动算成销毁，须在回收账中明确归类。</p><p>${p.fixed_active_cohort?'当前按每日固定同一批活跃账号计算，只有这批账号领取周期奖励。':'当前按账号每天独立活跃计算；7日内至少一次领取概率＝1−(1−日活概率×选择Q30概率)⁷。'} 同样日活人数，不同上线人群重叠率会产生不同发行量；两种情况均已列入批量观察。</p></div>`;
 }
 html+=`<details><summary>模型边界与复算信息</summary><ul><li>版本 ${r.version}；种子 ${p.seed}；公共行动抽样 ${num(p.trials)} 次。合同概率估计的单项95% Hoeffding误差界不超过 ±${(e.sample_bound95*100).toFixed(2)} 个百分点，仅针对抽样误差。</li><li>核心战按节点/人物战成功率和到场率分别计算条件概率，同轮双方结算，首次死亡后停止后续轮次。独立成功率假设未经真人验证。</li><li>项目核账为独立、有限钱包情景。宏观收支表是另一个覆盖全服的账，不自动叠加事件支出，避免把相同回收算两遍。</li><li>基础补给、月卡、产量、成交率、成本、固定窗口限额都是候选输入，不改现行游戏奖励。月卡与免费玩家的个人负担尚未建模。</li><li>新账号按5220一次性铜和1080三材候选处理；转服不是新账号。宏观曲线没有内生价格、囤货、脚本、多账号或真实市场深度。</li><li>项目默认成本与需求相同以隔离阵营概率；不代表两类服务已经完成各自配方和玩家需求验证。</li></ul></details>`;
 $('results').innerHTML=html;
}
async function calculate(){
 $('run').disabled=true;$('export').disabled=true;$('status').textContent='正在复算，结果仍显示上一组参数…';$('status').className='';
 const snapshot=JSON.stringify(params);
 try{
   const response=await fetch('/api/run',{method:'POST',headers:{'Content-Type':'application/json'},body:snapshot});
   const data=await response.json();if(!response.ok)throw Error(data.error||'计算失败');
   result=data;dirty=JSON.stringify(params)!==snapshot;render();
   $('status').textContent=dirty?'计算期间参数已改，请再次推演。':`已完成 ${num(result.params.trials)} 次公共情景与条件概率核算。`;
   $('export').disabled=dirty;
 }catch(e){$('status').textContent='未更新：'+e.message;$('status').className='error';}
 finally{$('run').disabled=false;}
}
document.querySelectorAll('[data-tab]').forEach(button=>button.addEventListener('click',()=>{
 tab=button.dataset.tab;document.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));buildControls();render();
}));
$('run').addEventListener('click',calculate);
$('controls').addEventListener('submit',e=>{e.preventDefault();calculate();});
$('reset').addEventListener('click',()=>{params=recommended();$('preset').value='recommended';buildControls();calculate();});
$('preset').addEventListener('change',()=>{
 params=$('preset').value==='base'?{...defaults}:recommended();
 if($('preset').value==='minority')Object.assign(params,{hard_b:1,hard_success_b:.8,node_b:.75,boss_b:.7});
 if($('preset').value==='shortage')params.supply_a=8;
 if($('preset').value==='idle')Object.assign(params,{orders_a:0,orders_b:0});
 buildControls();calculate();
});
$('export').addEventListener('click',()=>{
 if(!result||dirty)return;const url=URL.createObjectURL(new Blob([JSON.stringify(result,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='mistport-lights-'+result.params.seed+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),5000);
});
Promise.all([fetch('/api/defaults').then(r=>r.json()),fetch('/api/audit').then(r=>r.json())]).then(([p,a])=>{defaults=p;audit=a;params=recommended();buildControls();calculate();}).catch(e=>{$('status').textContent='无法连接本地推演服务或验证结果：'+e.message;});
let resizeTimer;
window.addEventListener('resize',()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(render,120);});
