using UnityEngine;

/// Presentation-only contact accent. The caller's real clock still owns damage,
/// cancellation and duration. Only visual geometry briefly holds and catches up.
public static class HeroVisualBeat
{
    public static float Sample(float time, float contact, float hold = .10f)
    {
        if (time <= contact) return time;
        float age = time - contact;
        if (age < hold) return contact + age * .06f;
        float released = age - hold;
        float recovered = Mathf.SmoothStep(0, 1, Mathf.Clamp01(released / .28f));
        return contact + hold * .06f + released + hold * .94f * recovered;
    }
    public static float Burst(float time, float contact, float amplitude)
    {
        float age = time - contact;
        if (age <= 0) return 1;
        float open = Mathf.SmoothStep(0, 1, Mathf.Clamp01(age / .045f));
        return 1 + amplitude * open * Mathf.Exp(-Mathf.Max(0, age - .045f) * 11f);
    }
}
