using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

public static class DunhuangAttackPreviewAssets
{
    const string ModelPath =
        "Assets/Resources/RuntimeModels/DunhuangTestCharacter/DunhuangCelestialWarrior_Attack_v3.fbx";
    const string ControllerPath =
        "Assets/Resources/RuntimeModels/DunhuangAttackPreview.controller";

    [MenuItem("Mindstone/Preview/Prepare Dunhuang Attack Assets")]
    public static void PrepareFromMenu() => Prepare();

    public static void PrepareFromBatch()
    {
        try
        {
            Prepare();
            EditorApplication.Exit(0);
        }
        catch (Exception exception)
        {
            Debug.LogException(exception);
            EditorApplication.Exit(2);
        }
    }

    static void Prepare()
    {
        AssetDatabase.Refresh();
        var clips = AssetDatabase.LoadAllAssetsAtPath(ModelPath)
            .OfType<AnimationClip>()
            .Where(clip => !clip.name.StartsWith("__preview__", StringComparison.OrdinalIgnoreCase))
            .ToArray();
        if (clips.Length == 0)
            throw new InvalidOperationException($"No animation clips found in {ModelPath}");

        var preferred = clips.FirstOrDefault(clip =>
            clip.name.IndexOf("Attack_v3", StringComparison.OrdinalIgnoreCase) >= 0)
            ?? clips.FirstOrDefault(clip =>
                clip.name.IndexOf("Attack", StringComparison.OrdinalIgnoreCase) >= 0)
            ?? clips[0];

        var existing = AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath);
        if (existing != null)
            AssetDatabase.DeleteAsset(ControllerPath);
        Directory.CreateDirectory(Path.GetDirectoryName(
            Path.Combine(Application.dataPath, "Resources/RuntimeModels"))!);
        var controller = AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);
        var state = controller.layers[0].stateMachine.AddState("Dunhuang Attack");
        state.motion = preferred;
        controller.layers[0].stateMachine.defaultState = state;
        EditorUtility.SetDirty(controller);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log($"Mindstone: prepared Dunhuang attack controller from {preferred.name}");
    }
}
