using System;
using System.Linq;
using System.IO;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

// Versioned import: the three new source GLBs and v1-v3 remain unchanged.
public static class RefinedHeroV4Import
{
    const string Root = "Assets/Resources/CombatTempo/RefinedHeroV4/";
    public static void BuildPreview() { Build(); BuildRuntimePreview.BuildMacPlayer(); }
    public static void Build()
    {
        foreach (var file in new[] {"night-painted-4k", "starlight-painted-4k", "carnival-painted-4k"}) {
            var texture = (TextureImporter)AssetImporter.GetAtPath(Root + file + ".png");
            texture.textureType = TextureImporterType.Default;
            texture.sRGBTexture = true; texture.mipmapEnabled = true;
            texture.maxTextureSize = 4096;
            texture.anisoLevel = 8;
            var ios = texture.GetPlatformTextureSettings("iPhone");
            ios.overridden = true; ios.maxTextureSize = 4096;
            ios.format = TextureImporterFormat.ASTC_4x4;
            texture.SetPlatformTextureSettings(ios);
            texture.textureCompression = TextureImporterCompression.CompressedHQ;
            texture.wrapMode = TextureWrapMode.Clamp; texture.SaveAndReimport();
        }
        string path = Root + "HeroSovereignV4.fbx";
        var importer = (ModelImporter)AssetImporter.GetAtPath(path);
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.optimizeGameObjects = false; importer.importAnimation = true;
        // Current-pose world skin bounds are measured once when replacing the hero.
        importer.isReadable = true;
        importer.importCameras = false; importer.importLights = false;
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
        foreach (var source in imported) {
            string materialPath = Root + source.name.Replace(" ", "-") + ".mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (!m) { m = new Material(Shader.Find("Standard")); AssetDatabase.CreateAsset(m, materialPath); }
            m.name = source.name; m.shader = Shader.Find("Mistport/HeroIllustratedV4");
            m.SetFloat("_Form", .14f);
            m.color = Color.white;
            var outfit = source.name.Contains("starlight") ? "starlight" : source.name.Contains("carnival") ? "carnival" : "night";
            m.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + outfit + "-painted-4k.png");
            if (!m.mainTexture) throw new Exception("Missing illustrated atlas: " + outfit);
            EditorUtility.SetDirty(m);
            importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), source.name), m);
        }
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
        if (clips.Length != 14) throw new Exception("Expected 14 shared hero clips, got " + clips.Length);
        var controllerPath = Root + "HeroSovereignV4.controller";
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
        Debug.Log("SOVEREIGN_HERO_V4_IMPORTED " + clips.Length + " shared clips / " + imported.Length + " materials");
    }
}
