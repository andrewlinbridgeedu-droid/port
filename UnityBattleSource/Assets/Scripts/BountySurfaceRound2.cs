using System;
using System.Collections.Generic;
using UnityEngine;

// Bounty-only rolled surfaces. Silhouettes come from the mesh, never rectangular decals.
public sealed class BountySurfaceRound2 : MonoBehaviour
{
    public enum Silhouette { Fold, Blade, Water, Thread, Plate, Droplet, Veil }
    const int Along = 44, Across = 8;
    readonly List<Vector3> vertices = new List<Vector3>(10000);
    readonly List<Vector3> normals = new List<Vector3>(10000);
    readonly List<Vector2> uv = new List<Vector2>(10000);
    readonly List<Color> colors = new List<Color>(10000);
    readonly List<int> indices = new List<int>(48000);
    Mesh mesh;
    Material material;
    float clock;
    Vector3 impactPivot;
    float impactScale = 1f;

    public void SetContactExpansion(Vector3 pivot, float scale)
    {
        impactPivot = pivot;
        impactScale = Mathf.Clamp(scale, 1f, 3.4f);
    }

    public void Configure(string species)
    {
        mesh = new Mesh { name = "Bounty folded matter " + species };
        mesh.MarkDynamic();
        material = new Material(Resources.Load<Shader>("Shaders/BountyMatterRound2"));
        string texture = species == "b05" || species == "b10" || species == "b10-vessel" ? "CrimsonSilk"
            : species == "b01" || species == "b08" || species == "b08-echo" ? "Thunder01" : "aurora01";
        material.SetTexture("_MainTex", Resources.Load<Texture2D>(species == "b02" || species == "b09"
            ? "ChurchSpellArt/BindingAuthored/GoldFiligree" : "ChurchSpellArt/BountyEffekseer/Texture/" + texture));
        material.SetFloat("_Fabric", species == "b05" || species == "b10" || species == "b10-vessel" ? 1 : 0);
        material.SetFloat("_Metal", species == "b02" || species == "b09" ? 1 : 0);
        material.SetFloat("_Water", species.StartsWith("b03") ? 1 : 0);
        var filter = gameObject.AddComponent<MeshFilter>(); filter.sharedMesh = mesh;
        var renderer = gameObject.AddComponent<MeshRenderer>(); renderer.sharedMaterial = material;
        renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        renderer.receiveShadows = false;
    }

    public void Begin(float time)
    {
        clock = time;
        impactScale = 1f;
        vertices.Clear(); normals.Clear(); uv.Clear(); colors.Clear(); indices.Clear();
    }

    // side is an orientation hint: project against the curve tangent, then roll the
    // surface about the tangent. Broad camber creates visible front/back folds.
    public void Ribbon(Func<float, Vector3> path, Vector3 side, float width,
        float camber, Color color, float seed, float twist = .5f, int segments = Along,
        Silhouette silhouette = Silhouette.Fold)
    {
        if (color.a <= .002f || width <= .0001f) return;
        path = StraightLines20261003.Flatten(path);
        int first = vertices.Count;
        for (int j = 0; j <= segments; j++)
        {
            float q = j / (float)segments;
            Vector3 p = impactPivot + (path(q) - impactPivot) * impactScale;
            Vector3 tangent = path(Mathf.Min(1, q + .008f)) - path(Mathf.Max(0, q - .008f));
            if (tangent.sqrMagnitude < .000001f) tangent = Vector3.forward;
            tangent.Normalize();
            Vector3 across = Vector3.ProjectOnPlane(side, tangent);
            if (across.sqrMagnitude < .001f) across = Vector3.Cross(tangent, Vector3.right);
            if (across.sqrMagnitude < .001f) across = Vector3.Cross(tangent, Vector3.up);
            across = Quaternion.AngleAxis(Mathf.Sin(q * 4.7f + seed) * twist * 55, tangent) * across.normalized;
            Vector3 normal = Vector3.Cross(tangent, across).normalized;
            float taper = Mathf.Pow(Mathf.Max(0, Mathf.Sin(q * Mathf.PI)), .65f);
            float uneven = .78f + .16f * Mathf.Sin(q * 9.1f + seed) + .08f * Mathf.Sin(q * 22.7f + seed * 1.9f);
            if (silhouette == Silhouette.Blade) {
                float notchA = Mathf.Max(0, 1 - Mathf.Abs(q - .28f) / .035f);
                float notchB = Mathf.Max(0, 1 - Mathf.Abs(q - .66f) / .028f);
                taper = Mathf.SmoothStep(0, 1, q / .06f) * Mathf.SmoothStep(0, 1, (1 - q) / .12f)
                    * (1 - notchA * .35f - notchB * .26f) * (.94f - q * .24f);
                uneven = .84f + .11f * Mathf.Sin(q * 11.4f + seed);
            } else if (silhouette == Silhouette.Water) {
                taper = Mathf.Pow(Mathf.Max(0, Mathf.Sin(q * Mathf.PI)), .82f);
                uneven = .93f + .18f * Mathf.Sin(q * 8.2f + seed) + .10f * Mathf.Sin(q * 22.4f + seed);
            } else if (silhouette == Silhouette.Thread) {
                taper = Mathf.SmoothStep(0, 1, q / .035f) * Mathf.SmoothStep(0, 1, (1 - q) / .035f);
                uneven = .93f + .07f * Mathf.Sin(q * 12.7f + seed);
            } else if (silhouette == Silhouette.Plate) {
                taper = Mathf.SmoothStep(0, 1, q / .075f) * Mathf.SmoothStep(0, 1, (1 - q) / .085f);
                float biteA = Mathf.Max(0, 1 - Mathf.Abs(q - .31f) / .047f);
                float biteB = Mathf.Max(0, 1 - Mathf.Abs(q - .74f) / .037f);
                uneven = .94f + .15f * Mathf.Sin(q * 6.9f + seed)
                    - .34f * biteA - .25f * biteB;
            } else if (silhouette == Silhouette.Droplet) {
                taper = Mathf.Pow(Mathf.Max(0, Mathf.Sin(q * Mathf.PI)), .78f) * (1.38f - q * .68f);
                uneven = .90f + .10f * Mathf.Sin(q * 9.5f + seed);
            } else if (silhouette == Silhouette.Veil) {
                taper = Mathf.SmoothStep(0, 1, q / .065f) * Mathf.SmoothStep(0, 1, (1 - q) / .11f);
                uneven = .78f + .19f * Mathf.Sin(q * 7.3f + seed) + .14f * Mathf.Sin(q * 25.1f + seed);
            }
            float breadth = width * impactScale * taper * uneven;
            for (int k = 0; k <= Across; k++)
            {
                float u = k / (float)Across, s = u * 2 - 1;
                float lip = Mathf.Sin(u * Mathf.PI) * camber + Mathf.Sin(u * Mathf.PI * 2 + q * 2.8f + seed) * camber * .25f;
                float fray = 1 + (silhouette == Silhouette.Veil ? .18f : .08f) * s * Mathf.Sin(q * 31.7f + seed * 3.3f);
                Vector3 v = p + across * (s * breadth * fray) + normal * (lip * breadth);
                Vector3 n = (normal - across * (Mathf.Cos(u * Mathf.PI) * camber)).normalized;
                vertices.Add(transform.InverseTransformPoint(v));
                normals.Add(transform.InverseTransformDirection(n));
                uv.Add(new Vector2(q + seed * .137f, u));
                Color c = color;
                // The authored colour lives in a broad body, with a wandering
                // hot vein *inside* the folded mesh. This is not an extra flat
                // light strip: it follows the same camber, tears and silhouette.
                float veinCenter = .5f + .085f * Mathf.Sin(q * 13.1f + seed * 2.3f);
                float vein = Mathf.Pow(Mathf.Clamp01(1 - Mathf.Abs(u - veinCenter) * 2.85f), 4.2f);
                float crossGrain = .76f + .24f * Mathf.Sin(q * 29.3f + seed + u * 8.7f);
                float heat = vein * crossGrain * (silhouette == Silhouette.Thread ? .29f : .51f);
                Color heart = silhouette == Silhouette.Water ? new Color(.83f, .98f, 1)
                    : silhouette == Silhouette.Veil ? new Color(1, .76f, .82f)
                    : silhouette == Silhouette.Droplet ? new Color(.90f, 1, .64f)
                    : silhouette == Silhouette.Plate ? new Color(1, .90f, .63f)
                    : new Color(1, .97f, .83f);
                c.r = Mathf.Lerp(c.r, heart.r, heat);
                c.g = Mathf.Lerp(c.g, heart.g, heat);
                c.b = Mathf.Lerp(c.b, heart.b, heat);
                c.a *= Mathf.SmoothStep(0, 1, q / .045f) * Mathf.SmoothStep(0, 1, (1 - q) / .055f);
                colors.Add(c);
                if (j == segments || k == Across) continue;
                int a = first + j * (Across + 1) + k;
                indices.Add(a); indices.Add(a + Across + 1); indices.Add(a + 1);
                indices.Add(a + 1); indices.Add(a + Across + 1); indices.Add(a + Across + 2);
            }
        }
    }

    // Tear-shaped, curved spray; deliberately no regular square chip/screen ring.
    public void Spray(Vector3 center, Vector3 right, Vector3 up, Vector3 depth,
        float age, float radius, int count, Color tint, float seed)
    {
        if (age < 0 || age > .52f) return;
        float fade = 1 - Mathf.SmoothStep(0, 1, age / .52f);
        for (int i = 0; i < count; i++)
        {
            float a = seed + i * 2.39996f;
            Vector3 direction = (right * Mathf.Cos(a) + up * (Mathf.Sin(a) * .73f + .19f)
                + depth * Mathf.Sin(a * 1.7f) * .42f).normalized;
            float speed = radius * (1.5f + .9f * Mathf.Sin(i * 7.1f + seed));
            Vector3 tip = center + direction * (.12f + age * speed) - up * (age * age * 1.7f);
            float length = (.09f + (i % 3) * .045f) * fade;
            Color c = tint; c.a *= fade;
            Ribbon(q => tip - direction * ((1 - q) * length) + up * (Mathf.Sin(q * Mathf.PI) * length * .25f),
                right, (.018f + (i % 3) * .007f) * fade, .22f, c, a, .2f, 6);
        }
    }

    // A small irregular closed volume for liquid drops. Unlike a ribbon this
    // keeps its thickness from the front, sides and above as the camera moves.
    public void Glob(Vector3 center, Vector3 radii, Color color, float seed)
    {
        if (color.a <= .002f || radii.x <= .001f) return;
        center = impactPivot + (center - impactPivot) * impactScale;
        radii *= impactScale;
        const int rings = 10, sides = 14;
        int first = vertices.Count;
        for (int j = 0; j <= rings; j++)
        {
            float v = j / (float)rings, latitude = v * Mathf.PI;
            float s = Mathf.Sin(latitude), y = Mathf.Cos(latitude);
            for (int k = 0; k <= sides; k++)
            {
                float u = k / (float)sides, a = u * Mathf.PI * 2;
                float wobble = 1 + .13f * Mathf.Sin(a * 3 + seed)
                    + .10f * Mathf.Sin(a * 5 - v * 5.7f + seed * 2.1f);
                Vector3 radial = new Vector3(Mathf.Cos(a) * s, y, Mathf.Sin(a) * s);
                Vector3 point = center + new Vector3(radial.x * radii.x * wobble,
                    radial.y * radii.y * (.93f + .07f * Mathf.Sin(a * 2 + seed)),
                    radial.z * radii.z * wobble);
                vertices.Add(transform.InverseTransformPoint(point));
                normals.Add(transform.InverseTransformDirection(new Vector3(
                    radial.x / radii.x, radial.y / radii.y, radial.z / radii.z).normalized));
                uv.Add(new Vector2(u * .78f + seed * .031f, v));
                colors.Add(color);
                if (j == rings || k == sides) continue;
                int n = first + j * (sides + 1) + k;
                indices.Add(n); indices.Add(n + sides + 1); indices.Add(n + 1);
                indices.Add(n + 1); indices.Add(n + sides + 1); indices.Add(n + sides + 2);
            }
        }
    }

    public void End(float opacity = 1, float light = 1)
    {
        mesh.Clear();
        mesh.SetVertices(vertices); mesh.SetNormals(normals); mesh.SetUVs(0, uv);
        mesh.SetColors(colors); mesh.SetTriangles(indices, 0); mesh.RecalculateBounds();
        material.SetFloat("_Clock", clock); material.SetFloat("_Opacity", Mathf.Clamp01(opacity));
        material.SetFloat("_Light", light);
    }

    public void Clear() { if (mesh) mesh.Clear(); }
    void OnDisable() { Clear(); }
    void OnDestroy() { if (mesh) Destroy(mesh); if (material) Destroy(material); }
}
