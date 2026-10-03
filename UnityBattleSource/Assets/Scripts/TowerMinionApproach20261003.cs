using UnityEngine;

/// Tower minion packs (2026-10-03): a small monster sets out from the back corners of
/// the arena and slowly walks in toward the hero to its slot, so the pack reads as a
/// crowd closing in from both sides. Presentation only. It waits for native combat
/// (the rules' clock starts there) plus 1.2 s, because the first wave is configured
/// behind the loading cover, then walks 4.4 + 0.5k s: home by 5.6 + 0.5k s, before the
/// rules let minion k act (no earlier than 6 + 0.9k s, MPCChurchTowerCatalog.minionArrival).
/// If it is asked to act early anyway it is placed at its slot at once; if it is
/// defeated on the way it stops where it fell.
public sealed class TowerMinionApproach20261003 : MonoBehaviour
{
    const float Distance = 4.6f, Widen = 1.6f, SetOutDelay = 1.2f;
    EnemyHandle handle;
    Vector3 home, from;
    Quaternion facing;
    float duration, age, stepRate, bob;
    Animator animator;
    bool walking, waiting;
    float holdUntil = -1f;
    static UnityBattleBridge bridge;
    static BattlePrototype battle;

    public static void Begin(EnemyHandle handle, int index, Vector3 home, bool quadruped)
    {
        if (!handle || !handle.EnemyRoot) return;
        var walk = handle.GetComponent<TowerMinionApproach20261003>();
        if (!walk) walk = handle.gameObject.AddComponent<TowerMinionApproach20261003>();
        walk.Configure(handle, index, home, quadruped);
    }

    /// Finish the walk now (the minion is about to act).
    public static void Arrive(EnemyHandle handle)
    {
        if (handle && handle.TryGetComponent(out TowerMinionApproach20261003 walk)) walk.Arrive();
    }

    void Configure(EnemyHandle owner, int index, Vector3 slot, bool quadruped)
    {
        handle = owner;
        home = slot;
        facing = owner.EnemyRoot.rotation;
        // Set out from deeper and wider (the outer pair enters at the screen edges) and
        // walk in toward the hero: the sideways part is what reads on this low camera.
        from = new Vector3(slot.x * Widen, slot.y, slot.z + Distance);
        duration = 4.4f + .5f * index;
        age = 0f;
        // Four-legged bodies trot with quicker, lower steps than the upright ones.
        stepRate = quadruped ? 2.6f : 1.9f;
        bob = (quadruped ? .045f : .065f) * Mathf.Max(.3f, owner.EnemyRoot.lossyScale.y);
        animator = owner.GetComponentInChildren<Animator>(true);
        if (animator) animator.speed = 1.35f;
        owner.EnemyRoot.SetPositionAndRotation(from, facing);
        if (Debug.isDebugBuild) Debug.Log($"MINIONWALK configure {owner.BattleEnemyId} k={index} t={Time.unscaledTime:F2} from={from:F1} home={home:F1}");
        waiting = true; holdUntil = -1f;
        walking = true;
        enabled = true;
    }

    public void Arrive()
    {
        if (!walking) return;
        if (Debug.isDebugBuild) Debug.Log($"MINIONWALK arrive {(handle ? handle.BattleEnemyId : "?")} t={Time.unscaledTime:F2} age={age:F2}/{duration:F2} waiting={waiting}");
        walking = false; waiting = false;
        if (handle && handle.EnemyRoot) handle.EnemyRoot.SetPositionAndRotation(home, facing);
        if (animator) animator.speed = 1f;
        enabled = false;
    }

    void Update()
    {
        if (!walking) return;
        if (!handle || !handle.EnemyRoot) { walking = false; enabled = false; return; }
        if (!bridge) bridge = FindFirstObjectByType<UnityBattleBridge>();
        if (bridge && bridge.IsEnemyExiting(handle))
        {
            // Defeated on the way (or before setting out): stop where it fell.
            walking = false; waiting = false;
            if (animator) animator.speed = 1f;
            enabled = false;
            return;
        }
        if (waiting)
        {
            if (!battle) battle = FindFirstObjectByType<BattlePrototype>();
            if (battle && !battle.NativeCombatEnabled) return;
            if (holdUntil < 0f) { holdUntil = Time.time + SetOutDelay; return; }
            if (Time.time < holdUntil) return;
            waiting = false;
            if (Debug.isDebugBuild) Debug.Log($"MINIONWALK set-out {handle.BattleEnemyId} t={Time.unscaledTime:F2}");
        }
        age += Time.deltaTime;
        float u = Mathf.Clamp01(age / duration);
        // A steady pace that settles into the slot over the last fifth.
        float travelled = u < .8f ? u / .8f * .9f : .9f + .1f * (1f - Mathf.Pow(1f - (u - .8f) / .2f, 2f));
        var position = Vector3.Lerp(from, home, travelled);
        float phase = age * stepRate * Mathf.PI;
        position.y = home.y + Mathf.Abs(Mathf.Sin(phase)) * bob * (1f - u);
        var sway = Quaternion.AngleAxis(Mathf.Sin(phase) * 4f * (1f - u), Vector3.up);
        handle.EnemyRoot.SetPositionAndRotation(position, facing * sway);
        if (u >= 1f) Arrive();
    }

    void OnDisable() => Arrive();
}
