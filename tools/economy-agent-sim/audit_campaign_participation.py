"""450 analytical comparisons, not simulated players or real item purchases."""
from fractions import Fraction as F
import hashlib
import itertools
import json
from pathlib import Path

from campaign_core_race import exact_probabilities
from campaign_participation import POLICIES, score_probabilities, threshold_deaths

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/development/world-campaign-prototype-20260927/participation-review"


def run():
    OUT.mkdir(exist_ok=True)
    rows = []
    pairs = [(F(7,20), F(7,20)), (F(1,2), F(1,2)), (F(13,20), F(13,20)),
             (F(7,20), F(13,20)), (F(13,20), F(7,20))]
    for population, share, ps, attendance in itertools.product(
        (20, 100, 400), (F(1,2), F(7,10)), pairs, (F(1), F(3,4), F(1,2))
    ):
        na = int(population * share)
        nb = population - na
        pa, pb = (p * attendance for p in ps)
        shared = {"registered_volunteers": population, "roster_A": na, "roster_B": nb,
                  "p_win_given_started_A": float(ps[0]), "p_win_given_started_B": float(ps[1]),
                  "attendance": float(attendance), "effective_p_A": float(pa), "effective_p_B": float(pb)}
        race = exact_probabilities((6,6), pa, pb)
        rows.append(dict(shared, policy="six_representatives", metric="world_outcome_under_pro_hypothesis",
                         outcomes={k:float(v) for k,v in race.items()}, opportunity_cap=12))
        rows.append(dict(shared, policy="everyone_fixed_four", metric="world_outcome_fixed_threshold_control",
                         outcomes=threshold_deaths(na,nb,pa,pb), opportunity_cap=population))
        for policy in POLICIES:
            rows.append(dict(shared, policy=policy, metric="faction_progress_only_not_npc_death",
                             outcomes=score_probabilities(na,nb,pa,pb,policy), opportunity_cap=population))
    assert len(rows)==450
    for r in rows:
        assert abs(sum(r["outcomes"].values())-1)<1e-9
        assert min(r["outcomes"].values())>=-1e-12
    data = {"status":"analytical_candidate_comparison_not_live_game_or_human_data", "rows":rows,
            "source_sha256":{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                for p in [Path(__file__),Path(__file__).with_name('campaign_participation.py'),
                          Path(__file__).with_name('test_campaign_participation.py'),
                          Path(__file__).with_name('campaign_core_race.py')]}}
    (OUT/'results.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    lines=['# 世界事件：扩大参与的450组解析比较','',
           '候选规则的概率积分，不是450次真人战斗、2000账号动态经济仿真或新Boss测试。每人至多一次世界贡献的独立尝试；注册名册在开战前冻结，缺席也留在分母。无价格、钱、掉落或消费行为。',
           '', '## 比较了什么','',
           '|方案|谁能贡献|结算含义|', '|---|---|---|',
           '|每方6代表，4胜|双方合计至多12人|沿Pro同轮吸收规则算世界胜负|',
           '|人人可打，固定4胜|所有报名者|截止时两方分别满足即双死，是反例控制组|',
           '|总胜场|所有报名者，每人至多一次|只比较阵营推进，未定义NPC死亡|',
           '|胜场/√报名人数|同上|人数优势减弱但保留，非已定规则|',
           '|胜场/报名人数|同上|比较成功比例；人数不提高期望分，非已定规则|',
           '', '20/100/400报名者 × 50:50/70:30 × 五组两方单次胜率 × 三种到场率 × 五种方案，共450个组合。代表组全部用FULL的6/6机会，以隔离人数效应；不再把20人自动分配为较差准备。',
           '到场率分别为100%/75%/50%，开战后的胜率分别35/50/65%及35:65、65:35。所有数字均为假设，阵营间独立。',
           '', '## 放开人数而不改门槛，会发生什么','',
           '|总报名/比例|各方单次p|代表制双死|人人固定4胜双死|', '|---|---:|---:|---:|']
    for n,share in itertools.product((20,100,400),(.5,.7)):
        selected=[r for r in rows if r['registered_volunteers']==n and r['roster_A']==int(n*share)
                  and r['attendance']==1 and r['p_win_given_started_A']==r['p_win_given_started_B']==.5]
        a=next(r for r in selected if r['policy']=='six_representatives')
        b=next(r for r in selected if r['policy']=='everyone_fixed_four')
        lines.append(f'|{n} / {int(share*100)}:{100-int(share*100)}|50%|{a["outcomes"]["both"]:.4%}|{b["outcomes"]["both_dead"]:.4%}|')
    lines+=['','## 人人贡献：人数优势与操作差异','',
            '这里的A/B领先只是阵营推进比较。至少4胜才有可比较的有效推进；同分不判死，两方均不足不冒充平局。不能与上表的NPC死亡率混称同一种胜率。',
            '', '|人数A:B|单次p A/B|计分|A领先|B领先|有效同分|双方不足4胜|', '|---|---|---|---:|---:|---:|---:|']
    for n,ps,policy in itertools.product((20,100,400),((.5,.5),(.35,.65)),POLICIES):
        r=next(r for r in rows if r['registered_volunteers']==n and r['roster_A']==int(n*.7)
               and r['attendance']==1 and r['p_win_given_started_A']==ps[0]
               and r['p_win_given_started_B']==ps[1] and r['policy']==policy)
        lines.append(f'|{r["roster_A"]}:{r["roster_B"]}|{ps[0]:.0%}/{ps[1]:.0%}|{policy}|'+
                     '|'.join(f'{r["outcomes"][k]:.4%}' for k in ('A_leads','B_leads','tied_ready','neither_ready'))+'|')
    lines+=['','## 不能从概率表直接决定的产品取舍','',
            '- 总胜场让人数和组织投入直接生效；70:30且操作相近时多数派会很稳定地领先。这是规则结果，不能承诺少数派仅稍微配好装备就可逆转。',
            '- 平方根折算保留人数优势，但引入需向玩家解释的缩放；不能在事后根据输赢改变分母或权重。',
            '- 成功比例给少数派接近对等的期望，但加入普通/低成功率玩家可能拉低队伍分数，存在劝退新人和精英小队倾向。',
            '- 两种折算都必须冻结报名名册；若用“实际出战人数”做分母，会奖励挑人和不出战。提前冻结能阻止中途改分母，不能完全消除报名期的挑人动机。',
            '- 每账号一次只限制账号，不识别同一真人；多账号、阵营渗透和资格策略未进入这些分布。',
            '- 全民推进可以带来更多真实战斗机会，但不等于玩家一定用药，更不等于经济平衡。外围体验与消费须实际测试。',
            '', '## 可复现入口','', '```sh',
            'PYTHONDONTWRITEBYTECODE=1 python3 tools/economy-agent-sim/audit_campaign_participation.py',
            "PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/economy-agent-sim -p 'test_campaign_participation.py' -v", '```',
            '结果完整保存于results.json，包含源码散列。没有改奖励、名额、战斗或玩家存档。']
    (OUT/'REVIEW.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'comparisons':len(rows),'report':str(OUT/'REVIEW.md')},ensure_ascii=False))


if __name__=='__main__':
    run()
