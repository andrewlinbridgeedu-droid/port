using System;
using System.Collections;
using System.Collections.Generic;
using Effekseer;
using UnityEngine;

// Q4-only presentation. Native combat owns the cycle and evaluates every hit.
public sealed class Q4HoundPresentation : MonoBehaviour
{
    public string Phase { get; private set; } = "clear";
    public bool Enabled => Phase != "clear";
    Func<Vector3> source, target;
    Transform actor;
    GameObject chargeRoot;
    readonly List<GameObject> effects = new List<GameObject>();
    readonly List<Material> materials = new List<Material>();
    readonly List<EffekseerHandle> blasts = new List<EffekseerHandle>();
    Material chargeA, chargeB;
    Transform orbA, orbB;
    float chargeTime, openingTime;
    Transform head;
    Quaternion lastHeadDelta = Quaternion.identity;
    bool headAdjusted;
    Quaternion appliedHead;
    int generation;
    MainlineBodyRound2 body;
    float bodyTime;
    public void Configure(Transform actorRoot, Func<Vector3> muzzle, Func<Vector3> victim)
    {
        actor = actorRoot; source = muzzle; target = victim;
        if(actor)body=MainlineBodyRound2.Get(actor.gameObject);
        if (actor && !head) foreach(var bone in actor.GetComponentsInChildren<Transform>(true))
            if (bone.name.ToLowerInvariant().Contains("head")) { head=bone;break; }
    }
    public void SetPhase(string phase)
    {
        if (phase == "clear") { Clear(); return; }
        Phase=phase;
        if (phase=="charge")
        {
            RemoveCharge();chargeTime=0;
            bodyTime=0;if(body)body.Begin(MainlineBodyRound2.Pose.EarlyHound,false,2f,2.45f,3.1f);
            chargeRoot=new GameObject("Q4 paired mouth fire warning");effects.Add(chargeRoot);
            orbA=Orb("Q4 left stored flame",chargeRoot.transform,out chargeA);
            orbB=Orb("Q4 right stored flame",chargeRoot.transform,out chargeB);
        }
        else if(phase=="first") { if(orbA)orbA.gameObject.SetActive(false); }
        else if(phase=="second" || phase=="recover" || phase=="opening") RemoveCharge();
        if(phase=="opening")openingTime=0;
    }
    void Update()
    {
        if(body){bodyTime+=Time.deltaTime;body.Sample(bodyTime);}
        if(chargeRoot && source!=null)
        {
            chargeTime+=Time.deltaTime;
            var origin=source();var right=Camera.main?Camera.main.transform.right:Vector3.right;
            float swell=Mathf.SmoothStep(.20f,.45f,Mathf.Clamp01(chargeTime/2));
            Place(orbA,origin-right*.30f,swell,swell);
            Place(orbB,origin+right*.30f,swell,swell);
            Color hot=new Color(1,.76f,.40f,Mathf.Lerp(.5f,.9f,Mathf.Clamp01(chargeTime/2)));
            Set(chargeA,chargeTime,hot,1.15f);Set(chargeB,chargeTime+.71f,hot,1.15f);
        }
        if(Phase=="opening") openingTime+=Time.deltaTime;
    }
    void LateUpdate()
    {
        // Modify only the head bone, after the authored animation, never the formation root.
        UndoHead();
        if (actor && actor.GetComponentInChildren<CombatTempoAnimatedBody>(false)) return;
        if(!head || !head.gameObject.activeInHierarchy)return;
        if(Phase=="charge") lastHeadDelta=Quaternion.Euler(Mathf.SmoothStep(0,9,Mathf.Clamp01(chargeTime/2)),0,0);
        else if(Phase=="opening" && openingTime<3) lastHeadDelta=Quaternion.Euler(0,Mathf.Sin(openingTime*5)*13*Mathf.Sin(Mathf.Clamp01(openingTime/3)*Mathf.PI),0);
        else return;
        head.localRotation*=lastHeadDelta;appliedHead=head.localRotation;headAdjusted=true;
    }
    void UndoHead(){if(headAdjusted&&head&&Quaternion.Angle(head.localRotation,appliedHead)<.01f)head.localRotation*=Quaternion.Inverse(lastHeadDelta);headAdjusted=false;}
    public IEnumerator Shot(Action contact, Action complete)
    {
        int token=generation;
        bool heavy=Phase=="first"||Phase=="second";
        if(source==null||target==null||!actor||!actor.gameObject.activeInHierarchy)yield break;
        bodyTime=0;if(body)body.Begin(MainlineBodyRound2.Pose.EarlyHound,Phase=="second",.04f,.45f,.85f);
        var root=new GameObject(heavy?"Q4 heavy pursuit fireball":"Q4 probe fireball");effects.Add(root);
        Material coreMat,tailMat;
        var core=Orb("Incandescent rolling core",root.transform,out coreMat);
        var tail=Orb("Rolling flame wake",root.transform,out tailMat);
        var start=source();var end=target();float age=0;
        var animation=actor.GetComponentInChildren<Animator>(true);
        animation?.ResetTrigger("Attack");animation?.SetTrigger("Attack");
        while(age<.45f)
        {
            if(token!=generation||!actor||!actor.gameObject.activeInHierarchy){DestroyOwned(root);yield break;}
            age+=Time.deltaTime;float t=Mathf.Clamp01(age/.45f);
            // Retarget the current phantom until contact so native and rendered victims agree.
            end=target();var p=Vector3.Lerp(start,end,t)+Vector3.up*Mathf.Sin(t*Mathf.PI)*.18f;
            var dir=(end-start).normalized;
            float radius=heavy?.81f:.30f;
            Place(core,p,radius,radius);
            Place(tail,p-dir*(heavy?.50f:.20f),radius*.72f,radius*1.30f);
            Set(coreMat,age*2,new Color(1,.82f,.60f,.95f),heavy?1.78f:1.20f);
            Set(tailMat,age*2+.8f,new Color(1,.35f,.045f,.65f),1);
            yield return null;
        }
        tail.gameObject.SetActive(false);
        var fireball=Resources.Load<EffekseerEffectAsset>("Effects/HellHound/FireBall");
        if(fireball)
        {
            var args=EffekseerPlayEffectParameters.Create(end);args.SetScale(Vector3.one*(heavy?.44f:.16f));args.Speed=2.2f;
            var blast=EffekseerSystem.PlayEffect(fireball,args);blast.SetAllColor(new Color(.98f,.85f,.70f,.84f));blast.SetTargetLocation(end);blast.UpdateHandleToMoveToFrame(150);blasts.Add(blast);
        }
        Material impactMat;var impact=Orb("Local pursuit detonation",root.transform,out impactMat);impactMat.SetFloat("_Mode",1);
        if(token==generation)contact?.Invoke();
        float fade=0;
        while(fade<.40f&&token==generation)
        {
            fade+=Time.deltaTime;float t=fade/.40f;float release=EnemyImpactEnvelope20260921.Sample(t);float size=(heavy?3.2f:1.22f)*Mathf.Lerp(.26f,1,Mathf.Clamp01(release*2.2f));
            Place(impact,end,size,size*.8f);Set(impactMat,age+fade,new Color(1,.68f,.22f,(1-t)*.88f),heavy?2.1f:1.4f);
            // A short turbulent core precedes the unequal torn fire fronts.
            Place(core,end,size*.74f,size*.74f);
            Set(coreMat,age+fade*3,new Color(1,.68f,.22f,Mathf.Max(0,1-t*2.5f)),heavy?1.6f:1f);
            yield return null;
        }
        DestroyOwned(root);
        if(token==generation)complete?.Invoke();
    }
    Transform Orb(string name,Transform parent,out Material mat)
    {
        var obj=GameObject.CreatePrimitive(PrimitiveType.Quad);obj.name=name;obj.transform.SetParent(parent,false);
        Destroy(obj.GetComponent<Collider>());
        mat=new Material(Resources.Load<Shader>("EnemySignature/Q4PursuitFlame"));materials.Add(mat);
        var renderer=obj.GetComponent<MeshRenderer>();renderer.sharedMaterial=mat;renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
        return obj.transform;
    }
    static void Place(Transform obj,Vector3 p,float x,float y){if(!obj)return;obj.position=p;obj.rotation=Camera.main?Camera.main.transform.rotation:Quaternion.identity;obj.localScale=new Vector3(x*2,y*2,1);}
    static void Set(Material m,float age,Color color,float power){if(!m)return;m.SetFloat("_Age",age);m.SetColor("_Tint",color);m.SetFloat("_Power",power);}
    void DestroyOwned(GameObject root)
    {
        if(!root)return;
        foreach(var r in root.GetComponentsInChildren<Renderer>(true)) {var mat=r.sharedMaterial;if(mat){materials.Remove(mat);Destroy(mat);}}
        effects.Remove(root);root.SetActive(false);Destroy(root);
    }
    void RemoveCharge(){DestroyOwned(chargeRoot);chargeRoot=null;orbA=null;orbB=null;chargeA=null;chargeB=null;}
    public void Clear()
    {
        generation++;StopAllCoroutines();UndoHead();Phase="clear";
        if(body)body.Stop();body=null;
        foreach(var fx in effects)if(fx){fx.SetActive(false);Destroy(fx);}effects.Clear();
        foreach(var m in materials)if(m)Destroy(m);materials.Clear();
        foreach(var b in blasts)b.Stop();blasts.Clear();
        chargeRoot=null;head=null;actor=null;source=null;target=null;
    }
    void OnDisable(){Clear();}void OnDestroy(){Clear();}
}
