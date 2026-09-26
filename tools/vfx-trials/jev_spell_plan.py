#!/usr/bin/env python3
"""Read-only TypeSafe planning review; credentials remain in process memory.

The model judges supplied plans, not pixels or game acceptance. Requests and
responses are retained without HTTP headers. No Unity/game files are modified.
"""
import argparse
import concurrent.futures
import datetime as dt
import getpass
import hashlib
import json
import math
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "output/jev-spell-plan-20260921"
ENDPOINT = "https://api.typesafe.ai/v1/systemone"
ROUTES = {
    "preserve": "已有用户认可的主体或阶段，优先保留，仅回归核对，不推倒重做。",
    "refine": "已有可用独立主体；沿原主体补曲面层次、原画细节、身体附着起手或收势。",
    "rebuild": "明确被否定的主体或飞行段尚未解决；局部重做，不覆盖已认可阶段。",
    "verify": "缺少证据或契约有歧义；先核实实际整招，再决定如何改视觉。",
    "defer": "暂停、旧库、纯数据或未批准正式接入的内容；保留方案，不重新开放。",
}


def save(path, data):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate(payload, result):
    if not isinstance(result.get("model"), str) or not isinstance(result.get("usage"), dict):
        raise ValueError("Missing model/usage")
    if set(result.get("answers", {})) != set(payload["questions"]):
        raise ValueError("Answer coverage mismatch")
    for qid, q in payload["questions"].items():
        answer = result["answers"][qid]
        if answer.get("type") != q["type"]:
            raise ValueError("Answer type mismatch")
        if q["type"] == "noul":
            value = answer["noul"]
            if not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 <= value <= 1:
                raise ValueError("Invalid Noul")
        else:
            probabilities = answer["probabilities"]
            expected = set(q["criteria"]) if q["type"] == "choice" else set(map(str, range(len(q["criteria"]))))
            if set(probabilities) != expected:
                raise ValueError("Probability option mismatch")
            if any(not isinstance(v, (int, float)) or not math.isfinite(v) or not 0 <= v <= 1 for v in probabilities.values()):
                raise ValueError("Invalid probability")
            if abs(sum(probabilities.values()) - 1) > .025:
                raise ValueError("Invalid probability sum")
            if not 0 <= answer["confidence"] <= 1:
                raise ValueError("Invalid confidence")
            if q["type"] == "choice" and answer["choice"] not in expected:
                raise ValueError("Invalid choice")
            if q["type"] == "score" and not 0 <= answer["score"] <= len(q["criteria"]) - 1:
                raise ValueError("Invalid score")


def evaluate(tag, payload, key, run_dir):
    raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    save(run_dir / f"{tag}.request.json", payload)
    started = time.monotonic()
    attempts = []
    for attempt in range(3):
        req = urllib.request.Request(ENDPOINT, data=raw, method="POST", headers={
            "Authorization": "Bearer " + key, "Content-Type": "application/json",
        })
        try:
            with urllib.request.build_opener(NoRedirect).open(req, timeout=45) as reply:
                result = json.load(reply)
                status = reply.status
            validate(payload, result)
            record = {"status": status, "endpoint": ENDPOINT, "request_sha256": hashlib.sha256(raw).hexdigest(),
                      "utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                      "seconds": round(time.monotonic() - started, 3), "attempts": attempts, "response": result}
            save(run_dir / f"{tag}.response.json", record)
            print(json.dumps({"batch": tag, "status": status, "model": result["model"], "usage": result["usage"]}), flush=True)
            return record
        except urllib.error.HTTPError as error:
            attempts.append({"attempt": attempt + 1, "status": error.code,
                             "body": error.read(1800).decode("utf-8", errors="replace").replace(key, "[REDACTED]")})
            if error.code not in (429, 500, 502, 503, 504, 529) or attempt == 2:
                break
        except (urllib.error.URLError, TimeoutError) as error:
            attempts.append({"attempt": attempt + 1, "error": type(error).__name__})
            if attempt == 2:
                break
        time.sleep(2 ** (attempt + 1))
    save(run_dir / f"{tag}.error.json", {"attempts": attempts})
    raise RuntimeError(f"{tag}: API failed; see sanitized error receipt")


def questions_for(row_id):
    pointer = f"state.spells[{row_id!r}]"
    return {
        row_id + "__route": {"type": "choice", "instructions": f"仅根据{pointer}的最新事实和候选整招方案，下一步最合适的处理路线是什么？已重做待复核不等于旧否定仍未解决。阶段可局部保留；仅判断文字规划，不声称看过视频。", "criteria": ROUTES},
        row_id + "__contradiction": {"type": "noul", "instructions": f"{pointer}.stages或.proposal中是否有明确违反该行.contract、.locked或state.rules的提案？只报实际矛盾；缺少视觉证据不算矛盾。",
                                     "criteria": {"true": "方案明确改目标/伤害/冷却、把蓄力拆成招、回退被否定造型或把试演当正式。", "false": "没有明确违反；方案区分既有事实与待验证视觉提案。"}},
        row_id + "__gap": {"type": "score", "instructions": f"{pointer}当前版本的已知未解决制作缺口有多大？只依据.current与.locked，不从拟议细节反推当前存在缺陷，也不把测试通过当视觉通过。",
                          "criteria": ["已有认可阶段，剩余是保持与回归检查，或本来不在正式制作范围。", "有待复核或细节打磨空间，但没有当前主体仍被否定的证据。", "记录明确当前某一主体/飞行/持续阶段不满足要求，需要局部重做。", "记录明确整招缺失或当前目标/回调契约损坏，无法作为完整法术使用。"]},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--manifest", type=Path, default=BASE / "manifest.json")
    parser.add_argument("--ids", nargs="*")
    args = parser.parse_args()
    if not sys.stdin.isatty():
        raise SystemExit("Use a terminal for the hidden credential prompt")
    key = getpass.getpass("TypeSafe API key (hidden): ").strip().replace("\\_", "_")
    if not key:
        raise SystemExit("Missing credential")
    run_dir = BASE / ("probe-" if args.probe else "run-") / dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run_dir.mkdir(parents=True)
    if args.probe:
        payload = {"model": "jev-latest", "state": {"spell": "束缚", "stages": ["蓄力", "释放", "命中", "持续", "收势"], "rule": "蓄力是同一法术的阶段"},
                   "questions": {"grouping": {"type": "choice", "instructions": "按state.rule，state.stages应如何计数？", "criteria": {"one_spell": "一招包含全部阶段", "five_spells": "五个独立法术"}}}}
        record = evaluate("probe", payload, key, run_dir)
        save(run_dir / "summary.json", {"probe_only": True, "record": record})
    else:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        rows = [r for r in manifest["spells"] if not args.ids or r["id"] in args.ids]
        if args.ids and set(args.ids) != {r["id"] for r in rows}:
            raise SystemExit("Unknown spell ID")
        if not rows:
            raise SystemExit("No rows")
        jobs = []
        for start in range(0, len(rows), 5):
            group = rows[start:start + 5]
            state = {"rules": manifest["rules"], "spells": {r["id"]: {k: v for k, v in r.items() if k not in ("clips", "audit_indices")} for r in group}}
            qs = {k: v for r in group for k, v in questions_for(r["id"]).items()}
            jobs.append((f"batch-{start // 5 + 1:02}", {"model": "jev-latest", "state": state, "questions": qs}))
        results = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {pool.submit(evaluate, name, payload, key, run_dir): name for name, payload in jobs}
            for future in concurrent.futures.as_completed(futures):
                results[futures[future]] = future.result()
        save(run_dir / "summary.json", {"manifest_sha256": hashlib.sha256(args.manifest.read_bytes()).hexdigest(),
             "spell_ids": [r["id"] for r in rows], "request_count": len(results), "question_count": len(rows) * 3,
             "models": sorted({v["response"]["model"] for v in results.values()}),
             "usage": {name: sum(v["response"]["usage"].get(name, 0) for v in results.values()) for name in ("input_tokens", "output_tokens")},
             "answers": {qid: answer for name in sorted(results) for qid, answer in results[name]["response"]["answers"].items()}})
    key = None
    print("RECEIPTS " + str(run_dir), flush=True)


if __name__ == "__main__":
    main()
