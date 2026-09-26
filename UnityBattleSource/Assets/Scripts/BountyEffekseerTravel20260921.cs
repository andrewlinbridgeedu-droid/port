using UnityEngine;
using Effekseer;

// Existing Effekseer highlights follow folded spell matter. No forged blocks/plates.
public sealed class BountyEffekseerTravel20260921 : MonoBehaviour
{
    EffekseerHandle main, core;
    bool playing, mainPlaying, corePlaying;
    string kind;
    bool guard, charge;
    float nextRenew;
    BountySurfaceRound2 volume;

    public void Configure(string species, bool held, bool charging = false)
    {
        kind = species; guard = held; charge = charging;
        var g = new GameObject("Bounty rolled volume " + species); g.transform.SetParent(transform, false);
        volume = g.AddComponent<BountySurfaceRound2>(); volume.Configure(species);
    }

    public void Draw(Vector3 from, Vector3 to, float age, float contact)
    {
        if (age < 0 || (!guard && !charge && age >= contact)) { Stop(); volume.Clear(); return; }
        bool held = guard || charge;
        float progress = Mathf.Clamp01(age / Mathf.Max(.01f, contact));
        float flight = Mathf.SmoothStep(0, 1, (progress - .24f) / .76f);
        Vector3 p = held ? from : Vector3.Lerp(from, to, flight);
        if (held && playing && Time.time >= nextRenew) Stop();
        if (!playing)
        {
            playing = true; nextRenew = Time.time + .8f;
            // B04's old accent exposes straight fan-ribs in the recorded charge.
            // Its replacement glints follow the brush curves below, not a radial emitter.
            var asset = kind == "b04" ? null : Resources.Load<EffekseerEffectAsset>(
                "Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostVortexTravel");
            if (asset)
            {
                var param = EffekseerPlayEffectParameters.Create(p);
                param.SetScale(Vector3.one * (guard ? .48f : .46f));
                main = EffekseerSystem.PlayEffect(asset, param); mainPlaying = true;
                main.SetAllColor(new Color(.56f, .8f, 1, .72f));
            }
            var glow = kind == "b04" ? null : Resources.Load<EffekseerEffectAsset>("ChurchSpellArt/SaltmawEffekseer/Gather");
            if (glow)
            {
                var param = EffekseerPlayEffectParameters.Create(p);
                param.SetScale(Vector3.one * (guard ? .19f : .115f));
                core = EffekseerSystem.PlayEffect(glow, param); corePlaying = true;
                core.SetAllColor(new Color(.48f, .78f, 1, .24f));
            }
        }
        if (mainPlaying)
        {
            main.SetLocation(p);
            Vector3 axis = to - from;
            if (guard) main.SetRotation(Quaternion.Euler(35, 15, age * 17));
            else if (axis.sqrMagnitude > .001f) main.SetRotation(Quaternion.FromToRotation(Vector3.up, axis.normalized));
        }
        if (corePlaying) core.SetLocation(p);
        Vector3 right = Camera.main ? Camera.main.transform.right : Vector3.right;
        Vector3 up = Camera.main ? Camera.main.transform.up : Vector3.up;
        Vector3 depth = Camera.main ? Camera.main.transform.forward : Vector3.forward;
        volume.Begin(age);
        if (guard) DrawGuard(p, right, up, depth, age);
        else if (kind == "b04") DrawInk(p, right, up, depth, age,
            charge ? .73f : 1.03f + flight * .46f);
        else DrawAnchor(p, from, to, right, up, depth, age,
            charge ? .64f : 1.05f + flight * .38f);
        volume.End(1, kind == "b04" ? 1.72f : 1.65f);
    }

    void DrawInk(Vector3 p, Vector3 right, Vector3 up, Vector3 depth, float t, float size)
    {
        // Different open brush paths, not phase-shifted copies which close into an
        // oval in projection. Their tips end at different heights and depths.
        for (int k = 0; k < 4; k++)
        {
            int lane = k;
            Color jade = k == 2 ? new Color(.82f, .61f, .22f, .92f) : new Color(.15f + k * .08f, .94f, .55f + k * .1f, .95f);
            volume.Ribbon(q => BrushPoint(p, right, up, depth, InkStroke(lane, q, t), size),
                up, (.49f - k * .080f) * size, 1.18f, jade,
                1.2f + k * 2.73f + t * .15f, 1.05f,
                silhouette: BountySurfaceRound2.Silhouette.Veil);
        }
        // Short frayed bristles peel away from the painted strokes; none is a bar
        // or a full perimeter, and their tips never meet the opposing stroke.
        for (int k = 0; k < 3; k++)
        {
            int lane = k;
            volume.Ribbon(q => BrushPoint(p, right, up, depth,
                    InkStroke(lane, .16f + q * (.55f - lane * .09f), t)
                    + new Vector3(-q * q * .32f, Mathf.Sin(q * 3.1f + t * 1.7f + lane) * q * .14f, q * .23f), size),
                up, (.085f - k * .012f) * size, .8f,
                new Color(.87f, 1, .76f, .91f), 8 + lane * 2.7f, 1.3f,
                silhouette: BountySurfaceRound2.Silhouette.Thread);
        }
    }

    public static Vector3 BrushPoint(Vector3 p, Vector3 right, Vector3 up, Vector3 depth, Vector3 point, float size)
        => p + (right * point.x + up * point.y + depth * point.z) * size;

    static Vector3 Bezier(Vector3 a, Vector3 b, Vector3 c, Vector3 d, float q)
    {
        float r = 1 - q;
        return a * (r * r * r) + b * (3 * r * r * q) + c * (3 * r * q * q) + d * (q * q * q);
    }

    public static Vector3 InkStroke(int lane, float q, float t)
    {
        Vector3 p;
        if (lane == 0) p = Bezier(new Vector3(-1.03f, -.49f, -.12f), new Vector3(-.52f, -.04f, .64f), new Vector3(.18f, .57f, -.51f), new Vector3(1.39f, .32f, .09f), q);
        else if (lane == 1) p = Bezier(new Vector3(-.17f, -.26f, -.42f), new Vector3(.08f, -.55f, .12f), new Vector3(.42f, -.17f, .55f), new Vector3(.77f, -.75f, .27f), q);
        else if (lane == 2) p = Bezier(new Vector3(-.67f, .06f, .23f), new Vector3(-.15f, .29f, -.36f), new Vector3(.42f, .11f, .25f), new Vector3(1.15f, .79f, -.15f), q);
        else p = Bezier(new Vector3(-.92f, -.20f, .34f), new Vector3(-.73f, .52f, .57f), new Vector3(-.29f, .47f, -.22f), new Vector3(-.16f, 1.02f, -.39f), q);
        float bend = q * (1 - q);
        p.y += Mathf.Sin(q * 4.1f + t * 2.3f + lane) * .14f * bend;
        p.z += Mathf.Sin(q * 3.3f - t * 1.8f + lane * 2.1f) * .42f * bend;
        return p;
    }

    void DrawGuard(Vector3 p, Vector3 right, Vector3 up, Vector3 depth, float t)
    {
        // Open storm-armor folds: shoulder, chest, forearm; separate depth/uneven rims.
        for (int k = 0; k < 3; k++)
        {
            int lane = k; float sign = k == 0 ? -1 : 1;
            float lockIn = Mathf.SmoothStep(0, 1, t / .22f);
            float breathing = 1 + Mathf.Sin(t * 2.4f + k * 2.1f) * .055f;
            volume.Ribbon(q => BrushPoint(p, right, up, depth,
                    GuardFold(lane, q) * breathing + new Vector3(sign * (1 - lockIn) * .20f, 0, 0), 1.16f),
                lane == 1 ? up : right, .47f - k * .047f, 1.42f,
                new Color(.31f + k * .08f, .60f + k * .10f, .87f + k * .05f, .95f),
                1 + k * 3.1f, 1.0f);
        }
    }

    static Vector3 GuardFold(int lane, float q)
    {
        // Shoulder hood, folded forearm cover, and a shorter oblique chest fold.
        // No two paths have the same vertical extent or describe upright side plates.
        if (lane == 0) return Bezier(new Vector3(-.73f, -.22f, .12f), new Vector3(-.81f, .52f, -.04f), new Vector3(-.48f, .69f, -.48f), new Vector3(-.03f, .44f, -.43f), q);
        if (lane == 1) return Bezier(new Vector3(.78f, -.44f, .18f), new Vector3(.25f, -.50f, -.42f), new Vector3(.07f, .17f, -.53f), new Vector3(.53f, .13f, .16f), q);
        return Bezier(new Vector3(-.51f, -.65f, .16f), new Vector3(-.22f, -.56f, -.47f), new Vector3(.08f, -.04f, -.64f), new Vector3(.38f, -.13f, -.31f), q);
    }

    void DrawAnchor(Vector3 p, Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float t, float size)
    {
        Vector3 forward = (to - from).normalized;
        if (forward.sqrMagnitude < .001f) forward = -depth;
        Vector3 side = Vector3.ProjectOnPlane(right, forward).normalized;
        if (side.sqrMagnitude < .001f) side = right;
        Vector3 rise = Vector3.Cross(forward, side).normalized;
        // Dense curved keel plus two unequal fluid flukes, no cubes or chain rings.
        volume.Ribbon(q => p - forward * ((1 - q) * 2.15f * size)
            + rise * (Mathf.Sin(q * 4.8f + t * 2) * .14f * size),
            side, .32f * size, 1.05f, new Color(.24f, .62f, 1, 1), 2.4f, .7f,
            silhouette: BountySurfaceRound2.Silhouette.Blade);
        for (int k = 0; k < 2; k++)
        {
            float sign = k == 0 ? -1 : 1, lane = k;
            volume.Ribbon(q => p - forward * ((.1f + q * .82f) * size)
                + side * (sign * Mathf.Sin(q * 2.7f) * (.72f - lane * .14f) * size)
                + rise * (Mathf.Sin(q * 3.5f + lane) * .3f * size),
                rise, .39f * size, 1.1f, new Color(.48f, .8f, 1, .97f), 5.1f + lane * 3.2f, .85f,
                silhouette: BountySurfaceRound2.Silhouette.Water);
        }
        volume.Ribbon(q => p - forward * ((.12f + q * 2.85f) * size)
            + side * (Mathf.Sin(q * 5.6f - t * 4) * .36f * size)
            + rise * (Mathf.Cos(q * 5.6f - t * 4) * .28f * size),
            rise, .17f * size, .8f, new Color(.77f, .96f, 1, .96f), 9.3f, 1.2f,
            silhouette: BountySurfaceRound2.Silhouette.Blade);
    }

    void Stop()
    {
        if (mainPlaying) main.Stop(); if (corePlaying) core.Stop();
        playing = mainPlaying = corePlaying = false;
    }
    void OnDisable() { Stop(); if (volume) volume.Clear(); }
    void OnDestroy() { Stop(); }
}
