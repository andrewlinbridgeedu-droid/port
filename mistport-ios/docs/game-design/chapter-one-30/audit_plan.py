"""Validate planning data and budget arithmetic, not combat balance or shipped code."""
import json
from pathlib import Path
from math import ceil

ROOT = Path(__file__).resolve().parent


def audit(data):
    checks = []

    def check(label, condition):
        checks.append({"check": label, "passed": bool(condition)})

    models = data["models"]
    missions = data["missions"]
    model_ids = {m["id"] for m in models}
    check("16 unique chapter models, including one hero and one new boss", len(models) == len(model_ids) == 16 and sum(m["role"] == "hero" for m in models) == 1 and sum(m["role"] == "new_boss" for m in models) == 1)
    check("30 consecutive unique main quests", sorted(m["q"] for m in missions) == list(range(1, 31)))
    check("all enemy references use budgeted models", all(e in model_ids and e != "M00" for m in missions for e in m["enemies"]))
    check("all 15 enemy models have a chapter role", {e for m in missions for e in m["enemies"]} == model_ids - {"M00"})
    by_q = {m["q"]: m for m in missions}
    check("Q1–15 accepted enemy rosters preserved", [by_q[q]["enemies"] for q in range(1, 16)] == [["M01"],["M02","M02"],["M03"],["M03"],["M04"],["M05"],["M01","M01","M06"],["M07"],["M10","M06"],["M08","M05"],["M07","M07","M01"],["M10","M10"],["M11","M06"],["M07","M10"],["M09","M06","M06"]])
    check("Q16–30 revised roster exact", [by_q[q]["enemies"] for q in range(16, 31)] == [["M03"],["M12"],["M13"],["M04"],["M14"],["M11","M06"],["M09"],["M13"],["M08","M02"],["M09"],["M14"],["M05","M08"],["M15"],["M15","M12","M01"],["M15"]])
    check("Q16–30 approved Pro titles preserved", [by_q[q]["title"] for q in range(16, 31)] == ["销号追索","自动补位","无效的许可","外海收件人","押运中的活档案","原始救援条款","不属于你的庇护","不以人名封口","地下泊位","自愿断线","最后一趟押运","未签署的归属","五次回流","最后的代签","无主者的签名"])
    check("boss narrative phases preserved", data["ending"]["boss_phase_names"] == ["受托人", "监护人", "所有者"])
    check("same boss appears Q28/29/30", [m["q"] for m in missions if "M15" in m["enemies"]] == [28,29,30])
    check("recurring entities follow approved encounters", {e["id"]: e["quests"] for e in data["recurring_entities"]} == {"H03":[3,4,16], "T15":[15,22,25], "R13":[13,21], "V21":[20,26], "S30":[28,29,30]})
    check("recurring entities use valid models and no more than three encounters", all(e["model"] in model_ids and len(e["quests"]) <= 3 and all(e["model"] in by_q[q]["enemies"] for q in e["quests"]) for e in data["recurring_entities"]))
    check("evidence obtained before first boss", data["evidence_nodes"]["original_name"] < 28 and data["evidence_nodes"]["external_claim_date"] < 28)
    check("five cycles on first two encounters; only final kills", [e.get("cycles") for e in data["boss_encounters"]] == [5,5,None] and [e["death"] for e in data["boss_encounters"]] == [False,False,True])
    check("talents follow moved events", {m["q"]:m.get("talent",0) for m in missions if m.get("talent",0)} == {9:4,16:4,18:6,22:8,24:8})
    ending = data["ending"]
    check("one-body three-phase boss truly dies, old three endings retired", ending["boss_bodies"] == 1 and ending["boss_phases"] == 3 and ending["boss_truly_dead"] and not ending["old_three_endings"])
    check("rescue remains real and departure preserves progression", ending["rescued_people_free"] and ending["destination"] == "黑盐岸·潮汐荒野" and ending["preserve_merit_loans_tower"] and data["promotion"]["ritual_location"] == "黑盐岸")
    check("breathing bag remains an unvalidated candidate", data["fallback"]["support_status"] == "candidate_not_implemented_or_validated")
    check("no main quest XP", all(m.get("xp", 0) == 0 for m in missions))
    check("skill grant timing preserved", data["skill_grants"] == {"1_after": "sidestep", "3_before": "mask_and_2_slots", "8_before": "identity", "9_after": "evidence", "10_after": "pursuit_and_4_slots", "11_after": "finale", "12_after": "turn_tables", "13_after": "nameless"})
    check("planned relic path available before Q5 without new base defense", data["fallback"]["available_after_q"] <= 4 and data["fallback"]["kind"] == "relic_loadout" and not data["fallback"]["base_defense_button"] and data["fallback"]["free_work_available_after_q"] <= 4)
    check("no tower completion prerequisite for promotion", data["promotion"]["required_tower_floor"] == 0)
    check("at least 8 relic contracts with anomaly downsides", len(data["relics"]) >= 8 and all(r["downside"] for r in data["relics"]))
    check("main mission money nonnegative", all(m["copper"] >= 0 for m in missions))
    income = sum(m["copper"] for m in missions)
    check("main income matches declared total", income == data["economy"]["main_total"])
    talents = sum(m.get("talent", 0) for m in missions)
    check("talents match new design ceiling", talents == data["talent_cap"])
    check("full talent build before final encounter", sum(m.get("talent", 0) for m in missions if m["q"] <= 27) == data["talent_cap"])
    promotion = sum(i["quantity"] * i["price"] for i in data["promotion"]["purchases"])
    check("promotion bill matches itemized sum", promotion == data["promotion"]["total_copper"])
    paid = 0
    purchase_balances = []
    for item in data["promotion"]["purchases"]:
        paid += item["quantity"] * item["price"]
        earned = sum(m["copper"] for m in missions if m["q"] <= item["available_after_q"])
        purchase_balances.append({"item": item["id"], "q": item["available_after_q"], "balance": earned-paid})
    check("mandatory purchases affordable at each proposed purchase node", all(x["balance"] >= 0 for x in purchase_balances))
    tiers = data["tower_bands"]
    available_demons = set(data["demon_models"]) | {data["tower_reused_model"]["id"]}
    check("tower samples only use seven available masters", all(e in available_demons for t in tiers for w in t["sample_waves"] for e in w))
    check("tower sample waves at most four enemies", all(1 <= len(w) <= 4 for t in tiers for w in t["sample_waves"]))
    check("one healing source per floor sample", all(sum(w.count("D03") for w in t["sample_waves"]) <= 1 for t in tiers))
    check("all seven masters represented across samples", {e for t in tiers for w in t["sample_waves"] for e in w} == available_demons)
    check("tower covers each floor 1–100 once", [f for t in tiers for f in range(t["from"], t["to"]+1)] == list(range(1, 101)))
    check("six user-supplied demon masters plus reused hound", len(data["demon_models"]) == len(set(data["demon_models"])) == 6 and data["demon_asset_count_including_reuse"] == 7)
    check("tower first-clear copper 1700 and merit 320", sum((t["to"]-t["from"]+1)*t["coin_per_floor"] for t in tiers) == 1700 and sum((t["to"]-t["from"]+1)*t["merit_per_floor"] for t in tiers) == 320)
    check("six bounty cases and six underground cases", len(data["bounties"]) >= 6 and len(data["underground"]) >= 6)
    check("side income 1220 and bounty merit 132", sum(b["copper"] for b in data["bounties"]+data["underground"]) == 1220 and sum(b["merit"] for b in data["bounties"]) == 132)
    check("no undeclared bounty combat models", all(e in model_ids for b in data["bounties"] if b["release"] == "chapter1" for e in b["enemies"]))
    check("repeat work accessible without copper or relic", data["economy"]["fallback_work"]["entry_fee"] == 0 and not data["economy"]["fallback_work"]["requires_combat"] and data["economy"]["fallback_work"]["copper"] > 0)
    loans = data["loan"]
    check("borrowed assets cannot be sold, dismantled, or pledged", not any(loans[k] for k in ("sellable", "dismantlable", "pledgeable")))
    check("loan payment never reduces earned merit tier", loans["tier_uses_lifetime_merit"])
    check("new contracts spend copper, not merit, for three battles", not loans["merit_spent_on_new_contract"] and loans["rental_battles"] == 3)
    check("rent is never refunded and ordinary wear cannot shrink escrow", not loans["rental_fee_refundable"] and loans["ordinary_wear_deposit_deduction"] == 0 and loans["deposit_forfeited_only_if_broken_or_lost"])
    check("refund not greater than paid deposit", loans["refund_max_fraction"] <= 1)
    relic_prices = {relic["id"]: relic["price"] for relic in data["relics"] if relic["loanable"]}
    check("all eight loanable relics have one price row", len(loans["prices"]) == len(relic_prices) == 8 and {row["id"] for row in loans["prices"]} == set(relic_prices))
    check("deposit and rent follow the approved copper formula", all(
        row["deposit"] == ceil(ceil(relic_prices[row["id"]] * 2 / 3) / 10) * 10
        and row["rent"] == ceil(relic_prices[row["id"]] / 10)
        and row["merit"] in (20, 40, 80)
        for row in loans["prices"]
    ))
    check("mask is never loanable", not data["relics"][0]["loanable"])
    check("repair then sell cannot earn copper at any durability", all((r["price"]*40//100 - ceil(r["price"]*(100-d)/200)) <= (r["price"]*40*d//10000) for r in data["relics"] if r["loanable"] for d in range(101)))
    scenarios = []
    for s in data["economy"]["scenarios"]:
        remaining = s["opening"] + income + s["side_income"] - promotion - s["other_spend"]
        scenarios.append({**s, "closing_copper": remaining})
        check("nonnegative planned budget: " + s["name"], remaining >= 0)
    work = data["economy"]["fallback_work"]
    recovery_jobs = ceil(promotion / work["copper"])
    return {"scope": "Design consistency and arithmetic only. No combat simulation, implementation, or phone acceptance.", "checks": checks, "passed": all(c["passed"] for c in checks), "main_copper": income, "promotion_copper": promotion, "purchase_node_balances": purchase_balances, "talent_total": talents, "budget_scenarios": scenarios, "zero_wallet_full_promotion_recovery_jobs": recovery_jobs, "recovery_minutes": [recovery_jobs * n for n in work["minutes_range"]]}


if __name__ == "__main__":
    report = audit(json.loads((ROOT / "plan_data.json").read_text()))
    (ROOT / "audit_results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["passed"] else 1)
