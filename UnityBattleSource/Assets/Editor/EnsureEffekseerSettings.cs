using System.Linq;
using Effekseer;
using UnityEditor;
using UnityEngine;

public static class EnsureEffekseerSettings
{
    const string AssetPath = "Assets/Resources/EffekseerSettings.asset";

    public static void Create()
    {
        var settings = AssetDatabase.LoadAssetAtPath<EffekseerSettings>(AssetPath);
        if (settings == null)
        {
            settings = ScriptableObject.CreateInstance<EffekseerSettings>();
            AssetDatabase.CreateAsset(settings, AssetPath);
        }

        var preloaded = PlayerSettings.GetPreloadedAssets().ToList();
        preloaded.RemoveAll(asset => asset is EffekseerSettings);
        preloaded.Add(settings);
        PlayerSettings.SetPreloadedAssets(preloaded.ToArray());
        AssetDatabase.SaveAssets();
    }
}
