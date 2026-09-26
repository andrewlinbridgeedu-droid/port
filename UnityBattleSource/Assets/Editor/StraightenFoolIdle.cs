using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class StraightenFoolIdle
{
    public static void Apply()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        var actor=GameObject.Find("Fool_Imported");var animator=actor.GetComponent<Animator>();
        var targetController=(AnimatorController)animator.runtimeAnimatorController;
        animator.runtimeAnimatorController=AssetDatabase.LoadAssetAtPath<RuntimeAnimatorController>("Assets/Generated/FoolBattle.controller");
        animator.Rebind();animator.Play("Meshy · Idle",0,0);animator.Update(.05f);
        var pose=new HumanPose();var handler=new HumanPoseHandler(animator.avatar,actor.transform);handler.GetHumanPose(ref pose);
        var names=HumanTrait.MuscleName;
        for(int i=0;i<names.Length;i++)
        {
            string name=names[i];
            if(name.StartsWith("Spine") || name.StartsWith("Chest") || name.StartsWith("UpperChest") || name.StartsWith("Neck") || name.StartsWith("Head"))pose.muscles[i]=0;
        }
        for(int i=0;i<names.Length;i++)
        {
            if(!names[i].StartsWith("Left"))continue;
            int right=Array.IndexOf(names,"Right"+names[i].Substring(4));if(right<0)continue;
            float average=(pose.muscles[i]+pose.muscles[right])*.5f;
            pose.muscles[i]=average;pose.muscles[right]=average;
        }
        // Relax the clavicles and lower the guard so the collar does not crowd the neck.
        for (int i = 0; i < names.Length; i++)
        {
            if (names[i].EndsWith("Shoulder Front-Back")) pose.muscles[i] = 0f;
            if (names[i].EndsWith("Shoulder Down-Up")) pose.muscles[i] = -.4f;
            if (names[i].EndsWith("Arm Down-Up")) pose.muscles[i] = -.45f;
        }
        const string path="Assets/Resources/RuntimeModels/FoolRefined/FoolCenteredIdle.anim";
        var clip=AssetDatabase.LoadAssetAtPath<AnimationClip>(path);
        if(!clip){clip=new AnimationClip();AssetDatabase.CreateAsset(clip,path);}else clip.ClearCurves();
        clip.name="Fool centered breathing idle";clip.frameRate=30;
        for(int i=0;i<names.Length;i++)
        {
            float value=pose.muscles[i];float breath=names[i]=="Chest Front-Back"?.012f:0;
            var curve=new AnimationCurve(new Keyframe(0,value),new Keyframe(2,value+breath),new Keyframe(4,value));
            for(int k=0;k<curve.length;k++)AnimationUtility.SetKeyLeftTangentMode(curve,k,AnimationUtility.TangentMode.ClampedAuto);
            clip.SetCurve("",typeof(Animator),names[i],curve);
        }
        // Center the hips and keep the body axis upright throughout the loop.
        float height=pose.bodyPosition.y;
        foreach(var item in new[]{("RootT.x",0f),("RootT.y",height),("RootT.z",0f),("RootQ.x",0f),("RootQ.y",0f),("RootQ.z",0f),("RootQ.w",1f)})
            clip.SetCurve("",typeof(Animator),item.Item1,AnimationCurve.Constant(0,4,item.Item2));
        var settings=AnimationUtility.GetAnimationClipSettings(clip);settings.loopTime=true;settings.loopBlend=true;settings.heightFromFeet=true;settings.keepOriginalPositionY=false;settings.loopBlendPositionY=true;settings.loopBlendPositionXZ=true;settings.loopBlendOrientation=true;AnimationUtility.SetAnimationClipSettings(clip,settings);
        var controller=targetController;
        var idle=controller.layers[0].stateMachine.states.First(s=>s.state.name=="Meshy · Idle").state;idle.motion=clip;idle.speed=1;idle.iKOnFeet=false;
        EditorUtility.SetDirty(idle);EditorUtility.SetDirty(clip);AssetDatabase.SaveAssets();handler.Dispose();
        Debug.Log("Centered symmetrical Fool idle installed; attack state preserved.");
    }
}
