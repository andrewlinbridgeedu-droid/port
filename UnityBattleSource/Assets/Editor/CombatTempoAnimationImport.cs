using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

public static class CombatTempoAnimationImport
{
    public static void Build()
    {
        foreach (var kind in new[] { "Hound", "Stonejaw", "Hollow", "Hero" })
        {
            string path = "Assets/Resources/CombatTempo/Animation/" + kind + ".fbx";
            var importer = AssetImporter.GetAtPath(path) as ModelImporter;
            if (!importer) throw new Exception("Missing animation: " + path);
            importer.animationType = ModelImporterAnimationType.Generic;
            importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
            importer.optimizeGameObjects = false;
            importer.importAnimation = true;
            importer.importCameras = false;
            importer.importLights = false;
            importer.materialImportMode = ModelImporterMaterialImportMode.None;
            importer.motionNodeName = kind == "Hound" || kind == "Hero" ? "Hips" : "Root";
            var definitions = importer.defaultClipAnimations;
            foreach (var clip in definitions)
            {
                // Blender exports Armature|Action; action names are the public states.
                clip.name = clip.takeName.Split('|').Last();
                clip.loopTime = clip.name == "BattleIdle" || clip.name == "Walking";
                clip.lockRootHeightY = true;
                clip.lockRootRotation = true;
                clip.lockRootPositionXZ = !new[] { "Light", "HeavyRelease", "HeavyReleaseSecond", "Pounce", "Probe", "Thrust" }.Contains(clip.name);
                clip.keepOriginalPositionY = true;
                clip.keepOriginalPositionXZ = true;
                clip.keepOriginalOrientation = true;
                clip.hasAdditiveReferencePose = clip.name == "HitAdditive" || clip.name == "Hit";
                clip.additiveReferencePoseFrame = clip.firstFrame;
            }
            importer.clipAnimations = definitions;
            importer.SaveAndReimport();
            var clips = AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>()
                .Where(c => !c.name.StartsWith("__")).ToArray();
            var controllerPath = "Assets/Resources/CombatTempo/Animation/" + kind + ".controller";
            var existing = AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath);
            if (existing) AssetDatabase.DeleteAsset(controllerPath);
            var controller = AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
            controller.AddParameter("ActionSpeed", AnimatorControllerParameterType.Float);
            controller.parameters = controller.parameters.Select(p => { if (p.name == "ActionSpeed") p.defaultFloat = 1; return p; }).ToArray();
            var machine = controller.layers[0].stateMachine;
            foreach (var clip in clips.Where(c => c.name != "HitAdditive" && c.name != "Hit"))
            {
                var state = machine.AddState(clip.name); state.motion = clip;
                state.speedParameterActive = true; state.speedParameter = "ActionSpeed";
                if (clip.name == "BattleIdle") machine.defaultState = state;
            }
            var hit = clips.FirstOrDefault(c => c.name == "HitAdditive" || c.name == "Hit");
            if (!hit) throw new Exception("Missing additive hit: " + kind);
            controller.AddLayer("ConfirmedHit");
            var layers = controller.layers;
            layers[1].blendingMode = AnimatorLayerBlendingMode.Additive;
            layers[1].defaultWeight = 0;
            var hitState = layers[1].stateMachine.AddState("Hit"); hitState.motion = hit;
            layers[1].stateMachine.defaultState = hitState;
            controller.layers = layers;
            EditorUtility.SetDirty(controller);
            Debug.Log("TEMPO_ANIMATION_IMPORTED " + kind + ": " + string.Join(",", clips.Select(c => c.name)));
        }
        AssetDatabase.SaveAssets();
    }
}
