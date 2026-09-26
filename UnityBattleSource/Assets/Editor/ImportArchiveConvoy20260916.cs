using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ImportArchiveConvoy20260916
{
    const string Folder = "Assets/Resources/Enemies/Signature/ArchiveConvoy/";
    static readonly string[] Names = {"Idle", "Charge", "Cast", "Hit", "Death", "Charge2", "Cast2", "Retreat"};
    public static void Import()
    {
        string source = Path.GetFullPath(Path.Combine(Application.dataPath, "../../ArtSource/ArchiveConvoy20260916"));
        Directory.CreateDirectory(Folder);
        foreach(var name in new[]{"ArchiveConvoy_Combat.fbx", "ArchiveConvoy_BaseColor_2k.png", "ArchiveConvoy_Normal_2k.png", "ArchiveConvoy_MetalSmooth_2k.png"}) File.Copy(Path.Combine(source,name),Folder+name,true);
        AssetDatabase.Refresh();
        string modelPath=Folder+"ArchiveConvoy_Combat.fbx";
        var importer=(ModelImporter)AssetImporter.GetAtPath(modelPath);
        importer.animationType=ModelImporterAnimationType.Generic; importer.avatarSetup=ModelImporterAvatarSetup.CreateFromThisModel;
        importer.importAnimation=true; importer.isReadable=true; importer.optimizeGameObjects=false;
        importer.importCameras=false; importer.importLights=false; importer.animationCompression=ModelImporterAnimationCompression.Off;
        importer.SaveAndReimport();
        var take=importer.defaultClipAnimations[0];
        int[] starts={0,91,134,165,177,208,251,282}, ends={90,133,164,176,207,250,281,321};
        importer.clipAnimations=Names.Select((name,i)=>new ModelImporterClipAnimation{
            name=name,takeName=take.takeName,firstFrame=take.firstFrame+starts[i],lastFrame=take.firstFrame+ends[i],
            loopTime=i==0,loopPose=i==0,keepOriginalOrientation=true,keepOriginalPositionXZ=true,keepOriginalPositionY=true,
            lockRootRotation=true,lockRootPositionXZ=true,lockRootHeightY=true
        }).ToArray();
        importer.SaveAndReimport();
        var clips=AssetDatabase.LoadAllAssetsAtPath(modelPath).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__")).ToArray();
        foreach(var name in Names) {
            var clip=clips.SingleOrDefault(c=>c.name==name);
            if(!clip || clip.length<=0 || AnimationUtility.GetCurveBindings(clip).Length==0)throw new Exception("Missing authored clip "+name);
            Debug.Log($"ARCHIVECONVOY_CLIP {name} seconds={clip.length:F3} curves={AnimationUtility.GetCurveBindings(clip).Length}");
        }
        string ctrlPath=Folder+"Combat.controller";
        var ctrl=AssetDatabase.LoadAssetAtPath<AnimatorController>(ctrlPath)??AnimatorController.CreateAnimatorControllerAtPath(ctrlPath);
        foreach(var p in ctrl.parameters)ctrl.RemoveParameter(p);
        ctrl.AddParameter("Running",AnimatorControllerParameterType.Bool);ctrl.AddParameter("Attack",AnimatorControllerParameterType.Trigger);ctrl.AddParameter("Hit",AnimatorControllerParameterType.Trigger);
        if(ctrl.layers.Length==0)ctrl.AddLayer("Base Layer");
        var layers=ctrl.layers;layers[0].defaultWeight=1;ctrl.layers=layers;
        var sm=ctrl.layers[0].stateMachine;foreach(var old in sm.states)sm.RemoveState(old.state);
        var idle=sm.AddState("Meshy · Idle");idle.motion=clips.Single(c=>c.name=="Idle");sm.defaultState=idle;
        foreach(var name in Names.Where(n=>n!="Idle")){
            var state=sm.AddState(name);state.motion=clips.Single(c=>c.name==name);
            if(name=="Hit"||name=="Cast"||name=="Cast2"){var back=state.AddTransition(idle);back.hasExitTime=true;back.exitTime=1;back.duration=.1f;}
            if(name=="Hit"){var t=sm.AddAnyStateTransition(state);t.hasExitTime=false;t.duration=.04f;t.canTransitionToSelf=false;t.AddCondition(AnimatorConditionMode.If,0,"Hit");}
        }
        var actor=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(modelPath));actor.name="ArchiveConvoy";
        var mat=AssetDatabase.LoadAssetAtPath<Material>(Folder+"IvoryBrass.mat");
        if(!mat){mat=new Material(Shader.Find("Standard"));AssetDatabase.CreateAsset(mat,Folder+"IvoryBrass.mat");}
        mat.name="ArchiveConvoy_IvoryBrass";
        mat.mainTexture=Texture("BaseColor",false,true);mat.color=Color.white;
        mat.SetTexture("_BumpMap",Texture("Normal",true,false));mat.EnableKeyword("_NORMALMAP");mat.SetFloat("_BumpScale",.7f);
        mat.SetTexture("_MetallicGlossMap",Texture("MetalSmooth",false,false));mat.EnableKeyword("_METALLICGLOSSMAP");mat.SetFloat("_GlossMapScale",.75f);
        foreach(var r in actor.GetComponentsInChildren<Renderer>(true))r.sharedMaterials=Enumerable.Repeat(mat,r.sharedMaterials.Length).ToArray();
        var animator=actor.GetComponentInChildren<Animator>(true);animator.runtimeAnimatorController=ctrl;animator.applyRootMotion=false;animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;
        foreach(var skin in actor.GetComponentsInChildren<SkinnedMeshRenderer>())skin.updateWhenOffscreen=true;
        var prefab=PrefabUtility.SaveAsPrefabAsset(actor,Folder+"Actor.prefab");UnityEngine.Object.DestroyImmediate(actor);
        var profile=AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(Folder+"VisualProfile.asset");
        if(!profile){profile=ScriptableObject.CreateInstance<EnemyVisualProfile>();AssetDatabase.CreateAsset(profile,Folder+"VisualProfile.asset");}
        profile.Configure("convoy",prefab,ctrl,new[]{new EnemyOrientationStep(EnemyOrientationAxis.Y,180)},1,EnemyFormationSlotIds.FrontCenter,Vector3.zero,new EnemyHoverConfiguration(false,0,4),new EnemyAnchorConfiguration(new Vector3(0,1,0),new Vector3(0,.02f,0),new Vector3(0,2.3f,0),new Vector3(0,1.8f,0),new Vector3(0,1.15f,0)));
        EditorUtility.SetDirty(mat);EditorUtility.SetDirty(ctrl);EditorUtility.SetDirty(profile);AssetDatabase.SaveAssets();
        AssetDatabase.SaveAssets();Debug.Log("ARCHIVECONVOY_IMPORT_OK");
    }

    static Texture2D Texture(string suffix,bool normal,bool srgb){
        string path=Folder+"ArchiveConvoy_"+suffix+"_2k.png";var t=(TextureImporter)AssetImporter.GetAtPath(path);
        t.textureType=normal?TextureImporterType.NormalMap:TextureImporterType.Default;t.sRGBTexture=srgb;t.maxTextureSize=2048;t.mipmapEnabled=true;t.SaveAndReimport();var image=AssetDatabase.LoadAssetAtPath<Texture2D>(path);if(!image || image.width>2048 || image.height>2048)throw new Exception("Invalid optimized texture "+path);return image;
    }
}
