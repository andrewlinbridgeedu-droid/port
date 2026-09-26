using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class AddOriginalFoolRibbons
{
    public static void Apply()
    {
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        Attach(GameObject.Find("Fool_Imported"));
        EditorSceneManager.SaveScene(scene);
        AssetDatabase.SaveAssets();
    }

    public static void Attach(GameObject actor)
    {
        const string root = "Assets/Resources/RuntimeModels/FoolRefined/";
        foreach (var old in actor.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r => r.name.StartsWith("FoolRibbon")))
            UnityEngine.Object.DestroyImmediate(old.gameObject);
        var bones = actor.GetComponentsInChildren<Transform>().GroupBy(t => t.name).ToDictionary(g => g.Key, g => g.First());
        var source = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(root + "FoolRefined.fbx"));
        source.transform.SetPositionAndRotation(actor.transform.position, actor.transform.rotation);
        source.transform.localScale = actor.transform.localScale;
        foreach (var ribbon in source.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r => r.name.StartsWith("FoolRibbon")).ToArray())
        {
            var mapped = ribbon.bones.Select(b => bones.TryGetValue(b.name, out var target) ? target : throw new InvalidOperationException("Missing ribbon bone " + b.name)).ToArray();
            var mesh = UnityEngine.Object.Instantiate(ribbon.sharedMesh);
            // Both exports use the original Fool skeleton; preserve its authored rest bind poses.
            string path = root + ribbon.name + "Original.mesh";
            var existing = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (existing) { EditorUtility.CopySerialized(mesh, existing); UnityEngine.Object.DestroyImmediate(mesh); mesh = existing; }
            else AssetDatabase.CreateAsset(mesh, path);
            ribbon.sharedMesh = mesh;
            ribbon.bones = mapped;
            ribbon.rootBone = bones[ribbon.rootBone.name];
            ribbon.transform.SetParent(actor.transform, true);
            ribbon.updateWhenOffscreen = true;
        }
        UnityEngine.Object.DestroyImmediate(source);
        if (!actor.GetComponent<FoolRibbonFlutter>()) actor.AddComponent<FoolRibbonFlutter>();
    }
}
