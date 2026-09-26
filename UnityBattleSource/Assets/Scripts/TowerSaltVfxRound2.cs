using UnityEngine;

// D02 sac-attached anticipation and a finite, folded breath. Salt-fang impact
// keeps the existing crystalline radiance; poison never borrows that explosion.
public sealed class TowerSaltVfxRound2 : MonoBehaviour
{
    EnemyHandle actor;
    Transform sacL, sacR, chest;
    TowerSurfaceRound2 tissue, trails;
    public static TowerSaltVfxRound2 Create(EnemyHandle actor, Transform owner)
    {
        var go = new GameObject("D02 folded salt breath round 2"); go.transform.SetParent(owner, false);
        var v = go.AddComponent<TowerSaltVfxRound2>(); v.actor = actor;
        foreach (var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))
        { if (t.name == "Sac.L") v.sacL = t; else if (t.name == "Sac.R") v.sacR = t; else if (t.name == "Chest") v.chest = t; }
        v.tissue = new TowerSurfaceRound2(go.transform, 14, "ChurchSpellArt/venom", false, .38f);
        v.trails = new TowerSurfaceRound2(go.transform, 12, "Effects/Mistport/Official/Slashing/Line01", true);
        return v;
    }
    static float E(float value) => TowerRigRound2.Ease(value);
    public void Draw(Vector3 mouth, Vector3 tip, Vector3 end, float elapsed, float contact, bool held, bool poison)
    {
        tissue.Hide(); trails.Hide(); if (!actor || !actor.gameObject.activeInHierarchy) return;
        float age = held || poison ? Mathf.Max(0, elapsed) : TowerImpactTiming20260921.Sample(Mathf.Max(0, elapsed), contact, .095f);
        float post = age - contact;
        float load = held ? E(age / .30f) : E(age / .19f) * (1 - E((age - .25f) / .18f));
        var face = TowerSurfaceRound2.Face;
        for (int i = 0; i < 2; i++)
        {
            float side = i == 0 ? -1 : 1;
            var sac = i == 0 ? sacL : sacR;
            Vector3 p = sac ? sac.position : chest ? chest.position + actor.EnemyRoot.right * side * .22f : mouth;
            p += -(face * Vector3.forward) * .18f + Vector3.up * .08f;
            float pulse = .86f + .10f * Mathf.Sin(age * 6.1f - i * 1.1f);
            tissue.Leaf(i, p, face * Quaternion.Euler(0, side * 22, side * 21), new Vector2(.48f, .90f) * pulse,
                i == 0 ? new Color(.72f, 1, .64f) : new Color(.78f, .93f, .51f), load * .9f, age, .38f);
            int sacIndex = i;
            trails.Stroke(i, q => Vector3.Lerp(p, mouth, q) + face * new Vector3(side * Mathf.Sin(q * Mathf.PI) * .12f,
                Mathf.Sin(q * 5.4f + sacIndex) * .035f, -.02f), .034f,
                new Color(.73f, 1, .44f), load * (.65f + .3f * Mathf.Sin(age * 7 - i)), age);
        }
        if (held) return;
        Vector3 axis = (end - mouth).sqrMagnitude > .001f ? (end - mouth).normalized : actor.EnemyRoot.forward;
        var flight = Quaternion.FromToRotation(Vector3.up, axis);
        if (!poison)
        {
            // A short curling side-lit wake reveals the physical fang's depth;
            // the nine broad fractured light tongues still own the contact beat.
            if (age < .24f || post >= 0) return;
            for (int i = 0; i < 2; i++)
                tissue.Leaf(2 + i, tip - axis * (.30f + i * .16f), flight * Quaternion.Euler(0, 47 + age * 91 + i * 131, i == 0 ? 13 : -18),
                    new Vector2(.30f, 1.12f), i == 0 ? new Color(.38f, .85f, 1) : new Color(1, .83f, .43f), .60f, age, .32f);
            return;
        }
        float fade = post < 0 ? E((age - .18f) / .12f) : 1 - E((post - .03f) / .47f);
        if (post < 0)
        {
            Vector3 across = Vector3.ProjectOnPlane(actor.EnemyRoot.right, axis);
            if (across.sqrMagnitude < .001f) across = Vector3.ProjectOnPlane(Vector3.right, axis);
            if (across.sqrMagnitude < .001f) across = Vector3.ProjectOnPlane(Vector3.forward, axis);
            across.Normalize();
            Vector3 lift = Vector3.Cross(axis, across).normalized;
            if (Vector3.Dot(lift, Vector3.up) < 0) lift = -lift;
            // Keep the same moving front and finite breath envelope, but give
            // each membrane its own bent spine and two unequal torn lobes.
            // Stroke tapers both ends and rolls the painted venom across depth.
            for (int i = 0; i < 3; i++)
            {
                int tongue = i;
                float q = Mathf.Clamp01((age - .24f) / Mathf.Max(.01f, contact - .24f) - i * .11f);
                Vector3 p = Vector3.Lerp(mouth, tip, 1 - i * .16f) + actor.EnemyRoot.right * Mathf.Sin(age * 5.2f + i) * q * .10f;
                float length = (1.65f + q * .85f) * (i == 0 ? 1 : i == 1 ? .86f : .70f);
                float split = i == 0 ? .39f : i == 1 ? .61f : .47f;
                float gap = i == 0 ? .09f : i == 1 ? .07f : .13f;
                for (int part = 0; part < 2; part++)
                {
                    float from = part == 0 ? 0 : split + gap, to = part == 0 ? split : 1;
                    tissue.Stroke(2 + i * 2 + part, u =>
                    {
                        float v = Mathf.Lerp(from, to, u), bow = Mathf.Sin(v * Mathf.PI);
                        float bend = Mathf.Sin(v * (4.1f + tongue * .8f) - age * 3.7f + tongue * 1.9f);
                        float curl = Mathf.Sin(v * (5.2f - tongue * .6f) - age * 4.3f + tongue * .8f);
                        return p + axis * ((v - .5f) * length)
                            + across * (bend * bow * (.22f + tongue * .025f))
                            + lift * (curl * bow * (.16f + tongue * .018f));
                    }, .42f + q * .18f, new Color(.66f, .94f, .29f),
                        fade * (.92f - i * .13f), age, .16f + i * .025f);
                }
            }
            // A pale living vein is a narrower painted *surface* inside each
            // wet fold. It follows a different sag and has no straight rail.
            for (int i = 0; i < 3; i++)
            {
                int tongue = i; float q = Mathf.Clamp01((age - .24f) / Mathf.Max(.01f, contact - .24f) - i * .11f);
                Vector3 p = Vector3.Lerp(mouth, tip, 1 - i * .16f);
                tissue.Stroke(8 + i, u => p + axis * ((u - .5f) * (1.46f + q * .65f) * (1 - i * .13f))
                    + across * Mathf.Sin(u * (4.2f + i * .7f) - age * 4.1f + i * 1.9f) * Mathf.Sin(u * Mathf.PI) * (.16f + i * .035f)
                    + lift * Mathf.Sin(u * (5.4f - i * .5f) - age * 4.3f + i * .8f) * Mathf.Sin(u * Mathf.PI) * .15f,
                    .19f - i * .035f, tongue == 0 ? new Color(.90f, 1, .69f) : new Color(.72f, 1, .48f),
                    fade * (.82f - i * .15f), age, .16f);
            }
        }
        else
        {
            // Contact spreads down uneven folds on the player, with open gaps.
            // No radial blast, hard polygon perimeter or arena-sized poison floor.
            for (int i = 0; i < 4; i++)
            {
                float sign = i % 2 == 0 ? -1 : 1;
                float wrap = E(post / .15f);
                Vector3 p = end + face * new Vector3(sign * (.12f + wrap * (.18f + i * .06f)), -.15f - post * (.45f + i * .10f), -.13f + i * .04f);
                tissue.Leaf(2 + i, p, face * Quaternion.Euler(0, sign * (25 + wrap * 25), sign * (19 + i * 12 - post * 17)),
                    new Vector2(.65f + wrap * .48f, 1.40f + wrap * .40f), new Color(.62f, .83f, .22f), fade * .76f, age, .42f, null, post * 1.2f);
                if (i < 3) tissue.Leaf(8 + i, p + face * new Vector3(sign * .08f, .07f, -.025f),
                    face * Quaternion.Euler(0, sign * (30 + wrap * 18), sign * (26 + i * 11 - post * 20)),
                    new Vector2(.32f + wrap * .21f, 1.10f + wrap * .25f), new Color(.86f, 1, .61f),
                    fade * .50f, age, .32f, null, post * 1.5f);
            }
        }
    }
    public void Hide() { tissue?.Hide(); trails?.Hide(); }
    void OnDisable() { Hide(); }
    void OnDestroy() { tissue?.Dispose(); trails?.Dispose(); }
}
