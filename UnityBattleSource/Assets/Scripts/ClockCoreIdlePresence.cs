using UnityEngine;

/// Organic micro-motion for the unrigged crimson eye shell. Never moves a root.
/// A private mesh retains the imported shape and all original material details.
[DisallowMultipleComponent]
public sealed class ClockCoreIdlePresence : MonoBehaviour
{
    MeshFilter filter;
    Mesh sourceMesh, liveMesh;
    Vector3[] rest, working, directions;
    float[] sinPhase, cosPhase, sinHalfPhase, cosHalfPhase, weights;
    Renderer shellRenderer;
    MaterialPropertyBlock originalBlock, animatedBlock;
    Color emission;
    bool deformed;
    public int AnimatedVertexCount => rest != null ? rest.Length : 0;
    public float MaximumVertexOffset { get; private set; }

    public void Configure(Transform visual)
    {
        Release();
        if (visual == null) return;
        filter = visual.GetComponentInChildren<MeshFilter>(true);
        if (filter == null || filter.sharedMesh == null) return;
        sourceMesh = filter.sharedMesh;
        if (!sourceMesh.isReadable) { Debug.LogWarning("ClockCore idle requires readable source mesh.", this); return; }
        liveMesh = Instantiate(sourceMesh);
        liveMesh.name = sourceMesh.name + " · living core instance";
        liveMesh.MarkDynamic();
        rest = sourceMesh.vertices;
        working = new Vector3[rest.Length];
        directions = new Vector3[rest.Length];
        sinPhase = new float[rest.Length]; cosPhase = new float[rest.Length];
        sinHalfPhase = new float[rest.Length]; cosHalfPhase = new float[rest.Length]; weights = new float[rest.Length];
        var bounds = sourceMesh.bounds;
        var size = Mathf.Max(bounds.size.x, Mathf.Max(bounds.size.y, bounds.size.z));
        var extent = bounds.extents;
        for (int i = 0; i < rest.Length; i++)
        {
            var radial = rest[i] - bounds.center;
            var unit = new Vector3(radial.x / Mathf.Max(.0001f, extent.x), radial.y / Mathf.Max(.0001f, extent.y), radial.z / Mathf.Max(.0001f, extent.z));
            directions[i] = radial.normalized;
            // Smooth spatial lobes breathe at different phases. This is not
            // uniform model scaling; shell ridges and eye beds settle apart.
            float phase = unit.x * 2.8f + unit.y * 1.7f + unit.z * 2.1f;
            sinPhase[i] = Mathf.Sin(phase); cosPhase[i] = Mathf.Cos(phase);
            sinHalfPhase[i] = Mathf.Sin(phase * .5f); cosHalfPhase[i] = Mathf.Cos(phase * .5f);
            weights[i] = size * .010f * (.35f + .65f * Mathf.Pow(Mathf.Sin(unit.x * 2f + unit.z * 1.4f), 2));
        }
        var animatedBounds = bounds; animatedBounds.Expand(size * .03f); liveMesh.bounds = animatedBounds;
        filter.sharedMesh = liveMesh;
        shellRenderer = filter.GetComponent<Renderer>();
        if (shellRenderer != null && shellRenderer.sharedMaterial != null)
        {
            originalBlock = new MaterialPropertyBlock(); animatedBlock = new MaterialPropertyBlock();
            shellRenderer.GetPropertyBlock(originalBlock);
            emission = shellRenderer.sharedMaterial.GetColor("_EmissionColor");
        }
    }

    public void Evaluate(float time, float intensity)
    {
        if (liveMesh == null || rest == null) return;
        MaximumVertexOffset = 0;
        float s1 = Mathf.Sin(time * 1.35f), c1 = Mathf.Cos(time * 1.35f);
        float s2 = Mathf.Sin(time * .63f), c2 = Mathf.Cos(time * .63f);
        // A contraction pair followed by a long settling interval reads as
        // an organ, not a uniformly wobbling balloon. Spatial lobes keep the
        // eye beds asynchronous while the imported surface stays intact.
        float beatPhase = Mathf.Repeat(time / 4.6f, 1f);
        float beat = Bell(beatPhase, .16f, .085f) + .55f * Bell(beatPhase, .35f, .10f);
        for (int i = 0; i < rest.Length; i++)
        {
            float pulse = (s1 * cosPhase[i] + c1 * sinPhase[i]) * .7f + (s2 * cosHalfPhase[i] - c2 * sinHalfPhase[i]) * .3f;
            float offset = (pulse * .48f - beat * (.5f + .5f * cosHalfPhase[i])) * weights[i] * intensity;
            working[i] = rest[i] + directions[i] * offset;
            MaximumVertexOffset = Mathf.Max(MaximumVertexOffset, Mathf.Abs(offset));
        }
        liveMesh.vertices = working;
        // Bounds were expanded once to include the maximum local motion.
        // Keeping original normals preserves the detailed normal-map shell.
        if (shellRenderer != null && animatedBlock != null)
        {
            shellRenderer.GetPropertyBlock(animatedBlock);
            animatedBlock.SetColor("_EmissionColor", emission * (1f + (.3f * beat + .08f * Mathf.Sin(time * 1.35f)) * intensity));
            shellRenderer.SetPropertyBlock(animatedBlock);
        }
        deformed = true;
    }

    static float Bell(float phase, float center, float width)
    {
        float distance = Mathf.Abs(phase - center) / width;
        return distance >= 1f ? 0f : .5f + .5f * Mathf.Cos(distance * Mathf.PI);
    }

    public void RestorePose()
    {
        if (!deformed) return;
        if (liveMesh != null && rest != null) liveMesh.vertices = rest;
        if (shellRenderer != null && originalBlock != null) shellRenderer.SetPropertyBlock(originalBlock);
        MaximumVertexOffset = 0; deformed = false;
    }

    public void Release()
    {
        RestorePose();
        if (filter != null && liveMesh != null && filter.sharedMesh == liveMesh) filter.sharedMesh = sourceMesh;
        if (liveMesh != null) Destroy(liveMesh);
        filter = null; sourceMesh = null; liveMesh = null;
        rest = null; working = null; directions = null; sinPhase = null; cosPhase = null; sinHalfPhase = null; cosHalfPhase = null; weights = null;
        shellRenderer = null; originalBlock = null; animatedBlock = null;
    }
    void OnDisable() => RestorePose();
    void OnDestroy() => Release();
}
