using System;
using System.Collections.Generic;
using UnityEngine;

// Tower-owned painted surfaces. Actual tapered, rolled geometry provides the
// outline; opacity/texture detail is secondary. No circles or rectangular plates.
public sealed class TowerSurfaceRound2
{
    const int Across = 8, Along = 40;
    sealed class Surface
    {
        public Mesh mesh;
        public MeshRenderer renderer;
        public Material material;
        public Transform transform;
        public Vector3[] vertices = new Vector3[(Across + 1) * (Along + 1)];
        public Vector2[] uv = new Vector2[(Across + 1) * (Along + 1)];
    }
    readonly List<Surface> surfaces = new List<Surface>();
    public static Quaternion Face => Camera.main ? Quaternion.LookRotation(Camera.main.transform.forward) : Quaternion.identity;
    public TowerSurfaceRound2(Transform owner, int count, string texture, bool additive = false, float paintedLuminance = 0)
    {
        var shader = Resources.Load<Shader>("Shaders/TowerOrganicSurfaceRound2");
        for (int i = 0; i < count; i++)
        {
            var go = new GameObject("Tower rolled surface " + i); go.transform.SetParent(owner, false);
            var s = new Surface { mesh = new Mesh(), transform = go.transform };
            s.mesh.MarkDynamic();
            int[] triangles = new int[Across * Along * 6];
            for (int y = 0; y <= Along; y++) for (int x = 0; x <= Across; x++)
            {
                int n = y * (Across + 1) + x;
                s.uv[n] = new Vector2(x / (float)Across, y / (float)Along);
                if (x == Across || y == Along) continue;
                int k = (y * Across + x) * 6;
                triangles[k] = n; triangles[k + 1] = n + 1; triangles[k + 2] = n + Across + 2;
                triangles[k + 3] = n; triangles[k + 4] = n + Across + 2; triangles[k + 5] = n + Across + 1;
            }
            s.mesh.vertices = s.vertices; s.mesh.uv = s.uv; s.mesh.uv2 = s.uv; s.mesh.triangles = triangles;
            go.AddComponent<MeshFilter>().sharedMesh = s.mesh;
            s.renderer = go.AddComponent<MeshRenderer>();
            s.material = new Material(shader ? shader : Shader.Find("Sprites/Default"));
            s.material.mainTexture = Resources.Load<Texture2D>(texture);
            s.material.SetColor("_Color", Color.clear);
            s.material.SetFloat("_Dst", additive ? 1 : 10);
            // Some authored paintings use transparent ink around their veins.
            // A per-effect luminance mix lets a folded *body* stay legible at
            // battlefield distance without changing the common shader.
            s.material.SetFloat("_Luma", additive ? 1 : Mathf.Clamp01(paintedLuminance));
            s.material.SetFloat("_Seed", i * 1.731f);
            s.renderer.sharedMaterial = s.material;
            s.renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            s.renderer.receiveShadows = false; s.renderer.enabled = false;
            surfaces.Add(s);
        }
    }
    public void Hide() { foreach (var s in surfaces) if (s.renderer) s.renderer.enabled = false; }
    public void Leaf(int index, Vector3 position, Quaternion rotation, Vector2 size, Color color,
        float alpha, float clock, float curl = .22f, Rect? textureArea = null, float dissolve = 0)
    {
        if (alpha <= .002f || index < 0 || index >= surfaces.Count) return;
        var s = surfaces[index]; float seed = index * 1.731f;
        Rect area = textureArea ?? new Rect(0, 0, 1, 1);
        for (int y = 0; y <= Along; y++) for (int x = 0; x <= Across; x++)
        {
            float q = y / (float)Along, u = x / (float)Across, side = u * 2 - 1;
            float envelope = Mathf.Pow(Mathf.Max(0, Mathf.Sin(q * Mathf.PI)), .63f);
            float outline = envelope * (.78f + .13f * Mathf.Sin(q * 8.2f + seed) + .07f * Mathf.Sin(q * 19.7f + seed * 3));
            float bend = Mathf.Sin(q * 4.5f + seed) * envelope * .16f;
            float roll = Mathf.Sin(q * 5.7f - clock * 3.2f + seed) * .14f;
            int n = y * (Across + 1) + x;
            s.vertices[n] = new Vector3((side * outline * .5f + bend) * size.x,
                (q - .5f) * size.y,
                (Mathf.Sin(u * Mathf.PI) * envelope + side * side * roll) * curl * size.x);
            s.uv[n] = new Vector2(area.x + u * area.width, area.y + q * area.height);
        }
        s.transform.SetPositionAndRotation(position, rotation); s.transform.localScale = Vector3.one;
        Apply(s, color, alpha, clock, dissolve);
    }
    public void Stroke(int index, Func<float, Vector3> path, float width, Color color, float alpha, float clock, float depth = .04f)
    {
        if (alpha <= .002f || index < 0 || index >= surfaces.Count) return;
        var s = surfaces[index]; var forward = Face * Vector3.forward;
        for (int y = 0; y <= Along; y++)
        {
            float q = y / (float)Along; Vector3 center = path(q);
            Vector3 tangent = path(Mathf.Min(1, q + .012f)) - path(Mathf.Max(0, q - .012f));
            Vector3 normal = Vector3.Cross(tangent, forward).normalized;
            float envelope = Mathf.Pow(Mathf.Max(0, Mathf.Sin(q * Mathf.PI)), .64f);
            float w = width * envelope * (.83f + .12f * Mathf.Sin(q * 12.3f + index) + .07f * Mathf.Sin(q * 24.1f + index * 2.3f));
            for (int x = 0; x <= Across; x++)
            {
                float u = x / (float)Across, side = u * 2 - 1; int n = y * (Across + 1) + x;
                s.vertices[n] = center + normal * side * w + forward * Mathf.Sin(u * Mathf.PI + q * 1.8f) * envelope * depth;
                s.uv[n] = new Vector2(u, q);
            }
        }
        s.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity); s.transform.localScale = Vector3.one;
        Apply(s, color, alpha, clock, 0);
    }
    void Apply(Surface s, Color color, float alpha, float clock, float dissolve)
    {
        s.mesh.vertices = s.vertices; s.mesh.uv = s.uv; s.mesh.RecalculateBounds();
        color.a = Mathf.Clamp01(alpha); s.material.SetColor("_Color", color);
        s.material.SetFloat("_Age", clock); s.material.SetFloat("_Dissolve", Mathf.Clamp01(dissolve));
        s.renderer.enabled = true;
    }
    public void Dispose()
    {
        foreach (var s in surfaces) { if (s.mesh) UnityEngine.Object.Destroy(s.mesh); if (s.material) UnityEngine.Object.Destroy(s.material); }
        surfaces.Clear();
    }
}
