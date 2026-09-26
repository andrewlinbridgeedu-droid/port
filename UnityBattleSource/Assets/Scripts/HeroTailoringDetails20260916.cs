using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>Small skinned garment welts traced from the real hero collar and sleeve sections.</summary>
public sealed class HeroTailoringDetails20260916 : MonoBehaviour
{
    [Serializable] sealed class Weight { public string bone; public float weight; }
    [Serializable] sealed class Influence { public Weight[] items; }
    [Serializable] sealed class Probe { public Vector3 position; public Vector2 uv; }
    [Serializable] sealed class Data { public Vector3[] vertices; public Vector3[] normals; public int[] triangles; public Influence[] weights; public Probe[] probes; }
    Mesh ownedMesh;
    Material ownedMaterial;
    GameObject detail;
    public static void Install(GameObject actor)
    {
        if (!actor || actor.GetComponent<HeroTailoringDetails20260916>()) return;
        var c = actor.AddComponent<HeroTailoringDetails20260916>();
        c.Build(actor);
    }
    public static bool ResolveSourceTransform(SkinnedMeshRenderer source,out Matrix4x4 conversion) {
        conversion=Matrix4x4.identity;
        var asset=Resources.Load<TextAsset>("HeroQualitySample/tailoring");
        if(!asset||!source||!source.sharedMesh||!source.sharedMesh.isReadable)return false;
        var data=JsonUtility.FromJson<Data>(asset.text);float error;
        return FindSourceTransform(data.probes,source.sharedMesh.vertices,source.sharedMesh.uv,out conversion,out error)
            && error<=source.sharedMesh.bounds.size.magnitude*.002f;
    }
    static string ShortName(string name) { int i = name.LastIndexOf(':'); return i < 0 ? name : name.Substring(i + 1); }
    void Build(GameObject actor)
    {
        var asset = Resources.Load<TextAsset>("HeroQualitySample/tailoring");
        if (!asset) return;
        var data = JsonUtility.FromJson<Data>(asset.text);
        SkinnedMeshRenderer source = null;
        foreach (var r in actor.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (!r.sharedMesh || r.bones.Length <= 10 || r.name.IndexOf("Ribbon", StringComparison.OrdinalIgnoreCase) >= 0) continue;
            if (r.name == "char1") { source = r; break; }
            foreach (var material in r.sharedMaterials)
                if (material && material.name.Contains("FoolMaterial") && material.mainTexture && material.mainTexture.name == "Meshy_AI_battle_magician_rig_biped_texture_0") source = r;
        }
        if (!source || !source.sharedMesh.isReadable) { Debug.LogWarning("[HeroTailoring] Readable hero skin missing; garment welts skipped."); return; }
        Debug.Log("[HeroTailoring] Body source=" + source.name + "; vertices=" + source.sharedMesh.vertexCount);
        var sourceVertices = source.sharedMesh.vertices;
        Matrix4x4 conversion;
        float error;
        if (!FindSourceTransform(data.probes, sourceVertices, source.sharedMesh.uv, out conversion, out error)) { Debug.LogWarning("[HeroTailoring] Could not recover source transform from UV correspondences: " + source.name); return; }
        // Do not guess when an unrelated hero model is installed later.
        float extent = source.sharedMesh.bounds.size.magnitude;
        if (error > extent * .002f) { Debug.LogWarning("[HeroTailoring] Source geometry mismatch: " + error); return; }
        var verts = new Vector3[data.vertices.Length];
        var normals = new Vector3[verts.Length];
        var weights = new BoneWeight[verts.Length];
        for (int i = 0; i < verts.Length; i++)
        {
            verts[i] = conversion.MultiplyPoint3x4(data.vertices[i]);
            normals[i] = conversion.inverse.transpose.MultiplyVector(data.normals[i]).normalized;
            var ids = new int[4]; var values = new float[4]; int count = 0; float total = 0;
            foreach (var w in data.weights[i].items)
            {
                int found = -1;
                for (int j = 0; j < source.bones.Length; j++) if (source.bones[j] && ShortName(source.bones[j].name) == w.bone) { found = j; break; }
                if (found < 0 || count == 4) continue;
                ids[count] = found; values[count] = w.weight; total += w.weight; count++;
            }
            if (total <= 0) { Debug.LogWarning("[HeroTailoring] Missing garment bone; skipped."); return; }
            weights[i] = new BoneWeight { boneIndex0 = ids[0], boneIndex1 = ids[1], boneIndex2 = ids[2], boneIndex3 = ids[3], weight0 = values[0] / total, weight1 = values[1] / total, weight2 = values[2] / total, weight3 = values[3] / total };
        }
        var tris = (int[])data.triangles.Clone();
        if (conversion.determinant < 0) for (int i = 0; i < tris.Length; i += 3) { int v = tris[i + 1]; tris[i + 1] = tris[i + 2]; tris[i + 2] = v; }
        ownedMesh = new Mesh { name = "Hero traced collar and cuff welts" };
        ownedMesh.vertices = verts; ownedMesh.normals = normals; ownedMesh.triangles = tris;
        ownedMesh.boneWeights = weights; ownedMesh.bindposes = source.sharedMesh.bindposes;
        ownedMesh.RecalculateBounds();
        var shader = Shader.Find("Standard");
        if (!shader) { Destroy(ownedMesh); ownedMesh = null; return; }
        ownedMaterial = new Material(shader) { name = "Hero antique gold garment welts", color = new Color(.32f, .205f, .075f, 1) };
        ownedMaterial.SetFloat("_Metallic", .58f); ownedMaterial.SetFloat("_Glossiness", .39f);
        detail = new GameObject("Hero garment collar and cuff welts");
        detail.transform.SetParent(source.transform, false);
        var target = detail.AddComponent<SkinnedMeshRenderer>();
        target.sharedMesh = ownedMesh; target.sharedMaterial = ownedMaterial;
        target.bones = source.bones; target.rootBone = source.rootBone;
        target.localBounds = source.localBounds;
        target.shadowCastingMode = source.shadowCastingMode; target.receiveShadows = source.receiveShadows;
        target.updateWhenOffscreen = source.updateWhenOffscreen;
        Debug.Log("[HeroTailoring] Installed 3 garment welts, " + verts.Length + " vertices; source match error=" + error);
    }
    static bool FindSourceTransform(Probe[] probes, Vector3[] target, Vector2[] uv, out Matrix4x4 best, out float error)
    {
        best = Matrix4x4.identity; error = float.MaxValue;
        if (uv == null || uv.Length != target.Length) return false;
        var p = new List<Vector3>(); var q = new List<Vector3>();
        foreach (var probe in probes)
        {
            int match = -1; bool ambiguous = false;
            for (int i = 0; i < uv.Length; i++)
            {
                if ((uv[i] - probe.uv).sqrMagnitude > 1e-10f) continue;
                if (match >= 0 && (target[i] - target[match]).sqrMagnitude > 1e-10f) { ambiguous = true; break; }
                match = i;
            }
            if (match >= 0 && !ambiguous) { p.Add(probe.position); q.Add(target[match]); }
        }
        if (p.Count < 8) { Debug.LogWarning("[HeroTailoring] UV matches=" + p.Count); return false; }
        // Four well-separated non-coplanar points recover the actual imported FBX transform.
        // This includes model-pivot translation and pre-rotation; no guessed axis or unit scale.
        int a = 0, b = 1, c = 2, d = 3; float score = -1;
        for (int i = 1; i < p.Count; i++) { float v = (p[i] - p[a]).sqrMagnitude; if (v > score) { score = v; b = i; } }
        score = -1;
        for (int i = 0; i < p.Count; i++) { float v = Vector3.Cross(p[b] - p[a], p[i] - p[a]).sqrMagnitude; if (v > score) { score = v; c = i; } }
        var n = Vector3.Cross(p[b] - p[a], p[c] - p[a]); score = -1;
        for (int i = 0; i < p.Count; i++) { float v = Mathf.Abs(Vector3.Dot(n, p[i] - p[a])); if (v > score) { score = v; d = i; } }
        if (score < 1e-8f) return false;
        var from = Frame(p[a], p[b], p[c], p[d]); var to = Frame(q[a], q[b], q[c], q[d]);
        best = to * from.inverse;
        float sum = 0, maximum = 0;
        for (int i = 0; i < p.Count; i++) { float v = (best.MultiplyPoint3x4(p[i]) - q[i]).magnitude; sum += v * v; maximum = Mathf.Max(maximum, v); }
        // Report the worst residual: one bad correspondence must not be hidden in an average.
        error = maximum;
        Debug.Log("[HeroTailoring] UV correspondences=" + p.Count + "; max residual=" + maximum + "; rms=" + Mathf.Sqrt(sum / p.Count) + "; matrix=" + best);
        return true;
    }
    static Matrix4x4 Frame(Vector3 origin, Vector3 b, Vector3 c, Vector3 d)
    {
        var result = Matrix4x4.identity;
        var x = b - origin; var y = c - origin; var z = d - origin;
        result.SetColumn(0, new Vector4(x.x, x.y, x.z, 0));
        result.SetColumn(1, new Vector4(y.x, y.y, y.z, 0));
        result.SetColumn(2, new Vector4(z.x, z.y, z.z, 0));
        result.SetColumn(3, new Vector4(origin.x, origin.y, origin.z, 1));
        return result;
    }
    void OnDisable() { if (detail) detail.SetActive(false); }
    void OnEnable() { if (detail) detail.SetActive(true); }
    void OnDestroy() { if (detail) Destroy(detail); if (ownedMesh) Destroy(ownedMesh); if (ownedMaterial) Destroy(ownedMaterial); }
}
