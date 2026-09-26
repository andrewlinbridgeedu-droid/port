using System.Collections;
using UnityEngine;

// Presentation only: native combat receives contact exactly when the glob lands.
public sealed class MemoryLeechPresentation : MonoBehaviour
{
    Animation clips;
    GameObject impactRoot;
    EnemyAuthoredBurstTier20260919 impactVisual;
    MainlineDistinct20260925 devourImpact;bool currentDevour;
    BattlePrototype battleOwner;
    Vector3 impactFrom,impactTarget;
    float impactAge;
    int epoch;GameObject activeGlob;Material globMaterial;MainlineBodyRound2 body;
    bool bodyActive;float bodyElapsed;
    void ClearImpactOnly(){if(impactRoot){impactRoot.SetActive(false);Destroy(impactRoot);}impactRoot=null;impactVisual=null;devourImpact=null;}
    void ClearGlob(){if(activeGlob){activeGlob.SetActive(false);Destroy(activeGlob);}if(globMaterial)Destroy(globMaterial);activeGlob=null;globMaterial=null;}
    public void ClearImpact(){epoch++;ClearImpactOnly();ClearGlob();bodyActive=false;if(body)body.Stop();}
    void BeginImpact(Vector3 from,Vector3 target){
        ClearImpactOnly();impactFrom=from;impactTarget=target;impactAge=0;
        battleOwner=FindFirstObjectByType<BattlePrototype>();
        impactRoot=new GameObject("Leech contact digestive rupture");impactRoot.transform.SetParent(transform,false);
        if(currentDevour){devourImpact=impactRoot.AddComponent<MainlineDistinct20260925>();devourImpact.Devour(1,impactFrom,impactTarget);}
        else {impactVisual=impactRoot.AddComponent<EnemyAuthoredBurstTier20260919>();impactVisual.Draw(EnemyAuthoredBurstTier20260919.Motif.Leech,1,impactFrom,impactTarget);}
    }
    void Update(){
        if(bodyActive&&body){bodyElapsed+=Time.deltaTime;body.Sample(bodyElapsed);if(bodyElapsed>=1.75f){body.Stop();bodyActive=false;}}
        if(!impactRoot)return;
        if(dying || !gameObject.activeInHierarchy || (battleOwner&&!battleOwner.NativeCombatEnabled)){ClearImpact();return;}
        impactAge+=Time.deltaTime;
        if(impactAge>=.35f){ClearImpactOnly();return;}
        if(devourImpact)devourImpact.Devour(1+impactAge/.35f*.5f,impactFrom,impactTarget);
        else if(impactVisual)impactVisual.Draw(EnemyAuthoredBurstTier20260919.Motif.Leech,1+impactAge/.35f*.5f,impactFrom,impactTarget);
    }
    void OnDisable(){ClearImpact();}
    void OnDestroy(){ClearImpact();}
    void Awake() {
        // Inactive scene templates can retain zero bounds until first skinning.
        // Evaluate even before the camera sees the actor to avoid a culling loop.
        foreach (var renderer in GetComponentsInChildren<SkinnedMeshRenderer>(true))
            renderer.updateWhenOffscreen = true;
        clips = GetComponent<Animation>();
        if (clips == null) clips = GetComponentInChildren<Animation>();
        if (clips == null) return;
        var source = new System.Collections.Generic.List<AnimationClip>();
        foreach (AnimationState state in clips) if (state.clip != null) source.Add(state.clip);
        foreach (var clip in source)
            foreach (var name in new[] { "Idle", "Cast", "Hit", "Death" })
                if (clips.GetClip(name) == null && clip.name.IndexOf(name, System.StringComparison.OrdinalIgnoreCase) >= 0) clips.AddClip(clip, name);
        clips.clip = clips.GetClip("Idle");
    }
    bool dying;
    void OnEnable() => RestoreIdle();
    public void RestoreIdle() { ClearImpact(); dying = false; PlayClip("Idle", WrapMode.Loop); }
    AnimationState PlayClip(string name, WrapMode mode)
    {
        var state = clips != null ? clips[name] : null;
        if (state == null) {
            Debug.LogError("Memory leech is missing required animation: " + name, this);
            return null;
        }
        clips.wrapMode = mode;
        state.wrapMode = mode;
        clips.Play(name);
        clips.Sample();
        return state;
    }
    public IEnumerator Cast(Vector3 from, System.Func<Vector3> target, System.Action contact,bool devour=false)
    {
        ClearImpact();currentDevour=devour;
        int ticket=epoch;
        body=MainlineBodyRound2.Get(gameObject);body.Begin(MainlineBodyRound2.Pose.Leech,false,.42f,1.04f,1.75f);
        bodyActive=true;bodyElapsed=0;
        PlayClip("Cast", WrapMode.Once);
        yield return new WaitForSeconds(.42f);
        if(ticket!=epoch||dying||!gameObject.activeInHierarchy)yield break;
        var glob=GameObject.CreatePrimitive(PrimitiveType.Sphere);
        Destroy(glob.GetComponent<Collider>());
        var mat=new Material(Resources.Load<Shader>("EnemySignature/MainlineLeechWetRound2"));
        mat.color=new Color(.24f,.42f,.045f);
        glob.GetComponent<Renderer>().material=mat;
        activeGlob=glob;globMaterial=mat;
        glob.transform.localScale=Vector3.one*.34f;
        var skin=glob.AddComponent<MainlineLeechGlobRound2>();
        var tier=devour?null:glob.AddComponent<EnemyAuthoredBurstTier20260919>();
        MainlineDistinct20260925 suction=null;
        if(devour){var strands=new GameObject("Devour inward name strands");strands.transform.SetParent(glob.transform,false);suction=strands.AddComponent<MainlineDistinct20260925>();}
        if(devour){glob.GetComponent<Renderer>().enabled=false;glob.transform.localScale=Vector3.one;}
        try {
            for(float t=0;t<.62f;t+=Time.deltaTime) {
                if(ticket!=epoch||dying||!gameObject.activeInHierarchy)yield break;
                if(!devour)skin.Sample(t);
                float f=t/.62f;
                glob.transform.position=Vector3.Lerp(from,target(),f)+Vector3.up*(Mathf.Sin(f*Mathf.PI)*.5f);
                if(suction)suction.Devour(.4f+f*.6f,from,target());
                else tier.Draw(EnemyAuthoredBurstTier20260919.Motif.Leech,.4f+f*.6f,from,target());
                yield return null;
            }
            if(ticket!=epoch||dying||!gameObject.activeInHierarchy)yield break;
            glob.transform.position = target();
            BeginImpact(from,glob.transform.position);
            contact?.Invoke();
        } finally {if(activeGlob==glob)ClearGlob();else{if(glob)Destroy(glob);if(mat)Destroy(mat);}}
        if (!dying) PlayClip("Idle", WrapMode.Loop);
    }
    public IEnumerator Die()
    {
        ClearImpact();
        dying = true;
        var death = PlayClip("Death", WrapMode.ClampForever);
        if (death != null) yield return new WaitForSeconds(death.length);
    }
}
