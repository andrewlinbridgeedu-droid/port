"""Small closed-form public-front -> core-opportunity -> NPC outcome study."""
from collections import defaultdict
from fractions import Fraction as F
from functools import lru_cache
import hashlib
import json
from pathlib import Path

from campaign_participation import binomial_pmf, core_caps_from_progress
from campaign_core_race import exact_probabilities

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/development/world-campaign-prototype-20260927/participation-review'


@lru_cache(None)
def core(caps,p):
    return {k:float(v) for k,v in exact_probabilities(caps,p,p).items()}


def run():
    rows=[]
    scenarios=[('equal_ordinary',.5,.5,(1,1),1),
               ('skilled_minority_hard',.5,.65,(1,2),1),
               ('equal_hard',.65,.65,(2,2),1),
               ('equal_ordinary_attendance75',.5,.5,(1,1),.75)]
    for n in (20,100,400):
        na,nb=7*n//10,3*n//10
        for label,pa,pb,weights,attendance in scenarios:
            allocation=defaultdict(float)
            for a,ap in enumerate(binomial_pmf(na,pa*attendance)):
                for b,bp in enumerate(binomial_pmf(nb,pb*attendance)):
                    allocation[core_caps_from_progress((a,b),(a*weights[0],b*weights[1]))]+=ap*bp
            assert abs(sum(allocation.values())-1)<1e-10
            for cp in (F(7,20),F(1,2),F(13,20)):
                outcomes={k:0. for k in ('A','B','both','neither')}
                for caps,mass in allocation.items():
                    for k,v in core(caps,cp).items():outcomes[k]+=mass*v
                assert abs(sum(outcomes.values())-1)<1e-10
                rows.append({'population':n,'n_A':na,'n_B':nb,'scenario':label,
                    'public_p_A':pa,'public_p_B':pb,'public_attendance':attendance,
                    'points_per_win':weights,'conditional_core_win_probability_both':float(cp),
                    'supplies':'both already meet requirement (assumed)',
                    'core_attendance':'all assigned candidates start (assumed)',
                    'opportunity_distribution':{f'{a}/{b}':v for (a,b),v in sorted(allocation.items())},
                    'world_outcomes':outcomes})
    assert len(rows)==36
    data={'status':'conditional_analytical_prototype_not_live_economy_or_human_win_rate','rows':rows,
          'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [Path(__file__),Path(__file__).with_name('campaign_participation.py'),
                        Path(__file__).with_name('campaign_core_race.py')]}}
    (OUT/'pipeline.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    lines=['# 公共战线到NPC结局：36组条件解析验证','',
        '用户已选择“相近实力下人数/组织占优，少数靠更好准备与操作翻盘”。以下是本地新增候选衔接，不是Pro已核定或正式规则。',
        '', '## 可执行的衔接','',
        '1. 所有人可报名公共战线，普通成功1点，高难成功2点；每账号一次有效世界尝试。',
        '2. 关窗后，两方均须具备至少4名不同成功账号及独立的真实工程物料条件。',
        '3. 双方均合格：公共贡献领先方最多6次核心机会，另一方4次；同分5/5。只有一方合格则6/0，均不合格0/0。',
        '4. 实际机会不超过该方成功候选账号数。例如仅4个合格账号即使领先也只能4次，不假造另外2人。',
        '5. 再执行四层核心突破、每账号一次、同轮齐结算；NPC死亡必须由最终合法战斗累计达标产生。公共积分本身不杀人、不发经营权。',
        '', '这使最后击杀仍可由少数人完成，但先前所有玩家的战斗会影响进攻机会。具体6/4/5与个人次数都是试验配置。投资只能通过真实物资用途帮助准备，不能购买点数或代表权。',
        '', '## 结果：核心单场胜率固定50%的对照','',
        '按70:30分组。公共普通/高难的成功概率、实际到场率均为假设；双方物料已齐，核心获资格者全部到场。这些条件不能省略。',
        '', '|总人数|公共战线情形|A独占|B独占|双死|无人死亡|','|---:|---|---:|---:|---:|---:|']
    for r in rows:
        if r['conditional_core_win_probability_both']==.5:
            lines.append(f'|{r["population"]}|{r["scenario"]}|'+
                         '|'.join(f'{r["world_outcomes"][k]:.4%}' for k in ('A','B','both','neither'))+'|')
    lines+=['', '## 必须保留的限制','',
        '- 个人公共战线p与核心p分开；并未把普通50%直接当高难50%。这里故意让双方核心p相同，隔离公共贡献带来的机会差。',
        '- 假设组内个人胜率一致且独立，没有模拟优胜者选择偏差、团队沟通、关联账号或主动弃权。',
        '- 多数场景无人死亡仍很常见。若事件几周才一次而多数结果是僵局，可能缺少满足感，必须试玩；不能为迎合结果自动送成功。',
        '- 物料门槛在这里假设已满足；代码有独立供给开关，没有建立新采购/配方或生成物料。',
        '- 最终核心仍只有少数人，但普通与高难公共目标的世界作用已经不同于无关练习。是否能让未获最终席位者满意，需要真人体验验证。',
        '- 公共战线结束前不得按实时领先授予独占权，防止谁先上线谁获胜。',
        '- 不估计药品需求、铜币平衡或投资回报。所有参与次数都是机会和输入假设。',
        '', '本轮只接通离线研究模型的三段计算；没有迁移Swift原型、实现两Boss、签发真实票据或改玩家数据。',
        '', '```sh','PYTHONDONTWRITEBYTECODE=1 python3 tools/economy-agent-sim/audit_campaign_pipeline.py','```']
    (OUT/'PIPELINE.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'pipeline_comparisons':len(rows),'report':str(OUT/'PIPELINE.md')},ensure_ascii=False))


if __name__=='__main__':run()
