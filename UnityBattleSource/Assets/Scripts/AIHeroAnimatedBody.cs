using System;
using System.Collections.Generic;
using UnityEngine;

// Approved 2D art, on the existing formation anchor. No rule callbacks here.
[DefaultExecutionOrder(31000)]
public sealed class AIHeroAnimatedBody : MonoBehaviour
{
    [Serializable] public sealed class ClipInfo {
        public string id; public int frames, columns, rows;
        public float releaseFrame, sourceStart, sourceRelease, sourceEnd, recoverySeconds;
    }
    sealed class Clip { public Texture2D atlas, idle; public ClipInfo info; }
    sealed class Bank { public int references; public Dictionary<string,Clip> clips; }
    static readonly Dictionary<string,Bank> banks=new Dictionary<string,Bank>();
    public static readonly string[] Actions = {
        "01-diagonal-cut", "02-command-flick", "03-overarm-throw", "04-seal-press", "05-sidearm-cast"
    };
    public string Outfit { get; private set; }
    public string CurrentAction { get; private set; }
    public bool IsActing => CurrentAction != null;
    public float ActionAge => age;
    public float DisplayFrame { get; private set; }
    public int LoadedAtlasCount => clips.Count;
    public Renderer Surface => surface;
    readonly Dictionary<string, Clip> clips = new Dictionary<string, Clip>();
    Material material;
    Mesh mesh;
    MeshRenderer surface;
    Clip current;
    float age, contact, recoverDuration, recoilAge = -1;
    Vector3 home;
    bool initialized;
    const string Root = "CombatTempo/AIHero/";

    public static AIHeroAnimatedBody Install(Transform parent, Bounds original, string outfit) {
        if (!Resources.Load<TextAsset>(Root + outfit + "/" + Actions[0])) return null;
        var shader = Resources.Load<Shader>(Root + "AIHeroAtlas");
        if (!shader || !shader.isSupported) { Debug.LogError("AI_HERO_SHADER_UNAVAILABLE"); return null; }
        var go = new GameObject("AI illustrated hero"); go.transform.SetParent(parent, false);
        go.transform.position = new Vector3(original.center.x, original.min.y, original.center.z);
        var scale = parent.lossyScale;
        go.transform.localScale = new Vector3(1/scale.x,1/scale.y,1/scale.z);
        var body = go.AddComponent<AIHeroAnimatedBody>(); body.material = new Material(shader);
        // Frame feet are fixed at (256,590); authored silhouette height is 520px.
        float unit = original.size.y / 520;
        body.mesh = new Mesh { name = "AI hero fixed-foot plane" };
        body.mesh.vertices = new[] {
            new Vector3(-256*unit,-50*unit,0), new Vector3(256*unit,-50*unit,0),
            new Vector3(-256*unit,590*unit,0), new Vector3(256*unit,590*unit,0)
        };
        body.mesh.uv = new[] {Vector2.zero,Vector2.right,Vector2.up,Vector2.one};
        body.mesh.triangles = new[] {0,2,1,2,3,1}; body.mesh.RecalculateBounds();
        go.AddComponent<MeshFilter>().sharedMesh = body.mesh;
        body.surface = go.AddComponent<MeshRenderer>(); body.surface.sharedMaterial = body.material;
        body.surface.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        body.surface.receiveShadows = false;
        body.home = go.transform.localPosition;
        if (!body.Apply(outfit)) { Destroy(go); return null; }
        body.initialized = true; body.Cancel(); return body;
    }

    public bool Apply(string outfit) {
        if (outfit != "mistport-night" && outfit != "starlight-magician" && outfit != "midnight-carnival") return false;
        if (Outfit == outfit) return true;
        var next = Acquire(outfit);
        if(next==null) return false;
        string previous=Outfit;
        clips.Clear();foreach(var pair in next) clips.Add(pair.Key,pair.Value);
        Outfit=outfit;current=clips[CurrentAction ?? Actions[0]];
        // Preserve the action clock across wardrobe changes; different recordings
        // map to the same rule contact, never restart the ongoing cast.
        Bind();ReleaseBank(previous);return true;
    }
    static Dictionary<string,Clip> Acquire(string outfit) {
        if(banks.TryGetValue(outfit,out var existing)) {existing.references++;return existing.clips;}
        var next = new Dictionary<string, Clip>();
        foreach (var action in Actions) {
            string path = Root + outfit + "/" + action;
            var json = Resources.Load<TextAsset>(path);
            var atlas = Resources.Load<Texture2D>(path);
            var idle = Resources.Load<Texture2D>(path + "-idle");
            if (!json || !atlas || !idle) {
                if (atlas) Resources.UnloadAsset(atlas); if (idle) Resources.UnloadAsset(idle);
                Release(next); Debug.LogError("AI_HERO_ASSET_MISSING " + path); return null;
            }
            next[action] = new Clip { atlas=atlas, idle=idle, info=JsonUtility.FromJson<ClipInfo>(json.text) };
        }
        banks.Add(outfit,new Bank {references=1,clips=next});return next;
    }
    static void ReleaseBank(string outfit) {
        if(outfit==null || !banks.TryGetValue(outfit,out var bank)) return;
        if(--bank.references>0)return;
        banks.Remove(outfit);Release(bank.clips);
    }
    static void Release(Dictionary<string, Clip> values) {
        foreach (var c in values.Values) { if(c.atlas) Resources.UnloadAsset(c.atlas); if(c.idle) Resources.UnloadAsset(c.idle); }
        values.Clear();
    }
    public static string ActionFor(string skill) {
        switch (skill) {
            case "basic": case "fool_skill_01": return Actions[0];
            case "fool_skill_02": case "fool_skill_08": return Actions[1];
            case "fool_skill_04": case "fool_skill_07": case "fool_skill_10": return Actions[2];
            case "fool_skill_05": case "fool_skill_09": return Actions[3];
            case "fool_skill_06": return Actions[4];
            default: return Actions[1];
        }
    }
    public void PlaySkill(string skill, float contactAfter) => PlayAction(ActionFor(skill),contactAfter);
    public void PlayAction(string action, float contactAfter) {
        if (!clips.TryGetValue(action,out current)) return;
        CurrentAction = action; age=0; contact=Mathf.Max(.08f,contactAfter);
        recoverDuration = Mathf.Clamp((current.info.sourceEnd-current.info.sourceRelease)/3,.16f,.55f);
        Bind(); Draw();
    }
    void Bind() {
        material.SetTexture("_MainTex",current.atlas); material.SetTexture("_IdleTex",current.idle);
        material.SetVector("_Grid",new Vector4(current.info.columns,current.info.rows,0,0));
        if (!IsActing) material.SetFloat("_IdleBlend",1);
    }
    void Update() {
        if (!initialized) return;
        if (IsActing) { age+=Time.deltaTime; Draw(); }
        if (recoilAge >= 0) {
            recoilAge += Time.deltaTime;
            if (recoilAge >= .22f) recoilAge=-1;
        }
    }
    void Draw() {
        if (!IsActing) return;
        float end=contact+recoverDuration;
        DisplayFrame = age <= contact
            ? current.info.releaseFrame * Mathf.Clamp01(age/contact)
            : Mathf.Lerp(current.info.releaseFrame,current.info.frames-1,Mathf.Clamp01((age-contact)/recoverDuration));
        material.SetFloat("_Frame", Mathf.Floor(DisplayFrame));
        // Short entry/exit blend uses the same costume's rest art; no backwards throw.
        float blend = age < .045f ? 1-age/.045f : Mathf.Clamp01((age-end)/current.info.recoverySeconds);
        material.SetFloat("_IdleBlend",blend);
        if (age >= end+current.info.recoverySeconds) Cancel();
    }
    void LateUpdate() {
        if (!initialized) return;
        if (Camera.main) transform.rotation=Camera.main.transform.rotation;
        transform.localPosition=home;
        if (recoilAge>=0) transform.position += transform.right * (Mathf.Sin(recoilAge*50)*.017f*(1-recoilAge/.22f));
    }
    public void ConfirmedHit(bool heavy) { recoilAge=0; }
    public void Cancel() {
        CurrentAction=null; age=0; DisplayFrame=0; recoilAge=-1;
        if (material) material.SetFloat("_IdleBlend",1);
        transform.localPosition=home;
    }
    void OnDisable() => Cancel();
    void OnDestroy() {
        if (surface) surface.sharedMaterial=null;
        if (material) Destroy(material); if(mesh) Destroy(mesh); ReleaseBank(Outfit);clips.Clear();
    }
}
