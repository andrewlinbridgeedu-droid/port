#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ImportStoryEnemies20260916
{
    const string Root = "Assets/Resources/Enemies/Signature/";
    static readonly string[] Models = { "TranscriptionScribe", "RescueBearer" };
    static readonly string[] Clips = { "Idle", "Charge", "Cast", "Hit", "Death", "Charge2", "Cast2" };

    public static void ImportAndBuild() { Import(); BuildRuntimePreview.BuildMacPlayer(); }

    [MenuItem("Mindstone/Import Story Enemies 20260916")]
    public static void Import()
    {
        var sourceRoot = Path.GetFullPath(Path.Combine(Application.dataPath,"../../ArtSource"));
        for(int model=0; model<Models.Length; model++) {
            var source=Path.Combine(sourceRoot,model==0?"TranscriptionScribe20260916":"RescueBearer20260916");
            Directory.CreateDirectory(Root+Models[model]);
            foreach(var file in Directory.GetFiles(source)) {
                var name=Path.GetFileName(file);
                bool needed=name.EndsWith("_Combat.fbx") || (model==0 ? name.StartsWith("Scribe_")&&name.EndsWith("_BaseColor.png") || name=="Image_2_2k.png" : name.StartsWith("Rescue_")&&name.EndsWith("_BaseColor.png") || name=="Rescue_Normal.png");
                if(needed) {
                    var optimized=name.EndsWith("_Combat.fbx") ? Path.Combine(source,name.Replace("_Combat.fbx","_Combat_Optimized.fbx")) : null;
                    var refined=name.EndsWith("_Combat.fbx") ? Path.Combine(source,name.Replace("_Combat.fbx","_Combat_Refined.fbx")) : null;
                    File.Copy(refined!=null && File.Exists(refined)?refined:optimized!=null && File.Exists(optimized)?optimized:file,Root+Models[model]+"/"+name,true);
                }
            }
        }
        AssetDatabase.Refresh();
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        var formation = AssetDatabase.LoadAssetAtPath<EnemyFormationProfile>(Install3DAssets.FormationAssetPath);
        for (int i = 0; i < Models.Length; i++)
        {
            var folder = Root + Models[i] + "/";
            var path = folder + Models[i] + "_Combat.fbx";
            var importer = AssetImporter.GetAtPath(path) as ModelImporter;
            if (importer == null) throw new FileNotFoundException(path);
            importer.animationType = ModelImporterAnimationType.Generic;
            importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
            importer.importAnimation = true; importer.isReadable = true; importer.importCameras = false; importer.importLights = false;
            importer.optimizeGameObjects = false; // Jaw/Chest and detachable arm bones remain addressable.
            importer.animationCompression = ModelImporterAnimationCompression.Off;
            importer.SaveAndReimport();
            var defaults = importer.defaultClipAnimations;
            if (defaults.Length == 0) throw new Exception("No timeline: " + path);
            Debug.Log($"SIGNATURE_TAKE {Models[i]} {defaults[0].takeName} range={defaults[0].firstFrame}..{defaults[0].lastFrame}");
            var origin = defaults[0].firstFrame;
            var starts = i==0 ? new[]{0,91,134,165,177,208,251} : new[]{0,121,164,195,207,238,281};
            var ends = i==0 ? new[]{90,133,164,176,207,250,281} : new[]{120,163,194,206,237,280,311};
            importer.clipAnimations = Clips.Select((name, k) => new ModelImporterClipAnimation {
                name = name, takeName = defaults[0].takeName,
                firstFrame = origin + starts[k], lastFrame = origin + ends[k],
                loopTime = name == "Idle", loopPose = name == "Idle", keepOriginalOrientation = true,
                keepOriginalPositionXZ = true, keepOriginalPositionY = true,
                lockRootRotation = true, lockRootPositionXZ = true, lockRootHeightY = true
            }).ToArray();
            importer.SaveAndReimport();
            var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
            foreach (var name in Clips) {
                var clip = clips.Single(c => c.name == name);
                if (clip.length <= 0 || AnimationUtility.GetCurveBindings(clip).Length == 0) throw new Exception("Empty clip " + name);
                Debug.Log($"SIGNATURE_CLIP {Models[i]} {name} {clip.length:F3}s");
            }
            var ctrlPath = folder + "Combat.controller";
            var ctrl = AssetDatabase.LoadAssetAtPath<AnimatorController>(ctrlPath) ?? AnimatorController.CreateAnimatorControllerAtPath(ctrlPath);
            foreach (var p in ctrl.parameters) ctrl.RemoveParameter(p);
            ctrl.AddParameter("Running", AnimatorControllerParameterType.Bool);
            ctrl.AddParameter("Attack", AnimatorControllerParameterType.Trigger);
            ctrl.AddParameter("Hit", AnimatorControllerParameterType.Trigger);
            if(ctrl.layers.Length==0)ctrl.AddLayer("Base Layer");
            var layers=ctrl.layers;layers[0].defaultWeight=1;ctrl.layers=layers;
            var sm = ctrl.layers[0].stateMachine;
            foreach (var s in sm.states) sm.RemoveState(s.state);
            var idle = sm.AddState("Meshy · Idle"); idle.motion = clips.Single(c => c.name == "Idle"); sm.defaultState = idle;
            foreach (var name in Clips.Where(n => n != "Idle")) {
                var state = sm.AddState(name); state.motion = clips.Single(c => c.name == name);
                if (name == "Hit" || name == "Cast" || name == "Cast2") {
                    var back = state.AddTransition(idle); back.hasExitTime = true; back.exitTime = 1; back.duration = .1f;
                }
                if (name == "Hit") { var t = sm.AddAnyStateTransition(state); t.hasExitTime = false; t.duration = .04f; t.canTransitionToSelf = false; t.AddCondition(AnimatorConditionMode.If, 0, "Hit"); }
            }
            var attack = sm.AddState("Meshy · Attack"); attack.motion = clips.Single(c => c.name == "Cast");
            var attackTransition = idle.AddTransition(attack); attackTransition.AddCondition(AnimatorConditionMode.If, 0, "Attack"); attackTransition.duration = .08f;
            var attackBack = attack.AddTransition(idle); attackBack.hasExitTime = true; attackBack.exitTime = 1; attackBack.duration = .1f;
            var actor = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(path)); actor.name = Models[i];
            var names=i==0 ? new[]{"Wax","InkPlumCloth","LedgerLeather","NibMetal"} : new[]{"Workwear","Skin","Gloves","Frame"};
            var rough=i==0 ? new[]{.44f,.78f,.56f,.30f} : new[]{.88f,.74f,.86f,.86f};
            var mats=new Material[4];
            for(int k=0;k<4;k++) {
                var pathMat=folder+names[k]+".mat";
                var mat=AssetDatabase.LoadAssetAtPath<Material>(pathMat);
                if(!mat){mat=new Material(Shader.Find("Standard"));AssetDatabase.CreateAsset(mat,pathMat);}
                var colorPath=folder+(i==0?"Scribe_"+names[k]+"_BaseColor.png":"Rescue_"+(k==0?"Workwear.001":names[k])+"_BaseColor.png");
                var normalPath=folder+(i==0?"Image_2_2k.png":"Rescue_Normal.png");
                ConfigureTexture(colorPath,false,true);ConfigureTexture(normalPath,true,false);
                mat.name=(i==0?"Scribe_":"Rescue_")+names[k];
                mat.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>(colorPath);mat.color=Color.white;
                mat.SetTexture("_BumpMap",AssetDatabase.LoadAssetAtPath<Texture2D>(normalPath));mat.EnableKeyword("_NORMALMAP");mat.SetFloat("_BumpScale",.8f);
                mat.SetFloat("_Metallic",i==0&&k==3?.68f:0);mat.SetFloat("_Glossiness",1-rough[k]);
                mats[k]=mat;EditorUtility.SetDirty(mat);
            }
            foreach(var renderer in actor.GetComponentsInChildren<Renderer>(true)) {
                var slots=renderer.sharedMaterials;
                for(int slot=0;slot<slots.Length;slot++) {
                    string imported=slots[slot]?slots[slot].name:"";
                    string canonical=System.Text.RegularExpressions.Regex.Replace(imported,@"\.\d{3}$","");
                    int match=Array.FindIndex(names,n=>canonical==((i==0?"Scribe_":"Rescue_")+n));
                    if(match<0)throw new Exception("Unexpected material slot "+Models[i]+"/"+renderer.name+"/"+slot+": "+imported);
                    Debug.Log("STORY_MATERIAL_SLOT "+Models[i]+" "+renderer.name+" "+slot+" "+imported);
                    slots[slot]=mats[match];
                }
                renderer.sharedMaterials=slots;
            }
            var animator = actor.GetComponentInChildren<Animator>(true); animator.runtimeAnimatorController = ctrl; animator.applyRootMotion = false; animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
            foreach (var r in actor.GetComponentsInChildren<SkinnedMeshRenderer>()) r.updateWhenOffscreen = true;
            var prefab = PrefabUtility.SaveAsPrefabAsset(actor, folder+"Actor.prefab"); UnityEngine.Object.DestroyImmediate(actor);
            var profilePath = folder+"VisualProfile.asset";
            var profile = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(profilePath);
            if (!profile) { profile = ScriptableObject.CreateInstance<EnemyVisualProfile>(); AssetDatabase.CreateAsset(profile, profilePath); }
            var profileID = i==0 ? "scribe" : "rescue";
            profile.Configure(profileID,prefab,ctrl,new[]{new EnemyOrientationStep(EnemyOrientationAxis.Y,180f)},
                1.0f,EnemyFormationSlotIds.FrontCenter,Vector3.zero,new EnemyHoverConfiguration(false,0,4),
                new EnemyAnchorConfiguration(new Vector3(0,1,0),new Vector3(0,.02f,0),new Vector3(0,2.3f,0),new Vector3(0,1.8f,0),new Vector3(0,1.15f,0)));
            var battleID=profileID+"-template";
            foreach(var h in UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include,FindObjectsSortMode.None))
                if(h.BattleEnemyId==battleID)UnityEngine.Object.DestroyImmediate(h.gameObject);
            var handle=EnemyPresenter.Present(new EnemyPresentationRequest{Profile=profile,Formation=formation,SlotId=EnemyFormationSlotIds.FrontCenter,BattleEnemyId=battleID,EnableMotion=false});
            var story=handle.gameObject.AddComponent<StoryEnemyPresentation20260916>();story.isScribe=i==0;
            story.targetWorldHeight=formation.ReferenceWorldHeight*profile.ReferenceHeightRatio;
            story.FitRestPose();
            handle.gameObject.name=Models[i]+"_Template";handle.gameObject.SetActive(false);
            EditorUtility.SetDirty(ctrl); EditorUtility.SetDirty(profile);
        }
        EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene); AssetDatabase.SaveAssets();
        Debug.Log("STORY_ENEMIES_IMPORT_OK");
    }
    static void ConfigureTexture(string path, bool normal, bool srgb)
    {
        var t = AssetImporter.GetAtPath(path) as TextureImporter;
        if (t == null) throw new FileNotFoundException(path);
        t.textureType = normal ? TextureImporterType.NormalMap : TextureImporterType.Default;
        t.sRGBTexture = srgb; t.maxTextureSize = 2048; t.mipmapEnabled = true; t.SaveAndReimport();
    }
}
#endif
