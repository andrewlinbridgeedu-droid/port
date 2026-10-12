using System;
using System.Collections.Generic;
using UnityEngine;

// The boss Sevian drawn from his AI-animated illustration instead of the 3D Meshy body
// (2026-10-09 pilot, user: 拿瑟维安试点吧 / 先做一个吧). Same recipe as AIHeroAnimatedBody: a
// camera-facing quad at his feet showing one cell of a 48-frame atlas matted from the video.
// Clips come from Resources/CombatTempo/SevianVideo/<name>.json/.png/-idle.png, each built by
// tools/animation/prepare_sevian_video_body.py with its own figure height:
//   strike (required; 2026-10-10 the whole-body sweep - turn, sink, side-on thrust, sweep across
//   with the coat flaring, back), sign / charge / hit (optional moves), idle (optional rest loop).
// Without an idle clip he rests on the strike's first frame with a slow breath. The hit shake
// moves the quad because it hangs under handle.Model. The 3D body stays in place, hidden, so
// anchors, bounds, animator events and the retreat keep working. --sevian-3d restores it.
public sealed class SevianVideoBody20261009 : MonoBehaviour
{
    [Serializable] sealed class Info { public int frames, columns, rows; public float releaseFrame; public int feetRow, figureHeight, width, height; public float[] hand; }
    sealed class Clip { public string name; public Info info; public Texture2D atlas, rest; }
    const string Root = "CombatTempo/SevianVideo/";
    static readonly string[] Optional = { "sign", "charge", "hit", "idle" };
    const float IdleLoopSeconds = 6f;
    public static bool Enabled => Array.IndexOf(Environment.GetCommandLineArgs(), "--sevian-3d") < 0;

    Material material; Mesh mesh; Renderer[] hidden;
    readonly Dictionary<string, Clip> clips = new Dictionary<string, Clip>();
    Clip playing, shown;
    int frameShown;
    float age = -1f, contact = 1f, recover = 1.3f, breath, height = 2.88f, restAge;
    Vector3 home;
    public bool Acting => age >= 0f;
    public bool Has(string clip) => clips.ContainsKey(clip);
    /// Extra size (the party fight shows him smaller and further away, 2026-10-10).
    public float SizeMul = 1f;
    /// How tall he stands on screen (world units), for effects aimed at his chest.
    public float FigureHeight => height * SizeMul;
    /// Where the bronze gauntlet is in the frame on screen now (2026-10-11, user on the wind-up glow
    /// left at the hidden 3D body's hip: 碍眼): each clip's json lists it per frame (hand, cell pixels,
    /// tools/animation/prepare_sevian_video_body.py hand_point). False without that data.
    public bool HandPoint(out Vector3 world)
    {
        world = transform.position;
        var info = shown?.info;
        if (info?.hand == null || info.hand.Length < 2) return false;
        int f = Mathf.Clamp(frameShown, 0, info.hand.Length / 2 - 1);
        float unit = height / info.figureHeight;
        world = transform.TransformPoint(new Vector3((info.hand[f * 2] - info.width * .5f) * unit, (info.feetRow - info.hand[f * 2 + 1]) * unit, 0f));
        return true;
    }

    static Clip Load(string name)
    {
        var json = Resources.Load<TextAsset>(Root + name);
        if (!json) return null;
        var clip = new Clip { name = name, info = JsonUtility.FromJson<Info>(json.text),
            atlas = Resources.Load<Texture2D>(Root + name), rest = Resources.Load<Texture2D>(Root + name + "-idle") };
        return clip.atlas && clip.rest && clip.info != null && clip.info.frames > 0 && clip.info.figureHeight > 0 ? clip : null;
    }

    /// Puts the illustrated body on a fitted Chronarch handle; worldHeight is the fitted
    /// height of the 3D body (ChronarchPresentation.targetWorldHeight in its root's scale).
    public static SevianVideoBody20261009 Install(EnemyHandle handle, float worldHeight)
    {
        if (!Enabled || !handle || !handle.MotionRoot) return null;
        var existing = handle.GetComponentInChildren<SevianVideoBody20261009>(true);
        if (existing) return existing;
        var strike = Load("strike");
        var shader = Resources.Load<Shader>("CombatTempo/AIHero/AIHeroAtlas");
        if (strike == null || !shader || !shader.isSupported) { Debug.LogError("SEVIAN_VIDEO_UNAVAILABLE"); return null; }
        var parent = handle.Model ? handle.Model : handle.VisualRoot ? handle.VisualRoot : handle.MotionRoot;
        var go = new GameObject("Sevian illustrated body");
        go.transform.SetParent(parent, false);
        go.transform.position = handle.MotionRoot.position;
        var s = parent.lossyScale; go.transform.localScale = new Vector3(1f / s.x, 1f / s.y, 1f / s.z);
        var body = go.AddComponent<SevianVideoBody20261009>();
        body.height = worldHeight;
        body.clips["strike"] = strike;
        foreach (var name in Optional) { var clip = Load(name); if (clip != null) body.clips[name] = clip; }
        body.material = new Material(shader) { name = "SevianIllustrated" };
        body.material.SetFloat("_IdleBlend", 1f);
        body.mesh = new Mesh { name = "Sevian fixed-foot plane" };
        body.mesh.vertices = new Vector3[4];
        body.mesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.up, Vector2.one };
        body.mesh.triangles = new[] { 0, 2, 1, 2, 3, 1 };
        body.Show(strike);
        go.AddComponent<MeshFilter>().sharedMesh = body.mesh;
        var surface = go.AddComponent<MeshRenderer>(); surface.sharedMaterial = body.material;
        surface.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; surface.receiveShadows = false;
        // Hide the 3D body's own renderers (not health bars or effects outside the model).
        var all = parent.GetComponentsInChildren<Renderer>(true);
        var list = new List<Renderer>();
        foreach (var r in all) if (r != surface && r.enabled && (r is SkinnedMeshRenderer || r is MeshRenderer)) { r.enabled = false; list.Add(r); }
        body.hidden = list.ToArray();
        body.breath = (handle.GetInstanceID() & 7) * .4f;
        body.home = go.transform.localPosition;
        Debug.Log($"SEVIAN_VIDEO installed height={worldHeight:F2} hidden={list.Count} clips={string.Join(",", body.clips.Keys)}");
        return body;
    }

    /// Puts a clip's atlas and rest frame on the quad, sized so its figure stands worldHeight
    /// tall with the feet on his position (clips are matted at different figure heights).
    void Show(Clip clip)
    {
        if (shown == clip) return;
        shown = clip;
        material.SetTexture("_MainTex", clip.atlas); material.SetTexture("_IdleTex", clip.rest);
        material.SetVector("_Grid", new Vector4(clip.info.columns, clip.info.rows, 0, 0));
        float unit = height / clip.info.figureHeight, half = clip.info.width * .5f;
        float below = clip.info.height - clip.info.feetRow, above = clip.info.feetRow;
        mesh.vertices = new[] {
            new Vector3(-half*unit,-below*unit,0), new Vector3(half*unit,-below*unit,0),
            new Vector3(-half*unit,above*unit,0), new Vector3(half*unit,above*unit,0) };
        mesh.RecalculateBounds();
    }

    /// Plays the strike so that the release frame lands contactAfter seconds from now, then
    /// the recovery over the next recoverSeconds.
    public void PlayStrike(float contactAfter, float recoverSeconds) => Play("strike", contactAfter, recoverSeconds);

    /// Plays a move (strike, sign, charge; the strike stands in for a missing one) timed the same way.
    public void Play(string clip, float contactAfter, float recoverSeconds)
    {
        if (!material) return;
        if (!clips.TryGetValue(clip, out var c)) c = clips["strike"];
        playing = c; Show(c);
        age = 0f; contact = Mathf.Max(.2f, contactAfter); recover = Mathf.Max(.3f, recoverSeconds);
        Draw();
    }

    /// The hit reaction, once its video exists: plays through over seconds, never over an attack.
    public void PlayHit(float seconds = 1.1f)
    {
        if (!material || Acting || !clips.TryGetValue("hit", out var c)) return;
        playing = c; Show(c);
        float share = c.info.releaseFrame / Mathf.Max(1f, c.info.frames - 1);
        age = 0f; contact = Mathf.Max(.05f, seconds * share); recover = Mathf.Max(.2f, seconds - contact);
        Draw();
    }

    void Update()
    {
        if (!material) return;
        if (age >= 0f) { age += Time.deltaTime; Draw(); return; }
        // At rest: the idle loop when its video exists, else the strike's first frame (with the
        // breath in LateUpdate). Both start from the same pose the moves end on.
        restAge += Time.deltaTime;
        if (clips.TryGetValue("idle", out var idle))
        {
            Show(idle);
            frameShown = Mathf.FloorToInt(Mathf.Repeat(restAge / IdleLoopSeconds, 1f) * idle.info.frames) % idle.info.frames;
            material.SetFloat("_Frame", frameShown);
            material.SetFloat("_IdleBlend", 0f);
        }
        else { Show(clips["strike"]); material.SetFloat("_IdleBlend", 1f); frameShown = 0; }
    }

    void Draw()
    {
        if (age < 0f || !material || playing == null) return;
        var info = playing.info;
        float frame = age <= contact
            ? info.releaseFrame * Mathf.Clamp01(age / contact)
            : Mathf.Lerp(info.releaseFrame, info.frames - 1, Mathf.Clamp01((age - contact) / recover));
        material.SetFloat("_Frame", Mathf.Floor(frame)); frameShown = Mathf.FloorToInt(frame);
        // The atlas's first and last cells match the rest frame; a short blend hides the swap.
        float end = contact + recover;
        material.SetFloat("_IdleBlend", age < .05f ? 1f - age / .05f : Mathf.Clamp01((age - end) / .12f));
        if (age >= end + .12f) Cancel();
    }

    void LateUpdate()
    {
        var cam = Camera.main;
        // A slow breath at rest so the still frame never reads as a cut-out (the idle loop breathes itself).
        float b = Acting || Has("idle") ? 0f : Mathf.Sin((Time.time + breath) * 2f * Mathf.PI / 3.4f);
        // The videos move his whole body themselves (2026-10-10); the quad only faces the camera.
        transform.localPosition = home;
        if (cam) transform.rotation = cam.transform.rotation;
        var p = transform.parent ? transform.parent.lossyScale : Vector3.one;
        transform.localScale = new Vector3(SizeMul / p.x * (1f - .004f * b), SizeMul / p.y * (1f + .008f * b), SizeMul / p.z);
    }

    public void Cancel()
    {
        age = -1f; restAge = 0f; transform.localPosition = home;
        if (material) material.SetFloat("_IdleBlend", 1f);
    }

    void OnDestroy()
    {
        if (hidden != null) foreach (var r in hidden) if (r) r.enabled = true;
        if (material) Destroy(material);
        if (mesh) Destroy(mesh);
    }
}
