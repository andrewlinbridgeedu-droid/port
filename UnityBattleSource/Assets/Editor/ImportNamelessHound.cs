#if UNITY_EDITOR
using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

public static class ImportNamelessHound
{
    const string Root = "Assets/Resources/Enemies/NamelessHound/";
    [MenuItem("Mindstone/Import Nameless Hound Actions")]
    public static void Import()
    {
        AssetDatabase.Refresh();
        var path = Root + "NamelessHound_Actions.fbx";
        var importer = (ModelImporter)AssetImporter.GetAtPath(path);
        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        importer.importAnimation = true;
        var names = new[] { "Idle", "Walk", "Charge", "Fire", "Hit", "Retreat" };
        var clips = importer.defaultClipAnimations;
        foreach (var clip in clips) {
            var name = names.FirstOrDefault(n => clip.name.EndsWith("|" + n) || clip.name == n);
            if (name == null) throw new Exception("Unexpected hound take: " + clip.name);
            clip.name = name;
            clip.loopTime = name == "Idle" || name == "Walk";
        }
        if (clips.Length != 6) throw new Exception("Expected six hound takes, got " + clips.Length);
        importer.clipAnimations = clips;
        importer.SaveAndReimport();
        var controllerPath = Root + "NamelessHound.controller";
        var controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath)
            ?? AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
        var machine = controller.layers[0].stateMachine;
        foreach (var state in machine.states) machine.RemoveState(state.state);
        var assets = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().ToArray();
        foreach (var name in names) {
            var clip = assets.Single(a => a.name == name);
            var state = machine.AddState(name);state.motion = clip;
            if (name == "Idle") machine.defaultState = state;
            Debug.Log("NAMELESS_HOUND_CLIP " + name + " duration=" + clip.length + " curves=" + AnimationUtility.GetCurveBindings(clip).Length);
            if (clip.length <= 0 || AnimationUtility.GetCurveBindings(clip).Length == 0) throw new Exception("Empty hound clip " + name);
        }
        var material = AssetDatabase.LoadAssetAtPath<Material>(Root + "NamelessHound.mat");
        if (material == null) {
            material = new Material(Shader.Find("Standard"));
            AssetDatabase.CreateAsset(material, Root + "NamelessHound.mat");
        }
        material.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(Root + "BaseColor.png");
        material.SetFloat("_Metallic", .15f);material.SetFloat("_Glossiness", .3f);
        var actor = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(path));
        actor.name = "NamelessHoundActor";
        foreach (var renderer in actor.GetComponentsInChildren<Renderer>()) renderer.sharedMaterial = material;
        var animator = actor.GetComponentInChildren<Animator>();
        animator.runtimeAnimatorController = controller;animator.applyRootMotion = false;
        PrefabUtility.SaveAsPrefabAsset(actor, Root + "NamelessHoundActor.prefab");
        UnityEngine.Object.DestroyImmediate(actor);
        EditorUtility.SetDirty(material);EditorUtility.SetDirty(controller);AssetDatabase.SaveAssets();
        Debug.Log("NAMELESS_HOUND_IMPORT_OK");
    }
}
#endif
