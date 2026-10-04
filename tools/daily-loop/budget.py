"""Daily-loop budget for chapter one under daily pacing (design estimate, not game data).

usage: python3 tools/daily-loop/budget.py [out.md]

Walks days 1-30 for players who give the game 45, 90, 120 or 240 minutes a day.
Progress (story, tower first clears, bounty cases, one-off stories) opens by day and
is the same for everyone; the rest of the day goes to world events, the workshop,
the tavern and repeatable jobs. Copper comes from the game's current one-time
rewards plus repeatable work, with and without the proposed daily taper.

Every minute value is an unmeasured human estimate; copper values marked "现行"
are the current game's, the rest are candidates. Change them here and rerun.
"""
import sys

DAYS = 30
FIRST_DAY_MISSIONS = 3            # MPCDailyPacing.missionsOnFirstDay
TOWER_FLOORS_PER_DAY = 4          # MPCDailyPacing.towerFloorsPerDay

# Minutes (estimates, to be measured on device).
MIN_MISSION = 6                   # battle, story and preparation
MIN_FLOOR = 2
MIN_CASE = 12                     # investigation 6-12 min plus the fight
MIN_STORY_TASK = 10               # tavern underground task (design U01-U06)
MIN_EVENT_DAY = 15                # during an event week: two battles and a delivery
MIN_WORKSHOP_BATCH = 3            # one F1 replay for hide plus a craft
MIN_TAVERN = 10
JOBS = {                          # name: (unlock day, minutes, copper 现行)
    "J0": (2, 3, 40),             # seal check, Q4 (day 2)
    "J1": (7, 8, 60),             # patrol, Q9 (day 7)
    "J2": (3, 10, 80),            # tower maintenance, first ten-floor band (day 3)
}

# Copper 现行 (current game).
START_COPPER = 180
def mission_copper(m):
    return 300 if m == 30 else [30, 40, 50, 80, 100, 120][min(5, (m - 1) // 5)]
def floor_copper(f):
    return 8 + 2 * ((f - 1) // 10)
CASE_DAYS = [3, 5, 7, 9, 11, 13, 15, 17, 19, 21]   # one case every other day (board 3-6/day)
CASE_COPPER = 106                                    # 1060 over ten cases
STORY_TASK_DAYS = [8, 14, 18, 21, 22, 25]            # U01-U06 at Q10/16/20/23/24/27

# Spending 现行: shop relics on unlock, a salve per mission from Q5, three materials, ritual.
SHOP = [(4, 120), (4, 160), (9, 360), (14, 520), (18, 400), (20, 640), (26, 720)]
MATERIALS = [(17, 260), (20, 340), (23, 480)]
RITUAL = (30, 280)
SALVE = 30
REPAIR_PER_BATTLE = 2

# Candidates in the design.
WORKSHOP_DAY = 3                  # proposed: basic workshop from Q5 (day 3), not Q16
STRAPS_PER_BATCH, BATCH_COST, STRAP_PRICE = 3, 13, 9
NPC_STRAPS_PER_DAY = 6            # finite NPC orders: two batches' worth a day
EVENT_WINDOWS = [(4, 10), (11, 17), (18, 24), (25, 28)]
EVENT_COPPER_PER_DAY = 20         # goods bought by the event's funded order
TAPER = [(3, 1.0), (6, 0.5), (10**9, 0.1)]   # repeatable jobs today: 1-3 full, 4-6 half, then 10%
WORKSHOP_ORDER_COPPER = 60        # candidate: NPC order budget a day once several basic recipes exist
WORKSHOP_PROFIT_PER_BATCH = 14    # 3 straps x 9 - 13 copper of base stock
# Street tasks opened by city contribution (StreetTasks.swift, written 2026-09-30). Tier days are the
# progression simulator's for a player doing the day's street tasks; minutes are the human-timing
# model at typical pace. Copper is the design's: urgent 15, joint 30, commission 60.
URGENT_FROM_DAY, JOINT_FROM_DAY, COMMISSION_FROM_DAY = 6, 12, 18
STREET = {"urgent": (1.4, 15), "joint": (2.0, 30), "commission": (2.8, 60)}
COMMISSIONS = 2                   # fountain, yard; one every seven days


def mission_day(m):
    return max(1, m - (FIRST_DAY_MISSIONS - 1))


def street_today(day):
    """Street tasks a player who does the day's street tasks takes on this day."""
    kinds = []
    if day >= URGENT_FROM_DAY: kinds.append("urgent")
    if day >= JOINT_FROM_DAY and day % 3 == 0: kinds.append("joint")
    if day >= COMMISSION_FROM_DAY and (day - COMMISSION_FROM_DAY) % 7 == 0 and (day - COMMISSION_FROM_DAY) // 7 < COMMISSIONS:
        kinds.append("commission")
    return kinds


def simulate(minutes_per_day, taper, max_jobs=None, rich_workshop=False, street=False):
    balance, low, earned_jobs, spent = START_COPPER, START_COPPER, 0, 0
    street_copper, street_minutes = 0, 0.0
    floors, jobs_done, rows = 0, 0, []
    for day in range(1, DAYS + 1):
        left = minutes_per_day
        copper = 0
        # Progress: the same for everyone.
        missions = [m for m in range(1, 31) if mission_day(m) == day]
        new_floors = min(100, day * TOWER_FLOORS_PER_DAY) - floors
        progress = len(missions) * MIN_MISSION + new_floors * MIN_FLOOR
        copper += sum(mission_copper(m) for m in missions)
        copper += sum(floor_copper(f) for f in range(floors + 1, floors + new_floors + 1))
        floors += new_floors
        if day in CASE_DAYS:
            progress += MIN_CASE; copper += CASE_COPPER
        if day in STORY_TASK_DAYS:
            progress += MIN_STORY_TASK
        left -= progress
        costs = sum(p for d, p in SHOP if mission_day(d) == day)
        costs += sum(p for d, p in MATERIALS if mission_day(d) == day)
        costs += RITUAL[1] if mission_day(RITUAL[0]) == day else 0
        costs += SALVE * sum(1 for m in missions if m >= 5)
        battles = len(missions) + new_floors
        # World event week.
        event = next((w for w in EVENT_WINDOWS if w[0] <= day <= w[1]), None)
        if event and left >= MIN_EVENT_DAY:
            left -= MIN_EVENT_DAY; copper += EVENT_COPPER_PER_DAY; battles += 2
        # Street tasks (city contribution), before the workshop.
        if street:
            for kind in street_today(day):
                mins, pay = STREET[kind]
                if left >= mins:
                    left -= mins; copper += pay; street_copper += pay; street_minutes += mins
        # Workshop: sell what NPC orders still take today.
        workshop = 0
        if day >= WORKSHOP_DAY:
            demand = (WORKSHOP_ORDER_COPPER // (STRAPS_PER_BATCH * STRAP_PRICE) if rich_workshop
                      else NPC_STRAPS_PER_DAY // STRAPS_PER_BATCH)
            batches = int(min(demand, max(0, left) // MIN_WORKSHOP_BATCH))
            left -= batches * MIN_WORKSHOP_BATCH; workshop = batches * MIN_WORKSHOP_BATCH
            copper += batches * WORKSHOP_PROFIT_PER_BATCH; battles += batches
        tavern = 0
        if minutes_per_day >= 90 and left >= MIN_TAVERN:
            left -= MIN_TAVERN; tavern = MIN_TAVERN
        # Repeatable jobs fill what is left, best copper per minute first.
        today = 0
        for name, (unlock, mins, pay) in sorted(JOBS.items(), key=lambda kv: -kv[1][2] / kv[1][1]):
            while day >= unlock and left >= mins and (max_jobs is None or today < max_jobs):
                today += 1
                rate = next(r for n, r in taper if today <= n) if taper else 1.0
                earned = round(pay * rate)
                copper += earned; earned_jobs += earned
                left -= mins; battles += 1 if name != "J0" else 0
        jobs_done += today
        costs += battles * REPAIR_PER_BATTLE
        balance += copper - costs; spent += costs
        low = min(low, balance)
        rows.append((day, minutes_per_day - max(0, left), today, copper, costs, balance, progress, max(0, left)))
    return {"rows": rows, "end": balance, "low": low, "jobs": jobs_done, "job_copper": earned_jobs, "spent": spent,
            "street_copper": street_copper, "street_minutes": street_minutes}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else None
    lines = ["**A. 如果剩下的时间只能靠重复工作填**（现行工作报酬）", "",
             "| 每天玩 | 平均每天做几单 | 重复工作铜（按单递减） | 章末余额 | 重复工作铜（不递减） | 章末余额 |",
             "|---|---:|---:|---:|---:|---:|"]
    for minutes in (45, 90, 120, 240):
        a, b = simulate(minutes, TAPER), simulate(minutes, None)
        lines.append(f"| {minutes} 分钟 | {a['jobs'] / DAYS:.1f} | {a['job_copper']} | {a['end']} | {b['job_copper']} | {b['end']} |")
    lines += ["", f"第一章必需支出（商店遗落物、止痛膏、三主材、仪式、修理）约 {simulate(90, TAPER)['spent']} 铜。", "",
              "**B. 按本设计分配**：重复工作只做玩家愿意做的几单，其余给工坊（有几种基础配方、NPC 订单每天约 60 铜）、世界事件和酒馆", "",
              "| 每天玩 | 每天做几单重复工作 | 30 天总铜（含一次性奖励） | 章末余额 | 平均每天还空着的分钟 |",
              "|---|---:|---:|---:|---:|"]
    for minutes, jobs in ((45, 2), (90, 4), (120, 6)):
        r = simulate(minutes, TAPER, max_jobs=jobs, rich_workshop=True)
        total = sum(row[3] for row in r["rows"]) + START_COPPER
        idle = sum(row[7] for row in r["rows"]) / DAYS
        lines.append(f"| {minutes} 分钟 | {jobs} | {total} | {r['end']} | {idle:.0f} |")
    lines += ["", "**C. 再加上城市贡献度开放的三类委托**（加急委托、街区难题、城市委托；第 6／12／18 天起，模拟器口径）", "",
              "| 每天玩 | 每天做几单重复工作 | 30 天总铜 | 章末余额 | 其中三类委托的铜 | 三类委托平均每天分钟 | 平均每天还空着的分钟 |",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for minutes, jobs in ((45, 2), (90, 4), (120, 6)):
        r = simulate(minutes, TAPER, max_jobs=jobs, rich_workshop=True, street=True)
        total = sum(row[3] for row in r["rows"]) + START_COPPER
        idle = sum(row[7] for row in r["rows"]) / DAYS
        lines.append(f"| {minutes} 分钟 | {jobs} | {total} | {r['end']} | {r['street_copper']} | {r['street_minutes'] / DAYS:.1f} | {idle:.0f} |")
    lines += ["", "| 天 | 推进内容用时（所有人相同，分钟） |", "|---:|---:|"]
    for day in (1, 2, 3, 7, 10, 14, 18, 21, 25, 28, 30):
        lines.append(f"| {day} | {_progress_minutes(day)} |")
    avg = sum(_progress_minutes(d) for d in range(1, DAYS + 1)) / DAYS
    lines.append(f"\n推进内容平均每天 {avg:.0f} 分钟。")
    text = "\n".join(lines) + "\n"
    print(text)
    if out:
        open(out, "w").write(text)


def _progress_minutes(day):
    missions = [m for m in range(1, 31) if mission_day(m) == day]
    floors = min(100, day * TOWER_FLOORS_PER_DAY) - min(100, (day - 1) * TOWER_FLOORS_PER_DAY)
    minutes = len(missions) * MIN_MISSION + floors * MIN_FLOOR
    minutes += MIN_CASE if day in CASE_DAYS else 0
    minutes += MIN_STORY_TASK if day in STORY_TASK_DAYS else 0
    return minutes


if __name__ == "__main__":
    main()
