using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

// v4 hero: re-tailored in Blender (tools/animation/build_hero_v4.py). One skinned
// mesh for the shared body and one per outfit; materials are configured from the
// manifest Blender writes, so the Unity look matches the Blender preview.
public static class RefinedHeroV4Import
{
    const string Root = "Assets/Resources/CombatTempo/RefinedHeroV4/";

    [Serializable] class Spec {
        public string name, kind, texture;
        public float[] color, shade, spec_tint;
        public float ao, rough, spec_lo, spec_hi, spec, rim;
    }
    [Serializable] class Specs { public Spec[] items; }

    public static void BuildPreview() { Build(); BuildRuntimePreview.BuildMacPlayer(); }

    public static void Build()
    {
        var specs = JsonUtility.FromJson<Specs>(File.ReadAllText(Root + "materials.json")).items
            .ToDictionary(s => s.name);
        foreach (var file in Directory.GetFiles(Root, "*.png")) {
            var texture = (TextureImporter)AssetImporter.GetAtPath(file.Replace('\\', '/'));
            texture.textureType = TextureImporterType.Default;
            texture.sRGBTexture = true; texture.mipmapEnabled = true;
            texture.maxTextureSize = 2048;
            texture.textureCompression = TextureImporterCompression.CompressedHQ;
            texture.wrapMode = TextureWrapMode.Clamp; texture.SaveAndReimport();
        }
        string path = Root + "HeroV4.fbx";
        var importer = (ModelImporter)AssetImporter.GetAtPath(path);
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.optimizeGameObjects = false; importer.importAnimation = true;
        // The runtime measures current-pose skin bounds when it swaps in the hero.
        importer.isReadable = true;
        importer.importCameras = false; importer.importLights = false;
        importer.importNormals = ModelImporterNormals.Import;
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
        var shader = Shader.Find("Mistport/HeroPaintedV4");
        if (!shader) throw new Exception("Mistport/HeroPaintedV4 shader missing");
        foreach (var source in imported) {
            if (!specs.TryGetValue(source.name, out var spec))
                throw new Exception("No painted spec for material " + source.name);
            string materialPath = Root + source.name.Replace(" ", "-") + ".mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (!m) { m = new Material(shader); AssetDatabase.CreateAsset(m, materialPath); }
            m.name = source.name; m.shader = shader;
            m.SetColor("_Color", spec.texture != null && spec.texture.Length > 0 ? Color.white : Col(spec.color));
            m.SetColor("_ShadeColor", Col(spec.shade));
            m.SetColor("_HighlightColor", Col(spec.spec_tint));
            m.SetFloat("_HighlightStrength", spec.spec);
            m.SetFloat("_HighlightFrom", spec.spec_lo);
            m.SetFloat("_HighlightTo", spec.spec_hi);
            m.SetFloat("_Gloss", Mathf.Clamp(2f / Mathf.Max(0.05f, spec.rough * spec.rough), 2f, 256f));
            m.SetFloat("_Rim", spec.rim);
            m.SetFloat("_AO", spec.ao);
            float outline = spec.kind == "metal" || spec.kind == "gem" ? 0.0005f : spec.kind == "hair" ? 0.0007f : 0.0012f;
            m.SetFloat("_OutlineWidth", outline);
            m.mainTexture = spec.texture != null && spec.texture.Length > 0
                ? AssetDatabase.LoadAssetAtPath<Texture2D>(Root + spec.texture) : Texture2D.whiteTexture;
            EditorUtility.SetDirty(m);
            importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), source.name), m);
        }
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
        if (clips.Length != 14) throw new Exception("Expected 14 shared hero clips, got " + clips.Length);
        var controllerPath = Root + "HeroV4.controller";
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
        Debug.Log("HERO_V4_IMPORTED " + clips.Length + " shared clips / " + imported.Length + " materials");
    }

    static Color Col(float[] c) => c == null || c.Length < 3 ? Color.white : new Color(c[0], c[1], c[2], 1);
}
