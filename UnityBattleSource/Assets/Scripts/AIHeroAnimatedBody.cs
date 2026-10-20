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
    sealed class Clip { public Texture2D atlas, idle; public ClipInfo info; public bool sharedIdle; }
    sealed class Bank { public int references; public Dictionary<string,Clip> clips; }
    static readonly Dictionary<string,Bank> banks=new Dictionary<string,Bank>();
    public static readonly string[] Actions = {
        "01-diagonal-cut", "02-command-flick", "03-overarm-throw", "04-seal-press", "05-sidearm-cast"
    };
    // A take recorded for one skill in one outfit (2026-10-19: 燃镜 in 雾港夜行). Loaded
    // when the outfit has it; other outfits keep the shared rotation for that skill.
    public static readonly Dictionary<string,string> Signatures = new Dictionary<string,string> {
        ["fool_skill_12"] = "06-mirror-burn"
    };
    public bool HasAction(string action) => action != null && clips.ContainsKey(action);
    public string Outfit { get; private set; }
    public string CurrentAction { get; private set; }
    public bool IsActing => CurrentAction != null;
    public float ActionAge => age;
    public const float HitPauseDuration = .10f;
    public bool IsRecoiling => recoilAge >= 0;
    public bool IsHitPausedAt(float unscaledTime) => unscaledTime < hitPauseUntil;
    public float DisplayFrame { get; private set; }
    public int LoadedAtlasCount => clips.Count;
    public Renderer Surface => surface;
    readonly Dictionary<string, Clip> clips = new Dictionary<string, Clip>();
    readonly MotionSequence motionSequence = new MotionSequence();
    Material material;
    Mesh mesh;
    MeshRenderer surface;
    Clip current;
    float age, contact, recoverDuration, recoilAge = -1, recoilStrength = 1, height = 1;
    /// The hero's standing height in world units (the final-boss party is sized from it).
    public float Height => height;
    Vector3 home, homeScale = Vector3.one;
    bool initialized;
    float hitPauseUntil = -1;
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
        body.home = go.transform.localPosition; body.homeScale = go.transform.localScale;
        body.height = Mathf.Max(.3f, original.size.y);
        if (!body.Apply(outfit)) { Destroy(go); return null; }
        body.initialized = true; body.Cancel(); return body;
    }

    // Spell echoes copy the visible illustrated frame, not the hidden old rig.
    // Retain the sampled outfit bank so a wardrobe switch cannot unload a frozen pose.
    public VisualEcho CreateEcho(Transform parent, Vector3 origin, Color tint) => new VisualEcho(this,parent,origin,tint);
    public sealed class VisualEcho : IDisposable {
        readonly AIHeroAnimatedBody source;
        readonly Mesh mesh;
        readonly Color tint;
        string heldOutfit;
        public readonly GameObject Root;
        public readonly Material Material;
        public VisualEcho(AIHeroAnimatedBody source,Transform parent,Vector3 origin,Color tint) {
            this.source=source;this.tint=tint;
            Root=new GameObject("Illustrated costume echo");Root.transform.SetParent(parent,false);
            mesh=Instantiate(source.mesh);mesh.name="Illustrated posed silhouette";
            Material=new Material(source.material);
            Root.AddComponent<MeshFilter>().sharedMesh=mesh;
            var renderer=Root.AddComponent<MeshRenderer>();renderer.sharedMaterial=Material;
            renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
            Capture(origin);
        }
        public bool Capture(Vector3 origin) {
            if(!source || !source.material || !Root) return false;
            if(heldOutfit!=source.Outfit) {
                Acquire(source.Outfit);ReleaseBank(heldOutfit);heldOutfit=source.Outfit;
            }
            Material.CopyPropertiesFromMaterial(source.material);
            Material.SetColor("_EchoTint",tint);Material.SetFloat("_EchoMix",.48f);
            var vertices=source.mesh.vertices;
            for(int i=0;i<vertices.Length;i++) vertices[i]=source.transform.TransformPoint(vertices[i])-origin;
            mesh.vertices=vertices;mesh.RecalculateBounds();return true;
        }
        public void SetOpacity(float alpha) { if(Material) Material.SetColor("_Color",new Color(1,1,1,Mathf.Clamp01(alpha))); }
        public void Dispose() {
            if(Root) {Root.SetActive(false);Destroy(Root);}
            if(mesh)Destroy(mesh);if(Material)Destroy(Material);
            ReleaseBank(heldOutfit);heldOutfit=null;
        }
    }

    public bool Apply(string outfit) {
        if (outfit != "mistport-night" && outfit != "starlight-magician" && outfit != "midnight-carnival") return false;
        if (Outfit == outfit) return true;
        var next = Acquire(outfit);
        if(next==null) return false;
        string previous=Outfit;
        clips.Clear();foreach(var pair in next) clips.Add(pair.Key,pair.Value);
        // Preserve the action clock across wardrobe changes; different recordings
        // map to the same rule contact, never restart the ongoing cast. A signature
        // take the new outfit lacks continues on the first shared take.
        if(CurrentAction!=null && !clips.ContainsKey(CurrentAction)) CurrentAction=Actions[0];
        Outfit=outfit;current=clips[CurrentAction ?? Actions[0]];
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
        // A signature take keeps the outfit's reference rest art: its own last frame is a
        // slimmer re-drawing of the coat, and the rest pose must not jump between casts.
        foreach (var action in Signatures.Values) {
            string path = Root + outfit + "/" + action;
            var json = Resources.Load<TextAsset>(path);
            if (!json) continue;
            var atlas = Resources.Load<Texture2D>(path);
            if (!atlas) { Debug.LogError("AI_HERO_ASSET_MISSING " + path); continue; }
            next[action] = new Clip { atlas=atlas, idle=next[Actions[0]].idle, sharedIdle=true, info=JsonUtility.FromJson<ClipInfo>(json.text) };
        }
        banks.Add(outfit,new Bank {references=1,clips=next});return next;
    }
    static void ReleaseBank(string outfit) {
        if(outfit==null || !banks.TryGetValue(outfit,out var bank)) return;
        if(--bank.references>0)return;
        banks.Remove(outfit);Release(bank.clips);
    }
    static void Release(Dictionary<string, Clip> values) {
        foreach (var c in values.Values) { if(c.atlas) Resources.UnloadAsset(c.atlas); if(c.idle && !c.sharedIdle) Resources.UnloadAsset(c.idle); }
        values.Clear();
    }
    // Only presentation chooses variants. The card still owns its contact and
    // cooldown; every take is retimed to the same release frame by PlayAction.
    public sealed class MotionSequence {
        int next;
        public string Next() {
            string action = Actions[next];
            next = (next + 1) % Actions.Length;
            return action;
        }
    }
    public void PlaySkill(string skill, float contactAfter) {
        var action = Signatures.TryGetValue(skill ?? "",out var signature) && clips.ContainsKey(signature)
            ? signature : motionSequence.Next();
        PlayAction(action,contactAfter);
        Debug.Log($"AI_HERO_CAST skill={skill} action={action} contact={contactAfter:F4} outfit={Outfit}");
    }
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
    void Update() => AdvancePresentation(Time.deltaTime, Time.unscaledTime);
    public void AdvancePresentation(float scaledDelta, float unscaledNow) {
        if (!initialized) return;
        // Keep the release clock aligned with the rules while briefly holding
        // the visible cast pose. The confirmed hit owns the body during this beat.
        if (IsActing) { age += scaledDelta; if (!IsHitPausedAt(unscaledNow)) Draw(); }
        if (recoilAge >= 0) {
            recoilAge += scaledDelta;
            if (recoilAge >= RecoilTime) recoilAge=-1;
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
        if (age >= end+current.info.recoverySeconds) FinishAction();
    }
    void LateUpdate() {
        if (!initialized) return;
        if (Camera.main) transform.rotation=Camera.main.transform.rotation;
        transform.localPosition=home; transform.localScale=homeScale;
        if (recoilAge>=0) {
            // Hit shake (2026-10-07, user: 关键是手机震动，以及角色摇晃): the figure is knocked
            // back and down a little, rattles side to side and rocks, damped over ~0.38 s.
            // It used to move 1.7 cm side to side, which nobody could see.
            // 2026-10-08: the first version rattled at 17 Hz with 5 % of the height. On the
            // simulator a hit frame runs at ~15 fps, so the sine was sampled at nearly the same
            // phase every frame and read as a still; 3 % of the figure is below notice anyway.
            // Now: an immediate 9 % knock that eases back, a 9 Hz damped swing of 6 % (three
            // visible swings at any frame rate), a squash for the first tenth of a second.
            float t=recoilAge, e=Mathf.Pow(1-t/RecoilTime,2f)*recoilStrength;
            float knock=Mathf.Exp(-t/.12f)*recoilStrength;
            float squash=Mathf.Exp(-t/.07f)*recoilStrength;
            transform.position += transform.right*(Mathf.Sin(t*2*Mathf.PI*9)*.06f*e*height)
                                + Vector3.down*(knock*.09f*height) - transform.forward*(knock*.03f*height);
            transform.rotation = transform.rotation*Quaternion.Euler(0,0,Mathf.Sin(t*2*Mathf.PI*7+.6f)*9f*e);
            transform.localScale=new Vector3(homeScale.x*(1+.14f*squash),homeScale.y*(1-.11f*squash),homeScale.z);
        }
    }
    const float RecoilTime = .38f;
    public void ConfirmedHit(bool heavy) => ConfirmedHit(heavy ? 1.3f : 1f);
    public void ConfirmedHit(float strength) {
        recoilAge=0;
        hitPauseUntil=Time.unscaledTime+HitPauseDuration;
        recoilStrength=Mathf.Clamp(strength,1f,1.4f)*(SpellSpectacle20260926.ReducedMotion?.35f:1f);
        Debug.Log($"AI_HERO_HIT action={CurrentAction ?? "idle"} heldFrame={DisplayFrame:F2} pause={HitPauseDuration:F2}");
    }
    void FinishAction() {
        CurrentAction=null; age=0; DisplayFrame=0;
        if (material) material.SetFloat("_IdleBlend",1);
        // Ending a cast cannot erase the hit that arrived on its final frame.
    }
    public void Cancel() {
        FinishAction(); recoilAge=-1; hitPauseUntil=-1;
        transform.localPosition=home; transform.localScale=homeScale;
    }
    void OnDisable() => Cancel();
    static void ReleaseObject(UnityEngine.Object value) {
#if UNITY_EDITOR
        if (!Application.isPlaying) { DestroyImmediate(value); return; }
#endif
        Destroy(value);
    }
    void OnDestroy() {
        if (surface) surface.sharedMaterial=null;
        if (material) ReleaseObject(material); if(mesh) ReleaseObject(mesh); ReleaseBank(Outfit);clips.Clear();
    }
}
