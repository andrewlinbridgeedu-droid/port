using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

// Local preparation only: no damage flare, no gameplay callbacks, no target creation.
public sealed class MainlineStateRound2 : IDisposable
{
    static readonly HashSet<MainlineStateRound2> active=new HashSet<MainlineStateRound2>();
    bool disposed;
    EnemyHandle actor;GameObject root;MainlineSpellMeshRound2 surface;MainlineBodyRound2 body;
    Transform chest,leftWrist,rightWrist,pen;float frontOffset=.34f;
    string intent;float duration;
    public static MainlineStateRound2 Attach(EnemyHandle handle,string state,float seconds){
        var value=new MainlineStateRound2();value.actor=handle;value.intent=state;value.duration=seconds;
        if(!handle||!handle.EnemyRoot)return value;
        value.chest=Find(handle,"Chest","Spine02","Spine2","Spine01","Spine","UpperBody");
        value.leftWrist=Find(handle,"Hand.L","LeftHand","Forearm.L","LeftForeArm");
        value.rightWrist=Find(handle,"Pen.R","Hand.R","RightHand","Forearm.R","RightForeArm");
        value.pen=Find(handle,"Pen.R","Hand.R","RightHand");
        foreach(var skin in handle.GetComponentsInChildren<SkinnedMeshRenderer>())value.frontOffset=Mathf.Max(value.frontOffset,Mathf.Min(.62f,skin.bounds.size.magnitude*.12f));
        value.root=new GameObject("Mainline local "+state+" preparation");value.root.transform.SetParent(handle.EnemyRoot,false);
        value.surface=value.root.AddComponent<MainlineSpellMeshRound2>();
        value.body=MainlineBodyRound2.Get(handle.gameObject);
        bool calibration=state=="calibrate"||state=="calibration";
        value.body.Begin(calibration?MainlineBodyRound2.Pose.ScribeCalibrate:state=="fortify"?MainlineBodyRound2.Pose.ScribeFortify:MainlineBodyRound2.Pose.GuardBrace,state=="thirteenth_charge",seconds*.82f,seconds,seconds+.25f);
        active.Add(value);
        return value;
    }
    static Transform Find(EnemyHandle handle,params string[] names){
        var all=handle.GetComponentsInChildren<Transform>(true);
        foreach(var name in names)foreach(var bone in all)if(bone.name==name||bone.name.EndsWith(":"+name,StringComparison.OrdinalIgnoreCase))return bone;
        return null;
    }
    public static IEnumerator Play(EnemyHandle handle,string intent,float seconds,Func<bool> valid){
        var value=Attach(handle,intent,seconds);
        try{for(float t=0;t<seconds;t+=Time.deltaTime){if(!handle||!handle.gameObject.activeInHierarchy||(valid!=null&&!valid()))yield break;value.Sample(t);yield return null;}}
        finally{value.Dispose();}
    }
    public void Sample(float elapsed){
        if(disposed||!actor||!actor.EnemyRoot||!surface)return;
        body.Sample(elapsed);float p=Mathf.Clamp01(elapsed/Mathf.Max(.01f,duration));
        var cam=Camera.main;Vector3 right=cam?cam.transform.right:Vector3.right,up=Vector3.up;
        Vector3 front=cam?Vector3.ProjectOnPlane(cam.transform.position-actor.EnemyRoot.position,up).normalized:Vector3.back;
        Vector3 center=(chest?chest.position+up*.18f:actor.EnemyRoot.position+up*1.6f)+front*frontOffset;
        // SmoothStep's first two arguments are output values, not time bounds.
        // The old call capped this whole state at ~14% alpha even at its peak.
        float fade=Mathf.SmoothStep(0,1,p*4)*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.84f,1,p)));
        bool calibration=intent=="calibrate"||intent=="calibration";
        bool charge=intent=="thirteenth_charge";
        Color color=calibration?new Color(.66f,.20f,.92f,fade):charge?new Color(1,.53f,.10f,fade):
            intent=="guard"?new Color(.94f,.50f,.15f,fade*.95f):new Color(.96f,.72f,.28f,fade*.96f);
        // Motif 20 is calibration-only; motif 1 remains untouched for other users.
        surface.Begin(elapsed,0,calibration?20:0);
        if(calibration){
            // An inscribed curl is written by the actual pen wrist, not hidden
            // at a fixed root-space height inside the chest.
            Vector3 hand=(pen?pen.position:rightWrist?rightWrist.position:center)+front*.20f;
            Vector3 a=hand-right*.57f-up*.20f,b=hand+right*.75f+up*.43f;
            surface.RibbonContinuous(a,a+up*.48f+front*.20f,b+up*.28f-right*.28f,b,right+up*.4f,.31f,color,p*1.7f);
            surface.RibbonContinuous(hand-right*.16f-up*.16f,hand+right*.27f-up*.34f,
                hand+right*.67f+up*.16f,hand+right*.38f+up*.37f,up,.14f,
                new Color(.91f,.64f,1,fade*.86f),4);
            surface.RibbonContinuous(hand-right*.51f-up*.12f,hand-right*.20f+up*.12f,
                hand+right*.10f+up*.49f,hand+right*.28f+up*.42f,right+front*.2f,.10f,
                new Color(.26f,.065f,.49f,fade*.82f),2.7f);
            surface.End();return;
        }
        if(charge){
            // The elite folds gold heat into the sword hand, not a chest halo.
            Vector3 hand=(rightWrist?rightWrist.position:center)+front*.20f;
            surface.RibbonContinuous(hand-right*.47f-up*.19f,
                hand-right*.58f+up*.59f,hand+right*.22f+up*1.38f,
                hand+right*.56f+up*1.03f,right+front*.22f,.43f,color,1.1f);
            surface.RibbonContinuous(hand-right*.12f-up*.13f,
                hand+right*.04f+up*.48f,hand+right*.33f+up*1.22f,
                hand+right*.26f+up*1.42f,right+front*.16f,.13f,
                new Color(1,.84f,.36f,fade*.89f),3.9f);
            surface.End();return;
        }
        // Guard and fortify clasp over the actual chest and two wrists.
        // Their folded metal surfaces stay local because these are statuses.
        for(int i=0;i<3;i++){
            float s=i==1?-1:1,h=i==0?.18f:i==1?.71f:.47f;
            var wrist=s>0?rightWrist:leftWrist;
            Vector3 start=(i<2&&wrist?wrist.position:center+right*s*.62f-up*.31f)+front*.25f;
            Vector3 end=center+right*s*(i==2?.15f:.35f+h*.16f)+up*(i==2?.37f:.24f+h*.14f);
            surface.RibbonContinuous(start,start+front*.28f+up*(.23f+h*.12f),
                end+right*s*.22f+up*.22f,end,right+front*.38f,
                i==2?.23f:.26f+h*.12f,color,i*2.3f+.7f);
        }
        surface.RibbonContinuous(center-right*.34f-up*.14f,center-right*.14f+up*.31f,
            center+right*.18f+up*.42f,center+right*.42f-up*.08f,up+front*.2f,.16f,
            new Color(1,.84f,.47f,fade*.82f),5.2f);
        surface.End();
    }
    public static void ClearAll(){foreach(var value in active.ToArray())value.Dispose();}
    public void Dispose(){if(disposed)return;disposed=true;active.Remove(this);if(body)body.Stop();if(root){root.SetActive(false);UnityEngine.Object.Destroy(root);}root=null;surface=null;body=null;actor=null;}
}
