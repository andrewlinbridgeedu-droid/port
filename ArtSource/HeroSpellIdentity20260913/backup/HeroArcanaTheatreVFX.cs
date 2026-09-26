using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Authored hero silhouettes, solid tarot pages and folded curtains.
/// Contact timing belongs to the skill contract; this component adds no damage.</summary>
public sealed class HeroArcanaTheatreVFX : MonoBehaviour
{
    int generation;
    GameObject root;
    HeroSpellVolume volume;
    Batch pages, fabric, smoke;
    readonly List<Mesh> snapshots = new List<Mesh>();
    readonly List<Material> materials = new List<Material>();
    readonly List<Color> materialColors = new List<Color>();
    readonly Transform[] ghosts = new Transform[2];
    Vector3 right, up, forward;
    public IEnumerator Play(string id, Transform actor, Func<Vector3> caster, Func<Vector3> target, Action onContact)
    {
        Clear();
        int run = generation;
        int skill = Parse(id);
        if (skill < 6 || skill > 9 || caster == null || target == null) yield break;
        float contactTime = skill == 7 ? .885f : skill == 8 ? .63f : .705f;
        Shader sprite = Shader.Find("Sprites/Default");
        Shader mistShader = Resources.Load<Shader>("EnemySignature/SignatureSprite");
        Texture2D atlas = Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas");
        if (!sprite || !mistShader || !atlas) { Debug.LogError("HeroArcanaTheatreVFX: missing tarot atlas or shaders."); yield return new WaitForSeconds(contactTime); if (run == generation) onContact?.Invoke(); yield break; }
        root = new GameObject("Hero arcana theatre " + skill);
        volume=new HeroSpellVolume(root.transform,skill,contactTime);
        pages = new Batch(root.transform, sprite, atlas, false, "Tarot original art");
        fabric = new Batch(root.transform, sprite, Texture2D.whiteTexture, false, "Folded stage fabric");
        smoke = new Batch(root.transform, mistShader, Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke"), true, "Organic aftermath");
        Vector3 origin = caster();
        if (skill == 6 && actor != null) CaptureGhosts(actor, origin);
        float time = 0;
        bool contacted = false;
        try
        {
            while (time < 1.9f && generation == run)
            {
                Draw(skill, time, contactTime, caster(), target());
                volume.Sample(time,caster(),target());
                if (!contacted && time >= contactTime)
                {
                    contacted = true; onContact?.Invoke();
                    if (generation != run) yield break;
                }
                yield return null;
                time += Time.deltaTime;
            }
            if (!contacted && generation == run) { contacted = true; onContact?.Invoke(); }
        }
        finally { if (generation == run) Clear(); }
    }
    static int Parse(string id)
    {
        if (string.IsNullOrEmpty(id)) return -1;
        for (int i = 6; i <= 9; i++)
            if (id == i.ToString() || id.EndsWith("0" + i, StringComparison.Ordinal)) return i;
        return -1;
    }
    void CaptureGhosts(Transform actor, Vector3 origin)
    {
        for (int i = 0; i < 2; i++)
        {
            var go = new GameObject("True hero hunting shadow " + i);
            go.transform.SetParent(root.transform, false); go.transform.position = origin;
            ghosts[i] = go.transform;
        }
        foreach (var renderer in actor.GetComponentsInChildren<SkinnedMeshRenderer>())
        {
            if (!renderer.enabled || !renderer.sharedMesh) continue;
            // Procedural blendshape accessories are not the body snapshot.
            if (renderer.name.StartsWith("FoolRibbon", StringComparison.Ordinal)) continue;
            try
            {
                Mesh original = renderer.sharedMesh;
                Vector3[] vertices = original.vertices, normals = original.normals;
                BoneWeight[] weights = original.boneWeights;
                Matrix4x4[] binds = original.bindposes;
                Transform[] bones = renderer.bones;
                // Some imported body renderers include extra unused bones; only
                // bindpose indices are meaningful. Rigid meshes have no weights.
                bool skinned = weights.Length == vertices.Length && binds.Length > 0;
                if (skinned && binds.Length > bones.Length)
                    throw new InvalidOperationException($"Missing bound bones: {renderer.name} binds={binds.Length} bones={bones.Length}");
                Matrix4x4[] matrices = new Matrix4x4[binds.Length], normalMatrices = new Matrix4x4[binds.Length];
                for (int b = 0; b < binds.Length; b++)
                {
                    matrices[b] = bones[b] ? bones[b].localToWorldMatrix * binds[b] : renderer.localToWorldMatrix;
                    normalMatrices[b] = matrices[b].inverse.transpose;
                }
                Matrix4x4 rigid = renderer.localToWorldMatrix, rigidNormal = rigid.inverse.transpose;
                for (int v = 0; v < vertices.Length; v++)
                {
                    vertices[v] = (skinned ? Skin(matrices, weights[v], vertices[v], true) : rigid.MultiplyPoint3x4(vertices[v])) - origin;
                    if (normals.Length == vertices.Length)
                        normals[v] = (skinned ? Skin(normalMatrices, weights[v], normals[v], false) : rigidNormal.MultiplyVector(normals[v])).normalized;
                }
                Mesh mesh = Instantiate(original); mesh.name = "Hero world skin snapshot";
                mesh.vertices = vertices;
                if (normals.Length == vertices.Length) mesh.normals = normals; else mesh.RecalculateNormals();
                mesh.RecalculateBounds(); mesh.RecalculateTangents(); snapshots.Add(mesh);
                for (int i = 0; i < 2; i++)
                {
                    var go = new GameObject(renderer.name + " echo"); go.transform.SetParent(ghosts[i], false);
                    go.AddComponent<MeshFilter>().sharedMesh = mesh;
                    var echo = go.AddComponent<MeshRenderer>(); echo.shadowCastingMode = ShadowCastingMode.Off;
                    var copies = renderer.sharedMaterials;
                    for (int m = 0; m < copies.Length; m++)
                    {
                        if (!copies[m]) continue;
                        var copy = new Material(copies[m]);
                        copy.SetOverrideTag("RenderType", "Transparent");
                        if (copy.HasProperty("_Mode")) copy.SetFloat("_Mode", 2);
                        if (copy.HasProperty("_SrcBlend")) copy.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                        if (copy.HasProperty("_DstBlend")) copy.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                        if (copy.HasProperty("_ZWrite")) copy.SetFloat("_ZWrite", 0);
                        copy.DisableKeyword("_ALPHATEST_ON"); copy.DisableKeyword("_ALPHAPREMULTIPLY_ON"); copy.EnableKeyword("_ALPHABLEND_ON");
                        copy.renderQueue = 3016;
                        Color tint = copy.HasProperty("_Color") ? copy.color : Color.white;
                        tint *= i == 0 ? new Color(.82f, .68f, 1f, 1) : new Color(.52f, .85f, 1f, 1);
                        if(copy.HasProperty("_EmissionColor")){copy.EnableKeyword("_EMISSION");copy.SetColor("_EmissionColor",i==0?new Color(.20f,.06f,.42f):new Color(.04f,.24f,.34f));}
                        materials.Add(copy); materialColors.Add(tint); copies[m] = copy;
                    }
                    echo.sharedMaterials = copies;
                }
            }
            catch (Exception e) { Debug.LogError("HeroArcanaTheatreVFX: hero snapshot failed: " + e.Message); }
        }
        if (snapshots.Count == 0) Debug.LogError("HeroArcanaTheatreVFX: no actual hero skin available for hunting shadows.");
    }
    static Vector3 Skin(Matrix4x4[] matrices, BoneWeight w, Vector3 v, bool point)
    {
        return TransformWeighted(matrices, w.boneIndex0, w.weight0, v, point)
            + TransformWeighted(matrices, w.boneIndex1, w.weight1, v, point)
            + TransformWeighted(matrices, w.boneIndex2, w.weight2, v, point)
            + TransformWeighted(matrices, w.boneIndex3, w.weight3, v, point);
    }
    static Vector3 TransformWeighted(Matrix4x4[] matrices, int index, float weight, Vector3 v, bool point)
    {
        if (weight <= 0) return Vector3.zero;
        return (point ? matrices[index].MultiplyPoint3x4(v) : matrices[index].MultiplyVector(v)) * weight;
    }
    void Draw(int skill, float time, float contact, Vector3 s, Vector3 t)
    {
        Camera camera = Camera.main;
        right = camera ? camera.transform.right : Vector3.right;
        up = camera ? camera.transform.up : Vector3.up;
        forward = camera ? camera.transform.forward : Vector3.forward;
        float attack = Mathf.Clamp01(time / contact);
        float tail = Mathf.Clamp01((time - contact) / (1.3f - contact));
        float alpha = Mathf.Clamp01(time / .14f) * (1 - tail);
        pages.Reset(); fabric.Reset(); smoke.Reset();
        if (skill == 6)
        {
            for (int i = 0; i < 2; i++)
            {
                float p = Mathf.Clamp01((time - i * .10f) / (contact - i * .10f));
                if (ghosts[i])
                {
                    ghosts[i].position = Vector3.Lerp(s, t, Mathf.Pow(p,2.4f))
                        + right * (i == 0 ? -.46f : .46f) * Mathf.Sin(p * Mathf.PI)
                        + up * Mathf.Sin(p * Mathf.PI) * .13f;
                    ghosts[i].rotation = Quaternion.AngleAxis(Mathf.Sin(p * Mathf.PI) * (i == 0 ? -10 : 10), forward);
                }
                for (int j = 0; j < 12; j++)
                {
                    float u = Mathf.Clamp01(p - j * .025f);
                    Vector3 c = Vector3.Lerp(s, t, u) - up * .43f
                        + right * (i == 0 ? -.46f : .46f) * Mathf.Sin(u * Mathf.PI);
                    Puff(c, .39f + N(j) * .27f, new Color(.12f, .075f, .24f, alpha * .11f), j, time);
                }
            }
            for (int i = 0; i < materials.Count; i++)
            { Color color = materialColors[i]; color.a = alpha * .93f; if (materials[i].HasProperty("_Color")) materials[i].color = color; }
        }
        else if (skill == 7)
        {
            // One heavy, face-on original-art blade dominates, then breaks into
            // individual textured pieces only after the actual contact moment.
            if (time < contact)
            {
                float plunge = Mathf.Pow(Mathf.Clamp01((attack - .35f) / .65f),2.7f);
                Vector3 c = t + up * (3.1f * (1 - plunge) + .12f) + right * (.55f * (1 - plunge));
                Card(c, 1.8f, 3.1f, -.85f + plunge * 1.7f, alpha, attack * .4f);
                for (int i = 0; i < 3; i++) Card(c + right * (i - 1) * .25f + forward * (.15f + i * .13f), .45f, .92f, i * .28f - .3f, alpha * .6f, i);
            }
            else for (int i = 0; i < 23; i++)
            {
                Vector3 c = t + right * (N(i + 20) - .5f) * (1 + tail * 2.4f)
                    + up * (.15f + Mathf.Sin(tail * Mathf.PI) * N(i + 3) * 1.4f - tail * .5f)
                    + forward * (N(i + 16) - .5f) * .75f;
                Card(c, .12f + N(i) * .12f, .23f + N(i + 4) * .15f, i + tail * 3, alpha, i);
            }
            for (int i = 0; i < 19; i++)
                Puff(t - up * .27f + right * (N(i) - .5f) * (time < contact ? .5f : 1 + tail * 1.3f)
                    + up * N(i + 6) * tail * .7f, .5f + tail * .4f,
                    new Color(.30f, .20f, .085f, alpha * (time < contact ? .06f : .21f)), i, time);
        }
        else if (skill == 8)
        {
            // Broad folded stage skins peel away in opposite directions. Open
            // central gap shows the enemy as the outer role is overturned.
            for (int i = 0; i < 4; i++)
            {
                float side = i % 2 == 0 ? -1 : 1;
                float peel = Mathf.SmoothStep(0, 1, attack);
                Vector3 top = t + right * side * (1.02f + peel * .96f + tail * .45f) + up * 1.18f + forward * (i / 2) * .3f;
                Vector3 bottom = t + right * side * (.95f + peel * .76f + tail * .55f) - up * 1.0f;
                Drape(top, bottom, .62f, time, i, alpha*.42f*(1-Mathf.SmoothStep(.4f,1f,attack)));
            }
            for (int i = 0; i < 18; i++)
                Puff(t + right * (N(i) > .5f ? 1 : -1) * (.42f + attack * .56f)
                    + up * (N(i + 40) - .5f) * 1.6f, .47f,
                    new Color(.24f, .045f, .13f, alpha * .13f), i, time);
        }
        else
        {
            // A close, offset fan of real pages curls backwards into the caster;
            // this is a book-like motion, never an orbital glyph or ring.
            for (int i = 0; i < 9; i++)
            {
                float rewind = Mathf.Clamp01(Mathf.Pow(attack,2.2f) * 1.4f - i * .03f);
                float angle = -1.12f + i * .17f + rewind * 1.4f;
                Vector3 c = s + right * (.66f + (1 - rewind) * (i * .095f + .25f))
                    + up * (.24f + Mathf.Sin(angle) * .42f) + forward * (.1f + i * .025f);
                Card(c, .38f, .64f, angle * .46f, alpha, angle * 2);
            }
            for (int i = 0; i < 22; i++)
            {
                float u = Mathf.Repeat(N(i) + attack * .65f, 1);
                Vector3 c = s + right * (.64f + (1 - u) * .70f) + up * ((N(i + 8) - .5f) * .7f) + forward * .15f;
                Puff(c, .30f + N(i + 12) * .25f, new Color(.065f, .21f, .26f, alpha * .13f), i, time);
            }
        }
        pages.Upload(); fabric.Upload(); smoke.Upload();
    }
    void Card(Vector3 c, float width, float height, float angle, float alpha, float curl)
    {
        Vector3 x = (right * Mathf.Cos(angle) + up * Mathf.Sin(angle)) * width;
        Vector3 y = (-right * Mathf.Sin(angle) + up * Mathf.Cos(angle)) * height;
        // Crop only the actual upright tarot in tile 1; the atlas has no alpha,
        // so using an entire tile would render a large black square.
        for (int strip = 0; strip < 6; strip++)
        {
            float a = strip / 6f, b = (strip + 1) / 6f;
            Vector3 ca = c + x * (a - .5f) - forward * Mathf.Sin(a * Mathf.PI) * Mathf.Sin(curl) * width * .17f;
            Vector3 cb = c + x * (b - .5f) - forward * Mathf.Sin(b * Mathf.PI) * Mathf.Sin(curl) * width * .17f;
            pages.Quad(ca - y * .5f, cb - y * .5f, cb + y * .5f, ca + y * .5f, new Color(.82f, .76f, .70f, alpha),
                new Rect(Mathf.Lerp(.344f, .396f, a), .814f, (.396f - .344f) / 6f, .111f));
        }
    }
    void Drape(Vector3 top, Vector3 bottom, float width, float time, int seed, float alpha)
    {
        // Broad velvet panels have nine continuous shaded folds across their
        // width, with depth and moving sheen instead of two flat cutout colors.
        for (int row = 0; row < 24; row++)
        for (int band = 0; band < 12; band++)
        {
            float a = row / 24f, b = (row + 1) / 24f;
            float x0 = band / 12f, x1 = (band + 1) / 12f;
            float light = .5f + .5f * Mathf.Cos((band + .5f) / 12f * 19 + a * 2.2f - time * 1.4f + seed);
            float sheen = Mathf.Pow(light, 2.1f);
            var tint = new Color(.14f + sheen * .32f, .018f + sheen * .06f, .065f + sheen * .12f, alpha * .96f);
            fabric.Quad(DrapePoint(top,bottom,width,a,x0,time,seed),DrapePoint(top,bottom,width,b,x0,time,seed),
                DrapePoint(top,bottom,width,b,x1,time,seed),DrapePoint(top,bottom,width,a,x1,time,seed), tint, new Rect(0,0,1,1));
        }
    }
    Vector3 DrapePoint(Vector3 top,Vector3 bottom,float width,float v,float u,float time,int seed)
    {
        float fold = Mathf.Sin(u * 19 + v * 2.2f - time * 1.4f + seed);
        return Vector3.Lerp(top,bottom,v) + right * ((u-.5f)*width*2 + Mathf.Sin(v*4+time*2+seed)*.10f)
            - forward * fold * .19f + up * Mathf.Sin(u*6+v*2+time)*.055f;
    }
    void Puff(Vector3 c, float size, Color tint, int seed, float time)
    {
        tint.a = Mathf.Min(.58f, tint.a * 3f);
        float angle = seed * 2.39f + time * .3f;
        Vector3 x = (right * Mathf.Cos(angle) + up * Mathf.Sin(angle)) * size * .5f;
        Vector3 y = (-right * Mathf.Sin(angle) + up * Mathf.Cos(angle)) * size * .6f;
        smoke.Quad(c - x - y, c + x - y, c + x + y, c - x + y, tint, new Rect(seed % 2 * .5f, seed % 4 / 2 * .5f, .5f, .5f));
    }
    static float N(float seed) { return Mathf.Repeat(Mathf.Sin(seed * 127.1f) * 43758.5453f, 1); }
    public void Clear()
    {
        generation++;
        if(volume!=null){volume.Dispose();volume=null;}
        if (root) { root.SetActive(false); Destroy(root); root = null; }
        if (pages != null) { pages.Dispose(); pages = null; }
        if (fabric != null) { fabric.Dispose(); fabric = null; }
        if (smoke != null) { smoke.Dispose(); smoke = null; }
        foreach (var mesh in snapshots) if (mesh) Destroy(mesh);
        foreach (var material in materials) if (material) Destroy(material);
        snapshots.Clear(); materials.Clear(); materialColors.Clear();
        ghosts[0] = null; ghosts[1] = null;
    }
    void OnDisable() { Clear(); }
    void OnDestroy() { Clear(); }
    sealed class Batch
    {
        readonly Mesh mesh;
        readonly Material material;
        readonly List<Vector3> vertices = new List<Vector3>(1800);
        readonly List<Color> colors = new List<Color>(1800);
        readonly List<Vector2> uv = new List<Vector2>(1800);
        readonly List<int> triangles = new List<int>(2700);
        public Batch(Transform parent, Shader shader, Texture texture, bool mist, string name)
        {
            var go = new GameObject(name); go.transform.SetParent(parent, false);
            mesh = new Mesh { name = name }; mesh.MarkDynamic();
            material = new Material(shader) { name = name, mainTexture = texture, renderQueue = mist ? 3011 : 3015 };
            if (mist) { material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha); material.SetFloat("_Shape", 0); }
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = go.AddComponent<MeshRenderer>(); renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off; renderer.receiveShadows = false;
        }
        public void Reset() { vertices.Clear(); colors.Clear(); uv.Clear(); triangles.Clear(); }
        public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color color, Rect rect)
        {
            int n = vertices.Count; vertices.Add(a); vertices.Add(b); vertices.Add(c); vertices.Add(d);
            for (int i = 0; i < 4; i++) colors.Add(color);
            uv.Add(new Vector2(rect.xMin, rect.yMin)); uv.Add(new Vector2(rect.xMax, rect.yMin)); uv.Add(new Vector2(rect.xMax, rect.yMax)); uv.Add(new Vector2(rect.xMin, rect.yMax));
            triangles.Add(n); triangles.Add(n + 1); triangles.Add(n + 2); triangles.Add(n); triangles.Add(n + 2); triangles.Add(n + 3);
        }
        public void Upload() { mesh.Clear(); mesh.SetVertices(vertices); mesh.SetColors(colors); mesh.SetUVs(0, uv); mesh.SetTriangles(triangles, 0); mesh.RecalculateBounds(); }
        public void Dispose() { UnityEngine.Object.Destroy(mesh); UnityEngine.Object.Destroy(material); }
    }
}
