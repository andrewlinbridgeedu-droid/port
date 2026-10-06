using UnityEngine;

/// One oval light shield that wraps a body whole: a glowing membrane with
/// flowing bands and glints (user, 2026-10-05: 要一个椭圆的光盾，会有流光闪烁；
/// 你这像是栅栏). Two presets so the Q1 guard's ward and the puppets'
/// fortify never read as the same shield.
public sealed class OvalLightShield : MonoBehaviour
{
    public enum Preset { Ward, Fortify }

    static Mesh sphere;
    Transform body; Material material; Preset preset;
    float born, life = -1f, opacity = 1f, hitAt = -100f, seed; bool breaking; float breakAt;
    Vector3 lastCentre; float lastW = .6f, lastH = 1f;

    public static OvalLightShield Attach(Transform bodyRoot, Preset preset)
    {
        var go = new GameObject(preset == Preset.Ward ? "Oval light shield · ward" : "Oval light shield · fortify");
        go.transform.SetParent(bodyRoot, false);
        var s = go.AddComponent<OvalLightShield>();
        s.body = bodyRoot; s.preset = preset; s.Build();
        return s;
    }

    /// A shield that lives `seconds`, fading in and out on its own.
    public static OvalLightShield Flash(Transform bodyRoot, Preset preset, float seconds)
    {
        if (!bodyRoot) return null;
        foreach (var old in bodyRoot.GetComponentsInChildren<OvalLightShield>()) if (old.preset == preset && old.life > 0f) { old.born = Time.time; old.life = seconds; return old; }
        var s = Attach(bodyRoot, preset); s.life = seconds; return s;
    }

    void Build()
    {
        if (!sphere)
        {
            var tmp = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere = tmp.GetComponent<MeshFilter>().sharedMesh;
            Destroy(tmp);
        }
        gameObject.AddComponent<MeshFilter>().sharedMesh = sphere;
        var r = gameObject.AddComponent<MeshRenderer>();
        material = new Material(Resources.Load<Shader>("Shaders/OvalLightShield"));
        r.sharedMaterial = material; r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
        seed = Random.Range(0f, 6.28f); born = Time.time;
        if (preset == Preset.Ward)
        {
            // Cool, calm: a slow vertical tide of light, soft glints, no facets.
            material.SetColor("_Tint", new Color(.30f, .72f, 1f)); material.SetColor("_Rim", new Color(.80f, .95f, 1f)); material.SetColor("_Spark", Color.white);
            material.SetFloat("_FlowSpeed", .32f); material.SetFloat("_FlowAngle", Mathf.PI * .5f); material.SetFloat("_BandFreq", 5.5f);
            material.SetFloat("_Facet", 0f); material.SetFloat("_SparkAmt", .35f);
        }
        else
        {
            // Hot, nervous: amber-gold plates with violet rim, fast diagonal sweep, cells flaring.
            material.SetColor("_Tint", new Color(1f, .68f, .22f)); material.SetColor("_Rim", new Color(.78f, .45f, 1f)); material.SetColor("_Spark", new Color(1f, .95f, .8f));
            material.SetFloat("_FlowSpeed", 1.15f); material.SetFloat("_FlowAngle", Mathf.PI * .2f); material.SetFloat("_BandFreq", 8.5f);
            material.SetFloat("_Facet", .9f); material.SetFloat("_SparkAmt", .7f);
        }
        material.SetFloat("_Seed", seed);
        Fit(true);
    }

    public void SetOpacity(float value) { opacity = value; }
    public void Impact() { hitAt = Time.time; }
    public void ImpactAfter(float delay) { CancelInvoke(nameof(Impact)); Invoke(nameof(Impact), delay); }
    public void Break() { if (breaking) return; breaking = true; breakAt = Time.time; }

    void Fit(bool force)
    {
        if (!body) return;
        bool any = false; var b = new Bounds();
        foreach (var r in body.GetComponentsInChildren<Renderer>())
        {
            if (!r || r.GetComponentInParent<OvalLightShield>() || !(r is SkinnedMeshRenderer || r is MeshRenderer)) continue;
            if (!any) { b = r.bounds; any = true; } else b.Encapsulate(r.bounds);
        }
        if (any && b.size.y > .3f)
        {
            // Width from the torso, not from an outstretched sword: never wider than
            // 55% of the body height (user, 2026-10-05: Q1 的这个太大了).
            lastCentre = b.center; lastH = b.extents.y;
            lastW = Mathf.Min(Mathf.Max(b.extents.x, b.extents.z), lastH * .55f);
        }
        else if (force) { lastCentre = body.position + Vector3.up * 1f; }
    }

    void LateUpdate()
    {
        if (!material) return;
        float t = Time.time - born;
        Fit(false);
        float breathe = 1f + (preset == Preset.Ward ? .02f : .045f) * Mathf.Sin(t * (preset == Preset.Ward ? 1.1f : 2.6f) + seed);
        float hit = 1f - Mathf.Clamp01((Time.time - hitAt) / .5f);
        float fade = 1f;
        if (life > 0f) fade = Mathf.SmoothStep(0f, 1f, t / .22f) * (1f - Mathf.SmoothStep(0f, 1f, (t - (life - .45f)) / .45f));
        float grow = 1f;
        if (breaking)
        {
            float u = Mathf.Clamp01((Time.time - breakAt) / .55f);
            fade *= 1f - u; grow = 1f + u * .35f;
            if (u >= 1f) { Destroy(gameObject); return; }
        }
        if (life > 0f && t > life) { Destroy(gameObject); return; }
        float rx = (lastW * 1.08f + .06f) * breathe * grow * (1f + hit * .06f), ry = (lastH * 1.04f + .06f) * breathe * grow;
        // Comes and goes: a slow tide of visibility with an occasional quick flicker
        // (user: 需要忽隐忽现). Never fully gone while the state holds.
        float tideRate = preset == Preset.Ward ? .55f : 1.1f;
        float tide = .5f + .5f * Mathf.Sin(t * tideRate * 6.2832f + seed);
        float flick = Mathf.PerlinNoise(t * (preset == Preset.Ward ? 2.4f : 4.5f), seed) ;
        float visible = Mathf.Lerp(.18f, 1f, tide * tide) * Mathf.Lerp(.7f, 1f, flick);
        transform.position = lastCentre + Vector3.up * .04f;
        transform.rotation = Quaternion.identity;
        var parentScale = transform.parent ? transform.parent.lossyScale : Vector3.one;
        transform.localScale = new Vector3(2f * rx / Mathf.Max(.001f, parentScale.x), 2f * ry / Mathf.Max(.001f, parentScale.y), 2f * rx / Mathf.Max(.001f, parentScale.z));
        material.SetFloat("_Age", t);
        material.SetFloat("_Opacity", opacity * fade * visible * (.85f + .35f * hit));
    }

    void OnDestroy() { if (material) Destroy(material); }
}
