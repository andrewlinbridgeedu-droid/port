using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Three authored porcelain masks, organic soul mist and torn curtains.
/// Presentation calls contact at 0.96 s, once. Cancellation never calls contact.</summary>
public sealed class NamelessDeclarationVFX : MonoBehaviour
{
    const float ContactTime = .96f, EndTime = 1.95f;
    const string MaskPath = "Effects/Fool/NamelessDeclaration/MaskActor";
    int generation;
    GameObject root;
    HeroSpellVolume volume;
    readonly List<Material> ownedMaterials = new List<Material>();
    readonly List<Color> baseColors = new List<Color>();
    readonly List<int> maskIndices = new List<int>();
    readonly Transform[] masks = new Transform[3];
    readonly Vector3[] maskScales = new Vector3[3];
    Batch mist, cloth;
    Vector3 screenRight, screenUp, viewForward;

    public IEnumerator Play(Func<Vector3> caster, Func<Vector3> target, Action onContact)
    {
        Clear();
        int run = generation;
        if (caster == null || target == null) yield break;
        var prefab = Resources.Load<GameObject>(MaskPath);
        var shader = Resources.Load<Shader>("EnemySignature/SignatureSprite");
        if (prefab == null || shader == null)
        {
            Debug.LogError("NamelessDeclarationVFX: required authored mask or sprite shader missing: " + MaskPath);
            yield return new WaitForSeconds(ContactTime);
            if (run == generation) onContact?.Invoke();
            yield break;
        }
        root = new GameObject("Nameless declaration runtime");
        volume=new HeroSpellVolume(root.transform,10,ContactTime);
        mist = new Batch(root.transform, shader, "Organic soul mist", Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke"));
        cloth = new Batch(root.transform, shader, "Memory curtains", null);
        for (int i = 0; i < 3; i++)
        {
            var holder = new GameObject("Porcelain memory " + i);
            holder.transform.SetParent(root.transform, false);
            var actor = Instantiate(prefab, holder.transform);
            var renderers = actor.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0) { Debug.LogError("NamelessDeclarationVFX: MaskActor has no renderers."); Clear(); yield break; }
            Bounds bounds = renderers[0].bounds;
            foreach (var r in renderers) bounds.Encapsulate(r.bounds);
            actor.transform.position -= bounds.center;
            float scale = (i == 0 ? 2.3f : i == 1 ? 1.35f : 1.15f) / Mathf.Max(.01f, bounds.size.y);
            holder.transform.localScale = Vector3.one * scale;
            masks[i] = holder.transform;
            maskScales[i] = holder.transform.localScale;
            foreach (var r in renderers)
            {
                var materials = r.sharedMaterials;
                for (int j = 0; j < materials.Length; j++)
                {
                    if (materials[j] == null) continue;
                    var material = new Material(materials[j]);
                    var granular=Resources.Load<Shader>("EnemySignature/GranularPorcelain");
                    if(granular) { material.shader=granular; material.SetFloat("_Dust",.72f); material.SetColor("_Tint",new Color(1f,.67f,.25f,1f)); }
                    // Preserve imported PBR texture/normal response; only configure
                    // this private instance's fade, never mutate an asset material.
                    material.SetOverrideTag("RenderType", "Transparent");
                    if (material.HasProperty("_Mode")) material.SetFloat("_Mode", 2);
                    if (material.HasProperty("_SrcBlend")) material.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                    if (material.HasProperty("_DstBlend")) material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                    if (material.HasProperty("_ZWrite")) material.SetFloat("_ZWrite", 0);
                    material.DisableKeyword("_ALPHATEST_ON"); material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.EnableKeyword("_ALPHABLEND_ON"); material.renderQueue = 3020 + i;
                    ownedMaterials.Add(material);
                    baseColors.Add(material.HasProperty("_Color") ? material.color : Color.white);
                    maskIndices.Add(i); materials[j] = material;
                }
                r.sharedMaterials = materials;
                r.shadowCastingMode = ShadowCastingMode.Off;
            }
        }
        float elapsed = 0;
        bool contacted = false;
        try
        {
            while (elapsed < EndTime && run == generation)
            {
                Draw(elapsed, caster(), target());
                volume.Sample(elapsed,caster(),target());
                if (!contacted && elapsed >= ContactTime)
                {
                    contacted = true;
                    onContact?.Invoke();
                    if (run != generation) yield break;
                }
                yield return null;
                elapsed += Time.deltaTime;
            }
            // A long frame can cross both contact and end; preserve one contact.
            if (!contacted && run == generation)
            {
                contacted = true;
                onContact?.Invoke();
            }
        }
        finally { if (run == generation) Clear(); }
    }

    void Draw(float time, Vector3 source, Vector3 target)
    {
        Camera camera = Camera.main;
        screenRight = camera != null ? camera.transform.right : Vector3.right;
        screenUp = camera != null ? camera.transform.up : Vector3.up;
        viewForward = camera != null ? camera.transform.forward : Vector3.forward;
        float appear = Mathf.SmoothStep(0, 1, Mathf.Clamp01((time - .21f) / .36f));
        float strike = Mathf.SmoothStep(0, 1, Mathf.Clamp01((time - .75f) / .21f));
        float dissolve = Mathf.Clamp01((time - ContactTime) / (EndTime - ContactTime));
        Vector3 stage = Vector3.Lerp(source, target, .51f) + screenUp * .67f;
        Vector3 center = Vector3.Lerp(stage, target + screenUp * .24f, strike);
        for (int i = 0; i < 3; i++)
        {
            float offset = i == 0 ? 0 : i == 1 ? -.88f : .93f;
            float lag = Mathf.Clamp01((time - .28f - i * .075f) / .30f);
            Vector3 c = center + screenRight * offset * (1 - strike * .65f + dissolve * .45f)
                + screenUp * (i == 0 ? .15f : i == 1 ? -.38f : .43f)
                + viewForward * (i == 0 ? -.18f : .28f + i * .12f);
            c += screenUp * (Mathf.Sin(time * 6.4f + i*2) * .18f + dissolve * .8f)
                + screenRight*Mathf.Sin(time*7+i*2.1f)*(.16f+strike*.34f)
                + viewForward*Mathf.Cos(time*7+i*2.1f)*.35f;
            masks[i].position = c;
            Vector3 face = camera != null ? camera.transform.position - c : -viewForward;
            masks[i].rotation = Quaternion.LookRotation(face, screenUp)
                * Quaternion.Euler(i == 0 ? -7 : i == 1 ? 12 : -11, i == 0 ? -9 : i == 1 ? 24 : -25,
                    (i == 0 ? -6 : i == 1 ? 17 : -14) + Mathf.Sin(time * 2 + i) * 3);
            masks[i].localScale = maskScales[i] * (.88f + .12f * lag) * (1 + dissolve * .05f);
        }
        for (int i = 0; i < ownedMaterials.Count; i++)
        {
            float alpha = Mathf.SmoothStep(0, 1, Mathf.Clamp01((time - .28f - maskIndices[i] * .075f) / .22f))
                * (1 - Mathf.SmoothStep(0, 1, dissolve));
            Color color = baseColors[i]; color.a *= alpha;
            if (ownedMaterials[i].HasProperty("_Color")) ownedMaterials[i].color = color;
            ownedMaterials[i].SetFloat("_Dust",Mathf.Lerp(.64f,1f,Mathf.Clamp01(dissolve*3)));
        }
        mist.Reset(); cloth.Reset();
        float strength = Mathf.Clamp01(time / .25f) * (1 - dissolve);
        // Smoke moves behind and around porcelain edges, never in a dense layer
        // across the masks' facial center or the caster's foreground silhouette.
        for (int i = 0; i < 76; i++)
        {
            float seed = Hash(i + 1);
            float side = i % 2 == 0 ? -1 : 1;
            float drift = Mathf.Repeat(seed + time * (.15f + Hash(i + 8) * .13f), 1);
            Vector3 c = center + screenRight * side * (.64f + Hash(i + 19) * .73f + dissolve * .35f)
                + screenUp * ((drift - .48f) * 2.35f)
                + viewForward * (.24f + Hash(i + 41) * .5f);
            c += screenRight * Mathf.Sin(drift * 7 + i) * .18f;
            float opacity = strength * Mathf.Sin(drift * Mathf.PI) * .48f;
            Color tint = i % 3 == 0 ? new Color(.30f, .065f, .12f, opacity) : new Color(.13f, .065f, .24f, opacity);
            float size = 1.0f + Hash(i + 29) * 1.1f;
            Billboard(mist, c, size, size * (1.1f + seed * .5f), seed * 6 + time * .22f, tint, i % 4);
        }
        for (int ribbon = 0; ribbon < 7; ribbon++)
        {
            float side = ribbon % 2 == 0 ? -1 : 1;
            Vector3 start = center + screenRight * side * (.70f + Hash(ribbon) * .35f) + screenUp * .62f;
            Vector3 end = center + screenRight * side * (.48f + Hash(ribbon + 18) * .35f) - screenUp * (1.1f + Hash(ribbon + 6) * .4f);
            Curtain(start, end, ribbon, time, strength * appear * .08f);
        }
        mist.Upload(); cloth.Upload();
    }

    void Curtain(Vector3 start, Vector3 end, int seed, float time, float alpha)
    {
        Vector3 pa = Vector3.zero, pb = Vector3.zero, pf = Vector3.zero;
        for (int j = 0; j <= 22; j++)
        {
            float u = j / 22f;
            Vector3 c = Vector3.Lerp(start, end, u) + screenRight * Mathf.Sin(u * 8 + seed + time * 3) * .14f
                + viewForward * (.24f + Mathf.Sin(u * 6 + seed - time * 2) * .12f);
            float width = (.10f + Hash(seed + 7) * .11f) * (.25f + Mathf.Sin(u * Mathf.PI) * .75f);
            Vector3 a = c - screenRight * width, b = c + screenRight * width;
            Vector3 fold = c - viewForward * width * .5f;
            if (j > 0)
            {
                cloth.Quad(pa, a, fold, pf, new Color(.13f, .035f, .10f, alpha * .88f));
                cloth.Quad(pf, fold, b, pb, new Color(.34f, .105f, .20f, alpha * .86f));
            }
            pa = a; pb = b; pf = fold;
        }
    }
    void Billboard(Batch batch, Vector3 c, float width, float height, float angle, Color color, int tile = -1)
    {
        Vector3 x = (screenRight * Mathf.Cos(angle) + screenUp * Mathf.Sin(angle)) * width * .5f;
        Vector3 y = (-screenRight * Mathf.Sin(angle) + screenUp * Mathf.Cos(angle)) * height * .5f;
        batch.Quad(c - x - y, c + x - y, c + x + y, c - x + y, color, tile);
    }
    static float Hash(float seed) { return Mathf.Repeat(Mathf.Sin(seed * 127.1f) * 43758.5453f, 1); }
    public void Clear()
    {
        generation++;
        if(volume!=null){volume.Dispose();volume=null;}
        if (root != null) { root.SetActive(false); Destroy(root); root = null; }
        if (mist != null) { mist.Dispose(); mist = null; }
        if (cloth != null) { cloth.Dispose(); cloth = null; }
        foreach (var material in ownedMaterials) if (material != null) Destroy(material);
        ownedMaterials.Clear(); baseColors.Clear(); maskIndices.Clear();
        for (int i = 0; i < masks.Length; i++) masks[i] = null;
    }
    void OnDisable() { Clear(); }
    void OnDestroy() { Clear(); }

    sealed class Batch
    {
        readonly Mesh mesh;
        readonly Material material;
        readonly List<Vector3> vertices = new List<Vector3>(3200);
        readonly List<Color> colors = new List<Color>(3200);
        readonly List<Vector2> uv = new List<Vector2>(3200);
        readonly List<int> triangles = new List<int>(4800);
        public Batch(Transform parent, Shader shader, string name, Texture texture)
        {
            var go = new GameObject(name); go.transform.SetParent(parent, false);
            mesh = new Mesh { name = name }; mesh.MarkDynamic();
            material = new Material(shader) { name = name, renderQueue = texture != null ? 3011 : 3018 };
            material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
            material.SetFloat("_Shape", 0);
            if (texture != null) material.mainTexture = texture;
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = go.AddComponent<MeshRenderer>(); renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off; renderer.receiveShadows = false;
            renderer.lightProbeUsage = LightProbeUsage.Off;
        }
        public void Reset() { vertices.Clear(); colors.Clear(); uv.Clear(); triangles.Clear(); }
        public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color color, int tile = -1)
        {
            int n = vertices.Count;
            vertices.Add(a); vertices.Add(b); vertices.Add(c); vertices.Add(d);
            for (int i = 0; i < 4; i++) colors.Add(color);
            float x = tile < 0 ? 0 : tile % 2 * .5f, y = tile < 0 ? 0 : tile / 2 * .5f, size = tile < 0 ? 1 : .5f;
            uv.Add(new Vector2(x, y)); uv.Add(new Vector2(x + size, y)); uv.Add(new Vector2(x + size, y + size)); uv.Add(new Vector2(x, y + size));
            triangles.Add(n); triangles.Add(n + 1); triangles.Add(n + 2); triangles.Add(n); triangles.Add(n + 2); triangles.Add(n + 3);
        }
        public void Upload() { mesh.Clear(); mesh.SetVertices(vertices); mesh.SetColors(colors); mesh.SetUVs(0, uv); mesh.SetTriangles(triangles, 0); mesh.RecalculateBounds(); }
        public void Dispose() { UnityEngine.Object.Destroy(mesh); UnityEngine.Object.Destroy(material); }
    }
}
