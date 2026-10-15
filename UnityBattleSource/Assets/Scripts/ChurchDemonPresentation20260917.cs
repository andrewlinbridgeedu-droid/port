using System;
using System.Collections;
using UnityEngine;

// Each species uses its independently authored creature skeleton and organ clips.
// This presentation owns no damage; contact is reported once to the native rules.
public sealed class ChurchDemonPresentation20260917 : MonoBehaviour
{
    public string species;
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
    int epoch;
    GameObject effect;
    Material lineMaterial;
    Vector3 savedHome;
    Transform movingRoot;
    public static bool IsPreparation(string intent) => ((intent.StartsWith("tower_copperback_")||intent.StartsWith("tower_brute_")||intent.StartsWith("tower_veil_")||intent.StartsWith("tower_throat_")||intent.StartsWith("tower_moonfang_")) && intent.Contains("charge")) || intent=="recover" || intent=="tower_sac_charge" || intent=="tower_mend_charge" || intent=="tower_blade_charge" || intent=="tower_raised_blade" || intent=="tower_crown_charge" || intent=="tower_claw_charge";
    public void Prepare(string intent) {
        // A walking minion reaches its slot before it winds up (tower packs, 2026-10-03).
        TowerMinionApproach20261003.Arrive(GetComponent<EnemyHandle>());
        Cancel();var a=GetComponentInChildren<Animator>(true);if(!a)return;
        if(intent=="recover"){a.CrossFadeInFixedTime("Meshy · Idle",.12f,0,0);return;}
        effect=new GameObject("Church charge organs");var handle=GetComponent<EnemyHandle>();if(ChurchMinionVfx20260921.Handles(species)){ChurchMinionVfx20260921.Create(handle,species,intent,()=>handle.EffectAnchor.position,1,effect.transform);MinionActingRound220260922.Create(handle,species,intent,1,effect.transform);string clip=intent.EndsWith("charge2")?"Charge2":"Charge";a.CrossFadeInFixedTime(clip,.10f,0,0);StartCoroutine(HoldCharge(a,clip,epoch));return;}if(TowerSupportRound2.Handles(species)){TowerSupportRound2.Create(handle,intent,()=>handle.EffectAnchor.position,1,effect.transform);return;}if(species=="saltmaw"){SaltmawSpell20260919.Create(handle,intent,()=>handle.EffectAnchor.position,1,effect.transform);return;}if(species=="ironclaw"){IronclawSpell20260918.Create(handle,intent,()=>handle.EffectAnchor.position,1,effect.transform);return;}var art=ChurchSpellVisual20260917.Create(species,intent,handle.EnemyRoot.position+Vector3.up*(targetWorldHeight*.75f*handle.EnemyRoot.lossyScale.y),()=>handle.EffectAnchor.position,1);art.transform.SetParent(effect.transform,true);art.ambient=true;
        if(species=="boneclaw")TowerBodyRound2.Create(handle,"boneclaw",intent,1,effect.transform);
        string state=intent=="tower_raised_blade"?"Charge2":"Charge";
        a.CrossFadeInFixedTime(state,.10f,0,0);StartCoroutine(HoldCharge(a,state,epoch));
    }
    IEnumerator HoldCharge(Animator a,string state,int token){
        yield return new WaitForSeconds(1.45f);
        // Keep the loaded tendons breathing instead of freezing the creature.
        // Cancellation restores animator speed before any attack/idle transition.
        float held=0;
        while(token==epoch && a){held+=Time.deltaTime;a.speed=0;a.Play(state,0,.92f+.045f*Mathf.Sin(held*3.2f));a.Update(0);yield return null;}
    }
    public IEnumerator Act(EnemyHandle actor, Func<Vector3> target, string intent, Action contact, Func<bool> valid, Action cancelled=null) {
        TowerMinionApproach20261003.Arrive(actor);
        Cancel();int token=epoch;var a=GetComponentInChildren<Animator>(true);
        bool second=(ChurchMinionVfx20260921.Handles(species)&&intent.EndsWith("second"))||intent=="tower_salt_spike"||intent=="tower_short_pounce"||intent=="tower_cut_second"||intent=="tower_heavy_cut"||intent=="tower_sound_arrow"||intent=="tower_tail_sweep"||intent=="tower_heavy_claw";
        a?.CrossFadeInFixedTime(second?"Cast2":"Cast",.04f,0,0);
        bool support=intent=="tower_mend"||intent=="tower_empower";
        bool pounce=intent=="tower_short_pounce";
        bool hit=false;float contactTime=ChurchMinionVfx20260921.Handles(species)?.5f:.65f;
        if(intent=="tower_cut_first"||intent=="tower_cut_second")contactTime=.35f;
        effect=new GameObject("ChurchDemon_"+intent);lineMaterial=new Material(Shader.Find("Sprites/Default"));var owned=effect;var ownedMat=lineMaterial;
        var start=actor.EnemyRoot.position+Vector3.up*(species=="saltmaw"||species=="frilled-naga"?targetWorldHeight*.85f:targetWorldHeight*.55f)*actor.EnemyRoot.lossyScale.y;
        ChurchSpellVisual20260917 art=null;IronclawSpell20260918 directed=null;SaltmawSpell20260919 salt=null;TowerSupportRound2 organ=null;
        ChurchMinionVfx20260921 minion=null;
        MinionActingRound220260922 acting=null;
        if(ChurchMinionVfx20260921.Handles(species))minion=ChurchMinionVfx20260921.Create(actor,species,intent,target,contactTime,effect.transform);
        else if(species=="saltmaw")salt=SaltmawSpell20260919.Create(actor,intent,target,contactTime,effect.transform);
        else if(species=="ironclaw")directed=IronclawSpell20260918.Create(actor,intent,target,contactTime,effect.transform);
        else if(TowerSupportRound2.Handles(species))organ=TowerSupportRound2.Create(actor,intent,target,contactTime,effect.transform);
        else {art=ChurchSpellVisual20260917.Create(species,intent,start,target,contactTime);art.transform.SetParent(effect.transform,true);}
        var boneGesture=species=="boneclaw"?TowerBodyRound2.Create(actor,"boneclaw",intent,contactTime,effect.transform):null;
        if(minion)acting=MinionActingRound220260922.Create(actor,species,intent,contactTime,effect.transform);
        savedHome=actor.EnemyRoot.position;movingRoot=pounce?actor.EnemyRoot:null;
        try {
            for(float t=0;t<1.25f;t+=Time.deltaTime){
                if(token!=epoch)yield break;
                if(!actor||!actor.gameObject.activeInHierarchy||!valid()){cancelled?.Invoke();yield break;}
                if(minion && a && a.isActiveAndEnabled){
                    // Compress the authored wind-up into the projectile release,
                    // then preserve its follow-through. A leaping double slam
                    // instead reaches its striking pose on the landing contact.
                    // Only the visual clip is sampled; the .5s contact stays below.
                    float release=species=="crimson-brute"&&second?contactTime:second?.23f:.18f;
                    float pose=t<release?Mathf.Lerp(0,.50f,Mathf.Clamp01(t/release)):
                        Mathf.Lerp(.50f,.995f,Mathf.SmoothStep(0,1,Mathf.Clamp01((t-release)/.65f)));
                    a.speed=0;a.Play(second?"Cast2":"Cast",0,pose);a.Update(0);
                }
                var end=target();float flight=Mathf.Clamp01(t/contactTime);var center=Vector3.Lerp(start,end,flight);float fade=t<contactTime?1:Mathf.Clamp01(1-(t-contactTime)/.45f);
                if(pounce && movingRoot){float q=t<contactTime?Mathf.Sin(flight*Mathf.PI*.5f):Mathf.Clamp01(1-(t-contactTime)/.55f);var direction=end-savedHome;direction.y=0;movingRoot.position=savedHome+direction.normalized*(q*1.15f)+Vector3.up*Mathf.Sin(q*Mathf.PI)*.12f;}
                if(minion)minion.Tick(t);if(acting)acting.Tick(t);if(organ)organ.Tick(t);if(boneGesture)boneGesture.Tick(t);if(art)art.Tick(t);if(directed)directed.Tick(t);if(salt)salt.Tick(t);
                if(!hit&&t>=contactTime){hit=true;contact?.Invoke();}
                yield return null;
            }
        } finally {
            if(movingRoot&&token==epoch){movingRoot.position=savedHome;movingRoot=null;}
            if(effect==owned)Clear();else{if(owned)Destroy(owned);if(ownedMat)Destroy(ownedMat);}
            if(a&&token==epoch){a.speed=1;if(actor&&actor.gameObject.activeInHierarchy)a.CrossFadeInFixedTime("Meshy · Idle",.10f,0,0);}
        }
    }
    public void Cancel(){epoch++;StopAllCoroutines();if(movingRoot){movingRoot.position=savedHome;movingRoot=null;}Clear();var a=GetComponentInChildren<Animator>(true);if(a){a.speed=1;if(ChurchMinionVfx20260921.Handles(species)&&a.isActiveAndEnabled)a.Play("Meshy · Idle",0,0);}}
    void Clear(){if(effect){foreach(var v in effect.GetComponentsInChildren<MinionActingRound220260922>()){v.Restore();v.enabled=false;}foreach(var v in effect.GetComponentsInChildren<TowerSupportRound2>()){v.Restore();v.enabled=false;}foreach(var v in effect.GetComponentsInChildren<TowerBodyRound2>()){v.Restore();v.enabled=false;}foreach(var v in effect.GetComponentsInChildren<SaltmawSpell20260919>()){v.Restore();v.enabled=false;}foreach(var v in effect.GetComponentsInChildren<IronclawSpell20260918>()){v.Restore();v.enabled=false;}Destroy(effect);}if(lineMaterial)Destroy(lineMaterial);effect=null;lineMaterial=null;}
    void OnDisable(){Cancel();}
}
