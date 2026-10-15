#!/usr/bin/env python3
"""Refuse to build the institution playtest against the superseded art tree.

This checks required production resources and their wiring. Export freshness
remains a separate check; neither check constitutes visual approval.
"""

from pathlib import Path
import sys


def check(root: Path) -> list[str]:
    required = [
        "UnityBattleSource/Assets/Scripts/AIHeroAnimatedBody.cs",
        "UnityBattleSource/Assets/Resources/CombatTempo/AIHero/mistport-night/01-diagonal-cut.png",
        "UnityBattleSource/Assets/Resources/SpellSpectacle20260926/SpectacleInk20261008.shader",
    ]
    problems = [name for name in required if not (root / name).is_file()]
    for name, symbol in [
        ("UnityBattleSource/Assets/Scripts/BattlePrototype.cs", "AIHeroAnimatedBody"),
        ("UnityBattleSource/Assets/Scripts/SpellSpectacle20260926.cs", "Ink2D"),
        ("mistport-ios/Mistport/ChapterOneTestView.swift", "combatItemsOnLeft"),
        ("mistport-ios/MistportCombatCore/Sources/MistportCombatCore/OrderedSkillRules.swift", "MPCOrderedSkill"),
    ]:
        path = root / name
        if not path.is_file() or symbol not in path.read_text():
            problems.append(f"{name}: missing {symbol} wiring")
    for name in ("RefinedHero", "RefinedHeroV2", "RefinedHeroV3", "RefinedHeroV4"):
        path = root / "UnityBattleSource/Assets/Resources/CombatTempo" / name
        if path.exists():
            problems.append(f"retired hero resources reintroduced: {name}")
    presentation = root / "UnityBattleSource/Assets/Scripts/CombatTempoPresentation.cs"
    if presentation.is_file() and any(f"--hero-v{i}" in presentation.read_text() for i in range(1, 5)):
        problems.append("retired hero version selector reintroduced")
    for number in ("01", "04", "05", "06", "07", "08", "09", "11", "12", "13"):
        path = root / f"mistport-ios/Mistport/Assets.xcassets/FoolOrderedCard{number}20261012.imageset/card.png"
        if not path.is_file():
            problems.append(f"ordered card art missing: {number}")
    hud = root / "mistport-ios/Mistport/ChapterOneTestView.swift"
    if hud.is_file():
        text = hud.read_text()
        if "stage.size.width - 40" not in text or "combatDock" not in text:
            problems.append("current bottom dock/right item rail missing")
    return problems


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).resolve().parent.parent
    problems = check(root)
    if problems:
        print("error: 机构试玩仍指向过时美术，停止构建。先整合新版资源及挂接，再重新导出 Unity。", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        sys.exit(1)
    print("Institution art baseline present; Unity export freshness and visual review still required.")
