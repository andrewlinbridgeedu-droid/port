using System;
using System.Collections;
using UnityEngine;

public sealed class MainlineGhostRound2 : MonoBehaviour
{
    int generation;GameObject effect;MainlineBodyRound2 body;
    public static MainlineGhostRound2 Get(GameObject actor){var c=actor.GetComponent<MainlineGhostRound2>();return c?c:actor.AddComponent<MainlineGhostRound2>();}
    // Both existing JSON specs: .18 windup + .72 travel, .24 impact + .42 decay.
    // secondary means presentation slot, never the ghost model's red material.
    public IEnumerator Play(bool secondary,Func<Vector3> source,Func<Vector3> target,Action contact,Func<bool> valid){
        Cancel();int token=generation;bool contacted=false;
        var owned=new GameObject(secondary?"Hooked spectral wisp":"Broken fog chime folds");effect=owned;owned.transform.SetParent(transform,false);
        var distinct=owned.AddComponent<MainlineDistinct20260925>();
        body=MainlineBodyRound2.Get(gameObject);body.Begin(MainlineBodyRound2.Pose.Ghost,secondary,.18f,.9f,1.56f);
        Vector3 frozenTarget=target();
        try{
            for(float t=0;t<1.56f;t+=Time.deltaTime){
                if(token!=generation||!gameObject.activeInHierarchy||(valid!=null&&!valid()))yield break;
                body.Sample(t);Vector3 from=source();
                if(!contacted)frozenTarget=target();
                distinct.Ghost(secondary,t,from,frozenTarget);
                if(!contacted&&t>=.9f){contacted=true;contact?.Invoke();}
                yield return null;
            }
        }finally{if(owned){owned.SetActive(false);Destroy(owned);}if(effect==owned)effect=null;if(token==generation&&body)body.Stop();}
    }
    static void Draw(MainlineSpellMeshRound2 surface,bool wisp,float t,Vector3 source,Vector3 target){
        var cam=Camera.main;Vector3 r=cam?cam.transform.right:Vector3.right,u=cam?cam.transform.up:Vector3.up;
        Vector3 f=(target-source).normalized;if(f.sqrMagnitude<.01f)f=Vector3.forward;
        float travel=Mathf.Clamp01((t-.18f)/.72f),age=Mathf.Clamp01((t-.9f)/.66f);
        float p=EnemyImpactEnvelope20260921.Sample(age);
        bool hit=t>=.9f;
        float fade=hit?Mathf.Pow(1-p,1.45f):Mathf.SmoothStep(0,1,t/.18f);
        float bloom=hit?Mathf.SmoothStep(0,1,Mathf.Clamp01((age-.115f)/.075f)):0;
        float recoil=hit?1-Mathf.SmoothStep(0,1,Mathf.Clamp01((age-.39f)/.38f)):1;
        Vector3 center=Vector3.Lerp(source,target,travel)+u*Mathf.Sin(travel*Mathf.PI)*.35f;
        surface.Begin(t,hit?Mathf.Exp(-p*8):0,wisp?3:2);
        if(!hit){
            if(wisp){
                // Violet hooks drag a dense mulberry membrane; three unequal
                // curves do not form the cyan ghost's bell or a closed halo.
                for(int i=0;i<3;i++){
                    float k=i*.31f,side=i==1?-1f:1f;
                    Vector3 tail=center-f*(1.45f+k)+r*(i-1)*.32f;
                    Vector3 tip=center+f*(.22f+k*.13f)+r*side*(.56f+i*.13f);
                    surface.RibbonContinuous(tail,tail+u*(1.05f-k)+r*side*.32f,
                        center-r*side*(.75f+k)+u*(.62f-k*.3f),tip,u+r*side*.22f,
                        .47f+i*.075f,new Color(.25f,.08f,.53f,fade*.77f),i+3);
                    surface.RibbonContinuous(tail+f*.18f,tail+u*(.68f-k*.35f)+r*side*.30f,
                        center-r*side*(.46f+k)+u*.30f,tip-f*.10f,u+r*side*.20f,
                        .17f+i*.025f,new Color(.96f,.52f,1f,fade*.94f),i+8);
                }
            }else{
                // A wide descending fog-bell with a bright cracked mouth.
                // The unequal lips and central fold stay open at the bottom.
                Vector3 a=center-r*.82f-u*.52f,b=center-r*1.02f+u*.74f;
                Vector3 c=center+r*.58f+u*1.02f,d=center+r*.98f-u*.40f;
                surface.RibbonContinuous(a,b,c,d,u,.82f,new Color(.06f,.35f,.60f,fade*.80f),2);
                surface.RibbonContinuous(a+f*.11f,b+u*.08f,c-u*.06f,d-r*.11f,u,
                    .34f,new Color(.60f,.96f,1f,fade*.95f),2.8f);
                surface.RibbonContinuous(center+u*.58f-f*.42f,center-r*.43f+u*.13f,
                    center+f*.38f-u*.63f,center-u*.98f,r,.52f,
                    new Color(.09f,.55f,.77f,fade*.79f),9);
                surface.RibbonContinuous(center-f*1.43f-u*.20f,center-f*.79f+r*.56f,
                    center-f*.22f+u*.36f,center+r*.14f+u*.15f,r+u*.4f,.34f,
                    new Color(.31f,.87f,1f,fade*.82f),5);
            }
        }else if(wisp){
            // Five hooked tears grow outward at different depths; a smaller
            // hot edge follows each hook instead of a generic radial burst.
            for(int i=0;i<5;i++){
                float h=Mathf.Repeat(i*.618034f+.21f,1),a=h*6.283f;
                Vector3 d=r*Mathf.Cos(a)+u*Mathf.Sin(a);
                float reach=(.46f+bloom*(2.25f+h*1.90f))*recoil;
                Vector3 side=Vector3.Cross(f,d).normalized;
                Vector3 end=target+d*reach-f*(.18f+h*.48f);
                Vector3 start=target+d*.08f;
                surface.RibbonContinuous(start,start+d*reach*.28f+side*.86f,
                    end+side*(i%2==0?-.67f:.38f),end,side,.36f+h*.17f,
                    new Color(.32f,.10f,.60f,fade*.85f),i+2);
                surface.RibbonContinuous(start+f*.04f,start+d*reach*.30f+side*.68f,
                    end+side*(i%2==0?-.49f:.26f),end-d*.12f,side,.12f+h*.05f,
                    new Color(1f,.70f,1f,fade*.90f),i+6);
            }
        }else{
            // Bell contact opens as three broad offset resonant lips, followed
            // by shorter translucent wisps. No circular spokes or equal rays.
            float span=(.22f+bloom*2.32f)*recoil;
            for(int i=0;i<3;i++){
                float side=i==1?-1f:1f,depth=i==0?-.20f:i==1?.14f:.36f;
                Vector3 q=target+f*depth;
                float offset=i==0?-.56f:i==1?.12f:.62f;
                surface.RibbonContinuous(q+r*(offset-.35f)*span-u*.24f,
                    q+r*(offset-.57f)*span+u*(.88f+i*.12f)*span,
                    q+r*(offset+.56f)*span+u*(.52f-i*.09f)*span,
                    q+r*(offset+.68f)*span-u*.40f*span,u,
                    (i==0?.75f:i==1?.53f:.45f)*recoil,
                    new Color(i==1?.28f:.08f,i==1?.85f:.55f,1f,fade*.81f),i+2);
            }
            surface.RibbonContinuous(target-r*.53f*span+f*.08f,target-r*.41f*span+u*.61f*span,
                target+r*.42f*span+u*.43f*span,target+r*.57f*span-u*.29f*span,u,
                .20f*recoil,new Color(.82f,1f,1f,fade*.92f),10);
        }
        surface.End();
    }
    public void Cancel(){generation++;if(body)body.Stop();if(effect){effect.SetActive(false);Destroy(effect);}effect=null;}
    void OnDisable(){Cancel();}
}
