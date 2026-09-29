"""Local-wealth import on the 2,000-account market model (tools/economy-agent-sim), 2026-09-29.

The V3 server model has no player-to-player market, so imported copper there can only buy the
rationed basket and open services and barely moves any price. This model has one: bids rise with
the buyer's cash, so it can show imported wealth bidding prices up. Same corrected rules and
two-fold materials as fee_sweep.py, trade fee 5% (its decision). Half of the launch cohort (players
present on day 1) brings a local save: balance log-normal with median 2,000, at most 12,000, cut
at the import cap. Seeds use a separate random stream, so every cap sees the same players.

Decision rule, fixed before running: the largest cap at which the market basket index's yearly
peak rises by at most 10% and the free-player drug fill in the last 90 days falls by at most
2 points against no import.

    python3 tools/economy-decisions/import_market.py --out <dir> [--workers 4]
"""
from pathlib import Path
import argparse, json, statistics, subprocess, sys, tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fee_sweep import SEEDS, write_patched_model

CAPS = (0, 500, 1000, 2000, 4000, 12000)
FEE_BPS = 500

RUNNER = '''
import json, math, random, sys
from dataclasses import replace
from concurrent.futures import ProcessPoolExecutor
from model import Config, Sim
def one(job):
    cap, seed, fee = job
    conf = replace(Config(days=365), name=f"import{cap}", bundle=4, base_capacity=2, fee_bps=fee)
    s = Sim(conf, seed)
    r = random.Random(seed * 7919 + 1); imported = 0
    for a in s.p:
        if a.join == 0:
            carries = r.random() < 0.5
            balance = min(12000, int(r.lognormvariate(math.log(2000), 0.8)))
            if carries and cap > 0:
                a.cash += min(cap, balance); imported += min(cap, balance)
    s.open_money = s.total_money()
    out = s.run().summary()
    idx = [x for x in out["basket_index_30d"] if x is not None]
    return dict(cap=cap, seed=seed, imported=imported, index_peak=max(idx) if idx else None, index_last=idx[-1] if idx else None,
                max_30d_change=out["max_30d_change"], free_fill=out["free_fill_last90"], free_cash_p50=out["free_cash_p50"],
                paid_cash_p50=out["paid_cash_p50"], trades=out["trades"], gross=out["gross"], checks=out["checks"])
if __name__ == "__main__":
    caps = [int(x) for x in sys.argv[1].split(",")]; seeds = [int(x) for x in sys.argv[2].split(",")]
    with ProcessPoolExecutor(max_workers=int(sys.argv[3])) as pool:
        rows = list(pool.map(one, [(c, s, int(sys.argv[4])) for c in caps for s in seeds]))
    print(json.dumps(rows))
'''


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out", required=True); ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    with tempfile.TemporaryDirectory(prefix="mistport-import-") as tmp:
        tmp = Path(tmp); write_patched_model(tmp); (tmp / "runner.py").write_text(RUNNER)
        out = subprocess.run([sys.executable, str(tmp / "runner.py"), ",".join(map(str, CAPS)), ",".join(map(str, SEEDS)), str(args.workers), str(FEE_BPS)],
                             cwd=tmp, check=True, capture_output=True, text=True).stdout
    rows = json.loads(out.strip().splitlines()[-1])
    dest = Path(args.out); dest.mkdir(parents=True, exist_ok=True)
    (dest / "import_runs.json").write_text(json.dumps(rows, indent=1))
    by = {c: [r for r in rows if r["cap"] == c] for c in CAPS}
    m = lambda c, k: statistics.mean(r[k] for r in by[c])
    base_peak = m(0, "index_peak"); base_fill = m(0, "free_fill")
    lines = ["| 带入上限 | 带入总额 | 市场篮子指数全年峰值 | 比不带入高 | 最后 30 天指数 | 最大 30 天变化 | 免费玩家药品履约（末 90 天） | 免费玩家中位现金 |",
             "|---:|---:|---:|---:|---:|---:|---:|---:|"]
    ok = []
    for c in CAPS:
        peak = m(c, "index_peak"); fill = m(c, "free_fill"); rise = peak / base_peak - 1
        lines.append(f"| {c:,} | {m(c, 'imported'):,.0f} | {peak:.3f} | {rise:+.1%} | {m(c, 'index_last'):.3f} | {m(c, 'max_30d_change'):.0%} | {fill:.1%} | {m(c, 'free_cash_p50'):,.0f} |")
        if rise <= 0.10 and fill >= base_fill - 0.02:
            ok.append(c)
    chosen = max(ok) if ok else 0
    decision = f"**本地财富带入判定（市场模型）**：上限 {chosen:,} 铜（篮子指数全年峰值比不带入高不超过 10%、免费玩家药品履约下降不超过 2 个百分点的最大一档）。"
    text = "\n".join(["# 本地财富带入（2000 账户玩家市场模型）", "",
                      "事先定的判定规则：取市场篮子指数全年峰值比不带入高不超过 10%、免费玩家末 90 天药品履约下降不超过 2 个百分点的最大带入上限。", "",
                      f"开服批（第 1 天就在的玩家）一半带单机存档，余额对数正态，中位 2,000、最多 12,000，按上限截断；交易费 {FEE_BPS/100:g}%，"
                      f"两倍塔材、修正后的购物与工匠利润规则，{len(SEEDS)} 个种子 × 365 天。", ""] + lines + ["", decision, ""])
    (dest / "report.md").write_text(text + "\n"); (dest / "decision.json").write_text(json.dumps({"cap": chosen, "text": decision}, ensure_ascii=False))
    print(text)


if __name__ == "__main__":
    main()
