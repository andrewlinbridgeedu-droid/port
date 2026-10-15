using System.IO;
using UnityEditor;
using UnityEngine;

public sealed class AIHeroImport : AssetPostprocessor {
    void OnPreprocessTexture() {
        if (!assetPath.StartsWith("Assets/Resources/CombatTempo/AIHero/")) return;
        var t=(TextureImporter)assetImporter;
        t.textureType=TextureImporterType.Default;t.sRGBTexture=true;
        t.alphaSource=TextureImporterAlphaSource.FromInput;t.alphaIsTransparency=true;
        t.mipmapEnabled=false;t.isReadable=false;t.npotScale=TextureImporterNPOTScale.None;
        t.maxTextureSize=4096;t.wrapMode=TextureWrapMode.Clamp;t.filterMode=FilterMode.Bilinear;
        t.textureCompression=TextureImporterCompression.CompressedHQ;
        t.SetPlatformTextureSettings(new TextureImporterPlatformSettings { name="Standalone",overridden=true,maxTextureSize=4096,format=TextureImporterFormat.BC7,compressionQuality=70 });
        t.SetPlatformTextureSettings(new TextureImporterPlatformSettings { name="iPhone",overridden=true,maxTextureSize=4096,format=TextureImporterFormat.ASTC_6x6,compressionQuality=70 });
    }
    public static void BuildPreview() {
        AssetDatabase.Refresh();
        foreach (var file in Directory.GetFiles("Assets/Resources/CombatTempo/AIHero","*.png",SearchOption.AllDirectories))
            AssetDatabase.ImportAsset(file,ImportAssetOptions.ForceUpdate);
        AssetDatabase.SaveAssets();BuildRuntimePreview.BuildMacPlayer();
    }
}
