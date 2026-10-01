using System;
using System.Linq;
using System.IO;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

// Versioned import: the rejected v1 and both user GLBs are preserved.
public static class RefinedHeroV3Import
{
    const string Root = "Assets/Resources/CombatTempo/RefinedHeroV3/";
    // Blender's authored values are linear; Unity colour properties take a
    // display palette. Define them explicitly so repeated imports never brighten
    // an already-remapped material, and lift black cloth enough to retain folds.
    static Color PaintedPalette(string name) {
        if (name.Contains("Hair")) return name.Contains("Ridges") ? new Color(.24f,.20f,.28f) : new Color(.15f,.13f,.18f);
        if (name.Contains("Skin") || name.Contains("LeatherAtlas") || name.Contains("Brocade")) return Color.white;
        if (name == "V3 Gold") return new Color(.70f,.43f,.14f).gamma;
        if (name == "V3 Ivory") return new Color(.76f,.68f,.55f).gamma;
        if (name == "V3 Common Neck") return new Color(.37f,.24f,.18f).gamma;
        if (name == "V3 Common Leather") return new Color(.027f,.022f,.030f).gamma;
        bool star=name.Contains("starlight"), carnival=name.Contains("carnival");
        if (name.EndsWith("Cloth")) return (star ? new Color(.78f,.73f,.60f) : carnival ? new Color(.028f,.021f,.029f) : new Color(.027f,.022f,.035f)).gamma;
        if (name.EndsWith("Silk")) return (star ? new Color(.035f,.072f,.21f) : carnival ? new Color(.49f,.025f,.037f) : new Color(.13f,.019f,.26f)).gamma;
        if (name.EndsWith("Ribbon")) return (carnival ? new Color(.44f,.019f,.027f) : star ? new Color(.025f,.24f,.31f) : new Color(.018f,.25f,.28f)).gamma;
        if (name.EndsWith("Gem")) return (star ? new Color(.025f,.27f,.58f) : carnival ? new Color(.63f,.031f,.042f) : new Color(.29f,.025f,.52f)).gamma;
        throw new Exception("Unspecified illustrated palette: " + name);
    }
    public static void BuildPreview() { Build(); BuildRuntimePreview.BuildMacPlayer(); }
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
        string path = Root + "HeroMeshyV3.fbx";
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
            m.name = source.name; m.shader = Shader.Find("Mistport/HeroIllustratedV3");
            m.SetFloat("_Form", source.name.Contains("Hair") ? .18f : source.name.Contains("Cloth") || source.name == "V3 Common Leather" ? .24f : .16f);
            m.color = PaintedPalette(source.name);
            if (source.name.Contains("Brocade")) {
                var outfit = source.name.Contains("starlight") ? "starlight" : source.name.Contains("carnival") ? "carnival" : "night";
                m.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + outfit + "-brocade.png");
                m.color = Color.white;
            }
            if (source.name.Contains("Skin") || source.name.Contains("LeatherAtlas")) {
                m.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "MeshySkin.png");
            }
            EditorUtility.SetDirty(m);
            importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), source.name), m);
        }
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
        if (clips.Length != 14) throw new Exception("Expected 14 shared hero clips, got " + clips.Length);
        var controllerPath = Root + "HeroMeshyV3.controller";
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
        Debug.Log("MESHY_HERO_V3_IMPORTED " + clips.Length + " shared clips / " + imported.Length + " materials");
    }
}
