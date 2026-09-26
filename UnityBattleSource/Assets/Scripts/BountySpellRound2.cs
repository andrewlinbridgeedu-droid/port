using System;
using UnityEngine;
using Effekseer;

// A presentation owner only. No target discovery, retargeting, damage or combat clock.
// ChurchSpellVisual's bounty adapter also uses this for formally supplied states.
[DefaultExecutionOrder(1080)]
public sealed class BountySpellRound2 : MonoBehaviour
{
    string species, intent;
    Vector3 source, frozenSource;
    Func<Vector3> target, sourceProvider;
    float contact, born;
    bool sourceReleased, state, charge;
    BountySurfaceRound2 matter;
    BountyEffekseerTravel20260921 travel;
    BountyContactBurst20260919 impact;
    BindingRibbon20260921 binding;
    EffekseerHandle silk;
    bool silkPlaying, silkFinished;
    float sampledAge = -1;
    public bool ambient;
    public void Sample(float age) { sampledAge = age; }
    void LateUpdate() { if (ambient) Draw(Time.time - born, true); else if (sampledAge >= 0) Draw(sampledAge, false); }

    public void Configure(string kind, string action, Vector3 from, Func<Vector3> victim, float contactTime)
    {
        species = kind; intent = action.StartsWith("bounty_") ? action.Substring(7) : action;
        source = frozenSource = from; target = victim;
        contact = Mathf.Max(.01f, contactTime); born = Time.time;
        charge = intent.Contains("charge");
        state = intent == "guard" || intent == "escorted" || intent == "binding" || intent == "mirror" || intent == "armor";
        if (species == "b02" && (intent == "bind" || intent == "binding"))
        {
            var g = new GameObject("Preserved authored gold binding"); g.transform.SetParent(transform, false);
            binding = g.AddComponent<BindingRibbon20260921>();
            var layer = new GameObject("Gold binding curved body");
            layer.transform.SetParent(transform, false);
            matter = layer.AddComponent<BountySurfaceRound2>(); matter.Configure(species);
            return;
        }
        if (species == "b04" || species == "b06")
        {
            travel = gameObject.AddComponent<BountyEffekseerTravel20260921>();
            travel.Configure(species, state, charge);
            if (!state && !charge) { impact = gameObject.AddComponent<BountyContactBurst20260919>(); impact.Configure(species); }
            return;
        }
        var body = new GameObject("Bounty distinct matter " + species + " " + intent);
        body.transform.SetParent(transform, false); matter = body.AddComponent<BountySurfaceRound2>(); matter.Configure(species);
        if (species == "b05" && !charge && !state && intent != "strike")
        {
            var g = new GameObject("Silk contact rupture");
            g.transform.SetParent(transform, false);
            impact = g.AddComponent<BountyContactBurst20260919>(); impact.Configure("b05");
        }
    }

    public void AttachSource(Func<Vector3> provider) { sourceProvider = provider; }

    public void Draw(float age, bool held, float intensity = 1)
    {
        if (target == null) return;
        if (age < 0) { if (matter) matter.Clear(); if (binding) binding.Draw(source, target(), age, contact, held); if (travel) travel.Draw(source, target(), age, contact); if (impact) impact.Draw(-1, target()); StopSilk(); return; }
        Vector3 victim = target();
        // Follow the wrist while it loads. Once released the starting point is fixed,
        // so the projectile cannot be dragged backwards by the actor's recovery.
        bool anchored = held || state || charge;
        if (!sourceReleased && sourceProvider != null) frozenSource = sourceProvider();
        if (!anchored && age >= contact * .32f) sourceReleased = true;
        Vector3 from = sourceProvider != null ? frozenSource : source;
        float elapsed = Mathf.Max(0, Time.time - born), clock = anchored ? elapsed : age;
        if (binding) {
            binding.Draw(from, victim, age, contact, held || intent == "binding");
            matter.Begin(clock);
            float expansion = ContactExpansion(age, held);
            matter.SetContactExpansion(victim, expansion);
            Vector3 forward = victim - from; forward.y = 0;
            if (forward.sqrMagnitude < .0001f) forward = Vector3.forward;
            forward.Normalize();
            Vector3 upAxis = Vector3.up;
            Vector3 lateral = Vector3.Cross(upAxis, forward).normalized;
            BountySpellSignature20260923.Draw(matter, species, intent, from, victim,
                age, clock, contact, false, held || intent == "binding", lateral, upAxis, forward);
            matter.End(Mathf.Clamp01(intensity), 1.68f + (expansion - 1f) * .42f);
            return;
        }
        if (travel) { travel.Draw(from, victim, anchored ? clock : age, contact); if (impact && !anchored) impact.Draw(age - contact, victim); return; }

        // Build in the encounter's world frame. Camera-aligned ribbons became
        // flat cutouts in the battle view and moved with a review camera.
        Vector3 depth = victim - from; depth.y = 0;
        if (depth.sqrMagnitude < .0001f) depth = Camera.main ? Camera.main.transform.forward : Vector3.forward;
        depth.y = 0; depth.Normalize();
        Vector3 up = Vector3.up;
        Vector3 right = Vector3.Cross(up, depth).normalized;
        matter.Begin(clock);
        float contactExpansion = ContactExpansion(age, anchored);
        matter.SetContactExpansion(victim, contactExpansion);
        BountySpellSignature20260923.Draw(matter, species, intent, from, victim,
            age, clock, contact, charge, state || held, right, up, depth);
        matter.End(Mathf.Clamp01(intensity), 1.68f + (contactExpansion - 1f) * .42f);
        if (impact && !anchored) impact.Draw(age - contact, victim);
    }

    float ContactExpansion(float age, bool anchored)
    {
        float post = age - contact;
        if (anchored || post < 0 || post > .43f) return 1f;
        // The full visual body opens only at actual contact, then contracts.
        // Individual identities retain their own authored contour and colour.
        float peak = species == "b03" ? 2.05f
            : species == "b10" ? 1.86f
            : species == "b05" ? (intent == "strike" ? 1.62f : 1.91f)
            : species == "b07" ? (intent == "spittle" ? 1.65f : 1.78f)
            : species == "b08-echo" ? 1.58f
            : species == "b10-vessel" ? 1.08f
            : species == "b02" ? 1.45f
            : species == "b09" ? 1.82f : 1.85f;
        float rise = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(post / .052f));
        float retreat = Mathf.Exp(-Mathf.Max(0f, post - .052f) * 5.4f);
        return 1f + peak * rise * retreat;
    }

    void DrawGather(Vector3 p, Vector3 right, Vector3 up, Vector3 depth, float t)
    {
        if (species == "b01")
        {
            // Keep the cue at the hilt. Broad cyan folds beside the sword read
            // as a second, torn blade once the actor enters its charge pose.
            for (int k = 0; k < 3; k++)
            {
                float lane = k;
                matter.Ribbon(q => p + right * ((lane - 1) * .045f + Mathf.Sin(q * 6.1f + t * 2.7f + lane) * .022f)
                    + up * (-q * (.14f + lane * .025f))
                    + depth * (Mathf.Sin(q * 4.2f + lane * 1.9f) * .032f),
                    right, .024f - lane * .003f, .48f,
                    new Color(.56f, .83f, 1f, .66f), lane * 2.8f + t * .4f, .52f);
            }
            return;
        }
        if (species == "b03")
        {
            // Two unequal open folds draw into the real hands' midpoint. This
            // is a compact gathering gesture, not an early replay of the wave.
            for (int k = 0; k < 2; k++)
            {
                float sign = k == 0 ? -1 : 1, lane = k;
                matter.Ribbon(q => p + right * (sign * (1 - q) * (.53f - lane * .12f))
                    + up * ((q - 1) * (.24f + lane * .15f) + Mathf.Sin(q * 3.1f + lane * .4f) * .07f)
                    + depth * (Mathf.Sin(q * 3.7f + t * 1.1f + lane * 1.8f) * .12f * (1 - q)),
                    up, .12f - k * .025f, .85f, new Color(.22f + k * .15f, .76f, 1, .86f),
                    2.7f + k * 3.1f + t * .15f, .72f);
            }
            return;
        }
        Color c = species == "b02" || species == "b09" ? new Color(1, .72f, .21f, .95f)
            : species == "b05" || species == "b10" ? new Color(1, .09f, .24f, .9f)
            : species == "b07" ? new Color(.66f, .96f, .77f, .9f)
            : new Color(.38f, .81f, 1, .9f);
        // Three non-orbiting rolls ending at the casting hand, asymmetrical and short.
        for (int k = 0; k < 3; k++)
        {
            int lane = k; float sign = k == 1 ? -1 : 1;
            matter.Ribbon(q => p + right * (sign * (1 - q) * (.32f + lane * .14f))
                + up * ((q - 1) * (.52f + lane * .12f) + Mathf.Sin(q * 4.5f + lane) * .1f)
                + depth * (Mathf.Sin(q * 3.7f + t * 1.8f + lane) * .15f),
                right, .095f + k * .022f, .55f, c, 1.3f + k * 2.2f + t * .12f, .65f);
        }
    }

    void DrawState(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float t)
    {
        if (intent == "escorted") from = to;
        if (species == "b09")
        {
            // Three offset copper-paper folds stay attached to the actual shell.
            // Open edges and unequal heights convey ordinary breakable armour.
            for (int k = 0; k < 3; k++)
            {
                float lane = k;
                matter.Ribbon(q => from + right * ((q - .5f) * (1.2f - lane * .18f))
                    + up * (.16f + lane * .13f + Mathf.Sin(q * (3.8f + lane * .5f)) * .22f)
                    + depth * (.09f * lane + Mathf.Sin(q * 5.1f + t * .6f + lane) * .18f),
                    up, .21f - lane * .03f, .92f, new Color(.98f, .61f + lane * .08f, .25f, .86f),
                    lane * 3.11f + t * .22f, .84f);
            }
            return;
        }
        if (species == "b08")
        {
            // Incomplete wax-face afterimages gather beside the caster. They
            // are visual witnesses; only the real actor's contact deals damage.
            for (int k = 0; k < 2; k++)
            {
                float sign = k == 0 ? -1 : 1, lane = k;
                matter.Ribbon(q => from + right * (sign * (.38f + q * .38f))
                    + up * ((q - .42f) * (1.32f - lane * .17f))
                    + depth * (.22f * lane + Mathf.Sin(q * 4.9f + t * 1.4f + lane) * .17f),
                    right, .14f, .82f, new Color(.34f, .49f, .95f, .75f), 2.1f + lane * 4.3f, .7f);
            }
            return;
        }
        if (species == "b05")
        {
            // Actual binding state only: open textile ends curl inward, no replayed rupture.
            for (int k = 0; k < 3; k++)
            {
                float lane = k, sign = k == 1 ? -1 : 1;
                matter.Ribbon(q => to + right * (Mathf.Sin(q * 4.1f + lane * 2.1f + t * .21f) * .63f)
                    + up * ((q - .5f) * (1.8f - lane * .12f))
                    + depth * (Mathf.Cos(q * 4.1f + lane * 2.1f + t * .21f) * .48f + sign * .09f),
                    up, .17f, .5f, new Color(1, .08f, .25f, .8f), lane * 2.4f + 1, .85f);
            }
            return;
        }
        // The formal escort owner supplied 'from' at the protected actor. Each fold
        // covers only part of its body; none describes a closed shield perimeter.
        for (int k = 0; k < 3; k++)
        {
            float lane = k, sign = k == 1 ? -1 : 1;
            float breathe = .94f + .06f * Mathf.Sin(t * 2.1f + k * 1.7f);
            matter.Ribbon(q => from + right * (sign * (.28f + Mathf.Sin(q * 2.6f + .2f) * .38f) * breathe)
                + up * ((q - .5f) * (1.95f - lane * .18f) + .12f * lane)
                + depth * (-.30f + lane * .21f + Mathf.Cos(q * 3.8f + lane) * .3f),
                right, .31f - k * .035f, .95f, new Color(.19f + k * .09f, .63f + k * .08f, 1, .88f), k * 3.1f + .7f, .9f);
        }
    }

    void DrawSword(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float progress = Mathf.Clamp01(age / contact), post = age - contact;
        float flight = Mathf.SmoothStep(0, 1, (progress - .22f) / .78f);
        Vector3 head = Vector3.Lerp(from, to, flight);
        if (post < 0)
        {
            Vector3 slash = (right * .77f - up * .64f).normalized;
            // Offset notches in the edge rather than a clean crescent/circle.
            matter.Ribbon(q => head + slash * ((q - .53f) * 1.9f)
                + right * (Mathf.Sin(q * 3.3f) * .28f) + depth * (Mathf.Sin(q * 4.9f) * .2f),
                up, .18f + flight * .12f, .52f, new Color(.71f, .91f, 1, .95f), 2.4f, .42f);
            matter.Ribbon(q => head + slash * ((q - .53f) * 1.53f) + right * .09f + depth * .12f,
                up, .055f, .35f, new Color(1, .75f, .24f, .9f), 7.1f, .18f);
            return;
        }
        float release = Mathf.Max(0, post - .04f);
        float expand = Mathf.SmoothStep(0, 1, release / .045f) * Mathf.Exp(-Mathf.Max(0, release - .045f) * 10);
        float fade = 1 - Mathf.SmoothStep(0, 1, post / .4f);
        for (int k = 0; k < 3; k++)
        {
            float lane = k, sign = k == 1 ? -1 : 1;
            matter.Ribbon(q => to + right * ((q - .5f) * (1.15f + expand * 2.8f) + sign * release * .5f)
                + up * ((.5f - q) * (1 + expand) + Mathf.Sin(q * 5.2f + lane) * .22f)
                + depth * ((lane - 1) * .19f + Mathf.Sin(q * 3.3f) * .32f),
                up, (.12f + expand * .15f) * fade, .62f,
                k == 1 ? new Color(1, .72f, .22f, fade) : new Color(.64f, .9f, 1, fade), 2 + lane * 2.3f, .45f);
        }
        matter.Spray(to, right, up, depth, release, 4.8f, 12, new Color(1, .8f, .35f, .95f), .7f);
    }

    void DrawWater(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        bool heavy = intent == "heavy_strike", escort = species == "b03-escort";
        if (!heavy && !escort)
        {
            DrawWaterEdge(from, to, right, up, depth, age);
            return;
        }
        float size = heavy ? 1.25f : escort ? .53f : .68f;
        float post = age - contact, progress = Mathf.Clamp01(age / contact);
        float flight = Mathf.SmoothStep(0, 1, (progress - .20f) / .80f);
        Vector3 head = Vector3.Lerp(from, to, flight);
        float release = Mathf.Max(0, post - (heavy ? .066f : .025f));
        float expand = post < 0 ? 0 : Mathf.SmoothStep(0, 1, release / .05f) * Mathf.Exp(-Mathf.Max(0, release - .05f) * 8);
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / (heavy ? .56f : .34f));
        int lobes = heavy ? 3 : 2;
        for (int k = 0; k < lobes; k++)
        {
            float lane = k, scale = size * (1 + expand * 1.5f);
            // Crest rolls across depth and collapses downwards. Unequal heights and
            // transverse camber replace both the old moon and its two flat water walls.
            matter.Ribbon(q => head + right * ((q - .47f) * scale * (2.1f - lane * .23f))
                + up * ((Mathf.Sin(q * 3.7f + .35f + lane * .3f) * .56f - .25f + lane * .11f) * scale - release * .8f)
                + depth * ((Mathf.Sin(q * 4.4f + lane * .7f) * .54f + lane * .22f) * scale),
                up, (.3f - k * .055f) * scale, 1.1f,
                new Color(.13f + k * .13f, .65f + k * .09f, 1, fade * .95f), 1.1f + k * 2.63f + age * .2f, .85f);
        }
        if (post >= 0) matter.Spray(to, right, up, depth, release, size * 5, heavy ? 16 : 6,
            new Color(.65f, .93f, 1, .9f), escort ? 4.2f : 1.6f);
    }

    void DrawWaterEdge(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float post = age - contact, progress = Mathf.Clamp01(age / contact);
        float flight = Mathf.SmoothStep(0, 1, (progress - .20f) / .80f);
        Vector3 head = Vector3.Lerp(from, to, flight);
        // Keep the ordinary attack's existing flight/contact/tail waveform.
        float release = Mathf.Max(0, post - .025f);
        float expand = post < 0 ? 0 : Mathf.SmoothStep(0, 1, release / .05f) * Mathf.Exp(-Mathf.Max(0, release - .05f) * 8);
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / .34f);
        float reach = 1.15f + expand * .38f;
        Func<float, Vector3> edge = q =>
        {
            float a = 1 - q;
            // A short one-sided forearm fin, with a rolled thick heel and torn
            // pointed tip. Neither its profile nor motion uses the heavy crest.
            Vector3 p = new Vector3(-.88f, .23f, -.09f) * (a * a * a)
                + new Vector3(-.69f, .14f, .29f) * (3 * a * a * q)
                + new Vector3(-.24f, -.11f, -.18f) * (3 * a * q * q)
                + new Vector3(.12f, -.19f, .06f) * (q * q * q);
            return head + right * (p.x * reach) + up * (p.y * reach - release * .8f)
                + depth * (p.z * (1 + expand * .45f));
        };
        matter.Ribbon(edge, up, .27f + expand * .11f, 1.15f,
            new Color(.16f, .72f, 1, fade * .95f), 1.6f + age * .2f, .92f);
        // A short internal foam lip, not a second silhouette or parallel rib.
        matter.Ribbon(q => edge(.28f + q * .63f) + up * (.055f * Mathf.Sin(q * 3.2f))
                + depth * (.065f + q * .025f),
            up, .035f, .6f, new Color(.63f, .94f, 1, fade * .82f), 5.7f + age * .2f, .47f);
        if (post >= 0) matter.Spray(to, right, up, depth, release, 3.4f, 6,
            new Color(.65f, .93f, 1, .9f), 1.6f);
    }

    void DrawSilk(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        bool basic = intent == "strike";
        float progress = Mathf.Clamp01(age / contact), post = age - contact;
        float flight = Mathf.SmoothStep(0, 1, (progress - .18f) / .82f);
        Vector3 head = Vector3.Lerp(from, to, flight);
        if (!basic && post < 0 && !silkPlaying && !silkFinished)
        {
            var asset = Resources.Load<EffekseerEffectAsset>("ChurchSpellArt/BountyEffekseer/SilkTravel");
            if (asset) { var p = EffekseerPlayEffectParameters.Create(head); p.SetScale(Vector3.one); silk = EffekseerSystem.PlayEffect(asset, p); silkPlaying = true; }
        }
        if (silkPlaying) { silk.SetLocation(head); if (post >= 0) { StopSilk(); silkFinished = true; } }
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / (basic ? .24f : .10f));
        for (int k = 0; k < (basic ? 1 : 3); k++)
        {
            float lane = k;
            float width = basic ? .095f : .19f + k * .025f;
            matter.Ribbon(q => head + right * ((q - .5f) * (basic ? 1.15f : 1.85f)
                    + Mathf.Sin(q * 4.8f + lane * 1.9f + age * 2) * .16f)
                + up * (Mathf.Sin(q * 5.1f + lane * 2.1f) * (basic ? .22f : .37f))
                + depth * (Mathf.Cos(q * 4.3f + lane * 1.9f) * (basic ? .13f : .43f)),
                up, width, .88f, new Color(1, .055f + k * .02f, .19f + k * .09f, fade), 3.2f + lane * 2.3f, 1.05f);
        }
        if (basic && post >= 0) matter.Spray(to, right, up, depth, post, 2.2f, 5, new Color(1, .25f, .44f, .85f), 2.3f);
    }

    void DrawBelltoad(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float post = age - contact, p = Mathf.Clamp01(age / contact);
        bool venom = intent == "spittle";
        Vector3 head = Vector3.Lerp(from, to, Mathf.SmoothStep(0, 1, (p - .23f) / .77f));
        float expand = post < 0 ? 0 : Mathf.SmoothStep(0, 1, post / .048f) * Mathf.Exp(-Mathf.Max(0, post - .048f) * 11);
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / .40f);
        Color edge = venom ? new Color(.31f, .96f, .54f, fade) : new Color(1, .80f, .28f, fade);
        int folds = venom ? 2 : 3;
        for (int k = 0; k < folds; k++)
        {
            float lane = k, sign = k == 1 ? -1 : 1;
            matter.Ribbon(q => head + right * (sign * (q - .42f) * (.65f + expand * 1.9f)
                    + Mathf.Sin(q * 7.2f + lane * 1.8f) * .14f)
                + up * ((venom ? -.48f : .08f) + Mathf.Sin(q * (venom ? 4.9f : 6.2f) + lane) * (.18f + expand * .20f))
                + depth * (lane * .17f + Mathf.Sin(q * 5.4f + lane * 1.7f) * .17f),
                up, (venom ? .16f : .21f) + expand * .13f, .95f, edge,
                lane * 2.33f + age * .22f, .72f);
        }
        if (post >= 0) matter.Spray(to, right, up, depth, post, venom ? 2.6f : 4.2f,
            venom ? 9 : 15, edge, 2.7f);
    }

    void DrawMirren(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float post = age - contact, p = Mathf.Clamp01(age / contact);
        Vector3 head = Vector3.Lerp(from, to, Mathf.SmoothStep(0, 1, (p - .31f) / .69f));
        float bloom = post < 0 ? 0 : Mathf.SmoothStep(0, 1, post / .041f) * Mathf.Exp(-Mathf.Max(0, post - .041f) * 12);
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / .32f);
        // A narrow true blade crosses two shorter wax fragments. The fragments
        // fade early so they cannot pretend to have their own contact events.
        matter.Ribbon(q => head + right * ((q - .54f) * (1.14f + bloom * 1.9f))
            + up * ((q - .42f) * (.48f + bloom * .8f) + Mathf.Sin(q * 4.6f) * .12f)
            + depth * Mathf.Sin(q * 3.1f) * .2f,
            up, .12f + bloom * .12f, .85f, new Color(.82f, .94f, 1, fade), 1.7f, .78f);
        for (int k = 0; k < 2; k++)
        {
            float lane = k, sign = k == 0 ? -1 : 1;
            matter.Ribbon(q => head + right * (sign * .32f + (q - .5f) * .67f)
                + up * (sign * .14f + Mathf.Sin(q * 5.3f + lane) * .10f)
                + depth * (.26f + lane * .18f + Mathf.Sin(q * 4.1f) * .13f),
                up, .065f, .55f, new Color(.32f, .51f, .93f, fade * .53f), 4.2f + lane * 2, .5f);
        }
        if (post >= 0) matter.Spray(to, right, up, depth, post, 2.9f, 8,
            new Color(.72f, .87f, 1, fade), 1.1f);
    }

    void DrawCopperback(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float post = age - contact, p = Mathf.Clamp01(age / contact);
        Vector3 head = Vector3.Lerp(from, to, Mathf.SmoothStep(0, 1, (p - .28f) / .72f));
        float bloom = post < 0 ? 0 : Mathf.SmoothStep(0, 1, post / .045f) * Mathf.Exp(-Mathf.Max(0, post - .045f) * 9);
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / .48f);
        for (int k = 0; k < 3; k++)
        {
            float lane = k, sign = k == 1 ? -1 : 1;
            matter.Ribbon(q => head + right * ((q - .49f) * (1.12f + bloom * 2.55f)
                    + sign * lane * .12f)
                + up * ((q * q) * (.58f + bloom * 1.05f) + lane * .15f - .33f)
                + depth * (Mathf.Sin(q * 4.7f + lane * 1.1f) * (.23f + bloom * .14f)),
                up, (.22f - lane * .036f) + bloom * .17f, 1.12f,
                new Color(1, .57f + lane * .09f, .21f, fade), lane * 2.7f, .88f);
        }
        if (post >= 0) matter.Spray(to, right, up, depth, post, 4.7f, 15,
            new Color(1, .77f, .39f, fade), 2.8f);
    }

    void DrawLifeVeil(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float post = age - contact, p = Mathf.Clamp01(age / contact);
        Vector3 head = Vector3.Lerp(from, to, Mathf.SmoothStep(0, 1, (p - .17f) / .83f));
        float bloom = post < 0 ? 0 : Mathf.SmoothStep(0, 1, post / .048f) * Mathf.Exp(-Mathf.Max(0, post - .048f) * 9);
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / .45f);
        for (int k = 0; k < 3; k++)
        {
            float lane = k;
            matter.Ribbon(q => head + right * ((q - .51f) * (1.42f + bloom * 2.5f)
                    + Mathf.Sin(q * 3.7f + lane * 1.9f) * .23f)
                + up * ((q - .48f) * (.74f + bloom * .78f) + Mathf.Sin(q * 5.6f + lane) * .19f)
                + depth * ((lane - 1) * .23f + Mathf.Sin(q * 4.9f + lane * 1.7f) * .3f),
                up, .29f - lane * .038f + bloom * .13f, 1.18f,
                k == 1 ? new Color(1, .76f, .75f, fade) : new Color(.91f, .17f, .34f, fade),
                lane * 3.2f + age * .22f, .98f);
        }
        if (post >= 0) matter.Spray(to, right, up, depth, post, 4.3f, 13,
            new Color(1, .47f, .54f, fade), 3.1f);
    }

    void DrawTransfer(Vector3 from, Vector3 to, Vector3 right, Vector3 up, Vector3 depth, float age)
    {
        float p = Mathf.Clamp01(age / contact), post = age - contact;
        float fade = post < 0 ? 1 : 1 - Mathf.SmoothStep(0, 1, post / .35f);
        float length = Mathf.SmoothStep(0, 1, (p - .12f) / .72f);
        for (int k = 0; k < 2; k++)
        {
            float lane = k;
            matter.Ribbon(q => Vector3.Lerp(from, to, q * length)
                + right * (Mathf.Sin(q * 5.7f + lane * 2.4f + age * 2.3f) * (.11f + lane * .05f))
                + up * (Mathf.Sin(q * 3.9f + lane) * .14f)
                + depth * (Mathf.Sin(q * 4.2f + lane * 2f) * .12f),
                up, .16f - lane * .03f, .96f,
                new Color(1, .58f + lane * .25f, .75f + lane * .17f, fade),
                lane * 3.8f + age * .2f, .87f);
        }
    }

    void StopSilk() { if (silkPlaying) silk.Stop(); silkPlaying = false; }
    void OnDisable() { StopSilk(); }
    void OnDestroy() { StopSilk(); }
}
