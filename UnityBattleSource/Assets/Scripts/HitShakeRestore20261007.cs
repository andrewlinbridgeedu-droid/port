using System;
using UnityEngine;

/// Early phase of HitShake20261007 (same pattern as PlayerImpactRestore20260925):
/// DefaultExecutionOrder governs both Update and LateUpdate, so one component cannot be
/// first in Update and last in LateUpdate. This one runs before every other writer
/// (BountyPoseRestoreRound2 at 1200, Animator root motion, idle presences) and removes the
/// shake's own offset, so they all see the clean base position for this frame; the shake's
/// LateUpdate (32000) then stacks its offset on their final result.
[DisallowMultipleComponent, DefaultExecutionOrder(-20000)]
public sealed class HitShakeRestore20261007 : MonoBehaviour
{
    [NonSerialized] public HitShake20261007 shake;
    void Update() { if (shake) shake.RestoreOwnedOffset(); }
    void OnDisable() { if (shake) shake.RestoreOwnedOffset(); }
}
