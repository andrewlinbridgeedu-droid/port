using System;
using System.Collections;
using UnityEngine;

// Stonehide uses its own bent-arm creature rig and planted-foot double slam.
// This presentation owns no damage; contact is reported once to the native rules.
public sealed class StonehidePresentation20260917 : MonoBehaviour
{
    const bool isConvoy=true;
    public float targetWorldHeight=2.65f;
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
    public void SetDefensivePhase(string phase) {
        Cancel(); var animator=GetComponentInChildren<Animator>(true); if(!animator)return;
        animator.speed=1;
        if(phase=="guard"||phase=="charge"){var h=GetComponent<EnemyHandle>();effect=new GameObject("Stonehide shell phase");var art=ChurchSpellVisual20260917.Create("stonehide",phase,h.EnemyRoot.position+Vector3.up*(1.3f*h.EnemyRoot.lossyScale.y),()=>h.EffectAnchor.position,1);art.transform.SetParent(effect.transform,true);art.ambient=true;}

        if(phase=="guard") { TowerBodyRound2.Create(GetComponent<EnemyHandle>(),"stonehide","guard",1,effect.transform); StartCoroutine(BreatheDefense(animator,"Charge2",epoch)); }
        else if(phase=="charge") { TowerBodyRound2.Create(GetComponent<EnemyHandle>(),"stonehide","charge",1,effect.transform); StartCoroutine(BreatheDefense(animator,"Charge",epoch)); }
        else animator.CrossFadeInFixedTime("Meshy · Idle",.15f,0,0);
    }
    IEnumerator BreatheDefense(Animator animator,string state,int token){
        float t=0;while(token==epoch&&animator){t+=Time.deltaTime;animator.speed=0;animator.Play(state,0,.93f+.035f*Mathf.Sin(t*2.8f));animator.Update(0);yield return null;}
    }
    GameObject effect;
    Material material;
    int epoch, casts;
    public IEnumerator Strike(EnemyHandle handle, Transform target, Action contact, Func<bool> valid)
    {
        Cancel(); int token=epoch; GameObject ownedEffect=null; Material ownedMaterial=null; bool second=(casts++ & 1)!=0; bool hit=false;
        var animator=handle.GetComponentInChildren<Animator>(true);
        float oldSpeed=animator?animator.speed:1;
        try {
            if(animator)animator.speed=3.5f;
            animator?.CrossFadeInFixedTime(second?"Charge2":"Charge",.06f,0,0);
            effect=new GameObject(second?"StonehideGroundSlam":"StonehideGroundSlam");
            material=new Material(Shader.Find("Sprites/Default"));ownedEffect=effect;ownedMaterial=material;
            var art=ChurchSpellVisual20260917.Create("stonehide","slam",handle.EnemyRoot.position,()=>target.position,1f);art.transform.SetParent(effect.transform,true);
            var gesture=TowerBodyRound2.Create(handle,"stonehide","slam",1,effect.transform);
            for(float t=0;t<2.5f;t+=Time.deltaTime){
                if(token!=epoch||!handle||!handle.gameObject.activeInHierarchy||!valid())yield break;
                if(t>=.4f&&animator&&animator.speed!=1){animator.speed=1;animator.CrossFadeInFixedTime(second?"Cast2":"Cast",.04f,0,0);}
                var start=handle.EnemyRoot.position+Vector3.up*(1.8f*handle.EnemyRoot.lossyScale.y);
                var end=target.position+Vector3.up*(isConvoy?.06f:.9f);
                float flight=Mathf.Clamp01((t-.4f)/.6f);
                var center=isConvoy?end:Vector3.Lerp(start,end,flight);
                gesture.Tick(t);art.Tick(t);
                if(!hit&&t>=1){hit=true;contact?.Invoke();}
                yield return null;
            }
        } finally {if(effect==ownedEffect)Clear();else{if(ownedEffect)Destroy(ownedEffect);if(ownedMaterial)Destroy(ownedMaterial);}if(animator&&token==epoch){animator.speed=oldSpeed;if(handle&&handle.gameObject.activeInHierarchy)animator.CrossFadeInFixedTime("Meshy · Idle",.1f,0,0);}}
    }
    public void Cancel(){epoch++;Clear();var a=GetComponentInChildren<Animator>(true);if(a)a.speed=1;}
    // Q20 withdraws alive; the director owns visibility and the five-cycle rule.
    public void BeginRetreat(){Cancel();GetComponentInChildren<Animator>(true)?.CrossFadeInFixedTime("Retreat",.08f,0,0);}
    void Clear(){if(effect){foreach(var g in effect.GetComponentsInChildren<TowerBodyRound2>()){g.Restore();g.enabled=false;}Destroy(effect);}if(material)Destroy(material);effect=null;material=null;}
    void OnDisable(){Cancel();}
}
