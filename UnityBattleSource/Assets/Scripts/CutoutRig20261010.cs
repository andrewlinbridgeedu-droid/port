using System;
using System.Collections.Generic;
using UnityEngine;

// A painted 2D cutout rig (2026-10-10, the final-boss party: user, of video models: 不用视频生成
// 大模型可以吗 -> skeletal cutouts from the user's part sheets). tools/animation/pack_rig.py packs
// Resources/FinalBossParty/<name>.png + .json: every part with its atlas rect, world size, pivot,
// parent, offset from the parent's pivot, draw order and rest angle. Each part is a quad on its
// own transform under its parent's, so rotating a shoulder carries the elbow and the hand; the
// whole figure faces the camera like the video bodies. Actions are hand-keyed poses on the
// named parts (torso/body, head, armL/R, foreL/R or handL/R, panels, skirt, legs/boots, lantern,
// wings, staff) and move the whole body - lunges toward the boss, dips, leans, a fall to the floor
// - never only an arm (user 2026-10-09: 敌人的动作都要和守卫的转身攻击一样生动).
//
// Video skin (2026-10-14, user: 队友视频你接): with clips in Resources/FinalBossParty/Video
// (<ally>-<action>.png/.json/-idle.png, tools/animation/prepare_party_video_body.py) the parts are
// hidden and one camera-facing quad shows the user's AI video of that action. An action with its
// own clip plays it (the video moves the whole body, so the keyed root motion is dropped, except
// the guard's step in front); one without shows the rest frame moved by the keyed root pose as
// before (诺恩 has no hit / down / revive takes yet). An idle clip loops at rest.
public sealed class CutoutRig20261010 : MonoBehaviour
{
    [Serializable] sealed class PartData { public string name, parent; public float z, rot; public float[] uv, size, pivot, offset; }
    [Serializable] sealed class RigData { public string name; public float height, unit; public bool mirrorPose; public PartData[] parts; }
    const string Root = "FinalBossParty/";

    string kind;
    float height;
    /// The prop hand is on the other side from the poses' (奥黛尔's back view holds the flask on
    /// the right): left and right part names swap and every angle turns the other way.
    bool mirror;
    Material material;
    readonly Dictionary<string, Transform> bones = new Dictionary<string, Transform>();
    readonly Dictionary<string, float> rest = new Dictionary<string, float>();
    readonly Dictionary<string, float> pose = new Dictionary<string, float>();
    readonly List<Mesh> meshes = new List<Mesh>();
    Vector3 home, toward = Vector3.forward;
    string action = "idle"; float age, duration = 1f, idleClock, downHold;
    bool down;
    public bool IsDown => down;
    /// Wing spread added to the wings (deg, Elaia's descent); flap amplitude while idle.
    public float WingSpread, Flap = 6f;
    /// Which way it falls when down: +1 tips to the screen's left, -1 to the right (away from the hero).
    public float FallSide = 1f;
    /// Seconds into the current action, and its length (for callers timing a contact).
    public float ActionAge => age;
    public float Height => height * sizeMul;
    float sizeMul = 1f;
    /// Scales the figure to stand `worldHeight` tall (the rig is packed at its own height).
    public void SetHeight(float worldHeight) { if (worldHeight > .1f) sizeMul = worldHeight / height; }

    [Serializable] sealed class ClipInfo { public int frames, columns, rows, releaseFrame, feetRow, figureHeight, width, height; public bool held; }
    sealed class VideoClip { public ClipInfo info; public Texture2D atlas, rest; }
    const string VideoRoot = "FinalBossParty/Video/";
    static readonly string[] VideoActions = { "attack", "cast", "guard", "hit", "down", "revive", "idle" };
    readonly Dictionary<string, VideoClip> videos = new Dictionary<string, VideoClip>();
    Material videoMaterial; Mesh videoMesh; VideoClip videoShown; Texture2D videoRest; float videoIdleClock;
    /// The video skin is on (some action of this ally has its take).
    public bool HasVideo => videoMaterial != null;
    /// Each take's own pace: seconds to the contact cell, and in all (the cut rig's are too
    /// quick for the videos - a 2.7 s wind-up played in .55 s reads as a twitch).
    static (float contact, float total) VideoTiming(string a) => a switch
    {
        "attack" => (1f, 1.8f), "cast" => (1.2f, 2.5f), "guard" => (.6f, 1.35f), "hit" => (.25f, .65f),
        "down" => (1.4f, 1.4f), "revive" => (.8f, .8f), _ => (1f, 1f),
    };

    void LoadVideo(string ally, int sortingBase)
    {
        foreach (var a in VideoActions)
        {
            var json = Resources.Load<TextAsset>(VideoRoot + ally + "-" + a);
            if (!json) continue;
            var clip = new VideoClip { info = JsonUtility.FromJson<ClipInfo>(json.text),
                atlas = Resources.Load<Texture2D>(VideoRoot + ally + "-" + a), rest = Resources.Load<Texture2D>(VideoRoot + ally + "-" + a + "-idle") };
            if (clip.info != null && clip.info.frames > 0 && clip.info.figureHeight > 0 && clip.atlas && clip.rest) videos[a] = clip;
        }
        var shader = Resources.Load<Shader>("CombatTempo/AIHero/AIHeroAtlas");
        if (videos.Count == 0 || !shader || !shader.isSupported) { videos.Clear(); return; }
        // The rest frame: the idle loop's, else the first take's standing first frame.
        foreach (var a in VideoActions) if (videos.TryGetValue(a, out var c)) { videoRest = c.rest; if (a != "down" && a != "revive") break; }
        foreach (var r in GetComponentsInChildren<MeshRenderer>(true)) r.enabled = false;
        var go = new GameObject("Video body");
        go.transform.SetParent(transform, false);
        videoMesh = new Mesh { name = "Party video quad" };
        videoMesh.vertices = new Vector3[4];
        videoMesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.up, Vector2.one };
        videoMesh.triangles = new[] { 0, 2, 1, 2, 3, 1 };
        videoMaterial = new Material(shader) { name = "PartyVideo " + ally };
        videoMaterial.SetColor("_EchoTint", new Color(1f, .95f, .85f));
        go.AddComponent<MeshFilter>().sharedMesh = videoMesh;
        var surface = go.AddComponent<MeshRenderer>(); surface.sharedMaterial = videoMaterial;
        surface.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; surface.receiveShadows = false;
        surface.sortingOrder = sortingBase;
        ShowVideo(videos.TryGetValue("idle", out var idle) ? idle : null);
        Debug.Log($"PARTY_VIDEO {ally} clips={string.Join(",", videos.Keys)}");
    }

    /// Puts a take (or, null, the rest frame) on the quad, its figure standing `height` tall
    /// with the feet on the rig's root (takes are matted at their own figure height).
    void ShowVideo(VideoClip clip)
    {
        if (clip != null && clip == videoShown) return;
        videoShown = clip;
        var info = clip?.info ?? FirstInfo();
        videoMaterial.SetTexture("_MainTex", clip != null ? clip.atlas : videoRest);
        videoMaterial.SetTexture("_IdleTex", clip != null ? clip.rest : videoRest);
        videoMaterial.SetVector("_Grid", new Vector4(info.columns, info.rows, 0, 0));
        float unit = height / info.figureHeight, half = info.width * .5f;
        float below = info.height - info.feetRow, above = info.feetRow;
        videoMesh.vertices = new[] {
            new Vector3(-half*unit,-below*unit,0), new Vector3(half*unit,-below*unit,0),
            new Vector3(-half*unit,above*unit,0), new Vector3(half*unit,above*unit,0) };
        videoMesh.RecalculateBounds();
    }
    ClipInfo FirstInfo() { foreach (var c in videos.Values) return c.info; return null; }

    /// The video frame for this moment, and whether the keyed root motion still applies.
    bool DriveVideo(float dt)
    {
        videoIdleClock += dt;
        string a = action;
        if (a != "idle" && videos.TryGetValue(a, out var clip))
        {
            ShowVideo(clip);
            var (contact, total) = VideoTiming(a);
            var info = clip.info;
            float frame = age <= contact
                ? info.releaseFrame * Mathf.Clamp01(age / Mathf.Max(.01f, contact))
                : Mathf.Lerp(info.releaseFrame, info.frames - 1, Mathf.Clamp01((age - contact) / Mathf.Max(.01f, total - contact)));
            videoMaterial.SetFloat("_Frame", Mathf.Floor(frame));
            // Straight onto the take's first cell: blending it with the rest frame (another pose)
            // drew a see-through double (party rec2).
            videoMaterial.SetFloat("_IdleBlend", 0f);
            return a == "guard";
        }
        if (down && videos.TryGetValue("down", out var fallen))
        {
            ShowVideo(fallen);
            videoMaterial.SetFloat("_Frame", fallen.info.frames - 1); videoMaterial.SetFloat("_IdleBlend", 0f);
            return false;
        }
        if (!down && videos.TryGetValue("idle", out var idle))
        {
            ShowVideo(idle);
            // The loop plays at the take's own pace (24 fps cells over its source seconds, ~8 s).
            videoMaterial.SetFloat("_Frame", Mathf.Floor(Mathf.Repeat(videoIdleClock / 8.4f, 1f) * idle.info.frames) % idle.info.frames);
            videoMaterial.SetFloat("_IdleBlend", 0f);
            return action != "idle";
        }
        ShowVideo(null);
        videoMaterial.SetFloat("_IdleBlend", 1f);
        return true;
    }

    public static CutoutRig20261010 Create(string name, Vector3 feet, Transform parent = null, int sortingBase = 0)
    {
        var json = Resources.Load<TextAsset>(Root + name);
        var tex = Resources.Load<Texture2D>(Root + name);
        var shader = Resources.Load<Shader>(Root + "CutoutPart20261010");
        if (!json || !tex || !shader) { Debug.LogError("CUTOUT_RIG_MISSING " + name); return null; }
        var data = JsonUtility.FromJson<RigData>(json.text);
        var go = new GameObject("Cutout rig " + name);
        if (parent) go.transform.SetParent(parent, true);
        go.transform.position = feet;
        var rig = go.AddComponent<CutoutRig20261010>();
        rig.kind = name; rig.height = data.height; rig.home = feet; rig.mirror = data.mirrorPose;
        rig.material = new Material(shader) { name = "CutoutRig " + name };
        rig.material.SetTexture("_MainTex", tex);
        // Parents before children (the packer keeps the rig's order, which may not).
        var byName = new Dictionary<string, PartData>();
        foreach (var p in data.parts) byName[p.name] = p;
        void Build(PartData p)
        {
            if (rig.bones.ContainsKey(p.name)) return;
            Transform parentT = go.transform;
            if (!string.IsNullOrEmpty(p.parent) && byName.TryGetValue(p.parent, out var pp)) { Build(pp); parentT = rig.bones[p.parent]; }
            var b = new GameObject(p.name).transform;
            b.SetParent(parentT, false);
            b.localPosition = new Vector3(p.offset[0], p.offset[1], 0f);
            b.localRotation = Quaternion.Euler(0f, 0f, p.rot);
            float w = p.size[0], h = p.size[1], px = p.pivot[0], py = p.pivot[1];
            var m = new Mesh { name = "CutoutPart " + p.name };
            m.vertices = new[] { new Vector3(-px * w, -py * h, 0), new Vector3((1 - px) * w, -py * h, 0), new Vector3(-px * w, (1 - py) * h, 0), new Vector3((1 - px) * w, (1 - py) * h, 0) };
            m.uv = new[] { new Vector2(p.uv[0], p.uv[1]), new Vector2(p.uv[2], p.uv[1]), new Vector2(p.uv[0], p.uv[3]), new Vector2(p.uv[2], p.uv[3]) };
            m.triangles = new[] { 0, 2, 1, 2, 3, 1 }; m.RecalculateBounds();
            rig.meshes.Add(m);
            b.gameObject.AddComponent<MeshFilter>().sharedMesh = m;
            var r = b.gameObject.AddComponent<MeshRenderer>(); r.sharedMaterial = rig.material;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
            r.sortingOrder = sortingBase + Mathf.RoundToInt(p.z * 10f);
            rig.bones[p.name] = b; rig.rest[p.name] = p.rot;
        }
        foreach (var p in data.parts) Build(p);
        rig.idleClock = UnityEngine.Random.value * 10f;
        rig.LoadVideo(name.Replace("_back", ""), sortingBase);
        return rig;
    }

    /// The direction it lunges in (toward the boss, on the floor).
    public void Face(Vector3 target)
    {
        var d = target - home; d.y = 0f;
        if (d.sqrMagnitude > 1e-4f) toward = d.normalized;
    }

    /// attack, cast, guard, hit, down, revive; idle returns to rest.
    public void Play(string next)
    {
        if (down && next != "revive" && next != "down") return;
        action = next; age = 0f;
        duration = next switch { "attack" => 1f, "cast" => 1.3f, "guard" => 1f, "hit" => .5f, "down" => 1f, "revive" => .9f, _ => 1f };
        if (videos.ContainsKey(next)) duration = VideoTiming(next).total;
        if (next == "down") down = true;
        if (next == "revive") down = false;
    }

    /// Seconds from the start of an action to its contact (the throw leaves, the lantern lands).
    public static float ContactOf(string next) => next switch { "attack" => .55f, "cast" => .6f, "guard" => .5f, _ => 0f };

    void OnDestroy()
    {
        if (material) Destroy(material);
        foreach (var m in meshes) if (m) Destroy(m);
        if (videoMaterial) Destroy(videoMaterial);
        if (videoMesh) Destroy(videoMesh);
    }

    static float Smooth(float u) { u = Mathf.Clamp01(u); return u * u * (3f - 2f * u); }
    /// A keyed curve: pairs (time 0..1, value), eased between keys.
    static float K(float u, params float[] kv)
    {
        if (u <= kv[0]) return kv[1];
        for (int i = 2; i < kv.Length; i += 2)
            if (u <= kv[i]) return Mathf.Lerp(kv[i - 1], kv[i + 1], Smooth((u - kv[i - 2]) / Mathf.Max(1e-4f, kv[i] - kv[i - 2])));
        return kv[kv.Length - 1];
    }

    void Set(string part, float deg)
    {
        if (mirror)
        {
            part = part.EndsWith("L") ? part.Substring(0, part.Length - 1) + "R" : part.EndsWith("R") ? part.Substring(0, part.Length - 1) + "L" : part;
            deg = -deg;
        }
        if (bones.ContainsKey(part)) pose[part] = (pose.TryGetValue(part, out var v) ? v : 0f) + deg;
    }

    struct RootPose { public float lunge, dy, sy, rot, flash, alpha; }

    void Idle(float t, float w)
    {
        float s = Mathf.Sin(t * 2f * Mathf.PI / 3.2f), c = Mathf.Sin(t * 2f * Mathf.PI / 3.2f + 1.1f);
        Set("torso", 1.2f * s * w); Set("body", .8f * s * w); Set("head", -1.5f * c * w);
        Set("armL", 2.5f * c * w); Set("armR", -2.5f * s * w); Set("foreL", -3f * s * w); Set("foreR", 3f * c * w);
        Set("handL", -2f * s * w); Set("handR", 2f * c * w);
        Set("panelL", 2f * c * w); Set("panelR", -2f * c * w); Set("skirt", 1f * s * w);
        Set("lantern", 5f * Mathf.Sin(t * 2.6f) * w); Set("staff", 1f * s * w);
        Set("wingL", (Flap * Mathf.Sin(t * 1.9f) + WingSpread)); Set("wingR", -(Flap * Mathf.Sin(t * 1.9f) + WingSpread));
    }

    RootPose Act(string a, float u)
    {
        var r = new RootPose { sy = 1f, alpha = 1f };
        bool lantern = bones.ContainsKey("lantern");
        switch (a)
        {
            case "attack" when lantern:
                // 诺恩 smashes his lantern down: raises it over his head with the body leaning back,
                // then lunges a step toward the boss and brings it down across, crouching into it.
                Set("armR", K(u, 0, 0, .4f, 165f, .55f, -25f, .8f, -10f, 1, 0)); Set("handR", K(u, 0, 0, .4f, 20f, .55f, -20f, 1, 0));
                Set("lantern", K(u, 0, 0, .4f, -40f, .5f, 30f, .6f, 60f, .8f, -15f, 1, 0));
                Set("torso", K(u, 0, 0, .4f, 8f, .55f, -14f, .85f, -4f, 1, 0)); Set("head", K(u, 0, 0, .4f, 4f, .55f, -6f, 1, 0));
                Set("armL", K(u, 0, 0, .4f, -25f, .55f, 20f, 1, 0));
                Set("legL", K(u, 0, 0, .5f, -10f, .7f, 5f, 1, 0)); Set("legR", K(u, 0, 0, .5f, 8f, 1, 0));
                Set("panelL", K(u, 0, 0, .45f, -6f, .6f, 12f, 1, 0)); Set("panelR", K(u, 0, 0, .45f, 6f, .6f, -10f, 1, 0));
                r.lunge = K(u, 0, 0, .4f, -.12f, .55f, .7f, .85f, .2f, 1, 0);
                r.dy = K(u, 0, 0, .4f, .03f, .55f, -.05f, .7f, 0, 1, 0); r.sy = K(u, 0, 1, .4f, 1.02f, .55f, .93f, .7f, 1, 1, 1);
                break;
            case "attack":
                // 奥黛尔 throws a vial: winds the flask arm out and up, leaning away, then steps in and
                // whips it across her body.
                Set("armL", K(u, 0, 0, .38f, -70f, .55f, 35f, .75f, 15f, 1, 0)); Set("foreL", K(u, 0, 0, .38f, 35f, .55f, -45f, .8f, -10f, 1, 0));
                Set("torso", K(u, 0, 0, .38f, 9f, .55f, -11f, .85f, -3f, 1, 0)); Set("head", K(u, 0, 0, .38f, 5f, .55f, -6f, 1, 0));
                Set("armR", K(u, 0, 0, .38f, 18f, .55f, -12f, 1, 0));
                Set("bootL", K(u, 0, 0, .45f, -8f, .6f, 4f, 1, 0)); Set("bootR", K(u, 0, 0, .45f, 6f, .6f, -3f, 1, 0));
                Set("panelL", K(u, 0, 0, .4f, -6f, .58f, 10f, 1, 0)); Set("panelR", K(u, 0, 0, .4f, -4f, .58f, 8f, 1, 0)); Set("skirt", K(u, 0, 0, .58f, 4f, 1, 0));
                r.lunge = K(u, 0, 0, .38f, -.1f, .55f, .5f, .8f, .15f, 1, 0);
                r.dy = K(u, 0, 0, .38f, -.03f, .5f, .04f, .6f, 0, 1, 0); r.sy = K(u, 0, 1, .38f, .95f, .5f, 1.04f, .6f, 1, 1, 1);
                break;
            case "cast":
                // 奥黛尔's mend: dips, then rises lifting the flask over her head, the other hand open.
                Set("armL", K(u, 0, 0, .25f, 10f, .5f, -95f, .85f, -80f, 1, 0)); Set("foreL", K(u, 0, 0, .25f, -10f, .5f, 20f, 1, 0));
                Set("armR", K(u, 0, 0, .25f, -10f, .5f, 75f, .85f, 60f, 1, 0)); Set("foreR", K(u, 0, 0, .5f, -35f, 1, 0));
                Set("torso", K(u, 0, 0, .25f, 4f, .5f, -3f, 1, 0)); Set("head", K(u, 0, 0, .5f, -8f, 1, 0));
                Set("panelL", K(u, 0, 0, .5f, -10f, 1, 0)); Set("panelR", K(u, 0, 0, .5f, 10f, 1, 0)); Set("skirt", K(u, 0, 0, .5f, 3f, 1, 0));
                r.dy = K(u, 0, 0, .25f, -.05f, .5f, .07f, .8f, .03f, 1, 0); r.sy = K(u, 0, 1, .25f, .94f, .5f, 1.04f, 1, 1);
                break;
            case "guard":
                // 诺恩 steps in front of the one under attack, lantern raised before him, coat spread,
                // braces as the blow lands and is pushed back half a step.
                Set("armR", K(u, 0, 0, .3f, 110f, .7f, 100f, 1, 0)); Set("handR", K(u, 0, 0, .3f, -25f, 1, 0)); Set("lantern", K(u, 0, 0, .3f, 30f, .5f, -10f, 1, 0));
                Set("armL", K(u, 0, 0, .3f, -90f, .7f, -80f, 1, 0));
                Set("panelL", K(u, 0, 0, .3f, -12f, .7f, -8f, 1, 0)); Set("panelR", K(u, 0, 0, .3f, 12f, .7f, 8f, 1, 0));
                Set("torso", K(u, 0, 0, .48f, 0, .55f, 6f, 1, 0)); Set("legL", K(u, 0, 0, .3f, -8f, 1, 0)); Set("legR", K(u, 0, 0, .3f, 8f, 1, 0));
                r.lunge = K(u, 0, 0, .3f, .55f, .5f, .6f, .58f, .45f, .8f, .3f, 1, 0);
                r.sy = K(u, 0, 1, .46f, 1, .53f, .9f, .7f, 1, 1, 1); r.flash = K(u, 0, 0, .5f, 0, .53f, .35f, .7f, 0, 1, 0);
                break;
            case "hit":
                Set("torso", K(u, 0, 0, .15f, -12f, 1, 0)); Set("body", K(u, 0, 0, .15f, -8f, 1, 0)); Set("head", K(u, 0, 0, .15f, 10f, .6f, 0, 1, 0));
                Set("armL", K(u, 0, 0, .15f, -25f, .6f, 0, 1, 0)); Set("armR", K(u, 0, 0, .15f, 25f, .6f, 0, 1, 0));
                Set("panelL", K(u, 0, 0, .2f, 8f, 1, 0)); Set("panelR", K(u, 0, 0, .2f, 8f, 1, 0));
                r.lunge = K(u, 0, 0, .15f, -.25f, 1, 0); r.dy = K(u, 0, 0, .15f, -.02f, 1, 0); r.flash = K(u, 0, .9f, .35f, 0, 1, 0);
                break;
            case "down":
                // Seen from behind it slumps where it stands - knees give, sinks, leaning a little
                // outward - rather than tipping over out of the frame. Only the whole figure moves:
                // a part turned inside the squashed figure shears (rig5/6 read as lying flat).
                Set("armL", K(u, 0, 0, 1, 8f)); Set("armR", K(u, 0, 0, 1, -8f));
                r.rot = K(u, 0, 0, .3f, -5f, .75f, 14f, .85f, 11f, 1, 12f); r.sy = K(u, 0, 1, .3f, .86f, .75f, .55f, .85f, .6f, 1, .58f);
                r.alpha = K(u, 0, 1, 1, .72f); r.flash = K(u, 0, .6f, .25f, 0, 1, 0);
                break;
            case "revive":
                Set("armL", K(u, 0, 8f, 1, 0)); Set("armR", K(u, 0, -8f, 1, 0));
                r.rot = K(u, 0, 12f, .6f, -4f, 1, 0); r.sy = K(u, 0, .58f, .6f, .95f, .8f, 1.04f, 1, 1); r.alpha = K(u, 0, .72f, .5f, 1, 1, 1);
                r.flash = K(u, 0, .4f, .3f, .6f, 1, 0);
                break;
        }
        return r;
    }

    void LateUpdate()
    {
        float dt = Time.deltaTime;
        idleClock += dt;
        pose.Clear();
        var r = new RootPose { sy = 1f, alpha = down ? .72f : 1f };
        if (action != "idle")
        {
            age += dt;
            float u = Mathf.Clamp01(age / duration);
            // Ease in from rest over the first frames, out over the last ones (down holds its end).
            float w = action == "down" || action == "revive" ? 1f : Mathf.Min(Smooth(age / .08f), 1f - Smooth((age - (duration - .12f)) / .12f));
            Idle(idleClock, 1f - w);
            var a = Act(action, u);
            if (action == "down" || action == "revive") r = a;
            else { r.lunge = a.lunge * w; r.dy = a.dy * w; r.sy = Mathf.Lerp(1f, a.sy, w); r.flash = a.flash; r.rot = a.rot * w; }
            if (age >= duration && action != "down") action = "idle";
            if (age >= duration && action == "down") Act("down", 1f);
        }
        else Idle(idleClock, down ? 0f : 1f);
        if (action == "idle" && down) { var a = Act("down", 1f); r = a; }
        if (videoMaterial && !DriveVideo(dt))
        {
            // The take moves the body itself; a fallen take keeps the dimmed look of the fallen.
            r = new RootPose { sy = 1f, alpha = down ? .72f : 1f, flash = action == "hit" ? Mathf.Clamp01(1f - age / .35f) * .6f : 0f };
        }
        foreach (var kv in bones)
            kv.Value.localRotation = Quaternion.Euler(0f, 0f, rest[kv.Key] + (pose.TryGetValue(kv.Key, out var v) ? v : 0f));
        var cam = Camera.main;
        float hh = height * sizeMul;
        transform.position = home + toward * (r.lunge * hh * .4f) + Vector3.up * (r.dy * hh);
        if (cam) transform.rotation = cam.transform.rotation * Quaternion.Euler(0f, 0f, r.rot * (action == "down" || action == "revive" || down ? FallSide : 1f));
        float breathe = action == "idle" && !down ? 1f + .006f * Mathf.Sin(idleClock * 2f * Mathf.PI / 3.2f) : 1f;
        // A squash in an action keeps the area (wider as it compresses); slumped down it only
        // sinks - widening then read as lying flat (rig4).
        bool slump = action == "down" || action == "revive" || down;
        float sx = slump ? 1f + .12f * (1f - r.sy) : 1f / Mathf.Sqrt(r.sy);
        transform.localScale = new Vector3(sizeMul * sx, sizeMul * r.sy * breathe, sizeMul);
        material.SetFloat("_Flash", Mathf.Clamp01(r.flash));
        material.SetColor("_Color", new Color(1f, 1f, 1f, r.alpha));
        if (videoMaterial)
        {
            // A light warm flash only, and the fallen darkened, never see-through: on the video
            // body both read as a white ghost on the bright marble (party rec1).
            videoMaterial.SetFloat("_EchoMix", Mathf.Clamp01(r.flash) * .3f);
            float dim = Mathf.Clamp01((1f - r.alpha) / .28f);
            videoMaterial.SetColor("_Color", Color.Lerp(Color.white, new Color(.7f, .7f, .76f, 1f), dim));
        }
    }
}
