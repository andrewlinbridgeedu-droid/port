using System;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Visual snapshot only; damage and timing remain owned by EnemySignatureSpellVFX.</summary>
internal sealed class IronVaultArmProjectile : IDisposable
{
    readonly SkinnedMeshRenderer source;
    readonly Transform anchor;
    readonly bool wasEnabled;
    Mesh mesh;
    GameObject flight;
    Vector3 departure, impact, anchorOffset;
    Quaternion anchorRotation, outboundRotation = Quaternion.identity;
    bool released, returning;
    public Vector3 Position => flight ? flight.transform.position : source ? source.bounds.center : Vector3.zero;

    IronVaultArmProjectile(SkinnedMeshRenderer renderer, Transform bone)
    { source = renderer; anchor = bone; wasEnabled = renderer.enabled; }

    public static IronVaultArmProjectile Find(Transform actor)
    {
        foreach (var renderer in actor.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (renderer.name != "IronVaultLaunchArm" || !renderer.enabled) continue;
            foreach (var bone in renderer.bones)
                if (bone && bone.name == "Forearm.L") return new IronVaultArmProjectile(renderer, bone);
        }
        Debug.LogWarning("Iron Vault launch arm/Forearm.L missing; using archive spell fallback.", actor);
        return null;
    }

    public bool Release(Vector3 target)
    {
        try
        {
            if (!source || !source.sharedMesh || !anchor) return false;
            // Skin directly into WORLD coordinates. No lossyScale or BakeMesh scale is applied twice.
            var original = source.sharedMesh;
            var vertices = original.vertices;
            var normals = original.normals;
            var weights = original.boneWeights;
            var binds = original.bindposes;
            var bones = source.bones;
            if (vertices.Length == 0 || weights.Length != vertices.Length || binds.Length != bones.Length)
                throw new InvalidOperationException("Launch arm has no readable four-influence skin.");
            var matrices = new Matrix4x4[bones.Length];
            var normalMatrices = new Matrix4x4[bones.Length];
            for (int i = 0; i < bones.Length; i++)
            {
                if (!bones[i]) throw new InvalidOperationException("Launch arm bone is missing.");
                matrices[i] = bones[i].localToWorldMatrix * binds[i];
                normalMatrices[i] = matrices[i].inverse.transpose;
            }
            departure = Vector3.zero;
            for (int i = 0; i < vertices.Length; i++)
            {
                var w = weights[i]; var v = vertices[i];
                vertices[i] = Point(matrices, w, v);
                departure += vertices[i];
                if (normals.Length == vertices.Length) normals[i] = Normal(normalMatrices, w, normals[i]);
            }
            departure /= vertices.Length;
            for (int i = 0; i < vertices.Length; i++) vertices[i] -= departure;
            mesh = UnityEngine.Object.Instantiate(original);
            mesh.name = "Iron Vault arm world-space snapshot";
            mesh.vertices = vertices;
            if (normals.Length == vertices.Length) mesh.normals = normals; else mesh.RecalculateNormals();
            mesh.RecalculateBounds(); mesh.RecalculateTangents();
            flight = new GameObject("Iron Vault flying forearm and palm");
            flight.transform.position = departure; // identity rotation and scale; mesh already in world units
            flight.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = flight.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = source.sharedMaterials;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            anchorOffset = anchor.InverseTransformPoint(departure);
            anchorRotation = anchor.rotation;
            Vector3 palmAxis = source.transform.forward;
            foreach (var bone in bones)
                if (bone && bone.name == "Hand.L") { palmAxis = bone.position - anchor.position; break; }
            if (palmAxis.sqrMagnitude > .00001f && (target - departure).sqrMagnitude > .00001f)
                outboundRotation = Quaternion.FromToRotation(palmAxis, target - departure);
            source.enabled = false;
            released = true;
            Debug.Log($"IRON_VAULT_ARM_RELEASE vertices={vertices.Length} source={departure} target={target}");
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogWarning("Iron Vault arm snapshot failed; using archive spell fallback: " + exception.Message);
            Dispose(); return false;
        }
    }

    static Vector3 Point(Matrix4x4[] m, BoneWeight w, Vector3 v) =>
        m[w.boneIndex0].MultiplyPoint3x4(v) * w.weight0 + m[w.boneIndex1].MultiplyPoint3x4(v) * w.weight1 +
        m[w.boneIndex2].MultiplyPoint3x4(v) * w.weight2 + m[w.boneIndex3].MultiplyPoint3x4(v) * w.weight3;
    static Vector3 Normal(Matrix4x4[] m, BoneWeight w, Vector3 v) =>
        (m[w.boneIndex0].MultiplyVector(v) * w.weight0 + m[w.boneIndex1].MultiplyVector(v) * w.weight1 +
         m[w.boneIndex2].MultiplyVector(v) * w.weight2 + m[w.boneIndex3].MultiplyVector(v) * w.weight3).normalized;

    public void Update(int phase, float progress, Vector3 target)
    {
        if (!released || !flight) return;
        float p = Mathf.Clamp01(progress);
        if (phase == 1)
        {
            flight.transform.position = Vector3.Lerp(departure, target, Mathf.SmoothStep(0, 1, p))
                + Vector3.up * Mathf.Sin(p * Mathf.PI) * .12f;
            flight.transform.rotation = Quaternion.Slerp(Quaternion.identity, outboundRotation, Mathf.Clamp01(p * 3));
        }
        else if (phase == 2)
        {
            if (!returning) { impact = target; returning = true; Debug.Log("IRON_VAULT_ARM_CONTACT position=" + target); }
            float back = Mathf.SmoothStep(0, 1, Mathf.Clamp01((p - .1f) / .85f));
            Vector3 socket = anchor ? anchor.TransformPoint(anchorOffset) : departure;
            flight.transform.position = Vector3.Lerp(impact, socket, back)
                + Vector3.up * Mathf.Sin(back * Mathf.PI) * .18f;
            Quaternion socketRotation = anchor ? anchor.rotation * Quaternion.Inverse(anchorRotation) : Quaternion.identity;
            flight.transform.rotation = Quaternion.Slerp(outboundRotation, socketRotation, back);
            if (p >= .95f && flight.activeSelf) { flight.SetActive(false); Restore(); Debug.Log("IRON_VAULT_ARM_REATTACHED"); }
        }
    }
    void Restore() { if (source) source.enabled = wasEnabled; }
    public void Dispose()
    {
        Restore();
        if (flight) { flight.SetActive(false); UnityEngine.Object.Destroy(flight); }
        if (mesh) UnityEngine.Object.Destroy(mesh);
        flight = null; mesh = null; released = false;
    }
}
