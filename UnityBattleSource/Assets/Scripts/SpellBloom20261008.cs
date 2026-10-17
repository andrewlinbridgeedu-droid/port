using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Bloom for the spell layer only (2026-10-08, user: 试整屏辉光后期). The reference short gets
/// its light from a full-screen bloom over a night scene; our battle is bright marble and
/// sky, which a whole-image bloom would wash white. So every frame the live spell renderers
/// (children of the SpellSpectacle root, minus the full-screen tint and the darkening plane)
/// are drawn into a half-resolution buffer, blurred down four levels and back up (dual
/// filter), and added onto the camera image. Nothing runs while no spell is on screen.
/// Off with the environment variable MISTPORT_SPELL_BLOOM=0 (editor A/B recordings).
[RequireComponent(typeof(Camera))]
public sealed class SpellBloom20261008 : MonoBehaviour
{
    public static bool Enabled = System.Environment.GetEnvironmentVariable("MISTPORT_SPELL_BLOOM") != "0";
    /// How strongly the blurred light is added back. The four summed levels carry about four
    /// times the spell's own light; at 1.1 every hit washed out to a white blob (bloom1).
    public static float Intensity = .28f;
    const int Levels = 4;

    Camera cam;
    CommandBuffer cmd;
    Material mat;
    Transform source;
    readonly List<Renderer> renderers = new List<Renderer>();
    readonly List<Material> materials = new List<Material>();
    // Whether a material glows, by instance: reading Material.name every frame allocated a
    // string per renderer (2026-10-17, iPhone 13: 好卡).
    static readonly Dictionary<int, bool> glowByMaterial = new Dictionary<int, bool>();
    static readonly int[] Ids = { Shader.PropertyToID("_SpellBloom0"), Shader.PropertyToID("_SpellBloom1"), Shader.PropertyToID("_SpellBloom2"), Shader.PropertyToID("_SpellBloom3"), Shader.PropertyToID("_SpellBloom4") };
    static readonly int IntensityId = Shader.PropertyToID("_Intensity");

    public static void Ensure(Camera camera, Transform spellRoot)
    {
        if (!camera || !spellRoot) return;
        var b = camera.GetComponent<SpellBloom20261008>();
        if (!b) b = camera.gameObject.AddComponent<SpellBloom20261008>();
        b.source = spellRoot;
    }

    void OnEnable()
    {
        cam = GetComponent<Camera>();
        var shader = Resources.Load<Shader>("SpellSpectacle20260926/SpellBloom20261008");
        if (!shader) { Debug.LogWarning("SPELL_BLOOM_MISSING_SHADER"); enabled = false; return; }
        mat = new Material(shader) { name = "SpellBloom", hideFlags = HideFlags.HideAndDontSave };
        cmd = new CommandBuffer { name = "Spell bloom" };
        cam.AddCommandBuffer(CameraEvent.AfterForwardAlpha, cmd);
    }

    void OnDisable()
    {
        if (cam && cmd != null) cam.RemoveCommandBuffer(CameraEvent.AfterForwardAlpha, cmd);
        cmd?.Release(); cmd = null;
        if (mat) Destroy(mat);
    }

    void OnPreRender()
    {
        if (cmd == null) return;
        cmd.Clear();
        if (!Enabled || !source) return;
        renderers.Clear();
        source.GetComponentsInChildren(false, renderers);
        int drawn = 0;
        foreach (var r in renderers)
            if (r && r.enabled && Glows(r)) drawn++;
        if (drawn == 0) return;

        int w = Mathf.Max(16, cam.pixelWidth / 2), h = Mathf.Max(16, cam.pixelHeight / 2);
        cmd.GetTemporaryRT(Ids[0], w, h, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
        cmd.SetRenderTarget(Ids[0]);
        cmd.ClearRenderTarget(false, true, Color.clear);
        foreach (var r in renderers)
        {
            if (!r || !r.enabled || !Glows(r)) continue;
            r.GetSharedMaterials(materials);
            for (int i = 0; i < materials.Count; i++) if (materials[i]) cmd.DrawRenderer(r, materials[i], i);
        }
        for (int i = 1; i <= Levels; i++)
        {
            cmd.GetTemporaryRT(Ids[i], Mathf.Max(4, w >> i), Mathf.Max(4, h >> i), 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
            cmd.Blit(Ids[i - 1], Ids[i], mat, 0);
        }
        for (int i = Levels; i > 1; i--) cmd.Blit(Ids[i], Ids[i - 1], mat, 1);
        cmd.SetGlobalFloat(IntensityId, Intensity);
        cmd.Blit(Ids[1], BuiltinRenderTextureType.CameraTarget, mat, 2);
        for (int i = 0; i <= Levels; i++) cmd.ReleaseTemporaryRT(Ids[i]);
    }

    /// The full-screen tint and the darkening plane must not glow (they would light the
    /// whole screen).
    static bool Glows(Renderer r)
    {
        var m = r.sharedMaterial;
        if (!m) return false;
        int id = m.GetInstanceID();
        if (!glowByMaterial.TryGetValue(id, out var glows)) {
            var n = m.name;
            glowByMaterial[id] = glows = !(n.Contains("Wash") || n.Contains("Dim"));
        }
        return glows;
    }
}
