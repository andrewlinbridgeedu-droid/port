using UnityEditor;
using UnityEngine;

public static class ImportHeroTheatre
{
    const string Folder="Assets/Resources/Effects/Fool/NamelessDeclaration/";
    public static void Build()
    {
        AssetDatabase.Refresh();
        var importer=(ModelImporter)AssetImporter.GetAtPath(Folder+"NamelessDeclarationMask.fbx");
        importer.importAnimation=false; importer.isReadable=true;
        importer.importNormals=ModelImporterNormals.Import;
        importer.SaveAndReimport();
        var source=AssetDatabase.LoadAssetAtPath<GameObject>(Folder+"NamelessDeclarationMask.fbx");
        var root=new GameObject("MaskActor");
        var model=(GameObject)PrefabUtility.InstantiatePrefab(source);model.transform.SetParent(root.transform,false);
        foreach(var renderer in model.GetComponentsInChildren<Renderer>()) {
            var slots=renderer.sharedMaterials;
            for(int i=0;i<slots.Length;i++) {
                string name=slots[i]?slots[i].name:"Cold ivory porcelain";
                string path=Folder+name+".mat";
                var mat=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(!mat) { mat=new Material(Shader.Find("Standard"));AssetDatabase.CreateAsset(mat,path); }
                mat.color=name.Contains("Aubergine")?new Color(.075f,.025f,.105f):name.Contains("gold")?new Color(.64f,.39f,.105f):new Color(.49f,.46f,.42f);
                mat.SetFloat("_Metallic",name.Contains("gold")?.72f:.08f);
                mat.SetFloat("_Glossiness",.34f);slots[i]=mat;
                EditorUtility.SetDirty(mat);
            }
            renderer.sharedMaterials=slots;
        }
        PrefabUtility.SaveAsPrefabAsset(root,Folder+"MaskActor.prefab");Object.DestroyImmediate(root);
        AssetDatabase.SaveAssets();
        BuildRuntimePreview.BuildMacPlayer();
    }
}
