"""Trade-fee sweep on the 2,000-account market model (tools/economy-agent-sim), 2026-09-29.

Uses the corrected shopping and mature-crafter profit rules (run_shopping.py patches) on the
two-fold material supply the earlier study took as its starting point, and varies only the
player-to-player trade fee. Decision rule, fixed before running: the largest fee at which the
crafters' combined net market income falls by at most 10% and the free-player drug fill in the
last 90 days by at most 2 points against a zero fee.

    python3 tools/economy-decisions/fee_sweep.py --out <dir> [--workers 4]
"""
from pathlib import Path
import argparse, json, shutil, statistics, subprocess, sys, tempfile

ROOT = Path(__file__).resolve().parents[2]
AGENT = ROOT / "tools/economy-agent-sim"
FEES = (0, 200, 500, 800, 1200)
SEEDS = (101, 211, 307)

RUNNER = '''
import json, sys
from dataclasses import replace
from concurrent.futures import ProcessPoolExecutor
from model import Config, Sim
def one(job):
    fee, seed = job
    conf = replace(Config(days=365), name=f"fee{fee}", bundle=4, base_capacity=2, fee_bps=fee)
    s = Sim(conf, seed).run().summary()
    return dict(fee=fee, seed=seed, trades=s["trades"], gross=s["gross"], issuance=sum(s["issuance"].values()),
                sinks=s["sinks"], free_fill=s["free_fill_last90"], max_30d_change=s["max_30d_change"],
                crafter_net=sum(p["sales"] - p["purchases"] for p in s["profession"]),
                profession=s["profession"], free_cash_p50=s["free_cash_p50"], checks=s["checks"])
if __name__ == "__main__":
    fees = [int(x) for x in sys.argv[1].split(",")]; seeds = [int(x) for x in sys.argv[2].split(",")]
    with ProcessPoolExecutor(max_workers=int(sys.argv[3])) as pool:
        rows = list(pool.map(one, [(f, s) for f in fees for s in seeds]))
    print(json.dumps(rows))
'''

def write_patched_model(tmp: Path):
    """The market model with the corrected shopping and mature-crafter profit rules, in tmp."""
    sys.path.insert(0, str(AGENT))
    import run_shopping
    modified = (AGENT / "model.py").read_text()
    for old, new in run_shopping.REPLACEMENTS + [(run_shopping.PROFIT_OLD, run_shopping.PROFIT_NEW)]:
        assert modified.count(old) == 1; modified = modified.replace(old, new)
    (tmp / "model.py").write_text(modified)
    shutil.copyfile(AGENT / "source_inputs.json", tmp / "source_inputs.json")


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out", required=True); ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    with tempfile.TemporaryDirectory(prefix="mistport-fee-") as tmp:
        tmp = Path(tmp); write_patched_model(tmp); (tmp / "runner.py").write_text(RUNNER)
        out = subprocess.run([sys.executable, str(tmp / "runner.py"), ",".join(map(str, FEES)), ",".join(map(str, SEEDS)), str(args.workers)],
                             cwd=tmp, check=True, capture_output=True, text=True).stdout
    rows = json.loads(out.strip().splitlines()[-1])
    dest = Path(args.out); dest.mkdir(parents=True, exist_ok=True)
    (dest / "fee_runs.json").write_text(json.dumps(rows, indent=1))
    by = {f: [r for r in rows if r["fee"] == f] for f in FEES}
    base_net = statistics.mean(r["crafter_net"] for r in by[0]); base_fill = statistics.mean(r["free_fill"] for r in by[0])
    base_take = statistics.mean(sum(p["sales"] for p in r["profession"]) for r in by[0])
    lines = ["| 交易费 | 成交笔数 | 成交额 | 交易费回收 | 占全年发行 | 工匠市场净收入 | 比 0% 少 | 卖家到手 | 比 0% 少 | 免费玩家药品履约（末 90 天） | 最大 30 天价格变化 |",
             "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    ok = []
    for f in FEES:
        g = by[f]; m = lambda k: statistics.mean(r[k] for r in g)
        fee = statistics.mean(r["sinks"].get("trade_fee", 0) for r in g); issue = m("issuance")
        net = m("crafter_net"); fill = m("free_fill")
        # Every account has a profession, so the net is negative (players also buy from NPC stock);
        # the drop is measured against its size, not as a ratio of two negatives.
        drop = (base_net - net) / abs(base_net)
        take = statistics.mean(sum(p["sales"] for p in r["profession"]) for r in g); take_drop = 1 - take / base_take
        lines.append(f"| {f/100:g}% | {m('trades'):,.0f} | {m('gross'):,.0f} | {fee:,.0f} | {fee/issue:.2%} | {net:,.0f} | {drop:.1%} | {take:,.0f} | {take_drop:.1%} | {fill:.1%} | {statistics.mean(r['max_30d_change'] or 0 for r in g):.0%} |")
        if drop <= 0.10 and fill >= base_fill - 0.02:
            ok.append(f)
    chosen = max(ok) if ok else 0
    decision = f"**交易费判定**：{chosen/100:g}%（工匠市场净收入下降不超过 10%、免费玩家药品履约下降不超过 2 个百分点的最高一档）。"
    text = "\n".join(["# 交易费扫描（2000 账户玩家市场模型）", "", "事先定的判定规则：取工匠市场净收入相对 0% 下降不超过 10%、免费玩家末 90 天药品履约下降不超过 2 个百分点的最高交易费。", "",
                      f"两倍塔材、修正后的购物与工匠利润规则，{len(SEEDS)} 个种子 × 365 天，只改交易费。", ""] + lines + ["", decision, ""])
    (dest / "report.md").write_text(text + "\n"); (dest / "decision.json").write_text(json.dumps({"fee_bps": chosen, "text": decision}, ensure_ascii=False))
    print(text)

if __name__ == "__main__":
    main()
