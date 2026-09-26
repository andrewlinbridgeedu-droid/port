using System;
using UnityEngine;

// Filled, rolled marrow matter for D06. The caller supplies the original cut
// paths and impact envelope; this class owns neither timing nor targets.
public sealed class TowerMarrowRound2
{
    const int Across = 12, Along = 48, Count = 6;
    sealed class Fold
    {
        public Mesh mesh;
        public Material material;
        public MeshRenderer renderer;
        public Transform transform;
        public Vector3[] vertices = new Vector3[(Across + 1) * (Along + 1)];
    }
    readonly Fold[] folds = new Fold[Count];
    public TowerMarrowRound2(Transform owner)
    {
        var shader = Resources.Load<Shader>("Shaders/TowerMarrowRound2");
        var art = Resources.Load<Texture2D>("ChurchSpellArt/claw");
        for (int i = 0; i < Count; i++)
        {
            var go = new GameObject("D06 rolled marrow fold " + i); go.transform.SetParent(owner, false);
            var f = new Fold { mesh = new Mesh(), material = new Material(shader), transform = go.transform };
            f.mesh.MarkDynamic();
            var uv = new Vector2[f.vertices.Length]; var local = new Vector2[uv.Length]; var triangles = new int[Across * Along * 6];
            for (int y = 0; y <= Along; y++) for (int x = 0; x <= Across; x++)
            {
                int n = y * (Across + 1) + x; float q = y / (float)Along, u = x / (float)Across;
                // Sample along ONE painted wound, not the whole three-claw icon.
                uv[n] = new Vector2(.13f + q * .52f + (u - .5f) * .18f, .87f - q * .68f + (u - .5f) * .12f);
                local[n] = new Vector2(u, q);
                if (x == Across || y == Along) continue;
                int k = (y * Across + x) * 6;
                triangles[k] = n; triangles[k + 1] = n + 1; triangles[k + 2] = n + Across + 2;
                triangles[k + 3] = n; triangles[k + 4] = n + Across + 2; triangles[k + 5] = n + Across + 1;
            }
            f.mesh.vertices = f.vertices; f.mesh.uv = uv; f.mesh.uv2 = local; f.mesh.triangles = triangles;
            go.AddComponent<MeshFilter>().sharedMesh = f.mesh; f.renderer = go.AddComponent<MeshRenderer>();
            f.material.mainTexture = art; f.material.SetFloat("_Seed", i * 1.731f);
            f.renderer.sharedMaterial = f.material; f.renderer.enabled = false;
            f.renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; f.renderer.receiveShadows = false;
            folds[i] = f;
        }
    }
    static float Lobe(float q, float center, float radius) { float t = (q - center) / radius; return Mathf.Exp(-t * t); }
    public void Hide() { foreach (var f in folds) if (f.renderer) f.renderer.enabled = false; }
    public void Draw(int index, Func<float, Vector3> path, float width, float roll, Color body, Color veins, float alpha, float age)
    {
        if (alpha <= .002f) return;
        var f = folds[index]; Vector3 forward = TowerSurfaceRound2.Face * Vector3.forward;
        float seed = index * 1.731f;
        for (int y = 0; y <= Along; y++)
        {
            float q = y / (float)Along;
            Vector3 center = path(q);
            Vector3 tangent = path(Mathf.Min(1, q + .009f)) - path(Mathf.Max(0, q - .009f));
            Vector3 sideAxis = Vector3.Cross(tangent, forward).normalized;
            float taper = Mathf.Pow(Mathf.Max(0, Mathf.Sin(q * Mathf.PI)), .66f);
            // Unequal swept barbs, never evenly spaced ribs or a regular saw.
            float edgeA = .70f + .35f * Lobe(q, .19f, .065f) + .54f * Lobe(q, .57f, .09f) + .25f * Lobe(q, .82f, .045f);
            float edgeB = .66f + .44f * Lobe(q, .32f, .09f) + .30f * Lobe(q, .71f, .055f);
            for (int x = 0; x <= Across; x++)
            {
                float u = x / (float)Across, side = u * 2 - 1;
                float outline = side < 0 ? edgeA : edgeB;
                float sweep = side * side * Mathf.Sin(q * 4.3f + seed) * width * .24f;
                float curl = Mathf.Sin(u * Mathf.PI) * (.65f + .35f * Mathf.Sin(q * 5.2f - age * 3.1f + seed));
                f.vertices[y * (Across + 1) + x] = center + sideAxis * (side * width * taper * outline)
                    + tangent.normalized * sweep * taper - forward * (curl * roll * taper + index * .018f);
            }
        }
        f.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity); f.transform.localScale = Vector3.one;
        f.mesh.vertices = f.vertices; f.mesh.RecalculateBounds();
        body.a = Mathf.Clamp01(alpha); f.material.SetColor("_Color", body); f.material.SetColor("_VeinTint", veins);
        f.material.SetFloat("_Age", age); f.renderer.enabled = true;
    }
    public void Dispose()
    {
        foreach (var f in folds) { if (f.mesh) UnityEngine.Object.Destroy(f.mesh); if (f.material) UnityEngine.Object.Destroy(f.material); }
    }
}
