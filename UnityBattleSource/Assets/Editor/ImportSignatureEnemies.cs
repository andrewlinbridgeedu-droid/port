#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ImportSignatureEnemies
{
    const string Root = "Assets/Resources/Enemies/Signature/";
    static readonly string[] Models = { "HellhoundSentinel", "ArchivistSentinel", "ClockworkVeilMatriarch" };
    static readonly string[] Clips = { "Idle", "Charge", "Cast", "Hit", "Death", "Charge2", "Cast2" };
    static readonly int[] Starts = { 0, 61, 104, 135, 147, 178, 221 };
    static readonly int[] Ends = { 60, 103, 134, 146, 177, 220, 251 };

    [MenuItem("Mindstone/Import Signature Enemies")]
    public static void Import()
    {
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
            importer.clipAnimations = Clips.Select((name, k) => new ModelImporterClipAnimation {
                name = name, takeName = defaults[0].takeName,
                firstFrame = origin + Starts[k], lastFrame = origin + Ends[k],
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
            var materialPath = folder + "Body.mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (!material) { material = new Material(Shader.Find("Standard")); AssetDatabase.CreateAsset(material, materialPath); }
            ConfigureTexture(folder+"Image_0.png", false, true);
            ConfigureTexture(folder+"Image_2.png", true, false);
            ConfigureTexture(folder+"MetallicSmoothness.png", false, false);
            material.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"Image_0.png");
            material.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"Image_2.png")); material.EnableKeyword("_NORMALMAP");
            material.SetTexture("_MetallicGlossMap", AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"MetallicSmoothness.png")); material.EnableKeyword("_METALLICGLOSSMAP");
            material.SetFloat("_GlossMapScale", .72f); material.SetFloat("_BumpScale", .7f);
            material.color = Color.white;
            var actor = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(path)); actor.name = Models[i];
            foreach (var r in actor.GetComponentsInChildren<Renderer>(true)) {
                if (i == 1 && r.name.StartsWith("IronVaultEye", StringComparison.Ordinal)) {
                    r.sharedMaterial = SolidMaterial(folder + "AmberLenses.mat", new Color(.35f,.07f,.004f),
                        .05f, .72f, new Color(1f,.31f,.008f)*2.2f);
                } else if (i == 2 && r.name.StartsWith("CrimsonControlThreads", StringComparison.Ordinal)) {
                    r.sharedMaterial = SolidMaterial(folder + "CrimsonThreads.mat", new Color(.32f,.012f,.022f),
                        .05f, .52f, Color.black);
                } else r.sharedMaterial = material;
            }
            var animator = actor.GetComponentInChildren<Animator>(true); animator.runtimeAnimatorController = ctrl; animator.applyRootMotion = false; animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
            foreach (var r in actor.GetComponentsInChildren<SkinnedMeshRenderer>()) r.updateWhenOffscreen = true;
            var prefab = PrefabUtility.SaveAsPrefabAsset(actor, folder+"Actor.prefab"); UnityEngine.Object.DestroyImmediate(actor);
            var profilePath = folder+"VisualProfile.asset";
            var profile = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(profilePath);
            if (!profile) { profile = ScriptableObject.CreateInstance<EnemyVisualProfile>(); AssetDatabase.CreateAsset(profile, profilePath); }
            var profileID = i == 0 ? "hell-hound" : i == 1 ? "archivist" : "matriarch";
            profile.Configure(profileID, prefab, ctrl, new[] {new EnemyOrientationStep(EnemyOrientationAxis.Y, 180f)},
                i == 0 ? .74991804f : i == 1 ? 1.10f : 1.16f, EnemyFormationSlotIds.FrontCenter, Vector3.zero,
                new EnemyHoverConfiguration(false,0,4), new EnemyAnchorConfiguration(new Vector3(0,1,0),new Vector3(0,.02f,0),new Vector3(0,2.6f,0),new Vector3(0,1.8f,0),new Vector3(0,1.15f,0)));
            var battleID = i == 0 ? EnemyBattleIds.HellHoundPrimary : profileID+"-template";
            foreach (var h in UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include,FindObjectsSortMode.None))
                if (h.BattleEnemyId == battleID) UnityEngine.Object.DestroyImmediate(h.gameObject);
            var handle = EnemyPresenter.Present(new EnemyPresentationRequest { Profile=profile, Formation=formation, SlotId=EnemyFormationSlotIds.FrontCenter, BattleEnemyId=battleID, EnableMotion=false });
            var signature = handle.gameObject.AddComponent<SignatureEnemyPresentation>(); signature.kind = (EnemySignatureSpellVFX.Kind)i;
            signature.CalibrateRestPose();
            signature.CalibrateRestPose();
            handle.gameObject.name = i == 0 ? "HellHound_Imported" : Models[i]+"_Template"; handle.gameObject.SetActive(false);
            EditorUtility.SetDirty(ctrl); EditorUtility.SetDirty(profile); EditorUtility.SetDirty(material);
        }
        EditorSceneManager.MarkSceneDirty(scene); EditorSceneManager.SaveScene(scene); AssetDatabase.SaveAssets();
        Debug.Log("SIGNATURE_ENEMIES_IMPORT_OK");
    }
    static Material SolidMaterial(string path, Color color, float metallic, float smoothness, Color emission)
    {
        var material = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (!material) { material = new Material(Shader.Find("Standard")); AssetDatabase.CreateAsset(material,path); }
        material.color = color;
        material.mainTexture = null;
        material.SetFloat("_Metallic",metallic); material.SetFloat("_Glossiness",smoothness);
        material.SetColor("_EmissionColor",emission);
        if (emission.maxColorComponent > 0) material.EnableKeyword("_EMISSION"); else material.DisableKeyword("_EMISSION");
        EditorUtility.SetDirty(material);
        return material;
    }
    static void ConfigureTexture(string path, bool normal, bool srgb)
    {
        var t = AssetImporter.GetAtPath(path) as TextureImporter;
        if (t == null) throw new FileNotFoundException(path);
        t.textureType = normal ? TextureImporterType.NormalMap : TextureImporterType.Default;
        t.sRGBTexture = srgb; t.maxTextureSize = srgb ? 4096 : 2048; t.mipmapEnabled = true; t.SaveAndReimport();
    }
}
#endif
