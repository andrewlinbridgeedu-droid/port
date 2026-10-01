using System;
using System.Collections.Generic;
using UnityEngine;

// Contact sparks and three authored theatre effects; no combat callbacks.
public sealed class CombatTempoVFX : MonoBehaviour
{
    static readonly HashSet<CombatTempoVFX> live = new HashSet<CombatTempoVFX>();
    readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();
    readonly List<Piece> pieces = new List<Piece>();
    HeroPorcelainRound2 mask;
    Vector3 maskScale;
    float age, duration, contact;
    string mode;
    Vector3 start, end;
    sealed class Piece { public Transform node; public Vector3 a, b, size, velocity; public Quaternion rotation; public Material material; public Color baseColor; public float delay, phase; }
    static CombatTempoVFX New(string mode, Vector3 end, float duration) {
        var go = new GameObject("Tempo sample " + mode); var fx = go.AddComponent<CombatTempoVFX>();
        fx.mode = mode; fx.end = end; fx.duration = duration; live.Add(fx); return fx;
    }
    public static void Clear() { foreach (var fx in new List<CombatTempoVFX>(live)) if (fx) { fx.gameObject.SetActive(false); Destroy(fx.gameObject); } live.Clear(); }
    static Color Tone(string kind) => kind == "Hound" ? new Color(1, .35f, .035f) : kind == "Stonejaw" ? new Color(.56f, .43f, .30f) : new Color(.7f, .74f, .8f);
    public static void LightContact(Vector3 target, string kind, bool parried) {
        var fx = New("sparks", target, .32f);
        fx.Sparks(parried ? new Color(.82f, .86f, .9f) : Tone(kind), kind == "Stonejaw" ? 13 : 19, kind == "Stonejaw" ? .085f : .045f);
        if (parried) {
            var source = new GameObject("Metal parry click").AddComponent<AudioSource>(); source.transform.SetParent(fx.transform, false);
            source.clip = Resources.Load<AudioClip>("Audio/Spell/mask_impact"); source.volume = .35f; source.pitch = 1.5f; source.Play();
        }
    }
    public static void HeavyContact(Vector3 target, string kind) {
        var fx = New("sparks", target, .50f); fx.Sparks(Tone(kind), kind == "Stonejaw" ? 34 : 29, .13f);
    }
    public static CombatTempoVFX Telegraph(Vector3 target, string kind, float seconds) {
        target.y = .045f;
        var fx = New("telegraph", target, seconds);
        Vector2[] silhouette = kind == "Hound"
            ? new[] { new Vector2(-.2f, -.2f), new Vector2(-.9f, .25f), new Vector2(-.55f, .9f), new Vector2(-.3f, .48f), new Vector2(.1f, 1.45f), new Vector2(.36f, .6f), new Vector2(.74f, .85f), new Vector2(.97f, .13f), new Vector2(.3f, -.15f) }
            : kind == "Stonejaw"
            ? new[] { new Vector2(-.9f, -.15f), new Vector2(-1.1f, .35f), new Vector2(-.55f, .7f), new Vector2(-.3f, .4f), new Vector2(.05f, 1), new Vector2(.43f, .45f), new Vector2(.78f, .65f), new Vector2(1.15f, -.08f), new Vector2(.34f, -.35f) }
            : new[] { new Vector2(-1.1f, -.13f), new Vector2(-.64f, .02f), new Vector2(-.35f, .27f), new Vector2(.1f, .06f), new Vector2(.9f, .29f), new Vector2(.65f, -.12f), new Vector2(.1f, -.24f), new Vector2(-.4f, -.05f) };
        var vertices = new List<Vector3> { Vector3.zero }; foreach (var p in silhouette) vertices.Add(new Vector3(p.x, 0, p.y));
        var triangles = new List<int>(); for (int i = 0; i < silhouette.Length; i++) { triangles.Add(0); triangles.Add(i + 1); triangles.Add((i + 1) % silhouette.Length + 1); }
        var mesh = new Mesh(); mesh.SetVertices(vertices); mesh.SetTriangles(triangles, 0); mesh.RecalculateNormals(); fx.owned.Add(mesh);
        var piece = fx.MeshPiece("Torn " + kind + " warning", mesh, new Color(.92f, .10f, .075f, .33f));
        piece.node.position = target; piece.size = Vector3.one;
        return fx;
    }
    public static void PlayerSpell(Vector3 source, Vector3 target, string skill, float contact, Transform hero = null) {
        var foreground = target - (Camera.main ? Camera.main.transform.forward : Vector3.forward) * .8f;
        var fx = New(skill, foreground, 1.18f); fx.start = source; fx.contact = contact;
        if (skill == "fool_skill_02") {
            fx.mask = new HeroPorcelainRound2(fx.transform, 1.55f, new Color(.65f, .25f, .84f));
            if (fx.mask.Root) fx.maskScale = fx.mask.Root.localScale;
            fx.mask.EnablePortraitReadability();
            for (int i = 0; i < 2; i++) fx.Ribbon(new Color(.53f, .18f, .76f, .85f), i);
        } else if (skill == "fool_skill_06") {
            if (hero) for (int i = 0; i < 2; i++) fx.Shadow(hero, i);
            if (fx.pieces.Count == 0) for (int i = 0; i < 2; i++) fx.Ribbon(new Color(.19f, .065f, .3f, .8f), i);
        } else if (skill == "fool_skill_07") {
            for (int i = 0; i < 13; i++) fx.Prop(i);
            for (int i = 0; i < 2; i++) fx.Ribbon(i == 0 ? new Color(.5f, .16f, .65f, .75f) : new Color(.1f, .5f, .67f, .7f), i);
        } else {
            var card = fx.Card("Thrown tarot", .32f); card.a = source; card.b = target; card.delay = 0;
        }
    }
    Piece MeshPiece(string name, Mesh mesh, Color color) {
        var go = new GameObject(name); go.transform.SetParent(transform, false); go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var material = new Material(Shader.Find("Sprites/Default")); material.color = color; owned.Add(material);
        var renderer = go.AddComponent<MeshRenderer>(); renderer.sharedMaterial = material;
        renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        var piece = new Piece { node = go.transform, material = material, baseColor = color, rotation = Quaternion.identity, size = Vector3.one, phase = pieces.Count * .83f }; pieces.Add(piece); return piece;
    }
    Mesh ShardMesh(int seed) {
        var mesh = new Mesh(); float k = .5f + (seed % 5) * .12f;
        mesh.vertices = new[] { new Vector3(-.4f, -.2f, 0), new Vector3(.5f, -.15f, .14f), new Vector3(.07f, k, 0), new Vector3(0, 0, -.23f) };
        mesh.triangles = new[] { 0, 1, 2, 0, 3, 1, 1, 3, 2, 2, 3, 0 }; mesh.RecalculateNormals(); owned.Add(mesh); return mesh;
    }
    void Sparks(Color color, int count, float size) {
        for (int i = 0; i < count; i++) {
            var p = MeshPiece("Unequal contact shard", ShardMesh(i), color);
            float a = i * 2.399963f;
            p.a = end; p.node.position = end; p.size = Vector3.one * size * (1 + i % 3 * .27f);
            p.velocity = new Vector3(Mathf.Cos(a) * (1.2f + i % 4 * .3f), .8f + i % 5 * .34f, Mathf.Sin(a) * .9f);
        }
    }
    Piece Card(string name, float size) {
        var mesh = new Mesh(); mesh.vertices = new[] { new Vector3(-.32f, -.48f, 0), new Vector3(.32f, -.46f, 0), new Vector3(.30f, .48f, 0), new Vector3(-.31f, .46f, 0) };
        mesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.one, Vector2.up }; mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 }; mesh.RecalculateNormals(); owned.Add(mesh);
        var p = MeshPiece(name, mesh, new Color(.92f, .82f, .58f)); p.material.mainTexture = Resources.Load<Texture2D>("Effects/Fool/HeavyTarotFace"); p.size = Vector3.one * size; return p;
    }
    void Prop(int i) {
        Piece p;
        if (i % 4 == 0) {
            // Giant tarot is a physical card, never a rectangle of light.
            p = Card("Absurd falling tarot", .68f + i % 3 * .15f);
        } else if (i % 4 == 1) {
            var hat = new GameObject("Falling stage top hat"); hat.transform.SetParent(transform, false);
            var material = new Material(Shader.Find("Standard")); material.color = new Color(.16f, .09f, .23f); owned.Add(material);
            foreach (var part in new[] { (new Vector3(0, 0, 0), new Vector3(.70f, .04f, .70f)), (new Vector3(0, .24f, 0), new Vector3(.42f, .24f, .42f)) }) {
                var g = GameObject.CreatePrimitive(PrimitiveType.Cylinder); Destroy(g.GetComponent<Collider>()); g.transform.SetParent(hat.transform, false); g.transform.localPosition = part.Item1; g.transform.localScale = part.Item2; g.GetComponent<Renderer>().sharedMaterial = material;
            }
            p = new Piece { node = hat.transform, material = material, baseColor = material.color, size = Vector3.one * .7f }; pieces.Add(p);
        } else if (i % 4 == 2) {
            var mesh = new Mesh(); mesh.vertices = new[] { new Vector3(-.05f, -.42f, 0), new Vector3(.02f, -.10f, 0), new Vector3(.19f, .08f, 0), new Vector3(.04f, .4f, 0), new Vector3(-.04f, .42f, 0), new Vector3(.09f, .09f, 0), new Vector3(-.03f, -.07f, 0) }; mesh.triangles = new[] { 0, 1, 6, 1, 2, 6, 2, 5, 6, 2, 3, 5, 3, 4, 5 }; mesh.RecalculateNormals(); owned.Add(mesh);
            p = MeshPiece("Broken clock hand", mesh, new Color(.91f, .67f, .2f));
        } else {
            var mesh = new Mesh(); var v = new List<Vector3>(); var tr = new List<int>();
            for (int j = 0; j <= 18; j++) { float a = Mathf.Lerp(-1.15f, 1.15f, j / 18f); v.Add(new Vector3(Mathf.Cos(a) * .46f, Mathf.Sin(a) * .46f, 0)); v.Add(new Vector3(Mathf.Cos(a) * .22f + .19f, Mathf.Sin(a) * .46f, 0)); if (j > 0) { int k = j * 2; tr.AddRange(new[] { k - 2, k, k - 1, k - 1, k, k + 1 }); } }
            mesh.SetVertices(v); mesh.SetTriangles(tr, 0); mesh.RecalculateNormals(); owned.Add(mesh);
            p = MeshPiece("Torn paper moon", mesh, new Color(.95f, .9f, .73f));
        }
        float angle = i * 2.399963f;
        p.a = end + new Vector3(Mathf.Cos(angle) * .85f, 2.2f + i % 3 * .32f, Mathf.Sin(angle) * .45f);
        p.b = end + new Vector3(Mathf.Cos(angle) * .54f, -.15f, Mathf.Sin(angle) * .30f);
        p.delay = i % 4 * .065f; p.phase = i * .61f;
    }
    void Ribbon(Color color, int index) {
        var mesh = new Mesh(); var v = new List<Vector3>(); var uv = new List<Vector2>(); var tr = new List<int>();
        for (int i = 0; i <= 28; i++) {
            float t = i / 28f, side = index == 0 ? -1 : 1;
            float x = side * (.75f + Mathf.Sin(t * Mathf.PI + index * .2f) * .22f);
            float y = (t - .5f) * 1.95f;
            float width = .12f + Mathf.Sin(t * Mathf.PI) * .26f;
            float fold = Mathf.Sin(t * 19 + index) * .10f;
            v.Add(new Vector3(x - width, y + Mathf.Sin(t * 23) * .035f, fold));
            v.Add(new Vector3(x + width, y + Mathf.Cos(t * 27) * .048f, -fold));
            uv.Add(new Vector2(0,t)); uv.Add(new Vector2(1,t));
            if (i > 0) { int k = i * 2; tr.AddRange(new[] {k-2,k,k-1,k-1,k,k+1}); }
        }
        mesh.SetVertices(v); mesh.SetUVs(0,uv); mesh.SetTriangles(tr,0); mesh.RecalculateNormals(); owned.Add(mesh);
        var p = MeshPiece("Unequal folded theatre silk", mesh, color);
        p.material.mainTexture = Resources.Load<Texture2D>("Effects/Fool/CurtainRift");
        p.a = end; p.b = end; p.size = Vector3.one;
        p.rotation = Camera.main ? Camera.main.transform.rotation : Quaternion.identity; p.phase = index;
    }
    void Shadow(Transform hero, int index) {
        foreach (var skin in hero.GetComponentsInChildren<SkinnedMeshRenderer>(false)) {
            if (!skin.enabled) continue;
            var mesh = new Mesh(); skin.BakeMesh(mesh, false); owned.Add(mesh);
            var p = MeshPiece("Pursuing protagonist shadow " + index, mesh, index == 0 ? new Color(.19f, .07f, .3f, .60f) : new Color(.38f, .12f, .48f, .68f));
            p.rotation = skin.transform.rotation; p.size = skin.transform.lossyScale;
            p.a = skin.transform.position + Vector3.right * (index == 0 ? -.38f : .44f);
            p.b = end - (skin.bounds.center - skin.transform.position);
            var detailed = HeroHuntingEchoMaterial.Create(skin.sharedMaterial, index);
            if (detailed) { owned.Add(detailed); var tone = detailed.color; tone.a = .64f; detailed.color = tone; p.node.GetComponent<Renderer>().sharedMaterial = detailed; p.material = detailed; p.baseColor = tone; } p.delay = index * .18f;
        }
    }
    void Update()
    {
        age += Time.deltaTime;
        if (age >= duration) { Destroy(gameObject); return; }
        float fade = 1 - Mathf.SmoothStep(0, 1, Mathf.InverseLerp(duration - .20f, duration, age));
        if (mask != null && mask.Root) {
            float grow = Mathf.SmoothStep(0, 1, Mathf.Clamp01(age / contact));
            mask.Root.position = end + Vector3.up * .35f;
            mask.Root.rotation = (Camera.main ? Camera.main.transform.rotation : Quaternion.identity) * Quaternion.Euler(0, 180, 0);
            mask.Root.localScale = maskScale * Mathf.Lerp(.2f, 1, grow);
            mask.Sample(age, fade, 1 - fade);
        }
        foreach (var p in pieces) {
            if (!p.node) continue;
            float t = Mathf.Clamp01((age - p.delay) / Mathf.Max(.1f, contact - p.delay));
            if (mode == "sparks") { p.node.position = p.a + p.velocity * age + Vector3.down * 2.5f * age * age; p.node.rotation = Quaternion.Euler(age * 180, p.phase * 120, age * 280); }
            else if (mode == "telegraph") { p.node.localScale = Vector3.one * (.9f + Mathf.Sin(age * 7) * .045f); }
            else if (mode == "fool_skill_07" && !p.node.name.Contains("silk")) { p.node.position = Vector3.Lerp(p.a, p.b, t * t); p.node.rotation = (Camera.main ? Camera.main.transform.rotation : Quaternion.identity) * Quaternion.Euler(age * 117, p.phase * 34, age * 89); }
            else if (p.node.name.Contains("silk")) { p.node.position = end; p.node.rotation = p.rotation; p.node.localScale = p.size * Mathf.SmoothStep(.15f, 1, t) * fade; }
            else { p.node.position = Vector3.Lerp(p.a, p.b, Mathf.SmoothStep(0, 1, t)); p.node.rotation = p.rotation; }
            if (mode != "telegraph" && !p.node.name.Contains("silk")) p.node.localScale = p.size * fade;
            if (p.material) { var color = p.baseColor; color.a = mode == "telegraph" ? .25f + Mathf.Sin(age * 8) * .06f : color.a * fade; p.material.color = color; }
        }
    }
    void OnDestroy() { live.Remove(this); mask?.Dispose(); foreach (var item in owned) if (item) Destroy(item); owned.Clear(); }
}
