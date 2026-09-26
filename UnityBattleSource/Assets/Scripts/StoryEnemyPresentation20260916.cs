using System;
using System.Collections;
using UnityEngine;

// Authored pen-arm and empty-hand actors retain their own seven animation clips.
// This presentation owns no damage; contact is reported once to the native rules.
public sealed class StoryEnemyPresentation20260916 : MonoBehaviour
{
    public bool isScribe;
    public bool isExecutor;
    public float targetWorldHeight=2.88f;
    bool needsRestFit;
    void OnEnable(){needsRestFit=true;}
    void LateUpdate(){if(needsRestFit){needsRestFit=false;FitRestPose(false);}}
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
    Material effectMaterial;
    int epoch, castCount;
    Transform executorPen;
    MainlineBodyRound2 body;
    public IEnumerator Strike(EnemyHandle handle, Transform target, Action contact, Func<bool> valid)
    {
        Cancel();int current=epoch;GameObject ownedEffect=null;Material ownedMaterial=null;
        var animator=handle.EnemyRoot.GetComponentInChildren<Animator>(true);
        float previousSpeed=animator?animator.speed:1f;
        if(!executorPen)foreach(var bone in handle.GetComponentsInChildren<Transform>())if(bone.name==((isExecutor||isScribe)?"Pen.R":"Hand.R")){executorPen=bone;break;}
        bool hit=false;
        bool second=(castCount++ & 1)!=0;
        body=MainlineBodyRound2.Get(handle.gameObject);
        body.Begin(isExecutor?MainlineBodyRound2.Pose.Executor:isScribe?MainlineBodyRound2.Pose.Scribe:MainlineBodyRound2.Pose.Bearer,second,.4f,1f,2.5f);
        try {
            if(animator)animator.speed=3.5f; // 1.4 second authored charge in the existing 0.4 second windup.
            animator?.CrossFadeInFixedTime(second?"Charge2":"Charge",.06f,0,0);
            for(float t=0;t<2.5f;t+=Time.deltaTime) {
                if(current!=epoch || !handle || !target || !handle.gameObject.activeInHierarchy || !valid())yield break;
                body.Sample(t);
                if(t>=.4f && !effect) {
                    if(animator)animator.speed=1f;
                    animator?.CrossFadeInFixedTime(second?"Cast2":"Cast",.04f,0,0);
                    effect=new GameObject(isExecutor ? (second ? "ExecutorCountermark" : "ExecutorNibStroke") : isScribe?"InkNibStroke":"BearerPalmImpulse");
                    effect.AddComponent<EnemyAuthoredBurstTier20260919>();
                    var line=effect.AddComponent<LineRenderer>();
                    effectMaterial=new Material(Shader.Find("Sprites/Default"));line.sharedMaterial=effectMaterial;
                    ownedEffect=effect;ownedMaterial=effectMaterial;
                    line.positionCount=2;line.useWorldSpace=true;line.numCapVertices=4;
                    line.startColor=isExecutor ? new Color(.95f,.72f,.30f,.9f) : isScribe?new Color(.50f,.20f,.77f,.9f):new Color(.95f,.69f,.30f,.8f);
                    line.endColor=new Color(.95f,.85f,1,.7f);
                    line.startWidth=isScribe?.14f:.27f;line.endWidth=.015f;
                }
                if(effect) {
                    var line=effect.GetComponent<LineRenderer>();
                    var start=handle.EnemyRoot.position+Vector3.up*1.25f;
                    if(executorPen)start=executorPen.position;
                    var end=target.position+Vector3.up*.95f;
                    float p=Mathf.Clamp01((t-.4f)/.6f);
                    var head=Vector3.Lerp(start,end,p);
                    if(isExecutor && second) head += Vector3.up * Mathf.Sin(p*Mathf.PI)*.45f;
                    line.SetPosition(0,Vector3.Lerp(start,head,.72f));line.SetPosition(1,head);
                    effect.GetComponent<EnemyAuthoredBurstTier20260919>().Draw(isExecutor?EnemyAuthoredBurstTier20260919.Motif.Executor:isScribe?EnemyAuthoredBurstTier20260919.Motif.Scribe:EnemyAuthoredBurstTier20260919.Motif.Bearer,t,start,end,second);
                    // The sculpted nib/hook now supplies the trail; do not overlay
                    // a ruler-straight bright line over its material detail.
                    line.enabled=false;
                    effect.SetActive(t<1.5f);
                }
                if(!hit && t>=1f){hit=true;contact?.Invoke();}
                yield return null;
            }
        } finally {
            if(effect==ownedEffect)ClearEffect();else{if(ownedEffect)Destroy(ownedEffect);if(ownedMaterial)Destroy(ownedMaterial);}
            if(current==epoch){if(body)body.Stop();if(animator)animator.speed=previousSpeed;}
            if(animator && handle && handle.gameObject.activeInHierarchy && current==epoch)animator.CrossFadeInFixedTime("Meshy · Idle",.10f,0,0);
        }
    }
    void ClearEffect(){if(effect)Destroy(effect);if(effectMaterial)Destroy(effectMaterial);effect=null;effectMaterial=null;}
    public void Cancel(){epoch++;ClearEffect();if(body)body.Stop();var animator=GetComponentInChildren<Animator>(true);if(animator)animator.speed=1;}
    void OnDisable(){Cancel();}
}
