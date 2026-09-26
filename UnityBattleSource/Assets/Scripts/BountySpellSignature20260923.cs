using UnityEngine;

// Geometry for the eight authored bounty actors. Each entry has its own motion
// and contact silhouette; this component owns presentation only.
public static class BountySpellSignature20260923
{
    static float Ease(float value) => Mathf.SmoothStep(0, 1, Mathf.Clamp01(value));
    static float Pulse(float post, float rise = .045f, float decay = 10f)
        => post < 0 ? 0 : Ease(post / rise) * Mathf.Exp(-Mathf.Max(0, post - rise) * decay);
    static float Fade(float post, float duration)
        => post < 0 ? 1 : 1 - Ease(post / duration);
    static Vector3 Flight(Vector3 from, Vector3 to, float age, float contact, float wait)
        => Vector3.Lerp(from, to, Ease((age / contact - wait) / (1 - wait)));

    public static void Draw(BountySurfaceRound2 m, string species, string intent,
        Vector3 from, Vector3 to, float age, float clock, float contact,
        bool charge, bool state, Vector3 right, Vector3 up, Vector3 depth)
    {
        if (charge) { Gather(m, species, from, clock, right, up, depth); return; }
        if (state) { State(m, species, intent, from, to, clock, right, up, depth); return; }
        if (species == "b01") Sword(m, from, to, age, contact, right, up, depth);
        else if (species == "b02") Gold(m, from, to, age, contact, right, up, depth);
        else if (species.StartsWith("b03")) Water(m, intent, from, to, age, contact, right, up, depth);
        else if (species == "b05") Seam(m, intent, from, to, age, contact, right, up, depth);
        else if (species == "b07") Bell(m, intent, from, to, age, contact, right, up, depth);
        else if (species == "b08" || species == "b08-echo") Rapier(m, species, from, to, age, contact, right, up, depth);
        else if (species == "b09") Copper(m, from, to, age, contact, right, up, depth);
        else if (species == "b10") Veil(m, from, to, age, contact, right, up, depth);
        else if (species == "b10-vessel") Transfer(m, from, to, age, contact, right, up, depth);
    }

    static void Gather(BountySurfaceRound2 m, string species, Vector3 p, float t,
        Vector3 right, Vector3 up, Vector3 depth)
    {
        if (species == "b01") {
            // Short hilt scratches: no broad false blade during the held pose.
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => p + right * ((lane - 1) * .045f + Mathf.Sin(q * 5 + t * 3 + lane) * .018f)
                    - up * q * (.12f + lane * .022f) + depth * Mathf.Sin(q * 4 + lane) * .025f,
                    right, .022f, .38f, new Color(.72f, .91f, 1, .74f), lane * 2.7f + t * .3f,
                    silhouette: BountySurfaceRound2.Silhouette.Thread);
            }
            return;
        }
        if (species.StartsWith("b03")) {
            for (int k = 0; k < 2; k++) {
                float lane = k, sign = k == 0 ? -1 : 1;
                m.Ribbon(q => p + right * (sign * (.34f - q * .24f))
                    + up * ((q - .5f) * .55f + Mathf.Sin(q * 4.1f + t * 1.5f + lane) * .09f)
                    + depth * (Mathf.Sin(q * 4.7f + lane * 2.2f) * .17f),
                    up, .115f, 1.0f, new Color(.22f, .77f, 1, .79f),
                    2.2f + lane * 3.7f + t * .14f, .65f,
                    silhouette: BountySurfaceRound2.Silhouette.Water);
            }
            return;
        }
        if (species == "b05" || species == "b10") {
            bool veil = species == "b10";
            for (int k = 0; k < (veil ? 3 : 4); k++) {
                float lane = k, sign = k % 2 == 0 ? -1 : 1;
                m.Ribbon(q => p + right * (sign * (.10f + lane * .07f)
                        + Mathf.Sin(q * 5.1f + t * 1.5f + lane * 1.7f) * .07f)
                    + up * ((q - .5f) * (veil ? .63f : .38f))
                    + depth * (Mathf.Cos(q * 5.4f + lane * 1.6f) * .11f),
                    right, veil ? .10f : .035f, .65f,
                    new Color(1, veil ? .25f : .11f, .31f, .81f),
                    1.4f + lane * 2.9f + t * .16f, .65f,
                    silhouette: veil ? BountySurfaceRound2.Silhouette.Veil : BountySurfaceRound2.Silhouette.Thread);
            }
            return;
        }
        if (species == "b07") {
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => p + right * ((lane - 1) * .13f + Mathf.Sin(q * 3.7f + t * 3 + lane) * .04f)
                    + up * (.05f + (q - .5f) * (.23f + lane * .06f)) + depth * (lane * .06f),
                    right, .09f, .88f, new Color(1, .78f + lane * .04f, .26f, .82f),
                    2.6f + lane * 2.2f, .44f,
                    silhouette: BountySurfaceRound2.Silhouette.Droplet);
            }
            return;
        }
        if (species == "b09") {
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => p + right * ((q - .5f) * (.32f + lane * .09f))
                    + up * ((q - .5f) * .28f + lane * .10f)
                    + depth * (lane * .06f + Mathf.Sin(q * 5.1f + t + lane) * .07f),
                    up, .13f, .87f, new Color(1, .61f + lane * .07f, .21f, .83f),
                    1.2f + lane * 3.3f, .67f,
                    silhouette: BountySurfaceRound2.Silhouette.Plate);
            }
            return;
        }
        if (species == "b08") {
            for (int k = 0; k < 2; k++) {
                float sign = k == 0 ? -1 : 1;
                m.Ribbon(q => p + right * (sign * (.09f + q * .18f))
                    + up * ((q - .5f) * .48f) + depth * Mathf.Sin(q * 4 + t * 1.9f + k) * .07f,
                    up, .07f, .51f, new Color(.64f, .85f, 1, .79f), 3.1f + k * 3.5f,
                    silhouette: BountySurfaceRound2.Silhouette.Blade);
            }
            return;
        }
        Color tint = species.StartsWith("b03") ? new Color(.25f, .83f, 1, .78f)
            : species == "b07" ? new Color(1, .78f, .25f, .79f)
            : species == "b09" ? new Color(1, .60f, .24f, .85f)
            : species == "b05" || species == "b10" ? new Color(1, .16f, .30f, .82f)
            : new Color(.55f, .8f, 1, .80f);
        for (int k = 0; k < 3; k++) {
            float lane = k, side = k == 1 ? -1 : 1;
            m.Ribbon(q => p + right * (side * (1 - q) * (.20f + lane * .075f))
                + up * ((q - 1) * (.28f + lane * .08f) + Mathf.Sin(q * 4 + t * 2 + lane) * .055f)
                + depth * Mathf.Sin(q * 3.6f + lane * 1.8f) * .09f,
                up, .055f + lane * .015f, .63f, tint, 1.2f + lane * 2.6f + t * .17f);
        }
    }

    static void State(BountySurfaceRound2 m, string species, string intent,
        Vector3 from, Vector3 to, float t, Vector3 right, Vector3 up, Vector3 depth)
    {
        if (species == "b02") {
            // Persistent restraint breathes against the body; it never repeats
            // the one-off contact rupture or closes into a geometric ring.
            for (int k = 0; k < 3; k++) {
                float lane = k, sign = k == 1 ? -1 : 1;
                m.Ribbon(q => to + right * (sign * (.19f + q * (.13f + lane * .035f))
                        + Mathf.Sin(q * 5.4f + t * 1.3f + lane * 2.1f) * .08f)
                    + up * ((q - .5f) * (1.33f + lane * .11f))
                    + depth * (Mathf.Sin(q * 4.2f + t * .6f + lane) * .15f + lane * .08f),
                    right, .20f - lane * .022f, .88f,
                    k == 1 ? new Color(1, .89f, .48f, .80f)
                        : new Color(1, .53f, .13f, .74f),
                    2.1f + lane * 3.1f, .72f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
            return;
        }
        if (species == "b09") {
            // The forge flare opens uneven scales away from the real shell,
            // then settles into its defensive overlap. No damage burst is
            // implied by this support state.
            float forging = Mathf.Exp(-t * 3.0f);
            for (int k = 0; k < 4; k++) {
                float lane = k, sign = k % 2 == 0 ? -1 : 1;
                m.Ribbon(q => from + right * (sign * (.28f + q * (.22f + lane * .045f)
                        + forging * Mathf.Sin(q * Mathf.PI) * (.40f + lane * .075f)))
                    + up * ((q - .5f) * (.75f - lane * .065f + forging * .46f) + (lane - 1.5f) * .16f)
                    + depth * (.08f + lane * .09f + Mathf.Sin(q * 4.5f + t * .9f + lane) * .10f),
                    right, (.23f - lane * .018f + forging * .12f), .81f,
                    new Color(.32f, .14f, .06f, .96f), lane * 2.8f + t * .19f,
                    silhouette: BountySurfaceRound2.Silhouette.Plate);
                m.Ribbon(q => from + right * (sign * (.28f + q * (.22f + lane * .045f)
                        + forging * Mathf.Sin(q * Mathf.PI) * (.40f + lane * .075f)))
                    + up * ((q - .5f) * (.75f - lane * .065f + forging * .46f) + (lane - 1.5f) * .16f)
                    + depth * (.13f + lane * .09f + Mathf.Sin(q * 4.5f + t * .9f + lane) * .10f),
                    right, .14f - lane * .013f + forging * .06f, .72f,
                    new Color(1f, .60f + lane * .045f, .20f, .94f), lane * 2.8f + t * .19f,
                    silhouette: BountySurfaceRound2.Silhouette.Plate);
            }
            m.Spray(from, right, up, depth, t, 2.4f, 16,
                new Color(1f, .77f, .31f, .88f), 2.7f);
            return;
        }
        if (species == "b08") {
            // Broken, offset reflection facets open beside the real actor.
            // There is no closed mirror frame or false damage burst.
            for (int k = 0; k < 3; k++) {
                float lane = k, sign = k == 1 ? -1 : 1;
                m.Ribbon(q => from + right * (sign * (.29f + lane * .13f + q * .18f)
                        + Mathf.Sin(q * 6.1f + lane * 2.3f + t * .8f) * .07f)
                    + up * ((q - .5f) * (1.17f - lane * .15f) + (lane - 1) * .13f)
                    + depth * (.14f + lane * .16f + Mathf.Sin(q * 4.1f + lane) * .13f),
                    right, .16f - lane * .015f, .69f,
                    k == 1 ? new Color(.63f, .82f, 1, .74f)
                        : new Color(.23f, .47f, .90f, .66f),
                    2.7f + lane * 3.6f, .64f, 32,
                    BountySurfaceRound2.Silhouette.Plate);
            }
            return;
        }
        if (species == "b05") {
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => to + right * (Mathf.Sin(q * 5.4f + lane * 2.1f + t * 1.6f) * (.36f + lane * .055f))
                    + up * ((q - .5f) * 1.54f)
                    + depth * (Mathf.Cos(q * 5.4f + lane * 2.1f + t * 1.6f) * .34f),
                    up, .23f, .78f, new Color(.89f, .07f, .22f, .85f), lane * 3.3f + t * .23f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
            return;
        }
        // Escort: a two-part water mantle covers the recipient, not the caster.
        Vector3 recipient = intent == "escorted" ? to : from;
        for (int k = 0; k < 2; k++) {
            float lane = k, sign = k == 0 ? -1 : 1;
            m.Ribbon(q => recipient + right * (sign * (.23f + q * .38f))
                + up * ((q - .5f) * 1.43f + Mathf.Sin(q * 3.4f + lane) * .14f)
                + depth * (Mathf.Sin(q * 3.9f + t * .7f + lane * 2.1f) * .30f),
                right, .20f, .94f, new Color(.20f, .72f, 1, .70f), lane * 4.1f + t * .18f);
        }
    }

    static void Gold(BountySurfaceRound2 m, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        float post = age - contact, bloom = Pulse(post, .048f, 9.5f);
        float fade = Fade(post, .43f);
        Vector3 head = Flight(from, to, age, contact, .27f);
        for (int k = 0; k < 4; k++) {
            float lane = k, sign = k % 2 == 0 ? -1 : 1;
            float spread = .24f + lane * .13f + bloom * (.58f + lane * .13f);
            m.Ribbon(q => head + right * (sign * (spread * (1 - q * .32f)
                    + Mathf.Sin(q * 4.7f + lane * 2.1f) * (.07f + bloom * .10f)))
                + up * ((q - .48f) * (1.17f + bloom * 1.25f)
                    + Mathf.Sin(q * 8.1f + lane) * .07f)
                + depth * ((lane - 1.5f) * .17f + Mathf.Cos(q * 4.5f + lane) * .18f),
                right, (.17f + bloom * .19f) * fade * (1 - lane * .09f), 1.00f,
                k == 1 ? new Color(1, .84f, .35f, fade * .84f)
                    : new Color(1, .58f, .10f, fade * .77f),
                1.8f + lane * 2.7f, .83f,
                silhouette: BountySurfaceRound2.Silhouette.Veil);
        }
        if (post >= 0) {
            m.Spray(to, right, up, depth, post, 4.1f, 17,
                new Color(1, .86f, .43f, fade), 4.8f);
        }
    }

    static void Sword(BountySurfaceRound2 m, Vector3 from, Vector3 to, float age, float contact,
        Vector3 right, Vector3 up, Vector3 depth)
    {
        to += up * .27f;
        float post = age - contact, bloom = Pulse(post), fade = Fade(post, .38f);
        Vector3 head = Flight(from, to, age, contact, .26f);
        Vector3 cut = (right * .76f - up * .59f + depth * .13f).normalized;
        if (post < 0) {
            m.Ribbon(q => head + cut * ((q - .48f) * 1.36f)
                + right * Mathf.Sin(q * 5.2f) * .12f + depth * Mathf.Sin(q * 4.1f) * .16f,
                up, .20f, .58f, new Color(.54f, .80f, 1, .94f), 2.2f, .45f,
                silhouette: BountySurfaceRound2.Silhouette.Blade);
            m.Ribbon(q => head + cut * ((q - .48f) * 1.13f) + up * .055f + depth * .05f,
                up, .042f, .24f, new Color(1, .87f, .55f, .93f), 4.9f, .18f,
                silhouette: BountySurfaceRound2.Silhouette.Thread);
            return;
        }
        // A single torn diagonal plane carries the sword's force. The broken
        // subsidiary edges below are chips from this cut, not parallel blades.
        m.Ribbon(q => to + cut * ((q - .47f) * (2.05f + bloom * 2.42f))
            + right * Mathf.Sin(q * Mathf.PI) * (.15f + bloom * .37f)
            + depth * (Mathf.Sin(q * 6.2f + .4f) * .19f + bloom * .12f),
            up, (.29f + bloom * .47f) * fade, 1.02f,
            new Color(.20f, .56f, 1, fade * .94f), 6.3f, .82f,
            silhouette: BountySurfaceRound2.Silhouette.Blade);
        m.Ribbon(q => to + cut * ((q - .47f) * (1.86f + bloom * 2.27f))
            + right * Mathf.Sin(q * Mathf.PI) * (.13f + bloom * .33f)
            + depth * (Mathf.Sin(q * 6.2f + .4f) * .19f + bloom * .15f),
            up, (.067f + bloom * .12f) * fade, .46f,
            new Color(.95f, .99f, 1, fade), 8.6f, .58f,
            silhouette: BountySurfaceRound2.Silhouette.Blade);
        for (int k = 0; k < 4; k++) {
            float lane = k, sign = k % 2 == 0 ? -1 : 1;
            Vector3 axis = (cut + right * sign * (lane * .12f) + up * (lane - 1.5f) * .14f).normalized;
            m.Ribbon(q => to + axis * ((q - .42f) * (1.15f + bloom * (1.38f - lane * .13f)))
                + right * (Mathf.Sin(q * (5.1f + lane) + lane) * (.11f + bloom * .17f))
                + depth * ((lane - 1.5f) * .17f + Mathf.Sin(q * 3.6f + lane) * .18f),
                up, (.13f + bloom * .19f) * fade * (1 - lane * .11f), .82f,
                k == 1 ? new Color(1, .80f, .34f, fade) : new Color(.59f, .87f, 1, fade),
                1.4f + lane * 2.8f, .62f,
                silhouette: BountySurfaceRound2.Silhouette.Blade);
        }
        for (int k = 0; k < 7; k++) {
            float lane = k, angle = .31f + k * 2.39996f;
            Vector3 direction = (right * Mathf.Cos(angle) + up * Mathf.Sin(angle) * .82f
                + depth * Mathf.Sin(angle * 1.4f) * .21f).normalized;
            m.Ribbon(q => to + direction * ((q - .18f) * (.34f + bloom * (.55f + (k % 3) * .16f)))
                + depth * Mathf.Sin(q * 4.2f + lane) * .08f,
                up, (.035f + bloom * .061f) * fade, .40f,
                k % 3 == 0 ? new Color(1, .83f, .40f, fade) : new Color(.78f, .94f, 1, fade),
                3.8f + lane * 2.19f, .42f, 20, BountySurfaceRound2.Silhouette.Plate);
        }
        m.Spray(to, right, up, depth, post, 4.4f, 18, new Color(1, .86f, .46f, .96f), 1.6f);
    }

    static void Water(BountySurfaceRound2 m, string intent, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        bool heavy = intent == "heavy_strike", escort = intent == "escort_strike";
        float post = age - contact, bloom = Pulse(post, .052f, 8), fade = Fade(post, heavy ? .56f : .38f);
        Vector3 head = Flight(from, to, age, contact, heavy ? .20f : .32f);
        // Unequal sideways breakers curl forward and fall back to the ground.
        // The earlier upright tapered ribbons read as ice spears in the
        // recipient camera, even when their texture was set to water.
        int lobes = heavy ? 3 : 1;
        for (int k = 0; k < lobes; k++) {
            float lane = k;
            float span = (heavy ? 2.35f : 1.16f) * (1 + bloom * .42f) * (1 - lane * .11f);
            float height = (heavy ? 1.27f : .72f) * (1 + bloom * .42f) * (1 - lane * .12f);
            Vector3 root = head + right * ((lane - (lobes - 1) * .5f) * .29f)
                - up * (.59f - lane * .10f) + depth * (lane * .26f - .22f);
            m.Ribbon(q => root
                + right * ((q - .48f) * span + Mathf.Sin(q * 6.3f + lane * 1.7f) * .12f)
                + up * (height * Mathf.Sin(q * Mathf.PI)
                    + Mathf.Sin(q * 7.4f + lane) * .07f - Mathf.Max(0, post) * .70f)
                + depth * (Mathf.Sin(q * Mathf.PI) * (.23f + bloom * .28f)
                    + q * q * (.43f + bloom * .23f) + Mathf.Sin(q * 4.4f + lane) * .10f),
                up, (heavy ? .42f : .25f) * (1 - lane * .095f) * fade, 1.43f,
                heavy && k == 0 ? new Color(.06f, .39f, .82f, fade) : k == lobes - 1
                    ? new Color(.47f, .87f, 1, fade) : new Color(.14f, .68f, 1, fade),
                1.1f + lane * 2.71f + age * .12f, 1.1f,
                silhouette: BountySurfaceRound2.Silhouette.Water);
            // Separate, torn foam rides the falling side of each real wave.
            m.Ribbon(q => root
                + right * ((.26f + q * .50f - .48f) * span
                    + Mathf.Sin((.26f + q * .50f) * 6.3f + lane * 1.7f) * .12f)
                + up * (height * Mathf.Sin((.26f + q * .50f) * Mathf.PI)
                    + Mathf.Sin(q * 8.1f + lane) * .09f + .09f)
                + depth * (Mathf.Sin((.26f + q * .50f) * Mathf.PI) * (.23f + bloom * .28f)
                    + Mathf.Pow(.26f + q * .50f, 2) * (.43f + bloom * .23f) + .10f),
                up, (heavy ? .075f : .051f) * fade, .53f, new Color(.92f, .99f, 1, fade * .88f),
                5.2f + lane * 3.1f, .36f, 22, BountySurfaceRound2.Silhouette.Thread);
        }
        // Low, broken undertow grounds the water at the recipient's feet.
        m.Ribbon(q => head + right * ((q - .48f) * (heavy ? 2.25f : 1.25f))
            - up * (.60f + Mathf.Sin(q * 6.1f) * .055f)
            + depth * (Mathf.Sin(q * 4.7f) * .23f),
            up, heavy ? .31f : .20f, .9f, new Color(.08f, .49f, .92f, fade * .86f),
            9.4f, .62f, silhouette: BountySurfaceRound2.Silhouette.Water);
        if (heavy) {
            // Foamed leading edge ties the tall breaker back to its ground
            // surge; otherwise the contact reads as three ice walls.
            m.Ribbon(q => head + right * ((q - .49f) * (2.56f + bloom * .34f))
                - up * (.29f - Mathf.Sin(q * Mathf.PI) * (.24f + bloom * .13f))
                + depth * (Mathf.Sin(q * 5.2f) * .21f + .22f),
                up, .12f * fade, .72f, new Color(.93f, .99f, 1, fade),
                11.7f, .61f, silhouette: BountySurfaceRound2.Silhouette.Water);
        }
        if (post >= 0) {
            int drops = heavy ? 26 : 11;
            for (int k = 0; k < drops; k++) {
                float lane = k, angle = .41f + lane * 2.17f;
                float radius = (.15f + bloom * (.34f + k % 4 * .11f));
                Vector3 point = to + right * Mathf.Sin(angle) * radius
                    + up * (.20f + Mathf.Abs(Mathf.Cos(angle)) * (.25f + bloom * .34f)
                        - post * post * 2.4f)
                    + depth * (Mathf.Cos(angle * 1.3f) * radius * .54f);
                // Globs are enlarged by the contact expansion; keep each bead
                // small so the burst reads as spray rather than solid eggs.
                float size = (.026f + k % 3 * .011f) * fade;
                m.Glob(point, new Vector3(size * .83f, size * 1.38f, size),
                    k % 4 == 0 ? new Color(.85f, .97f, 1, fade * .88f)
                        : new Color(.13f, .62f, .94f, fade * .84f), 2.3f + lane * 1.81f);
            }
            m.Spray(to + up * .15f, right, up, depth, post,
                heavy ? 5.1f : 3.1f, heavy ? 23 : 9, new Color(.72f, .96f, 1, fade), 2.9f);
        }
    }

    static void Seam(BountySurfaceRound2 m, string intent, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        bool basic = intent == "strike";
        float post = age - contact, bloom = Pulse(post, .041f, 13), fade = Fade(post, basic ? .29f : .43f);
        Vector3 head = Flight(from, to, age, contact, basic ? .31f : .18f);
        int strands = basic ? 1 : 4;
        if (post < 0) {
            for (int k = 0; k < strands; k++) {
                float lane = k;
                m.Ribbon(q => Vector3.Lerp(from, head, q)
                    + right * Mathf.Sin(q * (6.2f + lane * .3f) + lane * 2.2f + age * 2) * (.07f + lane * .023f)
                    + up * Mathf.Sin(q * 4.7f + lane * 1.6f) * .09f
                    + depth * Mathf.Cos(q * 5.3f + lane * 1.4f) * .11f,
                    up, basic ? .046f : .055f + lane * .007f, .70f,
                    new Color(1, .16f, .30f, .84f), 1.7f + lane * 3.1f, .55f,
                    silhouette: BountySurfaceRound2.Silhouette.Thread);
            }
        }
        if (post >= -.08f) {
            int folds = basic ? 1 : 4;
            for (int k = 0; k < folds; k++) {
                float lane = k, sign = k % 2 == 0 ? -1 : 1;
                m.Ribbon(q => to + right * (sign * (.24f + lane * .13f + bloom * (.42f + lane * .12f))
                        + Mathf.Sin(q * 5.4f + lane * 1.9f + age * 3) * (.05f + bloom * .11f))
                    + up * ((q - .49f) * (1.26f + bloom * .82f))
                    + depth * (Mathf.Cos(q * 4.8f + lane * 2.1f) * (.16f + bloom * .18f)),
                    right, (basic ? .12f : .37f) * fade, .98f,
                    new Color(1, .07f + lane * .025f, .19f + lane * .025f, fade),
                    2.4f + lane * 2.82f + age * .12f, .96f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
            // One scissor point and a delayed mate, rather than a flat red carpet.
            for (int k = 0; k < (basic ? 1 : 2); k++) {
                float sign = k == 0 ? -1 : 1;
                m.Ribbon(q => to + right * (sign * (.32f - q * (.45f + bloom * .30f)))
                    + up * ((q - .5f) * (1.42f + bloom * 1.16f)) + depth * (k * .19f),
                    right, (.052f + bloom * .049f) * fade, .31f,
                    new Color(1, .38f, .54f, fade * .82f), 7.4f + k * 3.1f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
            // The seamstress closes two ragged scissor leaves across the
            // victim. A hot stitched tear separates them at the true contact.
            if (!basic) for (int k = 0; k < 2; k++) {
                float sign = k == 0 ? -1 : 1;
                m.Ribbon(q => to + right * (sign * ((.69f + bloom * .54f) * (1 - q) - q * .27f)
                        + Mathf.Sin(q * 6.8f + k * 2.3f) * .08f)
                    + up * ((q - .48f) * (1.62f + bloom * .78f))
                    + depth * ((k - .5f) * .21f + Mathf.Sin(q * 5.2f + k) * .12f),
                    right, .25f * fade, .88f,
                    k == 0 ? new Color(.93f, .05f, .31f, fade) : new Color(1, .25f, .44f, fade),
                    10.2f + k * 3.7f, .92f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
        }
        if (post >= 0) m.Spray(to, right, up, depth, post, basic ? 2.2f : 3.8f,
            basic ? 6 : 13, new Color(1, .34f, .42f, fade), 3.3f);
    }

    static void Bell(BountySurfaceRound2 m, string intent, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        bool venom = intent == "spittle";
        float post = age - contact, bloom = Pulse(post, .047f, 11), fade = Fade(post, .40f);
        Vector3 head = Flight(from, to, age, contact, venom ? .28f : .22f);
        if (venom) {
            if (post >= -.035f) {
                // The poison bursts as a three-lobed liquid crown, with real
                // droplets below; it never borrows the gold bell silhouette.
                for (int k = 0; k < 3; k++) {
                    float lane = k, side = k == 1 ? .12f : k == 0 ? -.29f : .43f;
                    m.Ribbon(q => to - up * .48f
                        + right * (side + Mathf.Sin(q * 5.7f + lane) * (.075f + bloom * .065f))
                        + up * (q * (.73f + lane * .16f + bloom * .38f)
                            - q * q * (.30f + lane * .08f))
                        + depth * (q * (.15f + bloom * .24f) + lane * .12f),
                        right, (.12f + bloom * .11f) * fade, 1.17f,
                        k == 1 ? new Color(.28f, .82f, .13f, fade) : new Color(.06f, .66f, .20f, fade),
                        8.1f + lane * 2.6f, .96f,
                        silhouette: BountySurfaceRound2.Silhouette.Water);
                }
            }
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => head + right * ((lane - 1.5f) * .14f + Mathf.Sin(q * 3.8f + lane) * .09f)
                    + up * ((q - .5f) * (.38f + bloom * .38f) - bloom * .24f)
                    + depth * (lane * .09f + Mathf.Sin(q * 4.4f + lane * 1.8f) * .08f),
                    right, (.085f + bloom * .083f) * fade, .95f,
                    new Color(.26f + lane * .05f, 1, .40f, fade), 1.8f + lane * 2.8f,
                    silhouette: BountySurfaceRound2.Silhouette.Droplet);
            }
            if (post >= 0) {
                // Separate tumbling drops read as liquid rather than a green
                // textile sheet. The local spit never becomes a full-area aura.
                for (int k = 0; k < 9; k++) {
                    float lane = k, a = .31f + k * 2.31f;
                    float flight = post * (1.15f + (k % 3) * .38f);
                    Vector3 point = to - up * .48f
                        + right * (Mathf.Sin(a) * (.10f + flight))
                        + up * (.16f + Mathf.Abs(Mathf.Cos(a)) * .31f
                            + post * (.30f + (k % 4) * .27f) - post * post * 3.4f)
                        + depth * (Mathf.Cos(a * 1.3f) * (.10f + flight * .61f));
                    float size = (.14f + (k % 4) * .042f) * fade;
                    m.Glob(point, new Vector3(size * .82f, size * (1.32f + k % 3 * .17f), size),
                        k % 3 == 0 ? new Color(.13f, .68f, .16f, fade * .88f)
                            : new Color(.36f, .98f, .32f, fade * .91f),
                        2.4f + lane * 1.79f);
                }
                m.Spray(to - up * .24f, right, up, depth, post,
                    3.2f, 15, new Color(.50f, 1, .37f, fade), 4.8f);
            }
            return;
        }
        // One falling copper clapper drives an uneven transverse sound skin.
        // It opens across the victim, rather than copying the green spit wings.
        float load = Ease((age / contact - .40f) / .55f);
        float beat = post < 0 ? 0 : Pulse(post, .036f, 14);
        m.Ribbon(q => head + right * Mathf.Sin(q * 4.9f) * .09f
            + up * (.65f - q * (1.22f + beat * .32f))
            + depth * Mathf.Sin(q * 5.1f) * .12f,
            right, (.095f + beat * .055f) * fade, .87f,
            new Color(.55f, .27f, .07f, fade), 2.4f, .56f,
            silhouette: BountySurfaceRound2.Silhouette.Droplet);
        m.Ribbon(q => head + right * ((q - .49f) * (.45f + load * 1.30f + beat * 1.09f)
                + Mathf.Sin(q * 7.1f + age * 1.7f) * (.07f + beat * .10f))
            + up * (Mathf.Sin(q * Mathf.PI) * (.16f + load * .22f + beat * .33f)
                + Mathf.Sin(q * 8.3f) * .065f - .10f)
            + depth * (Mathf.Sin(q * 4.5f + .6f) * (.11f + beat * .19f)),
            up, (.11f + load * .15f + beat * .19f) * fade, 1.06f,
            new Color(.83f, .46f, .10f, fade), 5.1f + age * .17f, .86f,
            silhouette: BountySurfaceRound2.Silhouette.Veil);
        if (post >= 0) {
            // Small mismatched torn sound echoes leave a ragged, open edge.
            for (int k = 0; k < 2; k++) {
                float lane = k;
                m.Ribbon(q => to + right * (k == 0 ? -.91f + q * (.65f + beat * .28f)
                        : .22f + q * (.78f + beat * .19f))
                    + up * (k == 0 ? .40f + Mathf.Sin(q * 5.0f) * .14f
                        : -.39f + Mathf.Sin(q * 4.4f + 1.2f) * .11f)
                    + depth * (k == 0 ? -.17f + q * .12f : .19f - q * .17f),
                    up, (.075f + beat * .07f) * fade, .68f,
                    new Color(1, .78f, .27f, fade * .79f), 7.3f + lane * 3.2f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
            for (int k = 0; k < 7; k++) {
                float lane = k, a = .5f + k * 2.07f;
                Vector3 point = to + right * (Mathf.Sin(a) * (.18f + bloom * .55f))
                    + up * (Mathf.Cos(a * 1.3f) * (.18f + bloom * .45f))
                    + depth * (Mathf.Sin(a * 2.3f) * .24f);
                m.Ribbon(q => point + up * ((q - .5f) * (.19f + lane % 3 * .08f))
                    + right * Mathf.Sin(q * 2.7f + a) * .06f,
                    right, .045f * fade, .42f, new Color(1, .91f, .52f, fade),
                    a, .48f, 14, BountySurfaceRound2.Silhouette.Droplet);
            }
        }
        if (post >= 0) m.Spray(to, right, up, depth, post, 4.0f, 15,
            new Color(1, .84f, .37f, fade), 5.1f);
    }

    static void Rapier(BountySurfaceRound2 m, string species, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        bool echo = species == "b08-echo";
        float post = age - contact, bloom = Pulse(post, .038f, 14), fade = Fade(post, .31f);
        Vector3 head = Flight(from, to, age, contact, .34f);
        if (echo) {
            // A false strike is a briefly displaced reflection, not a small
            // copy of the duelist's single physical rapier thrust.
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => head + right * ((q - .5f) * (.55f + bloom * .58f)
                        + (lane - 1) * (.20f + bloom * .16f))
                    + up * ((lane - 1) * .16f + Mathf.Sin(q * 4.7f + lane * 2.1f) * .10f)
                    + depth * ((lane - 1) * .22f + q * (.08f + bloom * .19f)),
                    up, (.095f + bloom * .077f) * fade, .47f,
                    k == 1 ? new Color(.59f, .81f, 1, fade * .69f)
                        : new Color(.22f, .49f, .94f, fade * .57f),
                    4.2f + lane * 2.3f, .55f, 18,
                    BountySurfaceRound2.Silhouette.Plate);
            }
            if (post >= 0) m.Spray(to, right, up, depth, post, 1.8f, 5,
                new Color(.48f, .71f, 1, fade * .75f), 6.7f);
            return;
        }
        float force = 1f;
        Vector3 thrust = (right * .43f + up * .71f + depth * .22f).normalized;
        m.Ribbon(q => head + thrust * ((q - .5f) * (1.68f + bloom * 2.10f) * force)
            + right * Mathf.Sin(q * 3.9f) * .09f + depth * Mathf.Sin(q * 4.5f) * .10f,
            up, (.16f + bloom * .25f) * force * fade, .62f,
            echo ? new Color(.40f, .62f, 1, fade * .67f) : new Color(.81f, .94f, 1, fade),
            2.6f, .51f,
            silhouette: BountySurfaceRound2.Silhouette.Blade);
        m.Ribbon(q => head + thrust * ((q - .5f) * (1.74f + bloom * 2.16f) * force) + right * .035f,
            up, (.061f + bloom * .11f) * force * fade, .28f,
            new Color(1, 1, 1, fade * (echo ? .55f : .96f)), 7.2f,
            silhouette: BountySurfaceRound2.Silhouette.Thread);
        if (post >= 0) {
            for (int k = 0; k < (echo ? 3 : 5); k++) {
                float lane = k, sign = k == 1 ? -1 : 1;
                m.Ribbon(q => to + right * (sign * (q * (.30f + bloom * (.81f + lane * .13f))) * force + (lane - 2) * .15f)
                    + up * ((q - .5f) * (.72f + bloom * .91f) * force + (lane - 2) * .14f)
                    + depth * (lane * .16f + Mathf.Sin(q * 4.3f + lane) * .13f),
                    right, (.11f + bloom * .13f) * force * fade, .72f,
                    k == 2 ? new Color(.84f, .96f, 1, fade * .88f)
                        : new Color(.31f, .54f, 1, fade * .82f), 1.9f + lane * 3.2f,
                    silhouette: BountySurfaceRound2.Silhouette.Plate);
            }
            m.Spray(to, right, up, depth, post, echo ? 2.2f : 3.0f,
                echo ? 5 : 9, new Color(.67f, .84f, 1, fade), 6.7f);
        }
    }

    static void Copper(BountySurfaceRound2 m, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        float post = age - contact, bloom = Pulse(post, .045f, 10), fade = Fade(post, .45f);
        Vector3 head = Flight(from, to, age, contact, .25f);
        for (int k = 0; k < 3; k++) {
            float lane = k;
            float angle = k == 0 ? -.63f : k == 1 ? .26f : .87f;
            Vector3 blade = (right * Mathf.Cos(angle) - up * Mathf.Sin(angle)).normalized;
            m.Ribbon(q => head + blade * ((q - .46f) * (1.42f + bloom * (2.10f - lane * .17f)))
                + right * ((lane - 1) * .25f + Mathf.Sin(q * 4.8f + lane * 1.7f) * .085f)
                + up * ((lane - 1) * .09f - .05f)
                + depth * (Mathf.Sin(q * 5.8f + lane * 2.3f) * (.17f + bloom * .17f) - .075f),
                up, (.31f + bloom * .36f) * fade * (1 - lane * .07f), 1.16f,
                new Color(.31f, .12f, .07f, fade * .84f), 10.4f + lane * 3.3f, .88f,
                silhouette: BountySurfaceRound2.Silhouette.Plate);
            m.Ribbon(q => head + blade * ((q - .46f) * (1.42f + bloom * (2.10f - lane * .17f)))
                + right * ((lane - 1) * .25f + Mathf.Sin(q * 4.8f + lane * 1.7f) * .085f)
                + up * ((lane - 1) * .09f)
                + depth * (Mathf.Sin(q * 5.8f + lane * 2.3f) * (.17f + bloom * .17f)),
                up, (.27f + bloom * .34f) * fade * (1 - lane * .07f), 1.1f,
                k == 1 ? new Color(.84f, .47f, .18f, fade) : new Color(.59f, .20f + lane * .045f, .08f, fade),
                2.3f + lane * 3.0f, .88f,
                silhouette: BountySurfaceRound2.Silhouette.Plate);
        }
        if (post >= 0) {
            m.Ribbon(q => to + right * ((q - .43f) * (1.35f + bloom * 2.0f))
                + up * (.16f + Mathf.Sin(q * 5.1f) * .21f)
                + depth * (Mathf.Sin(q * 4.7f) * .17f),
                up, (.030f + bloom * .043f) * fade, .42f,
                new Color(1, .79f, .38f, fade * .77f), 8.4f, .42f,
                silhouette: BountySurfaceRound2.Silhouette.Plate);
            // Separate forged scales shear away; each is a short curved solid
            // shard, never three parallel light strips or one orange ribbon.
            for (int k = 0; k < 9; k++) {
                float lane = k, a = .43f + k * 2.17f;
                Vector3 dir = (right * Mathf.Cos(a) + up * Mathf.Sin(a) * .72f
                    + depth * Mathf.Sin(a * 1.6f) * .35f).normalized;
                Vector3 place = to + dir * (bloom * (.24f + (k % 4) * .13f));
                m.Ribbon(q => place + dir * ((q - .45f) * (.37f + (k % 3) * .16f))
                    + depth * Mathf.Sin(q * 4.4f + lane) * .06f,
                    up, (.10f + (k % 3) * .024f) * fade, .92f,
                    k % 3 == 1 ? new Color(1, .82f, .41f, fade) : new Color(.71f, .33f, .12f, fade),
                    4.7f + lane * 2.32f, .64f, 20, BountySurfaceRound2.Silhouette.Plate);
            }
            m.Spray(to, right, up, depth, post, 3.7f, 16,
                new Color(1, .78f, .32f, fade), 2.1f);
        }
    }

    static void Veil(BountySurfaceRound2 m, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        float post = age - contact, bloom = Pulse(post, .052f, 8.5f), fade = Fade(post, .51f);
        Vector3 head = Flight(from, to, age, contact, .16f);
        if (post < 0) {
            m.Ribbon(q => Vector3.Lerp(from, head, q)
                    + right * Mathf.Sin(q * 5.2f + age * 1.5f) * .18f
                    + up * Mathf.Sin(q * 3.8f) * .21f + depth * Mathf.Cos(q * 4.2f) * .17f,
                up, .20f, .85f, new Color(.73f, .09f, .23f, .83f), 2.4f + age * .12f, .71f,
                silhouette: BountySurfaceRound2.Silhouette.Veil);
        }
        for (int k = 0; k < 5; k++) {
            float lane = k, sign = k % 2 == 0 ? -1 : 1;
            m.Ribbon(q => head + right * (sign * (.08f + lane * .065f
                        + q * (.38f + lane * .16f + bloom * (.23f + lane * .045f)))
                    + Mathf.Sin(q * 4.8f + lane * 1.8f + age * 1.4f) * (.12f + bloom * .13f))
                + up * (1.28f + lane * .06f - q * (2.12f + bloom * .97f)
                    - Mathf.Max(0, post) * .25f + Mathf.Sin(q * 7.3f + lane) * .065f)
                + depth * ((lane - 1.5f) * .20f + Mathf.Cos(q * 4.3f + lane * 1.9f) * (.35f + bloom * .12f)),
                right, (.39f + bloom * .29f) * fade * (1 - lane * .09f), 1.2f,
                k == 1 || k == 3 ? new Color(.88f, .24f, .43f, fade * .96f)
                    : new Color(.55f, .02f, .16f, fade),
                lane * 2.75f + age * .18f, 1.2f,
                silhouette: BountySurfaceRound2.Silhouette.Veil);
        }
        if (post >= 0) {
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => head + right * (Mathf.Sin(q * 5.2f + lane * 2.7f) * (.38f + bloom * .18f))
                    + up * ((q - .5f) * (1.32f + bloom * .27f))
                    + depth * (Mathf.Cos(q * 5.2f + lane * 2.7f) * .31f + .13f),
                    up, (.10f + bloom * .05f) * fade, .63f,
                    new Color(1, .69f, .54f, fade * .77f),
                    8.0f + lane * 2.73f, .75f, 32, BountySurfaceRound2.Silhouette.Thread);
            }
        }
        if (post >= 0) m.Spray(to, right, up, depth, post, 4.2f, 13,
            new Color(1, .46f, .55f, fade), 3.8f);
    }

    static void Transfer(BountySurfaceRound2 m, Vector3 from, Vector3 to,
        float age, float contact, Vector3 right, Vector3 up, Vector3 depth)
    {
        float p = Mathf.Clamp01(age / contact), post = age - contact;
        float fade = Fade(post, .38f), reach = Ease((p - .10f) / .75f);
        if (age < contact) {
            // The vessel is visibly squeezed before the life packets travel.
            for (int k = 0; k < 3; k++) {
                float lane = k, sign = k == 1 ? -1 : 1;
                m.Ribbon(q => from + right * (sign * (.26f - reach * .17f)
                        + Mathf.Sin(q * 5.1f + lane * 2.2f) * .06f)
                    + up * ((q - .5f) * (.48f + lane * .08f))
                    + depth * (lane * .12f + Mathf.Cos(q * 4.3f + lane) * .08f),
                    right, .11f * (1 - reach * .42f), .58f,
                    new Color(.46f, .035f, .13f, .82f), 1.7f + lane * 2.8f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
        }
        for (int k = 0; k < 3; k++) {
            float lane = k;
            m.Ribbon(q => Vector3.Lerp(from, to, q * reach)
                + right * Mathf.Sin(q * 5.1f + lane * 2.1f + age * 3.1f) * (.11f + lane * .029f)
                + up * (Mathf.Sin(q * Mathf.PI) * (k == 1 ? .31f : k == 2 ? -.21f : .13f)
                    + Mathf.Sin(q * 4.2f + lane) * .09f)
                + depth * (Mathf.Sin(q * Mathf.PI) * (k == 0 ? -.23f : .15f)
                    + Mathf.Cos(q * 5.6f + lane * 1.8f) * .11f),
                up, (.36f - lane * .033f) * fade, 1.13f,
                k == 1 ? new Color(1, .82f, .69f, fade) : new Color(.92f, .27f, .48f, fade),
                lane * 3.1f + age * .15f,
                silhouette: BountySurfaceRound2.Silhouette.Veil);
        }
        // Unequal travelling packets make the transfer direction legible.
        for (int k = 0; k < 3; k++) {
            float lane = k, q = Mathf.Repeat(age * (.72f + lane * .09f) - lane * .31f, 1);
            if (q > reach) continue;
            Vector3 packet = Vector3.Lerp(from, to, q)
                + up * (Mathf.Sin(q * Mathf.PI) * (k == 1 ? .31f : -.10f)
                    + Mathf.Sin(q * 4.2f + lane) * .1f)
                + depth * Mathf.Sin(q * Mathf.PI) * (k == 0 ? -.21f : .13f);
            m.Ribbon(s => packet + right * (s - .5f) * (.16f + lane * .026f)
                + up * Mathf.Sin(s * Mathf.PI) * .09f + depth * Mathf.Sin(s * 4 + lane) * .045f,
                up, .11f * fade, .75f, new Color(1, .91f, .52f, fade), 6.2f + lane * 2.6f, .42f, 14,
                BountySurfaceRound2.Silhouette.Droplet);
        }
        if (reach > .68f) {
            // The recipient catches the transfer in three short rising hems.
            for (int k = 0; k < 3; k++) {
                float lane = k;
                m.Ribbon(q => to + right * ((lane - 1) * .17f
                        + Mathf.Sin(q * 4.8f + lane * 2.0f) * .08f)
                    + up * ((q - .5f) * (.80f + lane * .10f))
                    + depth * (Mathf.Sin(q * 5.2f + lane) * .10f - .09f),
                    right, (.13f + lane * .018f) * fade, .86f,
                    new Color(1, .79f, .40f, fade * .89f), 9.1f + lane * 2.7f,
                    silhouette: BountySurfaceRound2.Silhouette.Veil);
            }
        }
        if (post >= 0) m.Spray(to, right, up, depth, post, 1.8f, 12,
            new Color(1f, .83f, .49f, fade * .82f), 6.4f);
    }
}
