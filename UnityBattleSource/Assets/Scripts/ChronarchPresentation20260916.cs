using System;
using System.Collections;
using UnityEngine;

// Same Chronarch body in all three encounters; eight authored skeletal clips.
// This presentation owns no damage; contact is reported once to the native rules.
public sealed class ChronarchPresentation20260916 : MonoBehaviour
{
    public float targetWorldHeight=2.88f;
    bool needsRestFit;
    void OnEnable(){needsRestFit=true;}
    SevianVideoBody20261009 video;
    /// The move the next Strike shows (set by the battle from the command's intent): name_seal plays
    /// the signing video, slam / thirteenth_charge the smash (when it exists), anything else the sweep.
    public string NextMove;
    /// The Q30 angel intro opens on him pressing his seal: the signing video's stamp.
    public void PlayIntroSeal(){if(video)video.Play("sign",.9f,1.6f);}
    /// Size of the illustrated body (the party fight sets him smaller, 2026-10-10).
    public void SetVideoSize(float mul){if(video)video.SizeMul=mul;}
    /// 第十三响 (2026-10-11): the charge clip starts with the wind-up glow, so the raised gauntlet
    /// fills the build-up and the palm lands with the blow; the strike turn that follows keeps it.
    /// The video's gauntlet on screen (null without the illustrated body or its hand data).
    public Func<Vector3> VideoHand(){if(!video||!video.HandPoint(out _))return null;var v=video;return()=>v&&v.HandPoint(out var p)?p:Vector3.zero;}
    public bool PlayChargeWindup(float contactAfter){if(!video||!video.Has("charge"))return false;video.Play("charge",contactAfter,2f);NextMove="held";return true;}
    // 2026-10-09 pilot: the illustrated body from his AI video replaces the visible 3D body.
    void LateUpdate(){if(needsRestFit){needsRestFit=false;FitRestPose(false);var h=GetComponent<EnemyHandle>();if(h&&h.MotionRoot)video=SevianVideoBody20261009.Install(h,targetWorldHeight*h.MotionRoot.lossyScale.y);}}
    public void FitRestPose(bool sampleIdle=true)
    {
        var handle=GetComponent<EnemyHandle>();
        if(!handle || !handle.VisualRoot || !handle.MotionRoot)return;
        var animator=handle.VisualRoot.GetComponentInChildren<Animator>(true);
        // Import samples Idle explicitly. Activation fitting never restarts a
        // running idle/attack or calls Rebind, avoiding a visible pose reset.
        if(sampleIdle && animator){animator.Play("Meshy · Idle",0,0);animator.Update(0);}
        if(!BakedBounds(handle,out var before) || before.size.y<.001f)return;
        var originalScale=handle.VisualRoot.localScale;
        var originalPosition=handle.VisualRoot.localPosition;
        float factor=targetWorldHeight/before.size.y;
        handle.VisualRoot.localScale*=factor;
        if(!BakedBounds(handle,out var resized)) {handle.VisualRoot.localScale=originalScale;return;}
        handle.VisualRoot.localPosition-=Vector3.up*resized.min.y;
        if(!BakedBounds(handle,out var after) || Mathf.Abs(after.size.y-targetWorldHeight)>.01f || Mathf.Abs(after.min.y)>.005f) {
            handle.VisualRoot.localScale=originalScale;handle.VisualRoot.localPosition=originalPosition;
            Debug.LogError($"STORY_REST_FIT_REJECTED {handle.ProfileEnemyId} before={before.size.y} target={targetWorldHeight} measured={after.size.y} floor={after.min.y}");return;
        }
        if(handle.HealthBarAnchor)handle.HealthBarAnchor.localPosition=new Vector3(0,after.max.y+.16f,0);
        if(handle.DamageTextAnchor)handle.DamageTextAnchor.localPosition=new Vector3(0,after.max.y*.8f,0);
        if(handle.EffectAnchor)handle.EffectAnchor.localPosition=new Vector3(0,after.max.y*.55f,0);
        Debug.Log($"STORY_REST_FIT {handle.ProfileEnemyId} before={before.size.y:F4} target={targetWorldHeight:F4} factor={factor:F4} after={after.size.y:F4} floor={after.min.y:F5}");
    }
    static bool BakedBounds(EnemyHandle handle,out Bounds result)
    {
        result=default;bool found=false;
        foreach(var skin in handle.VisualRoot.GetComponentsInChildren<SkinnedMeshRenderer>(true)) {
            var mesh=new Mesh();
            // FBX unit-scale hierarchy: true returns renderer-local vertices.
            // false already contains lossyScale; TransformPoint then doubles it.
            skin.BakeMesh(mesh,true);
            foreach(var vertex in mesh.vertices){var point=handle.MotionRoot.InverseTransformPoint(skin.transform.TransformPoint(vertex));if(!found){result=new Bounds(point,Vector3.zero);found=true;}else result.Encapsulate(point);}
            if(Application.isPlaying)Destroy(mesh);else DestroyImmediate(mesh);
        }
        return found;
    }
    GameObject effect;
    Material material;
    int epoch, casts;
    MainlineBodyRound2 body;
    Transform copperHand;
    public IEnumerator Strike(EnemyHandle handle, Transform target, Action contact, Func<bool> valid)
    {
        // A held charge clip (PlayChargeWindup) plays on through the strike.
        Cancel(NextMove=="held"); int token=epoch; GameObject ownedEffect=null; Material ownedMaterial=null; bool second=(casts++ & 1)!=0; bool hit=false;
        var animator=handle.GetComponentInChildren<Animator>(true);
        float oldSpeed=animator?animator.speed:1;
        body=MainlineBodyRound2.Get(handle.gameObject);
        body.Begin(MainlineBodyRound2.Pose.Chronarch,second,StoryStrikeTiming20261010.Release,1f,2.5f);
        var move=NextMove; NextMove=null;
        // The sweep and the walk back need two seconds (2026-10-10); 镇钟重砸 keeps the sweep, 第十三响's
        // charge clip is already running from its wind-up (PlayChargeWindup, 2026-10-11).
        if(video&&move!="held")video.Play(move=="name_seal"?"sign":move=="thirteenth_charge"?"charge":"strike",1f,2f);
        if(!copperHand)foreach(var bone in handle.GetComponentsInChildren<Transform>())if(bone.name=="Hand.R"){copperHand=bone;break;}
        try {
            int phase=0;
            StoryStrikeTiming20261010.BeginCharge(animator,second?"Charge2":"Charge");
            effect=new GameObject(second?"ChronarchOwnershipSeal":"ChronarchBronzeVerdict");
            material=new Material(Shader.Find("Sprites/Default"));ownedEffect=effect;ownedMaterial=material;
            var tier=effect.AddComponent<EnemyAuthoredBurstTier20260919>();
            for(float t=0;t<2.5f;t+=Time.deltaTime){
                if(token!=epoch||!handle||!target||!handle.gameObject.activeInHierarchy||!valid())yield break;
                body.Sample(t);
                StoryStrikeTiming20261010.Tick(animator,t,second?"Cast2":"Cast",ref phase);
                var start=copperHand?copperHand.position:handle.EnemyRoot.position+Vector3.up*1.8f;
                var end=target.position+Vector3.up*.9f;
                float flight=Mathf.Clamp01((t-StoryStrikeTiming20261010.Release)/(StoryStrikeTiming20261010.Contact-StoryStrikeTiming20261010.Release));
                var center=second?end:Vector3.Lerp(start,end,flight);
                tier.Draw(EnemyAuthoredBurstTier20260919.Motif.Clock,t,start,end,second);
                if(!hit&&t>=1){hit=true;contact?.Invoke();}
                yield return null;
            }
        } finally {if(effect==ownedEffect)Clear();else{if(ownedEffect)Destroy(ownedEffect);if(ownedMaterial)Destroy(ownedMaterial);}if(animator&&token==epoch){animator.speed=oldSpeed;if(handle&&handle.gameObject.activeInHierarchy)animator.CrossFadeInFixedTime("Meshy · Idle",.1f,0,0);}}
    }
    public void Cancel(bool keepVideo=false){epoch++;Clear();if(body)body.Stop();if(video&&!keepVideo)video.Cancel();var a=GetComponentInChildren<Animator>(true);if(a)a.speed=1;}
    // Q28/Q29 withdraw alive; the director owns visibility and the five-cycle rule.
    public void BeginRetreat(){Cancel();GetComponentInChildren<Animator>(true)?.CrossFadeInFixedTime("Retreat",.08f,0,0);}
    void Clear(){if(body)body.Stop();if(effect)Destroy(effect);if(material)Destroy(material);effect=null;material=null;}
    void OnDisable(){Cancel();}
}
