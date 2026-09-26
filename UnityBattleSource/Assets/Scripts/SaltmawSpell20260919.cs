using System;
using System.Collections.Generic;
using Effekseer;
using UnityEngine;

// Visual clock only. The encounter owns damage and the contact deadline.
[DefaultExecutionOrder(1800)]
public sealed class SaltmawSpell20260919 : MonoBehaviour
{
    sealed class Joint { public Transform t; public Quaternion rotation; public Vector3 scale; }
    readonly Dictionary<string,Joint> joints = new Dictionary<string,Joint>();
    readonly List<EffekseerHandle> effects = new List<EffekseerHandle>();
    EnemyHandle actor; Func<Vector3> target; float age, contact, pulse; bool held, poison, released, impacted, restored;
    SaltmawRadiance20260919 radiance; TowerSaltVfxRound2 folded; TowerRigRound2 rig; readonly List<Material> ownedMaterials=new List<Material>();
    Transform spike; Vector3 launch; EffekseerHandle gather, travel;
    public static SaltmawSpell20260919 Create(EnemyHandle actor,string intent,Func<Vector3> target,float contact,Transform owner)
    {
        var go=new GameObject("D02 salt organ spell");go.transform.SetParent(owner,false);
        var v=go.AddComponent<SaltmawSpell20260919>();v.actor=actor;v.target=target;v.contact=contact;
        v.held=intent.Contains("charge");v.poison=intent=="tower_poison";v.rig=new TowerRigRound2(actor.VisualRoot,v.gameObject);
        foreach(var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))
            if(t.name=="Pelvis"||t.name=="Chest"||t.name=="Neck"||t.name=="Head"||t.name.StartsWith("Sac.")||t.name.StartsWith("UpperArm.")||t.name.StartsWith("Forearm."))
                v.joints[t.name]=new Joint{t=t,rotation=t.localRotation,scale=t.localScale};
        var prefab=Resources.Load<GameObject>("ChurchSpellArt/SaltSpike");
        if(prefab&&!v.held&&!v.poison){v.spike=new GameObject("Physical salt fang").transform;v.spike.SetParent(go.transform,false);Instantiate(prefab,v.spike,false);v.spike.gameObject.SetActive(false);}
        if(!v.poison&&!v.held){v.radiance=go.AddComponent<SaltmawRadiance20260919>();v.radiance.Build();}
        v.folded=TowerSaltVfxRound2.Create(actor,go.transform);
        if(v.spike)foreach(var r in v.spike.GetComponentsInChildren<Renderer>()){var m=new Material(r.sharedMaterial);m.color=new Color(.34f,.62f,.55f);m.EnableKeyword("_EMISSION");m.SetColor("_EmissionColor",new Color(.018f,.07f,.06f));m.SetFloat("_Glossiness",.64f);m.SetFloat("_Metallic",.12f);r.sharedMaterial=m;v.ownedMaterials.Add(m);}
        v.gather=v.Play("Gather",v.Mouth(),.75f);
        return v;
    }
    EffekseerHandle Play(string name,Vector3 point,float scale)
    {
        var asset=Resources.Load<EffekseerEffectAsset>("ChurchSpellArt/SaltmawEffekseer/"+name);
        if(!asset){Debug.LogError("D02 missing Effekseer "+name);return default;}
        var p=EffekseerPlayEffectParameters.Create(point);p.SetScale(Vector3.one*scale*(name=="CorrosiveMist"?.36f:name=="Gather"?.24f:.32f));
        var h=EffekseerSystem.PlayEffect(asset,p);h.SetAllColor(name=="CorrosiveMist"?new Color(.22f,.55f,.07f,.28f):new Color(.55f,.85f,.22f,.62f));effects.Add(h);return h;
    }
    Vector3 Mouth(){return joints.TryGetValue("Head",out var j)?j.t.position+actor.EnemyRoot.forward*.16f:actor.EffectAnchor.position;}
    public void Tick(float t){age=Mathf.Max(0,t);}
    void Update(){if(!restored)rig?.Reset();}
    void LateUpdate()
    {
        if(restored||!actor||!actor.gameObject.activeInHierarchy)return;
        if(held)age+=Time.deltaTime;
        rig.Capture();
        float recover=held?1:1-TowerRigRound2.Ease((age-contact-.10f)/.34f);
        float wind=TowerRigRound2.Ease(age/.24f)*recover*(held?.90f+.045f*Mathf.Sin(age*4):1);
        float snap=held?0:TowerRigRound2.Ease((age-.24f)/Mathf.Max(.01f,contact-.24f))*recover;
        float crouch=wind*(1-.65f*snap);
        Pose("Thigh.L",new Vector3(-18*crouch,-4*wind,0));Pose("Thigh.R",new Vector3(-24*crouch,6*wind,0));
        Pose("Shin.L",new Vector3(23*crouch,0,0));Pose("Shin.R",new Vector3(30*crouch,0,0));
        Pose("Foot.L",new Vector3(-6*crouch,0,0));Pose("Foot.R",new Vector3(-8*crouch,0,0));
        rig.ShiftWorld("Pelvis",Vector3.down*(.035f*crouch));
        Pose("Pelvis",new Vector3(0,(poison?-8:12)*wind,0));
        Pose("Chest",new Vector3(-20*wind+28*snap,(poison?-14:24)*wind-(poison?-10:18)*snap,-9*wind));
        Pose("Neck",new Vector3(-23*wind+34*snap,5*wind,0));
        Pose("Head",new Vector3(8*wind-11*snap,0,0));
        Pose("UpperArm.L",new Vector3(-24*wind+18*snap,poison?0:18*wind,-32*wind));Pose("UpperArm.R",new Vector3(-16*wind+28*snap,poison?0:-25*wind,38*wind));
        Pose("Forearm.L",new Vector3(-22*wind,0,0));Pose("Forearm.R",new Vector3(-35*wind+22*snap,0,0));
        rig.Scale("Sac.L",Vector3.one*(1+.16f*wind-.13f*snap));rig.Scale("Sac.R",Vector3.one*(1+.13f*wind-.10f*snap));
        if(poison&&!held){
            float inhale=TowerRigRound2.Ease(age/.18f)*(1-TowerRigRound2.Ease((age-.22f)/.23f));
            float exhale=Mathf.SmoothStep(0,1,(age-.18f)/.20f)*(1-Mathf.SmoothStep(0,1,(age-contact-.12f)/.35f));
            Pose("Chest",new Vector3(-28*inhale+24*exhale,-8*inhale,0));
            Pose("Neck",new Vector3(-30*inhale+42*exhale,0,0));
            Pose("Head",new Vector3(10*inhale-20*exhale,0,0));
            Pose("UpperArm.L",new Vector3(-35*inhale+10*exhale,0,-28*exhale));
            Pose("UpperArm.R",new Vector3(-35*inhale+10*exhale,0,28*exhale));
            rig.Scale("Sac.L",Vector3.one+new Vector3(.22f,.17f,.20f)*inhale-new Vector3(.10f,.14f,.08f)*exhale);
            rig.Scale("Sac.R",Vector3.one+new Vector3(.18f,.22f,.15f)*inhale-new Vector3(.13f,.09f,.10f)*exhale);
        }
        var mouth=Mouth();gather.SetLocation(mouth);
        var endPoint=target();var tipPoint=released?Vector3.Lerp(launch,endPoint,Mathf.Clamp01((age-.24f)/Mathf.Max(.01f,contact-.24f))):mouth;
        if(radiance)radiance.Draw(mouth,tipPoint,endPoint,age,contact,held,poison);
        if(folded)folded.Draw(mouth,tipPoint,endPoint,age,contact,held,poison);
        if(held){pulse+=Time.deltaTime;if(pulse>.48f){pulse=0;gather.Stop();gather=Play("Gather",mouth,.75f);}return;}
        if(!released&&age>=.24f){released=true;launch=mouth;gather.Stop();travel=Play(poison?"CorrosiveMist":"Gather",mouth,poison?1.45f:.55f);}
        if(released){float q=Mathf.Clamp01((age-.24f)/Mathf.Max(.01f,contact-.24f));var end=target();var p=Vector3.Lerp(launch,end,q)+Vector3.up*Mathf.Sin(q*Mathf.PI)*.20f;travel.SetLocation(p);
            if(spike){spike.gameObject.SetActive(age<contact);spike.position=p;float turn=25+245*Mathf.SmoothStep(0,1,q);spike.rotation=Quaternion.FromToRotation(Vector3.up,(end-launch).normalized)*Quaternion.Euler(0,turn,Mathf.Lerp(12,2,q));spike.localScale=new Vector3(.52f,.92f,.49f);float glint=Mathf.Pow(Mathf.Sin(q*Mathf.PI),3);foreach(var m in ownedMaterials)m.SetColor("_EmissionColor",new Color(.018f,.07f,.06f)+new Color(.035f,.13f,.11f)*glint);}
            if(!impacted&&age>=contact){impacted=true;travel.Stop();Play(poison?"CorrosiveMist":"CrystalImpact",end,poison?1.9f:1.4f);}
        }
    }
    void Pose(string n,Vector3 e){rig.Rotate(n,e);}
    public void Restore(){if(restored)return;restored=true;foreach(var h in effects)h.Stop();effects.Clear();rig?.Reset();if(folded)folded.Hide();}
    void OnDisable(){Restore();} void OnDestroy(){Restore();foreach(var m in ownedMaterials)if(m)Destroy(m);}
}
