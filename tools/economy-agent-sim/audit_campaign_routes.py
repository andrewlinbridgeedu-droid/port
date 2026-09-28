"""Candidate ordinary/hard public-front contribution arithmetic.

User direction: equal skill/preparation should favor the larger organized side;
better preparation and play may let a minority reverse its disadvantage.
"""
from fractions import Fraction as F
import hashlib
import itertools
import json
from pathlib import Path

from campaign_participation import route_probabilities

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'docs/development/world-campaign-prototype-20260927/participation-review'


def run():
    pairs = [(F(7,20),F(7,20)),(F(1,2),F(1,2)),(F(13,20),F(13,20)),
             (F(7,20),F(13,20)),(F(1,2),F(13,20))]
    rows=[]
    for n,share,ps,attendance,weights in itertools.product(
        (20,100,400),(F(1,2),F(7,10)),pairs,(F(1),F(3,4),F(1,2)),((1,1),(1,2),(2,1),(2,2))
    ):
        na=int(n*share);nb=n-na
        result=route_probabilities(na,nb,ps[0]*attendance,ps[1]*attendance,weights)
        rows.append({"population":n,"n_A":na,"n_B":nb,"p_A_given_started":float(ps[0]),
            "p_B_given_started":float(ps[1]),"attendance":float(attendance),"points_per_win":weights,
            "outcomes":result,"metric":"public_front_lead_not_npc_death",
            "expected_points_A":float(na*ps[0]*attendance*weights[0]),
            "expected_points_B":float(nb*ps[1]*attendance*weights[1])})
    assert len(rows)==360
    data={"status":"candidate_route_arithmetic_not_observed_win_rates", "rows":rows,
          "source_sha256":{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [Path(__file__),Path(__file__).with_name('campaign_participation.py'),
                        Path(__file__).with_name('test_campaign_participation.py')]}}
    (OUT/'routes.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    lines=['# 用户选择后：普通/高难目标贡献候选','',
           '用户已明确：70:30且装备/操作/准备相近时，人多且组织好的阵营应明显占优；少数派靠更好的准备和操作翻盘。首测据此采用总贡献，不按人数除分。',
           '', '## 候选规则','',
           '- 所有合格报名者均可参与公共战线；每账号本事件暂定1次产生世界贡献的尝试，失败也占用。',
           '- 普通目标成功1点、高难节点成功2点；失败0点。新人的失败不扣阵营已有贡献，成功一定增加贡献。',
           '- 普通/高难必须对应不同的、已验证遭遇难度，不能同一战斗改标签领两倍分；投资或月卡不决定倍率。',
           '- 本文只比较公共战线领先。4名不同成功账号是暂用的最低有效推进假设，不是积分达到4就杀NPC。最终NPC必须另有合法挑战和世界结算。',
           '', '## 70:30的数值例子','',
           '|总参与|A/B选择|A/B开战后成功率|A期望点|B期望点|B领先概率|',
           '|---:|---|---|---:|---:|---:|']
    examples=[((1,1),(.5,.5)),((1,2),(.5,.65)),((1,2),(.5,.25)),((2,2),(.65,.65))]
    for n,(weights,ps) in itertools.product((20,100,400),examples):
        r=next(r for r in rows if r['population']==n and r['n_A']==7*n//10
               and r['attendance']==1 and tuple(r['points_per_win'])==weights
               and (r['p_A_given_started'],r['p_B_given_started'])==ps) if ps!=(.5,.25) else None
        if r is None:
            # Separate same-skill route-choice control, not one of the 360 matrix rows.
            na,nb=7*n//10,3*n//10
            r={'expected_points_A':na*.5,'expected_points_B':nb*.25*2,
               'outcomes':route_probabilities(na,nb,.5,.25,(1,2))}
        lines.append(f'|{n}|{weights[0]}点/{weights[1]}点|{ps[0]:.0%}/{ps[1]:.0%}|{r["expected_points_A"]:.2f}|{r["expected_points_B"]:.2f}|{r["outcomes"]["B_leads"]:.4%}|')
    lines+=['', '普通A的50%、高难B的65%必须来自不同能力/准备群体，**不是给相同玩家凭空提高高难胜率**。两方相同能力且都选同一难度时多数派仍明显占优。',
            '100人例：70人普通、p=.5，期望35点；30名更强玩家挑战高难、p=.65，期望39点，少数派公共战线领先约70.14%。这只是可行性算例，不是真人难度定案，也不是最终击杀概率。',
            '', '## 为什么不会自动变成人人都打高难','',
            '目前还不能证明不会。若相同玩家在普通/高难的成功率是pN/pH，则单次世界机会的期望贡献为pN与2pH。高难当2pH>pN时更有吸引力；还需比较实际时间、失败和资源成本。',
            '对普通玩家，候选例pN=.5、pH=.25，两路线期望点相同但风险不同；对熟练玩家pN=.85、pH=.65，高难期望1.3点、普通.85点。这些是假设，不能拿期望贡献来反推必须消费的药费。',
            '若所有装备/操作组中高难都更轻松、收益更高，普通路线就被淘汰；若高难对所有组都更差，也失去意义。必须用同一真实玩家/策略跨两难度的配对数据判断。',
            '', '## 仍须补齐','',
            '1. 公共战线领先如何改变真实进攻机会、节点状态或后续防御，而不是按积分直接处决NPC；尚未冻结。',
            '2. 每账号一次可能使一次失误过于惩罚；1/2/3次贡献规则需连同每人最大影响一起比较，不能暗加无限刷分。',
            '3. 两场高难Boss仍未实现；现有易遭遇不能改名当高难。',
            '4. 资金、材料和外围目标各有真实用途；这里没有成交/药耗数据，不证明新增工艺需求或货币平衡。',
            '5. 报名、反重复回执与资格检查为上游职责；离线PublicFront只测试受信任输入下的总分守恒与失败原子性。',
            '', '## 产物','',
            '360组路线分值解析比较见routes.json；另有3个pN=.5/pH=.25的同能力示例直接按同一函数计算，未冒充矩阵内行。',
            'PublicFront实现报名名册、每账号一次、普通/高难固定贡献、幂等回执、冲突拒绝和关闭后拒绝新结果。未接Swift、真实战斗、钱包或NPC死亡。',
            '', '```sh','PYTHONDONTWRITEBYTECODE=1 python3 tools/economy-agent-sim/audit_campaign_routes.py','```']
    (OUT/'ROUTES.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'route_comparisons':len(rows),'report':str(OUT/'ROUTES.md')},ensure_ascii=False))


if __name__=='__main__':run()
