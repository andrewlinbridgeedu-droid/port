using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

// Only the new hero assets; does not rebuild any enemy controller or old model.
public static class RefinedHeroImport
{
    const string Root = "Assets/Resources/CombatTempo/RefinedHero/";
    public static void BuildPreview() { Build(); BuildRuntimePreview.BuildMacPlayer(); }
    public static void Build()
    {
        var path = Root + "HeroRefined.fbx";
        var importer = AssetImporter.GetAtPath(path) as ModelImporter;
        if (!importer) throw new Exception("Refined Blender model missing");
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.optimizeGameObjects = false;
        importer.importAnimation = true; importer.importCameras = false; importer.importLights = false;
        importer.materialImportMode = ModelImporterMaterialImportMode.ImportStandard;
        importer.motionNodeName = "Hips";
        var definitions = importer.defaultClipAnimations;
        foreach (var c in definitions) {
            c.name = c.takeName.Split('|').Last(); c.loopTime = c.name == "BattleIdle";
            c.lockRootHeightY = true; c.lockRootRotation = true; c.lockRootPositionXZ = true;
            c.keepOriginalPositionY = true; c.keepOriginalPositionXZ = true; c.keepOriginalOrientation = true;
            c.hasAdditiveReferencePose = c.name == "Hit"; c.additiveReferencePoseFrame = c.firstFrame;
        }
        importer.clipAnimations = definitions; importer.SaveAndReimport();
        var imported = AssetDatabase.LoadAllAssetsAtPath(path).OfType<Material>()
            .Concat(importer.GetExternalObjectMap().Values.OfType<Material>())
            .GroupBy(m => m.name).Select(g => g.First()).ToArray();
        foreach (var original in imported) {
            string materialPath = Root + original.name.Replace(" ", "-") + ".mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (!m) { m = new Material(Shader.Find("Standard")); AssetDatabase.CreateAsset(m, materialPath); }
            m.name = original.name;
            m.color = original.color; m.SetFloat("_Metallic", original.name.Contains("Gold") ? .64f : 0);
            if (m.name.Contains("Hair")) m.color = new Color(.004f,.004f,.007f);
            if (m.name.Contains("Coat Charcoal")) m.color = new Color(.016f,.011f,.025f);
            if (m.name.Contains("Violet Silk")) m.color = new Color(.072f,.018f,.15f);
            if (m.name.Contains("Leather")) m.color = new Color(.016f,.012f,.018f);
            if (m.name.Contains("Gold") || m.name.Contains("Motifs")) m.color = new Color(.65f,.39f,.10f);
            m.SetFloat("_Glossiness", original.name.Contains("Gem") ? .80f : original.name.Contains("Silk") ? .50f : original.name.Contains("Gold") ? .69f : .30f);
            if (m.name.Contains("Hair")) {
                // Broad Standard reflections made black rear hair look like grey plastic.
                m.SetFloat("_Glossiness", .08f); m.SetFloat("_SpecularHighlights", 0); m.SetFloat("_GlossyReflections", 0);
                m.EnableKeyword("_SPECULARHIGHLIGHTS_OFF"); m.EnableKeyword("_GLOSSYREFLECTIONS_OFF");
            }
            if (original.name.Contains("Atlas")) {
                m.mainTexture = Resources.Load<Texture2D>("RuntimeModels/Fool/Meshy_AI_battle_magician_rig_biped_texture_0");
                m.color = Color.white; m.SetFloat("_Glossiness", .28f);
            }
            EditorUtility.SetDirty(m);
            importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), original.name), m);
        }
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
        var controllerPath = Root + "HeroRefined.controller";
        var controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath);
        if (!controller) controller = AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
        foreach (var layer in controller.layers) foreach (var state in layer.stateMachine.states) layer.stateMachine.RemoveState(state.state);
        while (controller.layers.Length > 1) controller.RemoveLayer(controller.layers.Length - 1);
        if (!controller.parameters.Any(p => p.name == "ActionSpeed")) controller.AddParameter("ActionSpeed", AnimatorControllerParameterType.Float);
        controller.parameters = controller.parameters.Select(p => { if (p.name == "ActionSpeed") p.defaultFloat = 1; return p; }).ToArray();
        var machine = controller.layers[0].stateMachine;
        foreach (var c in clips.Where(c => c.name != "Hit")) {
            var state = machine.AddState(c.name); state.motion = c;
            state.speedParameterActive = true; state.speedParameter = "ActionSpeed";
            if (c.name == "BattleIdle") machine.defaultState = state;
        }
        controller.AddLayer("ConfirmedHit"); var layers = controller.layers;
        layers[1].blendingMode = AnimatorLayerBlendingMode.Additive; layers[1].defaultWeight = 0;
        var hit = layers[1].stateMachine.AddState("Hit"); hit.motion = clips.First(c => c.name == "Hit");
        layers[1].stateMachine.defaultState = hit; controller.layers = layers;
        EditorUtility.SetDirty(controller); AssetDatabase.SaveAssets();
        Debug.Log("REFINED_HERO_IMPORTED " + clips.Length + " shared clips / " + imported.Length + " materials");
    }
}
