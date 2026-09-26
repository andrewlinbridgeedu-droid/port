"""Reference calculator for FOOL_COMBAT_IMPLEMENTATION_SPEC v1.1.0.

Not production code. Verifies deterministic hit/dodge, defense, guard,
shield order, rounding, and the standard Fool combo.
"""
from decimal import Decimal, ROUND_HALF_UP
from dataclasses import dataclass

PERCENT_SCALE = 10_000


def round_half_up(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def calculate_damage_after_defense(*, attack: int, coefficient_bp: int,
    target_defense: int, outgoing_bonus_bp: int = 0,
    armor_penetration_bp: int = 0, flat_defense_bonus: int = 0,
    flat_defense_penalty: int = 0, damage_type: str = "STANDARD") -> int:
    modified_defense = max(0, target_defense + flat_defense_bonus - flat_defense_penalty)
    effective_defense = 0 if damage_type == "TRUE" else (
        modified_defense * (PERCENT_SCALE - armor_penetration_bp)
    ) // PERCENT_SCALE
    raw = (Decimal(attack) * Decimal(coefficient_bp) / PERCENT_SCALE
           * Decimal(PERCENT_SCALE + outgoing_bonus_bp) / PERCENT_SCALE
           * Decimal(100) / Decimal(100 + effective_defense))
    if coefficient_bp == 0:
        return 0
    return max(1, round_half_up(raw))


def apply_reduction(damage_after_defense: int, *reductions_bp: int) -> int:
    reduction = min(sum(reductions_bp), 6000)
    return max(1, round_half_up(
        Decimal(damage_after_defense) * Decimal(PERCENT_SCALE - reduction) / PERCENT_SCALE
    ))


@dataclass
class ActionResult:
    hit_result: str
    damage_hits: list[int]
    evasion_charges_after: int
    guard_charges_after: int
    shield_after: int
    hp_after: int


def resolve_attack_action(*, attack: int, coefficients_bp: list[int], target_defense: int,
    hit_policy: str = "DODGEABLE", evasion_charges: int = 0,
    guard_charges: int = 0, guard_reduction_bp: int = 3500,
    other_reductions_bp: tuple[int, ...] = (), shield: int = 0, hp: int = 1000) -> ActionResult:
    if hit_policy == "DODGEABLE" and evasion_charges > 0:
        return ActionResult("DODGED", [0] * len(coefficients_bp), evasion_charges - 1,
                            guard_charges, shield, hp)
    hits = []
    for coefficient in coefficients_bp:
        dmg = calculate_damage_after_defense(attack=attack, coefficient_bp=coefficient,
                                             target_defense=target_defense)
        reductions = list(other_reductions_bp)
        if guard_charges > 0:
            reductions.append(guard_reduction_bp)
        dmg = apply_reduction(dmg, *reductions) if reductions else dmg
        absorb = min(shield, dmg)
        shield -= absorb
        hp -= dmg - absorb
        hits.append(dmg)
    return ActionResult("HIT", hits, evasion_charges,
                        max(0, guard_charges - 1), shield, max(0, hp))


def standard_combo(target_defense: int) -> list[int]:
    params = [
        (5000,0,0),(6000,1000,0),(8000,3500,0),(7000,1500,0),
        (13300,1500,0),(16800,0,0),(36000,0,3000)
    ]
    return [calculate_damage_after_defense(attack=100, coefficient_bp=c,
        target_defense=target_defense, outgoing_bonus_bp=b,
        armor_penetration_bp=p) for c,b,p in params]


def run_reference_assertions() -> None:
    expected = {0:986,10:904,15:870,20:837,25:807}
    for defense,total in expected.items():
        assert sum(standard_combo(defense)) == total
    assert standard_combo(20) == [42,55,90,67,127,140,316]

    t13 = resolve_attack_action(attack=100, coefficients_bp=[10000], target_defense=20)
    assert (t13.hit_result,t13.damage_hits) == ("HIT",[83])

    t14 = resolve_attack_action(attack=100, coefficients_bp=[10000], target_defense=20,
                                evasion_charges=1, shield=50)
    assert (t14.hit_result,t14.damage_hits,t14.evasion_charges_after,t14.shield_after,t14.hp_after) == ("DODGED",[0],0,50,1000)

    t15 = resolve_attack_action(attack=100, coefficients_bp=[7000,13300], target_defense=20,
                                evasion_charges=1)
    assert (t15.damage_hits,t15.evasion_charges_after) == ([0,0],0)

    t16 = resolve_attack_action(attack=100, coefficients_bp=[10000], target_defense=20,
                                hit_policy="UNAVOIDABLE", evasion_charges=1)
    assert (t16.damage_hits,t16.evasion_charges_after) == ([83],1)

    t17 = resolve_attack_action(attack=100, coefficients_bp=[10000], target_defense=20,
                                guard_charges=1)
    assert (t17.damage_hits,t17.guard_charges_after) == ([54],0)

    t18 = resolve_attack_action(attack=100, coefficients_bp=[10000], target_defense=20,
                                guard_charges=1, shield=50)
    assert (t18.shield_after,t18.hp_after) == (0,996)

    t19 = resolve_attack_action(attack=100, coefficients_bp=[10000], target_defense=20,
                                guard_charges=1, other_reductions_bp=(1500,))
    assert t19.damage_hits == [42]


if __name__ == "__main__":
    run_reference_assertions()
    print("All v1.1 reference assertions passed.")
    print("Defense 20 combo:", standard_combo(20), "total=", sum(standard_combo(20)))
    print("Dodge/guard/shield tests passed.")
