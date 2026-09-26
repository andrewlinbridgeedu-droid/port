using System.Collections.Generic;
using UnityEngine;

// Deterministic world-space wave. Artwork supplies internal veins, never a billboard silhouette.
public sealed class PhoenixWingTrial : MonoBehaviour
{
    sealed class Sheet
    {
        public Mesh mesh;
        public Vector3[] vertices;
        public Transform root;
        public Material material;
        public float lo, hi, layer;
    }
    readonly List<Sheet> sheets = new List<Sheet>();
    readonly List<Transform> sparks = new List<Transform>();
    Mesh shard;
    Material shardMaterial;
    Vector3 origin, target, right, forward;
    Matrix4x4 worldToLocal;
    Quaternion worldRotation;
    const int U = 32, V = 40;
    public const float ContactTime = .72f;
    public float WidthFactor = 1f;
    public Texture2D Art { get; private set; }

    public void Build(Vector3 start, Vector3 end, Texture2D art, Mesh unused)
    {
        Clear();
        Art = art;
        origin = start; target = end;
        forward = end - start; forward.y = 0;
        forward = forward.sqrMagnitude > .0001f ? forward.normalized : Vector3.forward;
        right = Vector3.Cross(Vector3.up, forward);
        worldToLocal = transform.worldToLocalMatrix;
        worldRotation = Quaternion.Inverse(transform.rotation);
        // Adjacent patches share the global-u deformation: no straight fan ribs or patch gaps.
        float[] cuts = { -1, -.56f, -.19f, .28f, .67f, 1 };
        for (int s = 0; s < cuts.Length - 1; s++) AddSheet(cuts[s], cuts[s + 1], 0);
        // Broad, unequal feather strokes overlap in depth, following the additional visual
        // reference. None spans the whole fan; the artwork remains internal surface detail.
        AddSheet(-.95f, -.10f, 1);
        AddSheet(-.33f, .62f, 2);
        AddSheet(.19f, .98f, 3);

        shard = FeatherMesh();
        shardMaterial = new Material(Shader.Find("Mistport/PhoenixWingTrial"));
        shardMaterial.SetTexture("_MainTex", art);
        shardMaterial.SetFloat("_Layer", 4);
        for (int i = 0; i < 56; i++)
        {
            var g = new GameObject("Curled departing feather " + i);
            g.transform.SetParent(transform, false);
            g.AddComponent<MeshFilter>().sharedMesh = shard;
            g.AddComponent<MeshRenderer>().sharedMaterial = shardMaterial;
            sparks.Add(g.transform);
        }
        Sample(0);
    }

    void AddSheet(float lo, float hi, float layer)
    {
        var g = new GameObject(layer == 0 ? "Continuous rainbow curl" : "Overturning feather fold " + layer);
        g.transform.SetParent(transform, false);
        var mesh = new Mesh { name = g.name }; mesh.MarkDynamic();
        var vertices = new Vector3[(U + 1) * (V + 1)];
        var uv = new Vector2[vertices.Length];
        var colors = new Color[vertices.Length];
        var indices = new List<int>(U * V * 6);
        for (int j = 0; j <= V; j++) for (int i = 0; i <= U; i++)
        {
            int n = j * (U + 1) + i;
            float u = i / (float)U, v = j / (float)V;
            uv[n] = new Vector2((Mathf.Lerp(lo, hi, u) + 1) * .5f, v);
            colors[n] = new Color(1, 1, 1, layer == 0 ? 1 : Mathf.Pow(Mathf.Max(0, Mathf.Sin(u * Mathf.PI)), .6f));
            if (i < U && j < V) indices.AddRange(new[] { n, n + U + 1, n + 1, n + 1, n + U + 1, n + U + 2 });
        }
        mesh.vertices = vertices; mesh.uv = uv; mesh.colors = colors; mesh.triangles = indices.ToArray();
        var material = new Material(Shader.Find("Mistport/PhoenixWingTrial"));
        material.SetTexture("_MainTex", Art); material.SetFloat("_Layer", layer);
        g.AddComponent<MeshFilter>().sharedMesh = mesh;
        g.AddComponent<MeshRenderer>().sharedMaterial = material;
        sheets.Add(new Sheet { mesh = mesh, vertices = vertices, root = g.transform, material = material, lo = lo, hi = hi, layer = layer });
    }

    public void Sample(float t)
    {
        float travel = Smooth(.18f, ContactTime, t), opening = Smooth(.04f, .49f, t);
        float post = Mathf.Max(0, t - ContactTime);
        // Preserve the extreme attack/release envelope, distributing expansion over the crest.
        float burst = (1 - Mathf.Exp(-post * 65)) * Mathf.Exp(-post * 8);
        float split = Smooth(.95f, 1.42f, t);
        Vector3 head = Vector3.Lerp(origin, target, travel);
        float span = Mathf.Max(0, WidthFactor) * (.5f + opening * 5.8f);
        float curl = .25f + opening * 2.15f;
        for (int s = 0; s < sheets.Count; s++)
        {
            var a = sheets[s];
            float fade = 1 - Smooth(1.04f + Mathf.Min(s, 4) * .045f, 1.65f + Mathf.Min(s, 4) * .05f, t);
            bool visible = t > .015f && fade > .001f && (a.layer == 0 || opening > .03f);
            a.root.gameObject.SetActive(visible);
            if (!visible) continue;
            a.material.SetFloat("_FxTime", t);
            a.material.SetFloat("_Opacity", fade * Mathf.Clamp01(t / .10f) * (a.layer == 0 ? 1 : .88f));
            a.material.SetFloat("_Flash", burst); a.material.SetFloat("_Erode", split);
            for (int j = 0; j <= V; j++) for (int i = 0; i <= U; i++)
            {
                float u = Mathf.Lerp(a.lo, a.hi, i / (float)U), v = j / (float)V;
                float irregular = Mathf.Sin(u * 8.7f + 1.4f) * .10f + Mathf.Sin(u * 17.1f) * .045f;
                float rim = .82f + .10f * Mathf.Sin(u * 5.3f + .7f) + .06f * Mathf.Sin(u * 13.1f);
                float w = v * rim;
                if (a.layer > 0) w = .22f + w * .76f;
                float crest = Mathf.Pow(Mathf.Max(0, Mathf.Sin(w * Mathf.PI)), 1.5f);
                float y = .08f + Mathf.Sin(w * Mathf.PI) * curl * (.9f - u * u * .25f);
                y += Mathf.Sin(u * 5.2f + t * 5) * w * .13f + irregular * w;
                float z = -Mathf.Cos(u * 1.28f) * w * curl * 1.25f;
                z += Mathf.Sin(u * 4.2f + t * 3) * w * .18f + irregular * w + post * .3f;
                // Upper edge overturns, then unrolls into separate folds at contact.
                float turn = Smooth(.42f, .94f, w);
                y += turn * opening * (.24f + .16f * Mathf.Sin(u * 6.1f + t * 4));
                z += turn * opening * (.32f + .22f * Mathf.Sin(u * 3.7f + .6f));
                y += burst * crest * (.32f + .20f * Mathf.Sin(u * 4.9f + 1));
                z += burst * crest * (.48f + .18f * Mathf.Sin(u * 6.3f));
                float x = Mathf.Sin(u * 1.25f) * span * .53f * (.10f + w * .90f);
                x *= 1 + burst * (.35f + 1.45f * crest);
                // Fill only the curved body, not the root, tips or whole effect bounds.
                float fullness = opening * crest * (1 - split * .70f);
                x *= 1 + fullness * .13f;
                z -= fullness * (.16f + .10f * Mathf.Sin(u * 5.7f + .9f));
                if (a.layer > 0)
                {
                    float fold = Mathf.Sin(v * Mathf.PI);
                    float localWidth = Mathf.Max(0, Mathf.Sin(i / (float)U * Mathf.PI));
                    float thickness = opening * fold * localWidth;
                    y += thickness * (.32f + a.layer * .065f + burst * .38f);
                    z += opening * fold * (.18f + a.layer * .17f) + split * v * .22f;
                    x += Mathf.Sin(v * 3.8f + a.layer) * thickness * span * .049f;
                }
                var world = head + right * x + forward * z + Vector3.up * y;
                a.vertices[j * (U + 1) + i] = worldToLocal.MultiplyPoint3x4(world);
            }
            a.mesh.vertices = a.vertices; a.mesh.RecalculateBounds();
        }
        if (shardMaterial)
        {
            shardMaterial.SetFloat("_FxTime", t); shardMaterial.SetFloat("_Erode", Smooth(1.15f, 1.88f, t));
            shardMaterial.SetFloat("_Opacity", 1); shardMaterial.SetFloat("_Flash", burst);
        }
        for (int i = 0; i < sparks.Count; i++)
        {
            float age = t - .73f - N(i + 34) * .09f;
            var b = sparks[i]; bool visible = age > 0 && age < 1.15f;
            b.gameObject.SetActive(visible);
            if (!visible) continue;
            float x = N(i + 9) * 2 - 1;
            Vector3 position = target + right * x * 1.8f * WidthFactor + Vector3.up * (.28f + N(i + 77) * .45f);
            Vector3 velocity = right * x * (2 + N(i + 42) * 3) * Mathf.Sqrt(Mathf.Max(0, WidthFactor));
            velocity += Vector3.up * (1 + N(i + 17) * 4) + forward * (N(i + 28) * 3 - .2f);
            float flight = .18f * (1 - Mathf.Exp(-age * 8)) + age * .45f;
            position += velocity * flight - Vector3.up * (age * age * 2.3f);
            position += right * Mathf.Sin(age * 7 + i) * age * .16f;
            b.localPosition = worldToLocal.MultiplyPoint3x4(position);
            b.localRotation = worldRotation * Quaternion.Euler(age * 100 + i * 73, i * 19, age * 160);
            b.localScale = Vector3.one * (.2f + N(i + 31) * .65f) * (1 - Mathf.InverseLerp(.6f, 1.15f, age));
        }
    }

    static Mesh FeatherMesh()
    {
        const int count = 12;
        var v = new Vector3[(count + 1) * 2]; var uv = new Vector2[v.Length]; var ix = new List<int>();
        var colors = new Color[v.Length];
        for (int i = 0; i <= count; i++)
        {
            float t = i / (float)count, width = Mathf.Max(0, Mathf.Sin(t * Mathf.PI)) * (.035f + .018f * Mathf.Sin(t * 8));
            var p = new Vector3(Mathf.Sin(t * 3) * .07f, t * .64f, Mathf.Sin(t * 2.4f) * .10f);
            for (int s = 0; s < 2; s++)
            {
                v[i * 2 + s] = p + Vector3.right * (s == 0 ? -width : width);
                uv[i * 2 + s] = new Vector2(.45f + s * .13f, t); colors[i * 2 + s] = Color.white;
            }
            if (i < count) ix.AddRange(new[] { i * 2, i * 2 + 2, i * 2 + 1, i * 2 + 1, i * 2 + 2, i * 2 + 3 });
        }
        var m = new Mesh { name = "Tapered curved feather" };
        m.vertices = v; m.uv = uv; m.colors = colors; m.triangles = ix.ToArray(); m.RecalculateBounds();
        return m;
    }
    static float Smooth(float a, float b, float t) { return Mathf.SmoothStep(0, 1, Mathf.InverseLerp(a, b, t)); }
    static float N(int i) { float n = Mathf.Sin(i * 12.93f) * 43758.54f; return n - Mathf.Floor(n); }
    static void Release(Object value) { if (value) { if (Application.isPlaying) Destroy(value); else DestroyImmediate(value); } }
    void Hide() { foreach (var s in sheets) if (s.root) s.root.gameObject.SetActive(false); foreach (var s in sparks) if (s) s.gameObject.SetActive(false); }
    void Clear()
    {
        foreach (var s in sheets) { if (s.root) { s.root.gameObject.SetActive(false); Release(s.root.gameObject); } Release(s.mesh); Release(s.material); }
        sheets.Clear(); foreach (var s in sparks) if (s) { s.gameObject.SetActive(false); Release(s.gameObject); } sparks.Clear();
        Release(shard); Release(shardMaterial); shard = null; shardMaterial = null;
    }
    void OnDisable() { Hide(); }
    void OnDestroy() { Clear(); }
}
