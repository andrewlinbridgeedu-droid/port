using System;
using System.Collections.Generic;
using UnityEngine;

// The memory leech as a pool of living crude oil (2026-10-12, user on Q8's flat grey blob with grey
// balls: 这个泡泡不好看，要更生动，如同石油一般冒泡起伏，略微蠕动 / 用blender画逼真些). A camera-facing quad
// on the floor under the leech plays a seamless Blender-rendered loop (tools/vfx-spectacle-20260926/
// blender_leech.py, packed by pack_leech.py: black oil, bubbles rising, swelling and popping, the rim
// writhing), sized to the 3D body it hides. The cast rears it up and slaps it down; death sinks it
// away. The 3D body stays, hidden, so anchors, animation events and the glob keep working.
public sealed class OilLeechBody20261012 : MonoBehaviour
{
    [Serializable] sealed class Info { public int frames, columns, rows, width, height; public float[] originPx; public float pxPerUnit, poolRadius, fps; }
    const string Root = "EnemyFlipbook/OilLeech";
    Material material; Mesh mesh; Renderer[] hidden, footprint; Info info; EnemyHandle handle;
    float clock, heaveAge = -1f, heaveRise = .42f, sinkAge = -1f, sinkLength = 1.2f;
    const float Fit = 1f;   // pool radius over the body's half-width

    /// Puts the oil pool on a leech model (MemoryLeechPresentation's object); null without the art.
    public static OilLeechBody20261012 Install(Transform model)
    {
        if (!model) return null;
        var existing = model.GetComponentInChildren<OilLeechBody20261012>(true);
        if (existing) return existing;
        var json = Resources.Load<TextAsset>(Root);
        var atlas = Resources.Load<Texture2D>(Root);
        var shader = Resources.Load<Shader>("EnemyFlipbook/OilLeechFlipbook");
        if (!json || !atlas || !shader || !shader.isSupported) return null;
        var info = JsonUtility.FromJson<Info>(json.text);
        if (info == null || info.frames <= 0 || info.originPx == null || info.originPx.Length < 2 || info.pxPerUnit <= 0f) return null;
        // Every mesh of the body is hidden for good; the ones showing now give the pool its footprint.
        var all = new List<Renderer>(); var shown = new List<Renderer>();
        foreach (var r in model.GetComponentsInChildren<Renderer>(true))
            if (r is SkinnedMeshRenderer || r is MeshRenderer) { all.Add(r); if (r.enabled) shown.Add(r); }
        var go = new GameObject("Leech oil pool");
        go.transform.SetParent(model, false);
        var body = go.AddComponent<OilLeechBody20261012>();
        body.info = info;
        // A pool of radius 1: the frame's pixels in units of the rendered pool's radius.
        float unit = 1f / (info.poolRadius * info.pxPerUnit);
        float ox = info.originPx[0], oy = info.originPx[1];
        body.mesh = new Mesh { name = "Leech oil quad" };
        body.mesh.vertices = new[] {
            new Vector3(-ox * unit, -(info.height - oy) * unit, 0), new Vector3((info.width - ox) * unit, -(info.height - oy) * unit, 0),
            new Vector3(-ox * unit, oy * unit, 0), new Vector3((info.width - ox) * unit, oy * unit, 0) };
        body.mesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.up, Vector2.one };
        body.mesh.triangles = new[] { 0, 2, 1, 2, 3, 1 };
        body.mesh.RecalculateBounds();
        body.material = new Material(shader) { name = "LeechOil" };
        body.material.SetTexture("_MainTex", atlas);
        body.material.SetVector("_Grid", new Vector4(info.columns, info.rows, 0, 0));
        go.AddComponent<MeshFilter>().sharedMesh = body.mesh;
        var surface = go.AddComponent<MeshRenderer>(); surface.sharedMaterial = body.material;
        surface.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; surface.receiveShadows = false;
        foreach (var r in all) r.enabled = false;
        body.hidden = all.ToArray(); body.footprint = shown.ToArray();
        body.clock = (model.GetInstanceID() & 15) * .37f;   // two leeches never bubble in step
        return body;
    }

    /// The cast: it rears up until the spit (riseSeconds), slaps down and wobbles back.
    public void Heave(float riseSeconds) { heaveAge = 0f; heaveRise = Mathf.Max(.1f, riseSeconds); }
    /// Death: it sinks flat and fades over seconds.
    public void Sink(float seconds) { sinkAge = 0f; sinkLength = Mathf.Max(.2f, seconds); }
    public void Restore() { heaveAge = sinkAge = -1f; if (material) material.SetColor("_Color", Color.white); }

    static float Smooth(float u) { u = Mathf.Clamp01(u); return u * u * (3f - 2f * u); }

    // Where the hidden body rests: the floor under it and its widest horizontal half-extent. Its
    // animated bounds take in the expanded death puddle (see EnemyPresenter.TryCalculateRendererBounds),
    // which made the first pool 1.7x too wide and hung it at the hovering body's middle, so this
    // measures the meshes themselves, wherever the body has moved, and stands on the enemy's floor.
    void RestFootprint(out Vector3 ground, out float radius)
    {
        Bounds b = default; bool any = false;
        foreach (var r in footprint)
        {
            if (!r) continue;
            var filter = r is SkinnedMeshRenderer ? null : r.GetComponent<MeshFilter>();
            var m = r is SkinnedMeshRenderer s ? s.sharedMesh : filter ? filter.sharedMesh : null;
            if (!m) continue;
            var lb = m.bounds; var w = r.transform.localToWorldMatrix;
            for (int i = 0; i < 8; i++)
            {
                var corner = lb.center + Vector3.Scale(lb.extents, new Vector3((i & 1) == 0 ? -1 : 1, (i & 2) == 0 ? -1 : 1, (i & 4) == 0 ? -1 : 1));
                var p = w.MultiplyPoint3x4(corner);
                if (!any) { b = new Bounds(p, Vector3.zero); any = true; } else b.Encapsulate(p);
            }
        }
        ground = any ? b.center : transform.parent.position;
        // Its width across the screen: the body lies lengthwise toward the hero, and the length
        // made the pool twice the creature's width.
        radius = any ? b.extents.x * Fit : .8f;
        if (!handle) handle = GetComponentInParent<EnemyHandle>();
        ground.y = handle && handle.EnemyRoot ? handle.EnemyRoot.position.y : any ? b.min.y : ground.y;
    }

    void LateUpdate()
    {
        if (!material || info == null) return;
        clock += Time.deltaTime;
        // Whatever turns the leech's renderers back on (idle presence, hit flashes), the 3D body stays hidden.
        if (hidden != null) foreach (var r in hidden) if (r && r.enabled) r.enabled = false;
        material.SetFloat("_Frame", Mathf.Floor(clock * Mathf.Max(1f, info.fps)) % info.frames);
        float sx = 1f, sy = 1f, alpha = 1f;
        if (heaveAge >= 0f)
        {
            heaveAge += Time.deltaTime;
            if (heaveAge < heaveRise) { float k = Smooth(heaveAge / heaveRise); sy = 1f + .35f * k; sx = 1f - .1f * k; }
            else
            {
                float u = heaveAge - heaveRise, w = Mathf.Exp(-5f * u) * Mathf.Cos(13f * u);
                sy = 1f - .22f * w; sx = 1f + .1f * w;
                if (u > .9f) heaveAge = -1f;
            }
        }
        if (sinkAge >= 0f)
        {
            sinkAge += Time.deltaTime;
            float k = Smooth(sinkAge / sinkLength);
            sy *= 1f - .6f * k; sx *= 1f + .15f * k; alpha = 1f - k;
        }
        material.SetColor("_Color", new Color(1f, 1f, 1f, alpha));
        RestFootprint(out var ground, out var radius);
        transform.position = ground;
        var cam = Camera.main;
        if (cam)
        {
            transform.rotation = cam.transform.rotation;
            // The quad's lower half reaches under the floor; it takes its depth from a point past the
            // front lip, toward the camera, so the marble never cuts it.
            var toCam = cam.transform.position - ground; toCam.y = 0f;
            material.SetVector("_DepthAnchor", ground + toCam.normalized * radius * 1.6f + Vector3.up * .02f);
        }
        var p = transform.parent ? transform.parent.lossyScale : Vector3.one;
        transform.localScale = new Vector3(radius * sx / p.x, radius * sy / p.y, radius / p.z);
    }

    void OnDestroy()
    {
        if (hidden != null) foreach (var r in hidden) if (r) r.enabled = true;
        if (material) Destroy(material);
        if (mesh) Destroy(mesh);
    }
}
