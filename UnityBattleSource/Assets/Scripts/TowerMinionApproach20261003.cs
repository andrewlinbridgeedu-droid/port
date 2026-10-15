using UnityEngine;

/// Small monsters advance from the rear to melee range of the protagonist.
/// Arrival finishes before the native first-action deadline (6 + 0.9k seconds).
/// Native rules still own damage; defeat interrupts approach at the current point.
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

    /// Set by the spell recorder, whose rows hold every actor in its encounter slot.
    public static bool Disabled;

    public static void Begin(EnemyHandle handle, int index, Vector3 home, bool quadruped)
    {
        if (Disabled || !handle || !handle.EnemyRoot) return;
        var walk = handle.GetComponent<TowerMinionApproach20261003>();
        if (!walk) walk = handle.gameObject.AddComponent<TowerMinionApproach20261003>();
        walk.Configure(handle, index, home, quadruped);
    }

    /// Settle at the melee destination before the native attack presentation.
    public static void Arrive(EnemyHandle handle)
    {
        if (handle && handle.TryGetComponent(out TowerMinionApproach20261003 walk)) walk.Arrive();
    }

    void Configure(EnemyHandle owner, int index, Vector3 slot, bool quadruped)
    {
        handle = owner;
        if (!battle) battle = FindFirstObjectByType<BattlePrototype>();
        var hero = battle ? battle.TempoSamplePlayer : null;
        // A shallow fan in front of the hero leaves distinct silhouettes while
        // putting every attacker within striking distance, rather than at z=5.6.
        float angle = (index % 6 - 2.5f) * 20f * Mathf.Deg2Rad;
        home = hero ? hero.position + new Vector3(Mathf.Sin(angle) * 1.55f, 0f, Mathf.Cos(angle) * 1.55f) : slot;
        home.y = slot.y;
        var direction = hero ? hero.position - home : owner.EnemyRoot.forward;
        direction.y = 0f;
        // The imported minion VisualProfile already turns the authored model
        // 180 degrees: its presented face is root -Z, not root +Z.
        facing = direction.sqrMagnitude > .001f
            ? Quaternion.LookRotation(-direction) : owner.EnemyRoot.rotation;
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
        owner.EnemyRoot.SetPositionAndRotation(from, FacingPlayer(from));
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
        if (handle && handle.EnemyRoot) handle.EnemyRoot.SetPositionAndRotation(home, FacingPlayer(home));
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
        handle.EnemyRoot.SetPositionAndRotation(position, FacingPlayer(position) * sway);
        if (u >= 1f) Arrive();
    }

    void OnDisable() => Arrive();

    Quaternion FacingPlayer(Vector3 position)
    {
        var hero = battle ? battle.TempoSamplePlayer : null;
        if (!hero) return facing;
        var direction = hero.position - position;
        direction.y = 0f;
        return direction.sqrMagnitude > .001f ? Quaternion.LookRotation(-direction) : facing;
    }
}
