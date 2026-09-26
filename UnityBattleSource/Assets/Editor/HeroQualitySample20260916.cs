using UnityEditor;
public static class HeroQualitySample20260916 {
 public static void ImportAndBuild() {
  AssetDatabase.Refresh();
  var path="Assets/Resources/RuntimeModels/Fool/HeroRegions.png";
  var i=(TextureImporter)AssetImporter.GetAtPath(path);i.sRGBTexture=false;i.textureCompression=TextureImporterCompression.Uncompressed;i.maxTextureSize=1024;i.mipmapEnabled=true;i.wrapMode=UnityEngine.TextureWrapMode.Clamp;i.SaveAndReimport();
  var face=(TextureImporter)AssetImporter.GetAtPath("Assets/Resources/RuntimeModels/Fool/HeroFacePaint.png");
  if(face){face.sRGBTexture=true;face.alphaSource=TextureImporterAlphaSource.FromInput;face.alphaIsTransparency=false;face.textureCompression=TextureImporterCompression.CompressedHQ;face.maxTextureSize=2048;face.mipmapEnabled=true;face.wrapMode=UnityEngine.TextureWrapMode.Clamp;face.SaveAndReimport();}
  foreach(var name in new[]{"HeroCostumeAlbedo","HeroCostumeRoughness","HeroCostumeMetallic"}) {
   var costume=(TextureImporter)AssetImporter.GetAtPath("Assets/Resources/RuntimeModels/Fool/"+name+".png");
   if(costume){costume.sRGBTexture=name=="HeroCostumeAlbedo";costume.textureCompression=TextureImporterCompression.CompressedHQ;costume.maxTextureSize=name=="HeroCostumeAlbedo"?4096:2048;costume.mipmapEnabled=true;costume.wrapMode=UnityEngine.TextureWrapMode.Clamp;costume.SaveAndReimport();}
  }
  BuildRuntimePreview.BuildMacPlayer();
 }
}
