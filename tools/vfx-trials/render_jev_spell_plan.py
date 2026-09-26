#!/usr/bin/env python3
"""Generate review artifacts from authored manifest and real, matching Jev receipts."""
from collections import Counter
import hashlib
import html
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/jev-spell-plan-20260921"
LABEL = {"preserve":"保留与回归", "refine":"沿主体精修", "rebuild":"局部重做", "verify":"先核对整招", "defer":"保留库／暂不接入"}
BATCHES = {
 "A": {"title":"先完成通缉样板", "ids":"B04 → B06 锁甲 → B06 飞行；B02 作保护基准", "work":"B04先移除用户否定的规则几何轮廓，再解决主体/中段厚度；同一招交完整起手至收势视频，不改已认可命中。", "exit":"全阶段无规则几何图元式轮廓；B04不规则卷墨、B06立体锁甲/锚芯飞行可读；B02不回退；正常/取消回调与持续handle清理通过。"},
 "B": {"title":"主角完整施法", "ids":"7张正式技能＋手动假面（普攻单列D批精修）", "work":"沿牌、面具、印章、双影、幕布身份精修；错步和无名优先验证真实目标集合。", "exit":"1/2/3/4敌阵容下目标正确；错步最多2敌、追猎同敌2段、全体宣告无伤害；无多实例回调倍增。"},
 "C": {"title":"塔与状态型样板", "ids":"六塔恶魔、剩余通缉；翠焰/机械盾", "work":"身体蓄力附着、材质细节、攻击瞬间撑开；治疗、强化、防护使用自身语义。", "exit":"D04/D06三招仍有不同姿态和轮廓；D03/D05固定受益者退场取消；持续状态不反复播放命中爆炸。"},
 "D": {"title":"普攻精修与主线全覆盖", "ids":"H00秘仪飞牌优先；幽灵、早/晚犬、核心、维娅、机械敌与Boss", "work":"普攻明确打磨动作、飞牌厚度、局部短命中与收势；敌方普通/试探攻击按身份核对，再补主线完整施法与缺漏路由。", "exit":"连续5次普攻不叠满屏尾效，单/双/四敌只中当前目标；原伤害/攻速/0.58秒contact保持。另验证双焰两次接触、飞臂装回、Q5/Q19毒雾分支及Boss退场。"},
 "E": {"title":"遗落物真实反馈", "ids":"其余9项白名单附效", "work":"先核对原生事件与Unity桥，再补局部生效反馈；不把数值被动包装成伤害技能。", "exit":"触发、落空、清算、受益/攻击来源绑定正确；停用旧物不开放。"},
 "F": {"title":"试演与旧库隔离", "ids":"虹翼/霜雷/裂界＋隐藏/未解锁技能", "work":"保留并完善对照；三招正式目标/槽位未决定，不擅自替换现有技能。", "exit":"作为可回看试演交付；正式接入需有明确规则，不能用模拟拍点当已上线。"},
 "G": {"title":"并行新增塔小怪", "ids":"D07–D11共10招；另一任务负责制作", "work":"本计划补齐当前first/second方案与整招验收边界；不修改另一个任务的源码。", "exit":"等待该制作批自己的全景/近景、回调/取消/死亡/重试回执；当前只做增量计划，不能当完成。"},
}


def comparable(row):
    return {k:v for k,v in row.items() if k not in ("clips","audit_indices")}


def main():
    manifest=json.loads((OUT/"manifest.json").read_text())
    feedback=json.loads((ROOT/"tools/vfx-trials/jev_spell_user_feedback_20260921.json").read_text())
    assert (ROOT/feedback["evidence"]).is_file()
    assert set(feedback["rows"]) <= {r["id"] for r in manifest["spells"]}
    reviews={}; runs=[]
    for folder in sorted((OUT/"run-").iterdir()):
        summary_path=folder/"summary.json"
        if not summary_path.exists():
            continue
        summary=json.loads(summary_path.read_text())
        runs.append({"path":str(folder.relative_to(ROOT)), **{k:summary[k] for k in ("models","usage","request_count","question_count")}})
        for request_file in sorted(folder.glob("batch-*.request.json")):
            payload=json.loads(request_file.read_text())
            response_file=request_file.with_name(request_file.name.replace(".request.",".response."))
            record=json.loads(response_file.read_text())
            assert record["status"]==200
            raw=json.dumps(payload,ensure_ascii=False).encode()
            assert hashlib.sha256(raw).hexdigest()==record["request_sha256"]
            for sid,state in payload["state"]["spells"].items():
                answers=record["response"]["answers"]
                reviews[sid]={"input":state, "route":answers[sid+"__route"],
                              "contradiction":answers[sid+"__contradiction"],"gap":answers[sid+"__gap"],
                              "receipt":str(response_file.relative_to(ROOT)), "utc":record["utc"], "model":record["response"]["model"]}
    assert {r["id"] for r in manifest["spells"]}==set(reviews)
    protected={"H01","T22","M11","B02"}
    for r in manifest["spells"]:
        review=reviews[r["id"]]
        assert comparable(r)==review["input"], "Stale review: "+r["id"]
        del review["input"]
        review["review_scope"]="原始文字方案；未覆盖此后的用户几何禁令、B04修订及普攻优化追加，不是视觉验收。"
        r["jev"]=review
        route=review["route"]["choice"]
        if r["batch"]=="F":
            action="defer"; why="正式接入/解锁未批准，模型建议核对也不构成上线授权。试演可继续保留对照。"
        elif r["id"] in protected:
            action="preserve"; why="优先服从最新用户保护边界；已认可阶段保留，未认可衔接按本行候选复核，不外推整招认可。"
        elif r["id"] in ("B04","B06H"):
            action="rebuild"; why="最新记录明确当前轻薄问题尚未解决；只重做未认可阶段。与Jev最高概率建议一致。"
        elif r["id"]=="B06G":
            action="refine"; why="Jev精修/重做概率接近；落到具体动作是保留Effekseer并重建贴甲体积/前后层，不恢复金属块。"
        elif r["batch"]=="G":
            action="verify"; why="另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。"
        elif not r["clips"]:
            action="verify"; why="没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。"
        else:
            action=route
            why="先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。"
        if r["id"]=="M14":
            why+=" 另复核该行0.18的矛盾概率：提案明确保留单目标/原contact，机械阵列是已存在第二视觉；无据改变战斗规则。"
        r["decision"]={"action":action,"reason":why,"route_confidence_below_08":review["route"]["confidence"]<.8,
                       "visual_acceptance":"未由本次审核判定","proposal_status":"候选方案，未实施"}
        r["decision"]["latest_visual_rule"]=feedback["id"]
        if r["id"] in feedback["rows"]:
            r["user_override"]=feedback["rows"][r["id"]]
            r["decision"].update(action=r["user_override"].get("action",action), reason=r["user_override"]["reason"],
                visual_acceptance=r["user_override"]["status"], proposal_status="依最新用户反馈修订，未实施、未重跑Jev")
        if r["id"] in feedback["basic_attack"]["enemy_rows"]:
            r["basic_attack_note"]=feedback["basic_attack"]["enemy_rows"][r["id"]]
    usage={k:sum(r["usage"][k] for r in runs) for k in ("input_tokens","output_tokens")}
    stats={"rows":len(manifest["spells"]),"excluded_rows":len(manifest["excluded"]),"current_questions":len(reviews)*3,"requests":sum(r["request_count"] for r in runs),
           "executed_questions":sum(r["question_count"] for r in runs),"usage":usage,
           "raw_routes":dict(Counter(v["route"]["choice"] for v in reviews.values())),
           "final_routes":dict(Counter(r["decision"]["action"] for r in manifest["spells"])),
           "low_route_confidence":sum(v["route"]["confidence"]<.8 for v in reviews.values()),
           "max_contradiction_probability":max(v["contradiction"]["noul"] for v in reviews.values()),
           "missing_dedicated_clips":[r["id"] for r in manifest["spells"] if not r["clips"]]}
    manifest.update(jev_runs=runs,stats=stats,batches=BATCHES,latest_user_feedback=feedback,
                    amendments=["M03/M04：按primary/secondary源码改正幽灵录像映射，不按赤红颜色判法术。",
                                "M10：补Q19 recover降档，不能复制Q5单调递增或误报固定三跳。",
                                "三项修订已重新请求Jev；其它76项基线输入与原回执逐字段一致。",
                                "终检发现任务“接入教会塔小怪与法术”并行写入D07–D11：另增10招并补跑Jev，不将旧六怪基线外推为当前全部源码。"])
    (OUT/"review.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    md=["# 全游戏法术整招梳理 · Jev审核计划", "", "## 结论", "",
        f"Jev已实际接通，返回模型 `jev-1.13.0`。本次计划覆盖 **{stats['rows']}项整招/状态/附效**：79项既有基线（主角8、正式塔14、主线31、通缉11、白名单遗落物10、独立试演3、保留库2）＋另一任务正在接入的D07–D11新增10招。不是89个已完成攻击技能。",
        f"原102条审计记录全部映射；85段现有总览MP4全部归位。旧目录{stats['excluded_rows']}项单列附录，不重新开放。",
        "", "优先：B04覆写 → B06锁甲厚度 → B06飞行中段。B02最新金纹版作为保护基准；B06认可爆炸、翠焰认可蓄力、错步认可残影、D02盐晶主体保留。",
        "", "本次是制作计划，不改Unity/Swift、不构建或装机。候选创作由主agent撰写，Jev审核文字契约、处理路线和已知缺口；Jev没有看视频像素，不提供视觉合格率。",
        "", "[交互总表与实录](../../output/jev-spell-plan-20260921/index.html) · [完整数据和逐项Jev回执](../../output/jev-spell-plan-20260921/review.json)"]
    md += ["", "## 最新用户约束 · "+feedback["date"], "", "> "+feedback["user_quote"], "",
        feedback["scope"], "", feedback["precedence"], ""]
    md += ["- 禁用："+x for x in feedback["forbidden"]]
    md += ["", "制作方向："+feedback["direction"], "", "验收补充：", ""]
    md += ["- "+x for x in feedback["checks"]]
    md += ["", f"[用户否定的截图](../../{feedback['evidence']})。"+feedback["evidence_note"], "",
        feedback["review_status"], "", feedback["implementation_status"]]
    basic=feedback["basic_attack"]
    md += ["", "## 普攻追加优化", "", "> "+basic["user_quote"], "", basic["scope"], ""]
    md += ["- "+x for x in basic["direction"]]
    md += ["", basic["contracts"], "", "敌方已有普通/试探条目同步核对：", ""]
    md += [f"- {sid}：{note}" for sid,note in basic["enemy_rows"].items()]
    md += ["", "普攻专项验收：", ""]+["- "+x for x in basic["checks"]]
    md += ["", "源码核对："+" · ".join(f"[{Path(p).name}](../../{p})" for p in basic["sources"]), "",
        "## Jev实际结果与复核（新反馈之前的原始方案）", "",
        f"既有79项审核16次请求/237个判断，源码核对后3项定向重审1次/9个判断；新增塔怪10招2次/30个判断。合计{stats['requests']}次审核请求/{stats['executed_questions']}个判断，均HTTP 200。另有1次连接探针，不算进计划审核。",
        f"审核用量：input {usage['input_tokens']:,} / output {usage['output_tokens']:,} tokens；原请求/响应无凭证落盘。",
        "", "|Jev原始最高概率路线|项数|解释|", "|---|---:|---|"]
    for k,n in stats["raw_routes"].items(): md.append(f"|{LABEL[k]}|{n}|处理建议，不是视觉结论|")
    md += ["", f"{stats['low_route_confidence']}项路线置信度低于0.8，保留完整概率而非包装成通过。证据不足项先核对已有实录/补录；保护项服从用户要求；试演和旧库不因此开放。",
           "缺口分数0–3衡量文字里已知问题，不是画面分数，也不是本次测试通过率。没有专项视频≠法术不存在或不合格。",
           "", "源码复核与并行增量：", ""] + ["- "+v for v in manifest["amendments"]]
    md += ["", "## 完整法术的统一口径", ""]+["- "+x for x in manifest["rules"]]
    md += ["", "## 制作批次", "", "|批次|范围|实际工作|完成门槛|", "|---|---|---|---|"]
    for k,b in BATCHES.items(): md.append(f"|{k} {b['title']}|{b['ids']}|{b['work']}|{b['exit']}|")
    md += ["", "## 每招交付与验收", "",
      "1. 开工前备份当前源码、原画、已有视频；记录该招唯一修改负责人。",
      "2. 同一条视频从身体起手/蓄力开始，到释放、contact、生效/持续和收势结束。持续状态另给足够长样本验证不重复爆炸，但仍属于同一行。",
      "3. Unity全景与近景实际录制；旧/新同机位同拍点对比，附正常速度/半速与接触前、保持、撑开、回收关键帧。GIF由实录转出，不代替MP4细节。",
      "4. 保留真实contact与数值；测试正常一次回调、contact前取消零迟到回调、contact后取消不重打、死亡/跨波/重试恢复；骨骼、材质、网格、粒子handle清理。",
      "5. 目标测试：单/双/三/四敌场景验证真实集合；状态不伪造伤害，固定受益者离场不改投；共享镜头/震动只一次。",
      "6. 先完成整组定向检查与实录，不每招停下来问继续。规则通过、Unity表现、用户视觉认可、原生构建和iPhone 13验收分列记录。",
      "", "## 逐招候选方案", ""]
    for r in sorted(manifest["spells"],key=lambda x:(x["batch"],x["id"])):
        j=r["jev"]; d=r["decision"]
        active=r.get("user_override",r)
        md += [f"### {r['id']} · {r['name']}","", f"{r['group']} / {r['status']} / 批次{r['batch']} / {r['scope']}","",
          "- 原始证据："+r["current"],"- 保护边界："+active["locked"],"- 当前候选改法："+active["proposal"],
          "- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。",
          f"- Jev（此前原始文字方案）：{LABEL[j['route']['choice']]}，路线置信度 {j['route']['confidence']:.2f}；缺口 {j['gap']['score']:.2f}/3；文字矛盾概率 {j['contradiction']['noul']:.2f}。",
          "- 执行判断："+LABEL[d["action"]]+"。"+d["reason"],"", "|阶段|本招方案|", "|---|---|"]
        md += [f"|{k}|{v}|" for k,v in active["stages"].items()]
        if "user_override" in r:
            md += ["", "最新状态："+active["status"], "", active["clip_caption"], "",
                "此前送Jev的原方案（仅溯源，受最新反馈覆盖）："+r["proposal"]]
        if "basic_attack_note" in r:
            md += ["", "普通/试探攻击追加核对："+r["basic_attack_note"]]
        md += ["", "实录："+(" · ".join(f"[{Path(p).stem}](../../{p})" for p in r["clips"]) or "85段总览中无独立完整样本，先补入口核对/录制。"),
               "", f"[Jev原始回执](../../{j['receipt']})", "", "源码/记录："+"；".join("`"+s+"`" for s in r["sources"]), ""]
    md += ["## 暂停和旧目录附录", "", "不把以下保留项算成当前制作完成；不重新开放奖励、装备或触发入口。", "", "|原审计项|名称|处理|", "|---|---|---|"]
    md += [f"|{r['audit_index']+1}|{r['name']}|{r['disposition']}|" for r in manifest["excluded"]]
    md += ["", "## 方法来源", "", "[TypeSafe API](https://docs.typesafe.ai/api) · [Choice](https://docs.typesafe.ai/primitives/choice) · [证据核对示例](https://docs.typesafe.ai/cookbooks/citation_check)", "",
           "采用 typesafe-ai 的类型化判断和 game-spell-impact 的整招、独立目标及真实实录边界；没有将技能里的样本参数统一强加到所有法术。", ""]
    doc=ROOT/"docs/development/JEV_WHOLE_SPELL_PLAN_20260921.md"
    doc.write_text("\n".join(md),encoding="utf-8")
    data=json.dumps(manifest,ensure_ascii=False).replace("</", "<\\/")
    template=(ROOT/"tools/vfx-trials/jev_spell_plan_template.html").read_text()
    (OUT/"index.html").write_text(template.replace("__PLAN_DATA__",data).replace("__ROW_COUNT__",str(stats["rows"])).replace("__EXCLUDED_COUNT__",str(stats["excluded_rows"])),encoding="utf-8")
    # Keep this report small and checkable, rather than declaring visual tests run.
    verification={"type":"artifact/data validation only", "base_input_matches_actual_jev_requests":True,
                  "all_base_rows_reviewed":len(reviews)==len(manifest["spells"]),"coverage":manifest["coverage"],
                  "latest_user_feedback_reviewed_by_jev":False, "post_review_overrides":list(feedback["rows"]),
                  "no_runtime_files_changed_by_generator":True,"stats":stats,
                  "not_run":["Unity runtime tests","native build","phone installation","visual acceptance"]}
    (OUT/"validation.json").write_text(json.dumps(verification,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(stats,ensure_ascii=False))


if __name__=="__main__": main()
