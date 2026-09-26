#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

/// Repeatable import of losslessly packed source channels. No scene/prefab regeneration.
public static class ModelAssetOptimization20260916
{
    const string Root="Assets/Resources/CharacterSurface20260916/";
    public static void ImportAndBuild() { Import(); BuildRuntimePreview.BuildMacPlayer(); }
    public static void Import()
    {
        AssetDatabase.Refresh();
        var report=new List<string>();
        foreach(var family in new[]{"Guard","OldHound","Core","Ghost","Story"}) {
            var files=family=="Story"?new[]{"Scribe_ORM","Rescue_ORM"}:new[]{"surface_orm"};
            foreach(var file in files) {
                var path=Root+family+"/"+file+".png";
                var importer=AssetImporter.GetAtPath(path) as TextureImporter;
                if(!importer)throw new Exception("Missing packed surface "+path);
                importer.textureType=TextureImporterType.Default;
                importer.sRGBTexture=false;importer.alphaSource=TextureImporterAlphaSource.None;
                importer.isReadable=false;importer.mipmapEnabled=true;importer.maxTextureSize=2048;
                importer.textureCompression=TextureImporterCompression.CompressedHQ;
                var ios=importer.GetPlatformTextureSettings("iPhone");
                ios.name="iPhone";ios.overridden=true;ios.maxTextureSize=2048;
                ios.format=TextureImporterFormat.ASTC_6x6;ios.compressionQuality=100;
                importer.SetPlatformTextureSettings(ios);importer.SaveAndReimport();
                report.Add(path+" linear / mipmapped / GPU-only / iPhone ASTC6");
            }
            if(family=="Story")continue;
            // Source copies stay editable but are no longer implicitly bundled by Resources.
            var source="Assets/SourceOnly/CharacterSurface20260916/"+family;
            Directory.CreateDirectory(source);AssetDatabase.Refresh();
            foreach(var map in new[]{"metallic","roughness"}) {
                var from=Root+family+"/"+map+".png";
                if(!File.Exists(from))continue;
                var error=AssetDatabase.MoveAsset(from,source+"/"+map+".png");
                if(!string.IsNullOrEmpty(error))throw new Exception(error);
            }
        }
        foreach(var model in new[]{"TranscriptionScribe","RescueBearer"}) {
            var path="Assets/Resources/Enemies/Signature/"+model+"/"+model+"_Combat.fbx";
            AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceUpdate);
            var meshes=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Mesh>().ToArray();
            if(meshes.Length==0)throw new Exception("No imported mesh "+path);
            foreach(var mesh in meshes) {
                long triangles=0;for(int s=0;s<mesh.subMeshCount;s++)triangles+=mesh.GetIndexCount(s)/3;
                if(mesh.boneWeights.Length!=mesh.vertexCount)throw new Exception("Missing weights "+path);
                report.Add(model+": vertices="+mesh.vertexCount+" triangles="+triangles+" submeshes="+mesh.subMeshCount+" bindposes="+mesh.bindposes.Length);
            }
            var clips=AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__")).ToArray();
            foreach(var name in new[]{"Idle","Charge","Cast","Hit","Death","Charge2","Cast2"})
                if(!clips.Any(c=>c.name==name&&c.length>0))throw new Exception("Missing clip "+model+"/"+name);
        }
        AssetDatabase.SaveAssets();
        var output=Path.GetFullPath(Path.Combine(Application.dataPath,"../../output/model-optimization-20260916"));
        Directory.CreateDirectory(output);File.WriteAllLines(Path.Combine(output,"unity-import-audit.txt"),report);
        Debug.Log("MODEL_OPTIMIZATION_IMPORT_OK\n"+string.Join("\n",report));
    }
}
#endif
