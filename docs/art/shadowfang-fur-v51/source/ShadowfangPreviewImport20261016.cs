using System;
using System.Linq;
using UnityEditor;
using UnityEngine;

// Experimental art stays under Editor until its complete motion set is reviewed.
public static class ShadowfangPreviewImport20261016
{
    public const string Root = "Assets/Editor/CharacterPolishShadowfang/";
    // v49: alpha-textured hair cards bent on the GPU; v43's solid tufts and shape keys are retired.
    // v51: finer cards, head cap and tail; each card carries the body colour under its root.
    public const string Model = "Shadowfang_FurCards_v51.fbx";
    public static void Begin()
    {
        Prepare();
        CharacterPolishPreview20261016.Begin();
    }
    public static void Prepare()
    {
        AssetDatabase.Refresh();
        var importer = (ModelImporter)AssetImporter.GetAtPath(Root + Model);
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.importAnimation = true;
        importer.motionNodeName = "Root";
        importer.isReadable = true;
        importer.materialImportMode = ModelImporterMaterialImportMode.None;
        // The cards' bend reads the strand direction from Mikk tangents built on their UVs.
        importer.importTangents = ModelImporterTangents.CalculateMikk;
        importer.generateSecondaryUV = false;
        importer.optimizeGameObjects = false;
        var clips = importer.defaultClipAnimations;
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
        importer.clipAnimations = clips;
        importer.SaveAndReimport();
        var normal = (TextureImporter)AssetImporter.GetAtPath(Root + "Normal.png");
        normal.textureType = TextureImporterType.NormalMap;
        normal.SaveAndReimport();
        var strands = (TextureImporter)AssetImporter.GetAtPath(Root + "FurStrands.png");
        strands.alphaIsTransparency = true;
        strands.mipmapEnabled = true;
        strands.wrapMode = TextureWrapMode.Clamp;
        strands.SaveAndReimport();
        var packed = (TextureImporter)AssetImporter.GetAtPath(Root + "RoughnessPacked.png");
        packed.sRGBTexture = false;
        packed.SaveAndReimport();
        Debug.Log("SHADOWFANG_IMPORTED " + string.Join(",", clips.Select(c => c.name)));
    }

    static bool BoundsOf(Transform root, out Bounds bounds)
    {
        bounds = default;
        bool found = false;
        foreach (var renderer in root.GetComponentsInChildren<SkinnedMeshRenderer>()) {
            if (!found) { bounds = renderer.bounds; found = true; }
            else bounds.Encapsulate(renderer.bounds);
        }
        return found;
    }

    public static CombatTempoAnimatedBody ReplaceForReview(CombatTempoAnimatedBody original)
    {
        var source = AssetDatabase.LoadAssetAtPath<GameObject>(Root + Model);
        var clips = AssetDatabase.LoadAllAssetsAtPath(Root + Model)
            .OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")).ToArray();
        var oldSkin = original.GetComponentsInChildren<SkinnedMeshRenderer>().First();
        var before = oldSkin.bounds;
        var go = UnityEngine.Object.Instantiate(source, original.transform.parent, false);
        go.name = "Shadowfang experimental review";
        var skins = go.GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach(var skin in skins) { skin.updateWhenOffscreen=true; for(int i=0;i<skin.sharedMesh.blendShapeCount;i++)skin.SetBlendShapeWeight(i,0); }
        var shader = Shader.Find("Mistport/Review/ShadowfangSurface");
        if (!shader || !shader.isSupported) throw new InvalidOperationException("Shadowfang surface shader unavailable.");
        var material = new Material(shader);
        material.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "Albedo.png");
        material.SetTexture("_PackedMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "RoughnessPacked.png"));
        material.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "Normal.png"));
        material.SetFloat("_BumpScale", .8f);
        material.color = new Color(.78f, .78f, .78f, 1);
        var furShader = Shader.Find("Mistport/Review/ShadowfangFurCards");
        if (!furShader || !furShader.isSupported) throw new InvalidOperationException("Shadowfang fur card shader unavailable.");
        var mane = new Material(furShader);
        mane.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "FurStrands.png");
        // v51: the colour is the body's (vertex colour from the albedo under each root);
        // the strand texture only brightens and darkens strands around it.
        mane.color = new Color(.78f,.78f,.78f,1);   // the body material's own tint
        mane.SetFloat("_RootShade", .45f);
        mane.SetFloat("_Wrap", .2f);
        foreach (var skin in skins) {
            var slots = new Material[skin.sharedMesh.subMeshCount];
            for (int i=0;i<slots.Length;i++) slots[i]= i==0 ? material : mane;
            skin.sharedMaterials=slots;
        }
        // Match the source body's current height and feet, not the large FBX animation bounds.
        if (!BoundsOf(go.transform, out var after))
            throw new InvalidOperationException("Missing Shadowfang bounds.");
        go.transform.localScale *= before.size.y / after.size.y;
        BoundsOf(go.transform, out after);
        go.transform.position += new Vector3(before.center.x-after.center.x, before.min.y-after.min.y, before.center.z-after.center.z);
        original.enabled = false;
        original.gameObject.SetActive(false);
        var body = CombatTempoAnimatedBody.Install(go, "Hound", null);
        var animator = go.GetComponent<Animator>();
        var controller = new AnimatorOverrideController(animator.runtimeAnimatorController);
        foreach (var old in controller.animationClips) {
            var replacement = clips.FirstOrDefault(c => c.name == old.name);
            if (!replacement) throw new InvalidOperationException("Missing Shadowfang clip " + old.name);
            var clean=UnityEngine.Object.Instantiate(replacement); clean.name=replacement.name;
            foreach(var binding in AnimationUtility.GetCurveBindings(clean))
                if(binding.propertyName.StartsWith("blendShape."))AnimationUtility.SetEditorCurve(clean,binding,null);
            controller[old.name] = clean;
        }
        animator.runtimeAnimatorController = controller;
        go.AddComponent<ShadowfangFurWind>();
        body.Idle();
        return body;
    }
}
