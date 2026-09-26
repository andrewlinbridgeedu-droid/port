using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class InstallRefinedFool
{
    const string Root = "Assets/Resources/RuntimeModels/FoolRefined/";
    [Serializable] sealed class MaterialSet { public MaterialInfo[] materials; }
    [Serializable] sealed class MaterialInfo { public string name; public float[] color; public float metallic; public float roughness; public bool painted; }
    [MenuItem("Mindstone/Install Refined Fool")]
    public static void Install()
    {
        AssetDatabase.Refresh();
        string source = Directory.GetFiles("Assets/Models/Fool", "*Combat_Stance*.fbx").First();
        var sourceImporter = (ModelImporter)AssetImporter.GetAtPath(source);
        var importer = (ModelImporter)AssetImporter.GetAtPath(Root + "FoolRefined.fbx");
        importer.animationType = ModelImporterAnimationType.Human;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        var description = importer.humanDescription;
        description.human = sourceImporter.humanDescription.human;
        importer.humanDescription = description;
        importer.importAnimation = false;
        importer.importBlendShapes = true;
        importer.optimizeGameObjects = false;
        importer.isReadable = true;
        importer.SaveAndReimport();
        var set = JsonUtility.FromJson<MaterialSet>(File.ReadAllText(Root + "materials.json"));
        Directory.CreateDirectory(Root + "Materials");
        foreach (var entry in set.materials)
        {
            string path = Root + "Materials/" + entry.name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                material = entry.painted
                    ? new Material(AssetDatabase.LoadAssetAtPath<Material>("Assets/Generated/FoolMaterial.mat"))
                    : new Material(Shader.Find("Standard"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.name = entry.name;
            if (!entry.painted) material.color = new Color(entry.color[0], entry.color[1], entry.color[2], entry.color[3]);
            material.SetFloat("_Metallic", entry.metallic);
            material.SetFloat("_Glossiness", 1f-entry.roughness);
            importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material), entry.name), material);
            EditorUtility.SetDirty(material);
        }
        importer.SaveAndReimport();
        string controllerPath = Root + "FoolRefined.controller";
        if (!AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath))
            AssetDatabase.CopyAsset("Assets/Generated/FoolBattle.controller", controllerPath);
        var controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath);
        foreach (var state in controller.layers[0].stateMachine.states)
            if (state.state.name == "Meshy · Idle") { state.state.speed = .65f; EditorUtility.SetDirty(state.state); }
        EditorUtility.SetDirty(controller);
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        ReplacePlayer();
        EditorSceneManager.SaveScene(scene);
        AssetDatabase.SaveAssets();
        Debug.Log("Refined Fool installed with humanoid idle/cast and independent ribbon flutter.");
    }

    public static void ReplacePlayer()
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(Root + "FoolRefined.fbx");
        if (!prefab) throw new InvalidOperationException("Refined Fool FBX missing");
        var previous = GameObject.Find("Fool_Imported");
        if (previous) UnityEngine.Object.DestroyImmediate(previous);
        var actor = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        actor.name = "Fool_Imported";
        actor.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
        actor.transform.localScale = Vector3.one;
        var renderers = actor.GetComponentsInChildren<Renderer>();
        var bounds = renderers[0].bounds;
        foreach (var r in renderers) bounds.Encapsulate(r.bounds);
        actor.transform.localScale = Vector3.one * (2.16f / bounds.size.y);
        bounds = renderers[0].bounds;
        foreach (var r in renderers) bounds.Encapsulate(r.bounds);
        actor.transform.position = new Vector3(0,-bounds.min.y,-4.8f);
        var animator = actor.GetComponent<Animator>();
        if (!animator || !animator.avatar || !animator.avatar.isValid || !animator.avatar.isHuman)
            throw new InvalidOperationException("Refined Fool humanoid avatar is invalid");
        animator.runtimeAnimatorController = AssetDatabase.LoadAssetAtPath<AnimatorController>(Root + "FoolRefined.controller");
        animator.applyRootMotion = false;
        animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        actor.AddComponent<FoolRibbonFlutter>();
        var ribbons = actor.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r => r.name.StartsWith("FoolRibbon")).ToArray();
        if (ribbons.Length != 2 || ribbons.Any(r => r.sharedMesh.blendShapeCount != 4))
            throw new InvalidOperationException("Expected two ribbons with four authored morphs each");
        foreach (var r in actor.GetComponentsInChildren<SkinnedMeshRenderer>()) r.updateWhenOffscreen = true;
    }
}
