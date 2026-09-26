#!/usr/bin/env python3
"""Artifact and traceability checks, explicitly not VFX runtime acceptance."""
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"output/jev-spell-plan-20260921"
data=json.loads((OUT/"review.json").read_text())
page=(OUT/"index.html").read_text()
md=ROOT/"docs/development/JEV_WHOLE_SPELL_PLAN_20260921.md"
checks={}


def check(name, condition):
    checks[name]=bool(condition)
    if not condition:
        raise AssertionError(name)


check("unique89",len(data["spells"])==len({r["id"] for r in data["spells"]})==89)
check("five_stages_each",all(len(r["stages"])==5 and all(r["stages"].values()) for r in data["spells"]))
check("archived27",len(data["excluded"])==27)
indices={i for r in data["spells"] for i in r["audit_indices"]}|{r["audit_index"] for r in data["excluded"]}
check("source_audit102_covered",indices==set(range(102)))
check("all89_real_responses",all(r["jev"]["model"]=="jev-1.13.0" and (ROOT/r["jev"]["receipt"]).exists() for r in data["spells"]))
check("267_current_plus9_rechecks",data["stats"]["current_questions"]==267 and data["stats"]["executed_questions"]==276)
check("19_review_requests",data["stats"]["requests"]==19)
check("only10_parallel_additions",len([r for r in data["spells"] if r["batch"]=="G"])==10)
check("all_existing85_videos",data["coverage"]["mapped_existing_mp4_count"]==85 and data["coverage"]["unmapped_mp4"]==[])
all_paths={p for r in data["spells"]+data["excluded"] for p in r["clips"]}
all_paths.update(s.split(":")[0] for r in data["spells"] for s in r["sources"])
check("all_local_sources_and_media_exist",all((ROOT/p).is_file() for p in all_paths))
check("html_has_data_not_placeholders","__PLAN_DATA__" not in page and "__ROW_COUNT__" not in page and "__EXCLUDED_COUNT__" not in page)
check("html_and_json_agree",json.loads(re.search(r'<script type="application/json" id="plan-data">(.*?)</script>',page,re.S).group(1))==data)
links=re.findall(r'\]\(([^)]+)\)',md.read_text())
check("markdown_local_links_exist",all((md.parent/p).resolve().exists() for p in links if not p.startswith("http")))
text_paths=list(OUT.rglob("*.json"))+list(OUT.glob("*.html"))+[md]
check("no_key_in_artifacts",all(not re.search(r"apikey_[A-Za-z0-9_]{30,}",p.read_text()) for p in text_paths))
check("rendered_count_matches_excluded",f"{len(data['excluded'])}项暂停／旧目录" in page)
feedback=data["latest_user_feedback"]
b04=next(r for r in data["spells"] if r["id"]=="B04")
verification=json.loads((OUT/"validation.json").read_text())
check("user_feedback_image_preserved",(ROOT/feedback["evidence"]).is_file())
check("all89_receive_latest_visual_rule",all(r["decision"]["latest_visual_rule"]==feedback["id"] for r in data["spells"]))
check("b04_override_separate_from_jev_input",b04["proposal"]!=b04["user_override"]["proposal"] and b04["user_override"]==feedback["rows"]["B04"])
check("b04_updated_all_five_stages",set(b04["stages"])==set(b04["user_override"]["stages"]) and all(b04["stages"][k]!=v for k,v in b04["user_override"]["stages"].items()))
check("new_rule_not_claimed_jev_reviewed",verification["latest_user_feedback_reviewed_by_jev"] is False and all("未覆盖" in r["jev"]["review_scope"] for r in data["spells"]))
check("old_b04_footage_labeled_rejected","仅作问题对照" in b04["user_override"]["clip_caption"] and "已被用户否定" in b04["user_override"]["status"])
check("markdown_shows_current_b04_plan",b04["user_override"]["proposal"] in md.read_text() and "最新用户约束" in md.read_text())
h00=next(r for r in data["spells"] if r["id"]=="H00")
basic=feedback["basic_attack"]
check("basic_attack_is_explicit_refine",h00["decision"]["action"]=="refine" and "普攻" in h00["user_override"]["status"])
check("basic_all_five_stages_revised",set(h00["stages"])==set(h00["user_override"]["stages"]) and all(h00["stages"][k]!=v for k,v in h00["user_override"]["stages"].items()))
check("basic_original_contract_preserved",h00["scope"]=="1名有效敌人" and "0.58秒contact不变" in h00["user_override"]["locked"] and "伤害、攻速" in h00["user_override"]["locked"])
check("basic_sources_exist",all((ROOT/p).is_file() for p in basic["sources"]))
check("six_existing_enemy_ordinary_rows_not_new_spells",{r["id"] for r in data["spells"] if "basic_attack_note" in r}==set(basic["enemy_rows"]) and len(basic["enemy_rows"])==6)
check("basic_old_review_preserved",h00["proposal"]!=h00["user_override"]["proposal"] and "普攻优化追加" in h00["jev"]["review_scope"])
check("basic_not_mislabeled_visually_rejected","不等于旧版整招被否定" in h00["user_override"]["clip_caption"] and "evidence" not in h00["user_override"])
check("markdown_basic_optimization_present",h00["user_override"]["proposal"] in md.read_text() and "## 普攻追加优化" in md.read_text())
report={"checks":checks,"checked_files":len(text_paths),"scope":"Artifact/traceability only; not Unity, native build or visual acceptance"}
(OUT/"artifact-checks.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(report,ensure_ascii=False))
