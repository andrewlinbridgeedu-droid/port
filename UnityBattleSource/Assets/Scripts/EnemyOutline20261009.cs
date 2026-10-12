using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Enemy body outline trial (2026-10-09, user: 钟卫和猎犬各试一版, after the UE overlay-material
/// outline article). Two looks, chosen by MISTPORT_OUTLINE for the review recordings:
///   ink  - a thin dark line round every enemy all the time, so the 3D bodies read more drawn;
///   glow - nothing at rest; while an enemy winds up, a soft band in its spell's colours
///          breathes round its body, flashes at the contact and fades.
/// Off (the default) changes nothing. Each outline is a child renderer drawing the body's own
/// mesh and bones with the outline shader, so the body's materials are never touched.
[DisallowMultipleComponent, DefaultExecutionOrder(30950)]
public sealed class EnemyOutline20261009 : MonoBehaviour
{
    public enum Mode { Off, Ink, Glow }
    public static readonly Mode Current = ParseMode();

    static Mode ParseMode()
    {
        switch ((Environment.GetEnvironmentVariable("MISTPORT_OUTLINE") ?? "").Trim().ToLowerInvariant())
        {
            case "ink": return Mode.Ink;
            case "glow": return Mode.Glow;
            default: return Mode.Off;
        }
    }

    const string ChildName = "Outline20261009";
    const float InkWidth = .0022f;
    static readonly Color InkColour = new Color(.07f, .04f, .09f, .92f);
    // Three additive shells, widest faintest, so the band fades out instead of ending in a hard edge.
    static readonly float[] ShellWidth = { .0026f, .0052f, .0090f };
    static readonly float[] ShellGain = { 1f, .5f, .24f };
    const float ChargeRamp = .45f, ChargeLimit = 6f, FlashTime = .4f, StopTime = .3f;

    static Shader shader;
    static Material inkMaterial;
    static readonly Dictionary<string, EnemyOutline20261009> byKey = new Dictionary<string, EnemyOutline20261009>();

    sealed class Pair { public Renderer src, dst; public SkinnedMeshRenderer srcSkin, dstSkin; }
    readonly List<Pair> pairs = new List<Pair>();
    readonly List<Renderer> scratch = new List<Renderer>();
    EnemyHandle handle;
    bool driver;
    int sourceCount = -1;
    float nextScan;

    Material[] shells;
    Color inner, mid, outer;
    float chargeStart = -1f, contactAt = -1f, stopAt = -1f, level;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (Current != Mode.Ink) return;
        var go = new GameObject("EnemyOutline20261009 driver") { hideFlags = HideFlags.HideAndDontSave };
        DontDestroyOnLoad(go);
        go.AddComponent<EnemyOutline20261009>().driver = true;
    }

    static EnemyOutline20261009 For(EnemyHandle h)
    {
        if (Current == Mode.Off || !h) return null;
        var o = h.GetComponent<EnemyOutline20261009>();
        if (!o) o = h.gameObject.AddComponent<EnemyOutline20261009>();
        o.handle = h;
        return o;
    }

    /// The enemy starts winding up (its preparation turn, or the attack's own lead-in).
    public static void Charge(EnemyHandle actor, string key, Color line, Color core, Color deep)
    {
        if (Current != Mode.Glow) return;
        var o = For(actor);
        if (!o) return;
        byKey[key] = o;
        o.inner = Color.Lerp(line, core, .35f);
        o.mid = line;
        o.outer = deep;
        if (o.chargeStart < 0f) o.chargeStart = Time.time;
        o.contactAt = -1f;
        o.stopAt = -1f;
    }

    /// The hit lands: the band flashes and fades.
    public static void Contact(string key)
    {
        if (Current != Mode.Glow || key == null || !byKey.TryGetValue(key, out var o) || !o) return;
        if (o.chargeStart < 0f && o.level < .01f) return;
        o.contactAt = Time.time;
        o.chargeStart = -1f;
    }

    /// The wind-up ends without a hit (recover): the band fades.
    public static void Stop(string key)
    {
        if (Current != Mode.Glow || key == null || !byKey.TryGetValue(key, out var o) || !o) return;
        if (o.chargeStart >= 0f) o.stopAt = Time.time;
        o.chargeStart = -1f;
    }

    static bool Load()
    {
        if (shader) return true;
        shader = Resources.Load<Shader>("EnemyOutline20261009/EnemyOutline20261009");
        if (!shader) { Debug.LogError("EnemyOutline20261009: shader missing"); return false; }
        return true;
    }

    static Material Make(bool glow, float width, Color c)
    {
        var m = new Material(shader) { name = glow ? "Enemy outline glow" : "Enemy outline ink", hideFlags = HideFlags.DontSave };
        m.SetColor("_Color", c);
        m.SetFloat("_Width", width);
        if (glow)
        {
            m.SetFloat("_Src", (float)BlendMode.One); m.SetFloat("_Dst", (float)BlendMode.One); m.SetFloat("_ZW", 0f);
            m.renderQueue = 3000; // after the skybox, which would cover a depthless band
        }
        else
        {
            m.SetFloat("_Src", (float)BlendMode.SrcAlpha); m.SetFloat("_Dst", (float)BlendMode.OneMinusSrcAlpha); m.SetFloat("_ZW", 1f);
            m.renderQueue = 2020;
        }
        return m;
    }

    static bool Eligible(Renderer r)
    {
        if (!r || !r.enabled || r.name == ChildName) return false;
        if (r.GetComponent<ParticleSystem>()) return false;
        if (r is SkinnedMeshRenderer s) { if (!s.sharedMesh) return false; }
        else if (r is MeshRenderer) { var mf = r.GetComponent<MeshFilter>(); if (!mf || !mf.sharedMesh) return false; }
        else return false;
        var m = r.sharedMaterial;
        if (!m || !m.shader) return false;
        // Effects and fading bodies are transparent; a dying enemy loses its outline with its opacity.
        if (m.renderQueue >= 2450) return false;
        string n = m.shader.name;
        return !(n.Contains("Particle") || n.Contains("Sprite") || n.Contains("UI/") || n.Contains("Shadow") || n.Contains("Unlit") || n.Contains("Outline"));
    }

    Transform Root => handle ? (handle.VisualRoot ? handle.VisualRoot : handle.EnemyRoot ? handle.EnemyRoot : handle.transform) : transform;

    int CountEligible()
    {
        scratch.Clear();
        Root.GetComponentsInChildren(false, scratch);
        int n = 0;
        foreach (var r in scratch) if (Eligible(r)) n++;
        return n;
    }

    void Rebuild()
    {
        Clear();
        // A battle clone copies the original's outline children; drop them and build our own.
        foreach (var t in Root.GetComponentsInChildren<Transform>(true))
            if (t && t.name == ChildName) Destroy(t.gameObject);
        scratch.Clear();
        Root.GetComponentsInChildren(false, scratch);
        sourceCount = 0;
        foreach (var r in scratch)
        {
            if (!Eligible(r)) continue;
            sourceCount++;
            var go = new GameObject(ChildName) { layer = r.gameObject.layer };
            go.transform.SetParent(r.transform, false);
            var p = new Pair { src = r };
            Mesh mesh;
            if (r is SkinnedMeshRenderer s)
            {
                var d = go.AddComponent<SkinnedMeshRenderer>();
                d.sharedMesh = mesh = s.sharedMesh;
                d.bones = s.bones;
                d.rootBone = s.rootBone;
                d.localBounds = s.localBounds;
                d.quality = s.quality;
                d.updateWhenOffscreen = true;
                p.srcSkin = s; p.dstSkin = d; p.dst = d;
            }
            else
            {
                mesh = r.GetComponent<MeshFilter>().sharedMesh;
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                p.dst = go.AddComponent<MeshRenderer>();
            }
            p.dst.shadowCastingMode = ShadowCastingMode.Off;
            p.dst.receiveShadows = false;
            p.dst.lightProbeUsage = LightProbeUsage.Off;
            p.dst.reflectionProbeUsage = ReflectionProbeUsage.Off;
            p.dst.motionVectorGenerationMode = MotionVectorGenerationMode.ForceNoMotion;
            p.dst.sortingLayerID = r.sortingLayerID;
            p.dst.sortingOrder = r.sortingOrder;
            // Materials past the submesh count draw the last submesh again: one mesh, three shells.
            int subs = Mathf.Max(1, mesh.subMeshCount);
            Material[] mats;
            if (Current == Mode.Ink)
            {
                mats = new Material[subs];
                for (int i = 0; i < subs; i++) mats[i] = inkMaterial;
            }
            else if (subs == 1) mats = shells;
            else
            {
                mats = new Material[subs];
                for (int i = 0; i < subs; i++) mats[i] = shells[1];
            }
            p.dst.sharedMaterials = mats;
            p.dst.enabled = false;
            pairs.Add(p);
        }
    }

    void Clear()
    {
        foreach (var p in pairs) if (p.dst) Destroy(p.dst.gameObject);
        pairs.Clear();
    }

    static float Smooth(float a, float b, float x)
    {
        float t = Mathf.Clamp01((x - a) / (b - a));
        return t * t * (3f - 2f * t);
    }

    /// Glow level and width scale for this frame.
    void Step(out float intensity, out float widen)
    {
        float now = Time.time;
        intensity = 0f; widen = 1f;
        if (contactAt >= 0f)
        {
            float u = (now - contactAt) / FlashTime;
            if (u >= 1f) contactAt = -1f;
            else { float f = 1f - u; intensity = 1.7f * f * f; widen = 1f + .7f * u; }
        }
        else if (chargeStart >= 0f)
        {
            float t = now - chargeStart;
            if (t > ChargeLimit) { chargeStart = -1f; stopAt = now; }
            else
            {
                float breathe = .5f + .5f * Mathf.Sin(t * 11f);
                intensity = Smooth(0f, ChargeRamp, t) * (.72f + .28f * breathe);
                widen = 1f + .12f * breathe;
            }
        }
        if (stopAt >= 0f && chargeStart < 0f && contactAt < 0f)
        {
            float u = (now - stopAt) / StopTime;
            if (u >= 1f) stopAt = -1f;
            else intensity = level * (1f - u);
        }
        level = intensity;
    }

    void LateUpdate()
    {
        if (driver)
        {
            if (Time.unscaledTime < nextScan) return;
            nextScan = Time.unscaledTime + .5f;
            foreach (var h in FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None)) For(h);
            return;
        }
        if (Current == Mode.Off || !Load()) return;
        if (!handle) { handle = GetComponent<EnemyHandle>(); if (!handle) return; }
        if (Current == Mode.Ink && !inkMaterial) inkMaterial = Make(false, InkWidth, InkColour);
        if (Current == Mode.Glow && shells == null)
        {
            shells = new Material[ShellWidth.Length];
            for (int i = 0; i < shells.Length; i++) shells[i] = Make(true, ShellWidth[i], Color.black);
        }
        float intensity = 1f, widen = 1f;
        if (Current == Mode.Glow)
        {
            Step(out intensity, out widen);
            if (intensity <= .003f && pairs.Count == 0) return; // nothing to draw yet; build on the first wind-up
            Color[] colours = { inner, mid, outer };
            for (int i = 0; i < shells.Length; i++)
            {
                shells[i].SetColor("_Color", colours[i] * (ShellGain[i] * intensity));
                shells[i].SetFloat("_Width", ShellWidth[i] * widen);
            }
        }
        if (Time.unscaledTime >= nextScan)
        {
            nextScan = Time.unscaledTime + .25f;
            if (CountEligible() != sourceCount) Rebuild();
        }
        bool lit = Current == Mode.Ink || intensity > .003f;
        foreach (var p in pairs)
        {
            if (!p.dst) continue;
            bool show = lit && p.src && p.src.enabled && p.src.gameObject.activeInHierarchy && !p.src.forceRenderingOff;
            if (p.dst.enabled != show) p.dst.enabled = show;
            if (show && p.srcSkin && p.dstSkin)
            {
                int n = p.srcSkin.sharedMesh ? p.srcSkin.sharedMesh.blendShapeCount : 0;
                for (int i = 0; i < n; i++) p.dstSkin.SetBlendShapeWeight(i, p.srcSkin.GetBlendShapeWeight(i));
            }
        }
    }

    void OnDestroy()
    {
        Clear();
        if (shells != null) foreach (var m in shells) if (m) Destroy(m);
    }
}
