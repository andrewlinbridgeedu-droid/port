using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class InstallP1Visuals
{
    public static void InstallAndExport()
    {
        const string source = "Assets/Models/MemoryLeech/MemoryLeech.fbx";
        AssetDatabase.Refresh();
        var importer = (ModelImporter)AssetImporter.GetAtPath(source);
        importer.animationType = ModelImporterAnimationType.Legacy;
        importer.importAnimation = true;
        importer.SaveAndReimport();
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        foreach (var old in Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None))
            if (old.BattleEnemyId == "memory-leech-primary") Object.DestroyImmediate(old.gameObject);
        var model = Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(source));
        model.name = "MemoryLeechModel";
        const string textureRoot = "Assets/Models/MemoryLeech/Textures/";
        foreach (var name in new[] { "BaseColor", "MetallicRoughness", "Normal" }) {
            var textureImporter = AssetImporter.GetAtPath(textureRoot + name + ".jpg") as TextureImporter;
            if (textureImporter == null) throw new System.Exception("Missing original leech texture: " + name);
            textureImporter.textureType = name == "Normal" ? TextureImporterType.NormalMap : TextureImporterType.Default;
            textureImporter.sRGBTexture = name == "BaseColor";
            textureImporter.SaveAndReimport();
        }
        const string materialPath = "Assets/Generated/MemoryLeechBody.mat";
        var bodyMaterial = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
        var bodyShader = Shader.Find("Mindstone/Memory Leech GLTF");
        if (bodyShader == null) throw new System.Exception("Missing leech GLTF shader");
        if (bodyMaterial == null) {
            bodyMaterial = new Material(bodyShader);
            AssetDatabase.CreateAsset(bodyMaterial, materialPath);
        }
        bodyMaterial.shader = bodyShader;
        bodyMaterial.SetTexture("_MainTex", AssetDatabase.LoadAssetAtPath<Texture2D>(textureRoot + "BaseColor.jpg"));
        bodyMaterial.SetTexture("_MetallicRoughness", AssetDatabase.LoadAssetAtPath<Texture2D>(textureRoot + "MetallicRoughness.jpg"));
        bodyMaterial.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(textureRoot + "Normal.jpg"));
        EditorUtility.SetDirty(bodyMaterial);
        var body = model.GetComponentsInChildren<SkinnedMeshRenderer>(true).FirstOrDefault(r => r.name == "Mesh_0");
        if (body == null) throw new System.Exception("Missing leech body mesh");
        body.sharedMaterial = bodyMaterial;
        // The imported animation envelope includes expanded death effects and
        // is hundreds of times larger than the resting creature. Formation
        // fitting must use the mesh's rest bounds, not that animation envelope.
        foreach (var skin in model.GetComponentsInChildren<SkinnedMeshRenderer>(true)) {
            if (skin.sharedMesh == null) continue;
            skin.localBounds = skin.sharedMesh.bounds;
            skin.updateWhenOffscreen = true;
        }
        var animation = model.GetComponent<Animation>() ?? model.AddComponent<Animation>();
        foreach (var clip in AssetDatabase.LoadAllAssetsAtPath(source).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__")))
        {
            Debug.Log("P1 leech clip: " + clip.name);
            foreach (var name in new[] { "Idle", "Cast", "Hit", "Death" })
                if (clip.name.Contains(name)) {
                    // Persist independent clips: imported FBX alias references have
                    // previously serialized as fileID 0 in the generated prefab.
                    var clipPath = "Assets/Generated/MemoryLeech_" + name + ".anim";
                    var stableClip = AssetDatabase.LoadAssetAtPath<AnimationClip>(clipPath);
                    if (stableClip == null) {
                        stableClip = Object.Instantiate(clip);
                        stableClip.name = name;
                        stableClip.legacy = true;
                        AssetDatabase.CreateAsset(stableClip, clipPath);
                    } else {
                        EditorUtility.CopySerialized(clip, stableClip);
                        stableClip.name = name;
                        stableClip.legacy = true;
                        EditorUtility.SetDirty(stableClip);
                    }
                    animation.AddClip(stableClip, name);
                }
        }
        if (animation.GetClip("Idle") == null || animation.GetClip("Cast") == null || animation.GetClip("Death") == null)
            throw new System.Exception("Memory leech requires Idle/Cast/Death animation clips.");
        animation.clip = animation.GetClip("Idle");
        animation.wrapMode = WrapMode.Loop;
        animation.playAutomatically = true;
        model.AddComponent<MemoryLeechPresentation>();
        var prefab = PrefabUtility.SaveAsPrefabAsset(model, "Assets/Generated/MemoryLeechModel.prefab");
        Object.DestroyImmediate(model);
        var path = "Assets/Generated/MemoryLeechVisualProfile.asset";
        var profile = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(path);
        if (profile == null) { profile = ScriptableObject.CreateInstance<EnemyVisualProfile>(); AssetDatabase.CreateAsset(profile, path); }
        profile.Configure("memory-leech", prefab, null,
            new[] { new EnemyOrientationStep(EnemyOrientationAxis.Y, 180f) }, .68f,
            EnemyFormationSlotIds.RearLeft, Vector3.zero,
            new EnemyHoverConfiguration(false, 0, 4),
            new EnemyAnchorConfiguration(new Vector3(0,.45f,0),Vector3.zero,new Vector3(0,1.35f,0),new Vector3(0,1.1f,0),new Vector3(0,.5f,0)));
        EditorUtility.SetDirty(profile);
        var handle = EnemyPresenter.Present(new EnemyPresentationRequest {
            Profile=profile, Formation=AssetDatabase.LoadAssetAtPath<EnemyFormationProfile>(Install3DAssets.FormationAssetPath),
            SlotId=EnemyFormationSlotIds.RearLeft, BattleEnemyId="memory-leech-primary", EnableMotion=false
        });
        handle.EnemyRoot.name = "MemoryLeech_Imported";
        handle.gameObject.SetActive(false);
        EditorSceneManager.SaveScene(scene);
        AssetDatabase.SaveAssets();
        ExportIOSLibrary.Export();
    }
}
