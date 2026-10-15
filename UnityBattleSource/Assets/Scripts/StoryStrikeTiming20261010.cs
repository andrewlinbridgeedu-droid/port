using UnityEngine;

/// Charge and strike timing for the authored story enemies (scribe, executor, rescue bearer,
/// chronarch, adjudicator / convoy, stonehide). Their rigs carry a 1.4 s Charge and a 1.0 s
/// Cast, but the rules land the blow one second after the attack starts, so the whole charge
/// used to be played at 3.5x inside the first 0.4 s - a twitch, not a wind-up (2026-10-10).
/// Now the charge gets 0.55 s and plays only its last 0.88 s at 1.6x, so it eases out of the
/// idle into the full charged pose; the cast then runs at 1.33x so that at the contact it is
/// on the same frame as before (0.6 s into the clip, the authored hit), and it finishes its
/// follow-through at normal speed. The contact time itself does not change.
public static class StoryStrikeTiming20261010
{
    /// Seconds from the attack start to the release (charge -> cast).
    public const float Release = .55f;
    /// Seconds from the attack start to the contact (set by the rules, unchanged).
    public const float Contact = 1f;
    const float ChargeLength = 1.4f, ChargeSpeed = 1.6f, CastAtContact = .6f;

    public static void BeginCharge(Animator animator, string state)
    {
        if (!animator) return;
        animator.speed = ChargeSpeed;
        animator.CrossFadeInFixedTime(state, .12f, 0, Mathf.Max(0f, ChargeLength - Release * ChargeSpeed));
    }

    /// Call every frame with the time since the attack started; phase starts at 0.
    /// Returns true on the frame the cast begins.
    public static bool Tick(Animator animator, float t, string castState, ref int phase)
    {
        if (phase == 0 && t >= Release)
        {
            phase = 1;
            if (animator)
            {
                animator.speed = CastAtContact / (Contact - Release);
                animator.CrossFadeInFixedTime(castState, .06f, 0, 0f);
            }
            return true;
        }
        if (phase == 1 && t >= Contact)
        {
            phase = 2;
            if (animator) animator.speed = 1f;
        }
        return false;
    }
}
