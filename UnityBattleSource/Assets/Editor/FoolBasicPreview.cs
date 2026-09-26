using System.Collections;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class FoolBasicPreview
{
    const string Key = "Mindstone.FoolBasicPreview";
    public static void Begin()
    {
        var shader = Resources.Load<Shader>("Effects/Fool/TarotNova");
        if (!shader || ShaderUtil.ShaderHasError(shader)) { Debug.LogError("Tarot shader validation failed"); EditorApplication.Exit(5); return; }
        SessionState.SetBool(Key, true);
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        EditorApplication.isPlaying = true;
    }
    [InitializeOnLoadMethod]
    static void Restore()
    {
        EditorApplication.playModeStateChanged += state =>
        {
            if (!SessionState.GetBool(Key, false)) return;
            if (state == PlayModeStateChange.EnteredPlayMode)
                new GameObject("Basic Preview Capture").AddComponent<FoolBasicPreviewRunner>();
            if (state == PlayModeStateChange.EnteredEditMode)
            { SessionState.SetBool(Key, false); EditorApplication.Exit(0); }
        };
    }
}
public sealed class FoolBasicPreviewRunner : MonoBehaviour
{
    IEnumerator Start()
    {
        yield return new WaitForSeconds(1);
        var battle = FindFirstObjectByType<BattlePrototype>();
        if (!battle) { Debug.LogError("Missing battle"); EditorApplication.Exit(2); yield break; }
        var camera = Camera.main;
        camera.aspect = 1080f / 1920f;
        Time.captureFramerate = 36;
        var dir = Path.GetFullPath("../artifacts/fool-basic-tarot-v2");
        Directory.CreateDirectory(dir);
        var rt = new RenderTexture(1080,1920,36);
        var image = new Texture2D(1080,1920,TextureFormat.RGBA32,false);
        battle.PresentPlayerBasic();
        for (int i=0;i<81;i++)
        {
            yield return null;
            var currentEffect=battle.GetComponent<FoolBasicTarotVFX>();
            if(currentEffect) currentEffect.Sample(i/36f);
            var old=camera.targetTexture; var active=RenderTexture.active;
            camera.targetTexture=rt; camera.Render(); RenderTexture.active=rt;
            image.ReadPixels(new Rect(0,0,1080,1920),0,0); image.Apply();
            File.WriteAllBytes(Path.Combine(dir,$"frame-{i:D3}.png"),image.EncodeToPNG());
            camera.targetTexture=old; RenderTexture.active=active;
        }
        if (GameObject.Find("Fool Basic Tarot Fullscreen"))
        { Debug.LogError("Basic VFX cleanup failed"); EditorApplication.Exit(3); yield break; }
        // Replay, interruption and cleanup exercise the same component used in battle.
        battle.PresentPlayerBasic(); yield return null;
        var effect=battle.GetComponent<FoolBasicTarotVFX>(); effect.enabled=false;
        yield return null;
        if(GameObject.Find("Fool Basic Tarot Fullscreen"))
        { Debug.LogError("Interrupted VFX cleanup failed"); EditorApplication.Exit(4); yield break; }
        File.WriteAllText(Path.Combine(dir,"validation.txt"),"Real BattlePrototype Play Mode; basic attack natural completion, replay and disable cleanup passed. Background remains ClockPlaza 2D. No device performance test.");
        Time.captureFramerate=0;rt.Release();Destroy(rt);Destroy(image);
        EditorApplication.isPlaying=false;
    }
}
