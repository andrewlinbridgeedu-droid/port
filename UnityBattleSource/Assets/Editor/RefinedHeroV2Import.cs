using System;
using System.Linq;
using System.IO;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

// Versioned import: the rejected v1 and both user GLBs are preserved.
public static class RefinedHeroV2Import
{
    const string Root = "Assets/Resources/CombatTempo/RefinedHeroV2/";
    public static void BuildPreview() {
        // The old v1 is loaded only by the standalone comparison flag. Enable
        // its CPU skin snapshot in this preview binary, then restore its exact
        // metadata so the historical asset and future iOS imports stay unchanged.
        const string previous = "Assets/Resources/CombatTempo/RefinedHero/HeroRefined.fbx";
        string meta = File.ReadAllText(previous + ".meta");
        try {
            var reference = (ModelImporter)AssetImporter.GetAtPath(previous);
            reference.isReadable = true; reference.SaveAndReimport();
            Build(); BuildRuntimePreview.BuildMacPlayer();
        } finally {
            File.WriteAllText(previous + ".meta", meta);
            AssetDatabase.ImportAsset(previous, ImportAssetOptions.ForceUpdate);
        }
    }
    public static void Build()
    {
        foreach (var file in new[] {"night-brocade", "starlight-brocade", "carnival-brocade", "MeshySkin"}) {
            var texture = (TextureImporter)AssetImporter.GetAtPath(Root + file + ".png");
            texture.textureType = TextureImporterType.Default;
            texture.sRGBTexture = true; texture.mipmapEnabled = true;
            texture.maxTextureSize = file == "MeshySkin" ? 2048 : 2048;
            texture.textureCompression = TextureImporterCompression.CompressedHQ;
            texture.wrapMode = TextureWrapMode.Clamp; texture.SaveAndReimport();
        }
        string path = Root + "HeroMeshyV2.fbx";
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
            m.name = source.name; m.shader = Shader.Find(source.name.Contains("Brocade") ? "Mistport/HeroBrocadeV2" : "Standard");
            m.color = source.color;
            m.SetFloat("_Metallic", source.name.Contains("Gold") ? .76f : source.name.Contains("Gem") ? .28f : 0);
            m.SetFloat("_Glossiness", source.name.Contains("Gold") ? .72f : source.name.Contains("Gem") ? .82f : source.name.Contains("Silk") ? .46f : .24f);
            if (source.name.Contains("Brocade")) {
                var outfit = source.name.Contains("starlight") ? "starlight" : source.name.Contains("carnival") ? "carnival" : "night";
                m.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + outfit + "-brocade.png");
                m.color = Color.white; m.SetFloat("_Relief", .12f);
            }
            if (source.name.Contains("Skin")) {
                m.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "MeshySkin.png");
                m.color = Color.white; m.SetFloat("_Glossiness", .18f);
            }
            if (source.name.Contains("Hair")) {
                m.color = source.name.Contains("Ridges") ? new Color(.0038f,.0020f,.0060f) : new Color(.0017f,.0010f,.0030f);
                m.SetFloat("_Glossiness", .18f);
            }
            EditorUtility.SetDirty(m);
            importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), source.name), m);
        }
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
        if (clips.Length != 14) throw new Exception("Expected 14 shared hero clips, got " + clips.Length);
        var controllerPath = Root + "HeroMeshyV2.controller";
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
        Debug.Log("MESHY_HERO_V2_IMPORTED " + clips.Length + " shared clips / " + imported.Length + " materials");
    }
}
