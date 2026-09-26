using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

/// <summary>Imports the eight supplied bounty masters as independent skinned actors.</summary>
public static class ImportBountyEight20260923
{
    static readonly string[] Cases = {"b01", "b02", "b03", "b05", "b07", "b08", "b09", "b10", "b10-vessel"};
    static readonly string[] Clips = {"Idle", "Charge", "Cast", "Hit", "Death", "Charge2", "Cast2", "Retreat"};
    static readonly int[] Starts = {0, 121, 166, 196, 208, 244, 289, 319};
    static readonly int[] Ends = {120, 165, 195, 207, 243, 288, 318, 358};

    // Measured from the actual skinned vertices in the battle scene. The old
    // .72 value left several imported humans over twice the protagonist's height.
    static float HeightRatio(string id) => id switch {
        "b01" => .33f, "b02" => .55f, "b03" => .38f, "b05" => .30f,
        "b07" => .84f, "b08" => .27f, "b09" => .84f,
        "b10" => .50f, "b10-vessel" => .43f,
        _ => throw new ArgumentOutOfRangeException(nameof(id), id, "Unknown bounty actor")
    };
    static float ActualHeight(string id) => id switch {
        "b01" => 1.74f, "b02" => 1.72f, "b03" => 1.74f, "b05" => 1.76f,
        "b07" => .98f, "b08" => 1.72f, "b09" => 1.01f,
        "b10" => 1.75f, "b10-vessel" => 1.31f,
        _ => throw new ArgumentOutOfRangeException(nameof(id), id, "Unknown bounty actor")
    };
    static EnemyAnchorConfiguration AnchorsFor(string id)
    {
        float h = ActualHeight(id);
        return new EnemyAnchorConfiguration(new Vector3(0, h * .52f, 0),
            new Vector3(0, .02f, 0), new Vector3(0, h + .16f, 0),
            new Vector3(0, h * .79f, 0), new Vector3(0, h * .53f, 0));
    }

    public static void Import()
    {
        foreach (var id in Cases) ImportOne(id);
        Debug.Log("BOUNTY_EIGHT_IMPORT_OK");
    }

    public static void ImportVessel()
    {
        ImportOne("b10-vessel");
        Debug.Log("BOUNTY_VESSEL_REIMPORT_OK");
    }

    public static void ImportB01AndRescale()
    {
        ImportOne("b01");
        RescaleProfiles();
        Debug.Log("BOUNTY_WEAPON_SCALE_OK");
    }

    public static void RescaleProfiles()
    {
        foreach (string id in Cases)
        {
            string model = id == "b10-vessel" ? "B10Vessel" : id.ToUpperInvariant();
            string path = "Assets/Resources/Enemies/Signature/Bounty" + model + "/VisualProfile.asset";
            var profile = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(path);
            if (!profile) throw new InvalidOperationException("Missing bounty profile " + path);
            profile.Configure(profile.EnemyId, profile.Prefab, profile.AnimatorController,
                profile.OrientationSteps, HeightRatio(id),
                profile.DefaultSlotId, profile.SlotOffset, profile.Hover, AnchorsFor(id));
            EditorUtility.SetDirty(profile);
        }
        AssetDatabase.SaveAssets();
    }

    static void ImportOne(string id)
    {
        string model = id == "b10-vessel" ? "B10Vessel" : id.ToUpperInvariant();
        string folder = "Assets/Resources/Enemies/Signature/Bounty" + model + "/";
        string source = Path.GetFullPath(Path.Combine(Application.dataPath,
            "../../ArtSource/BountyCombat20260923/" + id));
        if (!File.Exists(Path.Combine(source, model + "_Combat.fbx")))
            throw new FileNotFoundException("Bounty combat model has not been built", source);
        Directory.CreateDirectory(folder);
        foreach (string name in new[] {model + "_Combat.fbx", model + "_BaseColor_2k.png",
                     model + "_Normal_2k.png", model + "_MetalSmooth_2k.png"})
            File.Copy(Path.Combine(source, name), folder + name, true);
        AssetDatabase.Refresh();
        string modelPath = folder + model + "_Combat.fbx";
        var importer = (ModelImporter)AssetImporter.GetAtPath(modelPath);
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.importAnimation = true;
        importer.isReadable = true;
        importer.optimizeGameObjects = false;
        importer.importCameras = false;
        importer.importLights = false;
        importer.animationCompression = ModelImporterAnimationCompression.Off;
        importer.SaveAndReimport();
        var take = importer.defaultClipAnimations.First();
        importer.clipAnimations = Clips.Select((name, i) => new ModelImporterClipAnimation {
            name = name, takeName = take.takeName,
            firstFrame = take.firstFrame + Starts[i], lastFrame = take.firstFrame + Ends[i],
            loopTime = i == 0, loopPose = i == 0,
            keepOriginalOrientation = true, keepOriginalPositionXZ = true, keepOriginalPositionY = true,
            lockRootRotation = true, lockRootPositionXZ = true, lockRootHeightY = true
        }).ToArray();
        importer.SaveAndReimport();
        var clips = AssetDatabase.LoadAllAssetsAtPath(modelPath).OfType<AnimationClip>()
            .Where(c => !c.name.StartsWith("__")).ToArray();
        foreach (string name in Clips)
        {
            var clip = clips.SingleOrDefault(c => c.name == name);
            if (!clip || clip.length <= 0 || AnimationUtility.GetCurveBindings(clip).Length == 0)
                throw new InvalidOperationException("Bounty " + id + " missing clip " + name);
        }
        string controllerPath = folder + "Combat.controller";
        var controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath)
                         ?? AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
        foreach (var parameter in controller.parameters) controller.RemoveParameter(parameter);
        controller.AddParameter("Attack", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Hit", AnimatorControllerParameterType.Trigger);
        if (controller.layers.Length == 0) controller.AddLayer("Base Layer");
        var layers = controller.layers; layers[0].defaultWeight = 1; controller.layers = layers;
        var machine = controller.layers[0].stateMachine;
        foreach (var state in machine.states) machine.RemoveState(state.state);
        var idle = machine.AddState("Meshy · Idle"); idle.motion = clips.Single(c => c.name == "Idle");
        machine.defaultState = idle;
        foreach (string name in Clips.Where(n => n != "Idle"))
        {
            var state = machine.AddState(name); state.motion = clips.Single(c => c.name == name);
            if (name == "Hit" || name == "Cast" || name == "Cast2")
            {
                var back = state.AddTransition(idle); back.hasExitTime = true;
                back.exitTime = 1; back.duration = .1f;
            }
        }
        var actor = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(modelPath));
        actor.name = model;
        var material = AssetDatabase.LoadAssetAtPath<Material>(folder + "AuthoredPBR.mat");
        if (!material)
        {
            material = new Material(Shader.Find("Standard"));
            AssetDatabase.CreateAsset(material, folder + "AuthoredPBR.mat");
        }
        material.mainTexture = ImportTexture(folder + model + "_BaseColor_2k.png", false, true);
        material.color = Color.white;
        material.SetTexture("_BumpMap", ImportTexture(folder + model + "_Normal_2k.png", true, false));
        material.EnableKeyword("_NORMALMAP"); material.SetFloat("_BumpScale", .7f);
        material.SetTexture("_MetallicGlossMap", ImportTexture(folder + model + "_MetalSmooth_2k.png", false, false));
        material.EnableKeyword("_METALLICGLOSSMAP"); material.SetFloat("_GlossMapScale", .55f);
        foreach (var renderer in actor.GetComponentsInChildren<Renderer>(true))
            renderer.sharedMaterials = Enumerable.Repeat(material, renderer.sharedMaterials.Length).ToArray();
        var animator = actor.GetComponentInChildren<Animator>(true);
        animator.runtimeAnimatorController = controller;
        animator.applyRootMotion = false;
        animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        foreach (var skinned in actor.GetComponentsInChildren<SkinnedMeshRenderer>())
            skinned.updateWhenOffscreen = true;
        var prefab = PrefabUtility.SaveAsPrefabAsset(actor, folder + "Actor.prefab");
        UnityEngine.Object.DestroyImmediate(actor);
        var profile = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(folder + "VisualProfile.asset");
        if (!profile)
        {
            profile = ScriptableObject.CreateInstance<EnemyVisualProfile>();
            AssetDatabase.CreateAsset(profile, folder + "VisualProfile.asset");
        }
        profile.Configure("bounty-" + id, prefab, controller,
            new[] {new EnemyOrientationStep(EnemyOrientationAxis.Y, 180)},
            HeightRatio(id),
            EnemyFormationSlotIds.FrontCenter, Vector3.zero,
            new EnemyHoverConfiguration(false, 0, 4), AnchorsFor(id));
        EditorUtility.SetDirty(material); EditorUtility.SetDirty(controller); EditorUtility.SetDirty(profile);
        AssetDatabase.SaveAssets();
        Debug.Log("BOUNTY_IMPORT " + id + " clips=" + Clips.Length);
    }

    static Texture2D ImportTexture(string path, bool normal, bool srgb)
    {
        var importer = (TextureImporter)AssetImporter.GetAtPath(path);
        importer.textureType = normal ? TextureImporterType.NormalMap : TextureImporterType.Default;
        importer.sRGBTexture = srgb;
        importer.maxTextureSize = 2048;
        importer.mipmapEnabled = true;
        importer.SaveAndReimport();
        var image = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        if (!image || image.width > 2048 || image.height > 2048)
            throw new InvalidOperationException("Invalid bounty texture " + path);
        return image;
    }
}
