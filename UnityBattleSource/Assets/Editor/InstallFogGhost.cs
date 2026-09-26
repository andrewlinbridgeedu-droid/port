using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

public static class InstallFogGhost {
    public static void Install() {
        AssetDatabase.Refresh();
        const string source="Assets/Models/FogGhost/Ghost.fbx";
        var importer=(ModelImporter)AssetImporter.GetAtPath(source);
        importer.animationType=ModelImporterAnimationType.Generic;
        importer.importAnimation=false;
        importer.materialImportMode=ModelImporterMaterialImportMode.None;
        importer.SaveAndReimport();
        foreach(var file in Directory.GetFiles("Assets/Models/FogGhost","*.png")) {
            var ti=(TextureImporter)AssetImporter.GetAtPath(file);
            ti.maxTextureSize=2048;ti.mipmapEnabled=true;
            if(file.Contains("normal"))ti.textureType=TextureImporterType.NormalMap;
            if(file.Contains("metallic")||file.Contains("roughness"))ti.sRGBTexture=false;
            ti.SaveAndReimport();
        }
        Directory.CreateDirectory("Assets/Resources/RuntimeModels/FogGhost");AssetDatabase.Refresh();
        var mat=new Material(Shader.Find("Standard"));
        mat.mainTexture=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Models/FogGhost/Ghost_color.png");
        mat.SetTexture("_BumpMap",AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Models/FogGhost/Ghost_normal.png"));mat.EnableKeyword("_NORMALMAP");
        mat.SetFloat("_Metallic",.12f);mat.SetFloat("_Glossiness",.24f);
        const string materialPath="Assets/Resources/RuntimeModels/FogGhost/Ghost.mat";
        var existing=AssetDatabase.LoadAssetAtPath<Material>(materialPath);
        if(existing){EditorUtility.CopySerialized(mat,existing);Object.DestroyImmediate(mat);mat=existing;}
        else AssetDatabase.CreateAsset(mat,materialPath);
        var root=new GameObject("FogGhost");
        var model=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(source));model.transform.SetParent(root.transform,false);
        foreach(var animator in model.GetComponentsInChildren<Animator>(true)) Object.DestroyImmediate(animator);
        foreach(var renderer in model.GetComponentsInChildren<Renderer>(true))renderer.sharedMaterials=renderer.sharedMaterials.Select(_=>mat).ToArray();
        var bounds=new Bounds();bool first=true;
        foreach(var r in model.GetComponentsInChildren<Renderer>()){if(first){bounds=r.bounds;first=false;}else bounds.Encapsulate(r.bounds);}
        float scale=2.1f/Mathf.Max(.01f,bounds.size.y);
        model.transform.localScale*=scale;
        model.transform.localPosition=new Vector3(-bounds.center.x*scale,-bounds.min.y*scale,-bounds.center.z*scale);
        root.AddComponent<FogGhostActor>();
        PrefabUtility.SaveAsPrefabAsset(root,"Assets/Resources/RuntimeModels/FogGhost/Ghost.prefab");
        Object.DestroyImmediate(root);AssetDatabase.SaveAssets();
        Debug.Log("Fog ghost prefab installed, source height="+bounds.size.y);
    }
}
