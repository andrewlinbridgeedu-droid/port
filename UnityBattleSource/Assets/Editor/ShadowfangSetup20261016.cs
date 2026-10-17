using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

// Reproducible import of the early hound's Shadowfang body (v51, 2026-10-16) into
// Resources/CombatTempo/Shadowfang: model and texture import settings, the skin and fur
// materials, and an override of the hound controller with the Shadowfang clips (same
// state names as Hound.fbx). Run: -executeMethod ShadowfangSetup20261016.Run
public static class ShadowfangSetup20261016
{
    const string Root = "Assets/Resources/CombatTempo/Shadowfang/";

    public static void Run()
    {
        AssetDatabase.Refresh();
        var model = (ModelImporter)AssetImporter.GetAtPath(Root + "Shadowfang.fbx");
        model.animationType = ModelImporterAnimationType.Generic;
        model.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        model.importAnimation = true;
        model.motionNodeName = "Root";
        // Readable: the defeat shatter and outline passes bake this skin on the CPU.
        model.isReadable = true;
        model.materialImportMode = ModelImporterMaterialImportMode.None;
        model.optimizeGameObjects = false;
        // The cards' bend reads the strand direction from Mikk tangents built on their UVs;
        // uv2 carries each card's phase and length, so no lightmap UVs may replace it.
        model.importTangents = ModelImporterTangents.CalculateMikk;
        model.generateSecondaryUV = false;
        var clips = model.defaultClipAnimations;
        foreach (var clip in clips) {
            clip.name = clip.takeName.Split('|').Last();
            clip.loopTime = clip.name == "BattleIdle" || clip.name == "Walking";
            clip.lockRootHeightY = true;
            clip.lockRootRotation = true;
            clip.lockRootPositionXZ = true;
            clip.keepOriginalPositionY = true;
            clip.keepOriginalPositionXZ = true;
            clip.hasAdditiveReferencePose = clip.name == "HitAdditive";
            clip.additiveReferencePoseFrame = clip.firstFrame;
        }
        model.clipAnimations = clips;
        model.SaveAndReimport();

        var normal = (TextureImporter)AssetImporter.GetAtPath(Root + "ShadowfangNormal.png");
        normal.textureType = TextureImporterType.NormalMap;
        normal.SaveAndReimport();
        var packed = (TextureImporter)AssetImporter.GetAtPath(Root + "ShadowfangPacked.png");
        packed.sRGBTexture = false;
        packed.maxTextureSize = 1024;   // only its roughness channel is read
        packed.SaveAndReimport();
        var strands = (TextureImporter)AssetImporter.GetAtPath(Root + "ShadowfangFurStrands.png");
        strands.alphaIsTransparency = true;
        strands.mipmapEnabled = true;
        strands.wrapMode = TextureWrapMode.Clamp;
        strands.SaveAndReimport();

        var body = Material(Root + "ShadowfangBody.mat", "Mistport/Shadowfang/Surface");
        body.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "ShadowfangAlbedo.png");
        body.SetTexture("_PackedMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "ShadowfangPacked.png"));
        body.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "ShadowfangNormal.png"));
        body.SetFloat("_BumpScale", .8f);
        body.color = new Color(.78f, .78f, .78f, 1);
        EditorUtility.SetDirty(body);
        var fur = Material(Root + "ShadowfangFur.mat", "Mistport/Shadowfang/FurCards");
        fur.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "ShadowfangFurStrands.png");
        fur.color = new Color(.78f, .78f, .78f, 1);   // the body material's own tint
        fur.SetFloat("_RootShade", .45f);
        fur.SetFloat("_Wrap", .2f);
        fur.SetFloat("_StrandContrast", .6f);
        EditorUtility.SetDirty(fur);

        var hound = AssetDatabase.LoadAssetAtPath<RuntimeAnimatorController>("Assets/Resources/CombatTempo/Animation/Hound.controller");
        var shadowfangClips = AssetDatabase.LoadAllAssetsAtPath(Root + "Shadowfang.fbx").OfType<AnimationClip>()
            .Where(c => !c.name.StartsWith("__")).ToDictionary(c => c.name);
        var path = Root + "Shadowfang.overrideController";
        var overrides = AssetDatabase.LoadAssetAtPath<AnimatorOverrideController>(path);
        if (!overrides) { overrides = new AnimatorOverrideController(hound); AssetDatabase.CreateAsset(overrides, path); }
        overrides.runtimeAnimatorController = hound;
        var pairs = new List<KeyValuePair<AnimationClip, AnimationClip>>();
        overrides.GetOverrides(pairs);
        for (int i = 0; i < pairs.Count; i++) {
            if (!shadowfangClips.TryGetValue(pairs[i].Key.name, out var clip))
                throw new InvalidOperationException("Shadowfang has no clip " + pairs[i].Key.name);
            pairs[i] = new KeyValuePair<AnimationClip, AnimationClip>(pairs[i].Key, clip);
        }
        overrides.ApplyOverrides(pairs);
        EditorUtility.SetDirty(overrides);
        AssetDatabase.SaveAssets();
        Debug.Log("SHADOWFANG_SETUP_DONE clips=" + string.Join(",", pairs.Select(p => p.Key.name + "->" + p.Value.name)));
    }

    static Material Material(string path, string shaderName)
    {
        var shader = Shader.Find(shaderName);
        if (!shader) throw new InvalidOperationException("Missing shader " + shaderName);
        var material = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (!material) { material = new Material(shader); AssetDatabase.CreateAsset(material, path); }
        material.shader = shader;
        return material;
    }
}
