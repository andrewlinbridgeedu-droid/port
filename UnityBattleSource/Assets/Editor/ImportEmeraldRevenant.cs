#if UNITY_EDITOR
using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
using Object = UnityEngine.Object;

/// Imports the approved 3.glb rework with seven Blender-baked combat clips.
public static class ImportEmeraldRevenant
{
    const string Root = "Assets/Resources/Enemies/EmeraldRevenant/";
    const string ModelPath = Root + "EmeraldRevenant.fbx";
    const string PrefabPath = Root + "EmeraldRevenantActor.prefab";
    static readonly string[] Names = {"EmeraldIdle","EmeraldCharge","EmeraldCast","EmeraldHit","EmeraldDeath","EmeraldCharge2","EmeraldCast2"};
    static readonly int[] Starts = {0,61,104,135,147,178,221};
    static readonly int[] Ends = {60,103,134,146,177,220,251};

    [MenuItem("Mindstone/Import Emerald Revenant")]
    public static void Import()
    {
        AssetDatabase.Refresh();
        var importer = AssetImporter.GetAtPath(ModelPath) as ModelImporter;
        if (importer == null) throw new Exception("Missing approved Emerald model: " + ModelPath);
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.importAnimation = true; importer.isReadable = true;
        importer.importCameras = false; importer.importLights = false;
        importer.optimizeGameObjects = false;
        importer.animationCompression = ModelImporterAnimationCompression.Off;
        importer.SaveAndReimport();
        var takes = importer.defaultClipAnimations;
        if (takes.Length == 0) throw new Exception("Emerald combat timeline is missing");
        var origin = takes[0].firstFrame;
        importer.clipAnimations = Names.Select((name,i) => new ModelImporterClipAnimation {
            name=name, takeName=takes[0].takeName, firstFrame=origin+Starts[i], lastFrame=origin+Ends[i],
            loopTime=i==0, loopPose=i==0, keepOriginalOrientation=true,
            keepOriginalPositionXZ=true, keepOriginalPositionY=true,
            lockRootRotation=true, lockRootPositionXZ=true, lockRootHeightY=true
        }).ToArray();
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(ModelPath).OfType<AnimationClip>()
            .Where(c => !c.name.StartsWith("__")).ToArray();
        foreach (var name in Names) {
            var clip=clips.Single(c=>c.name==name);
            if (clip.length<=0 || AnimationUtility.GetCurveBindings(clip).Length==0) throw new Exception("Empty Emerald clip "+name);
            Debug.Log($"EMERALD_CLIP {name} {clip.length:F3}s");
        }
        ConfigureTexture("Emerald_BaseColor.png",false,true,4096);
        ConfigureTexture("Emerald_Normal.png",true,false,2048);
        ConfigureTexture("Emerald_MetallicSmoothness.png",false,false,2048);
        var body=MaterialAt("EmeraldRevenantMaterial.mat");
        body.color=Color.white;
        body.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>(Root+"Textures/Emerald_BaseColor.png");
        body.SetTexture("_BumpMap",AssetDatabase.LoadAssetAtPath<Texture2D>(Root+"Textures/Emerald_Normal.png"));
        body.EnableKeyword("_NORMALMAP");body.SetFloat("_BumpScale",.5f);
        body.SetTexture("_MetallicGlossMap",AssetDatabase.LoadAssetAtPath<Texture2D>(Root+"Textures/Emerald_MetallicSmoothness.png"));
        body.EnableKeyword("_METALLICGLOSSMAP");body.SetFloat("_GlossMapScale",.72f);
        body.DisableKeyword("_EMISSION");
        var eyes=Emissive("EmeraldEyes.mat",new Color(.01f,.23f,.035f),new Color(.01f,1f,.1f)*1.8f);
        var core=Emissive("EmeraldChestCore.mat",new Color(.002f,.12f,.012f),new Color(.002f,.60f,.025f)*2f);
        var actor=Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(ModelPath));actor.name="EmeraldRevenantActor";
        foreach(var renderer in actor.GetComponentsInChildren<Renderer>(true)) {
            renderer.sharedMaterial=renderer.name=="EncoreCore" ? core :
                renderer.name=="EyeR" || renderer.name=="EyeL" ? eyes : body;
            if(renderer is SkinnedMeshRenderer skin) skin.updateWhenOffscreen=true;
        }
        var controllerPath=Root+"EmeraldRevenantCast.controller";
        var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath)
            ?? AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
        var machine=controller.layers[0].stateMachine;
        foreach(var state in machine.states) machine.RemoveState(state.state);
        foreach(var name in Names) {
            var state=machine.AddState(name);state.motion=clips.Single(c=>c.name==name);state.speed=1;
            if(name=="EmeraldIdle") machine.defaultState=state;
        }
        var animator=actor.GetComponentInChildren<Animator>(true);
        if(animator==null) throw new Exception("Emerald actor has no Animator");
        animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;
        PrefabUtility.SaveAsPrefabAsset(actor,PrefabPath);Object.DestroyImmediate(actor);
        EditorUtility.SetDirty(body);EditorUtility.SetDirty(controller);
        AssetDatabase.SaveAssets();
        Debug.Log("EMERALD_REWORK_IMPORT_OK");
    }
    static void ConfigureTexture(string name,bool normal,bool srgb,int size) {
        var importer=AssetImporter.GetAtPath(Root+"Textures/"+name) as TextureImporter;
        if(importer==null) throw new Exception("Missing Emerald texture "+name);
        importer.textureType=normal ? TextureImporterType.NormalMap : TextureImporterType.Default;
        importer.sRGBTexture=srgb;importer.maxTextureSize=size;importer.mipmapEnabled=true;importer.SaveAndReimport();
    }
    static Material MaterialAt(string name) {
        var material=AssetDatabase.LoadAssetAtPath<Material>(Root+name);
        if(!material) {material=new Material(Shader.Find("Standard"));AssetDatabase.CreateAsset(material,Root+name);}
        return material;
    }
    static Material Emissive(string name,Color color,Color emission) {
        var material=MaterialAt(name);material.mainTexture=null;material.color=color;
        material.SetFloat("_Metallic",0);material.SetFloat("_Glossiness",.65f);
        material.SetColor("_EmissionColor",emission);material.EnableKeyword("_EMISSION");
        EditorUtility.SetDirty(material);return material;
    }
}
#endif
