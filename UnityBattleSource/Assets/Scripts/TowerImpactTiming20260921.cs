using UnityEngine;
// Local VFX time only. Native damage, contact deadlines and animator clocks never pause.
public static class TowerImpactTiming20260921
{
    public static float Sample(float age, float contact, float hold)
    {
        float post = age - contact;
        if (post < 0) return age;
        // Show a compact contact core throughout the held beat, then release
        // fast enough that the original finite action lifetime still clears.
        if (post < hold) return contact + post * .10f;
        return contact + hold * .10f + (post - hold) * 1.65f;
    }
}
