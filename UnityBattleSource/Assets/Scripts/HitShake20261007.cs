using UnityEngine;

/// The body that takes a hit shakes (2026-10-07, user: 关键是手机震动，以及角色摇晃).
/// Presentation only: an additive offset on the visible model, never the rules, the
/// actor root's formation slot or the Animator clock. It knocks back a little away from
/// the attacker and rattles side to side, fast and damped, for about 0.4 s.
///
/// Ownership (2026-10-08): the offset is applied last in the frame (32000) on top of
/// whatever the other writers produced, and removed again first thing next frame by
/// HitShakeRestore20261007 (-20000, equality-gated). So BountyBodyRound2.MoveVisual /
/// RestoreFrame, CombatTempoAnimatedBody.OnAnimatorMove and the idle presences only ever
/// see the clean base position; nobody bakes our offset into theirs, and we never add it
/// twice. If somebody did write the position between our two phases, the LateUpdate gate
/// still catches an untouched offset, and otherwise re-bases on the newer value.
[DisallowMultipleComponent, DefaultExecutionOrder(32000)]
public sealed class HitShake20261007 : MonoBehaviour
{
    public const float Duration = .42f;
    Transform target;
    Vector3 away, lastBase, lastApplied;
    float started = -100f, strength, height;
    bool written;

    public bool IsShaking => Time.time - started < Duration;
    public float LastStrength => strength;

    /// <paramref name="awayFrom"/>: where the hit came from (the knock goes the other way).
    /// Returns null for an inactive model: a component there never runs (fog ghosts and
    /// emerald revenants keep handle.Model on the hidden old model, see
    /// EarlyEnemyIdlePresence.ResolveVisibleActor), so callers pass the visible actor.
    public static HitShake20261007 Hit(Transform model, Vector3 awayFrom, float strength)
    {
        if (!model || strength <= 0f || !model.gameObject.activeInHierarchy) return null;
        var shake = model.GetComponent<HitShake20261007>();
        if (!shake) shake = model.gameObject.AddComponent<HitShake20261007>();
        var restore = model.GetComponent<HitShakeRestore20261007>();
        if (!restore) restore = model.gameObject.AddComponent<HitShakeRestore20261007>();
        restore.shake = shake;
        shake.Begin(awayFrom, strength);
        return shake;
    }

    void Begin(Vector3 awayFrom, float value)
    {
        target = transform;
        bool any = false; var b = new Bounds(target.position, Vector3.zero);
        foreach (var r in target.GetComponentsInChildren<Renderer>(false))
        {
            if (!(r is SkinnedMeshRenderer || r is MeshRenderer)) continue;
            if (!any) { b = r.bounds; any = true; } else b.Encapsulate(r.bounds);
        }
        height = any ? Mathf.Clamp(b.size.y, .4f, 6f) : 1.5f;
        var d = b.center - awayFrom; d.y = 0f;
        away = d.sqrMagnitude > 1e-4f ? d.normalized : Vector3.forward;
        // A new hit inside the tail keeps the stronger shake.
        strength = IsShaking ? Mathf.Max(strength * Envelope(Time.time - started), value) : value;
        if (SpellSpectacle20260926.ReducedMotion) strength *= .35f;
        started = Time.time;
    }

    static float Envelope(float t) => t < 0f || t >= Duration ? 0f : Mathf.Pow(1f - t / Duration, 1.6f);

    /// Early-frame removal of our own offset (HitShakeRestore20261007, execution order
    /// -20000), before any other writer runs. Equality-gated: a position somebody else wrote
    /// since is left alone, and the pending offset is kept for LateUpdate to re-check.
    public void RestoreOwnedOffset()
    {
        if (!written || !target) return;
        if ((target.localPosition - lastApplied).sqrMagnitude < 1e-10f)
        {
            target.localPosition = lastBase;
            written = false;
        }
    }

    void LateUpdate()
    {
        if (!target) return;
        var now = target.localPosition;
        // Normally RestoreOwnedOffset has already removed our offset this frame, so `now` is
        // the frame's clean final position. Our last offset is still there only if nobody
        // else wrote the position since.
        var basePos = written && (now - lastApplied).sqrMagnitude < 1e-10f ? lastBase : now;
        float t = Time.time - started;
        if (t >= Duration || strength <= 0f)
        {
            if (written) target.localPosition = basePos;
            written = false;
            return;
        }
        var cam = Camera.main;
        Vector3 right = cam ? cam.transform.right : Vector3.right;
        float e = Envelope(t);
        // 2026-10-08: was a 40 ms ramp, 5 % knock and a 19 Hz 4.5 % rattle. At the ~15 fps a
        // hit frame gets on the simulator the rattle aliased to a still, and 5 % of the body is
        // below notice. Now the knock is immediate and 9 %, the swing 9 Hz and 6 % (three
        // visible swings at any frame rate), the bob slower.
        float knock = Mathf.Exp(-t / .12f) * .09f;
        float rattle = Mathf.Sin(t * 2f * Mathf.PI * 9f) * .06f * e;
        float bob = Mathf.Sin(t * 2f * Mathf.PI * 6f + 1.3f) * .02f * e;
        var world = (away * knock + right * rattle + Vector3.up * bob) * height * strength;
        var local = target.parent ? target.parent.InverseTransformVector(world) : world;
        target.localPosition = basePos + local;
        lastBase = basePos; lastApplied = target.localPosition; written = true;
    }

    void OnDisable()
    {
        RestoreOwnedOffset();
        written = false; started = -100f;
    }
}
