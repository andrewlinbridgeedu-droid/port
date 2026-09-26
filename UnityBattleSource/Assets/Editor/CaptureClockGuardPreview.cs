using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// Captures the current installed Clock Guard model without the legacy 2D
/// fallback or the battle floor. This is a preview artifact for the native
/// simulator path; the device build continues to use the live Unity model.
public static class CaptureClockGuardPreview
{
    public static void Run()
    {
        var output = ReadArgument("-guardPreviewOutput");
        if (string.IsNullOrWhiteSpace(output))
            throw new ArgumentException("Missing -guardPreviewOutput.");

        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity", OpenSceneMode.Single);
        var guard = GameObject.Find("ClockGuard_Imported");
        if (guard == null)
            throw new InvalidOperationException("ClockGuard_Imported is missing from the current scene.");

        foreach (var renderer in UnityEngine.Object.FindObjectsByType<Renderer>(FindObjectsSortMode.None))
        {
            renderer.enabled = renderer.transform == guard.transform
                || renderer.transform.IsChildOf(guard.transform);
        }

        var cameraObject = new GameObject("Clock Guard Preview Camera");
        var camera = cameraObject.AddComponent<Camera>();

        var renderers = guard.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length == 0)
            throw new InvalidOperationException("Clock Guard has no renderers.");

        var bounds = renderers[0].bounds;
        for (var index = 1; index < renderers.Length; index++)
            bounds.Encapsulate(renderers[index].bounds);

        // Match the live battle camera's front-facing angle so the preview
        // cannot silently become a different character pose.
        camera.orthographic = false;
        camera.fieldOfView = 28f;
        camera.transform.rotation = Quaternion.Euler(9f, 0f, 0f);
        camera.transform.position = bounds.center - camera.transform.forward * 6.2f;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0f, 0f, 0f, 0f);

        const int size = 1024;
        var renderTexture = new RenderTexture(size, size, 24, RenderTextureFormat.ARGB32);
        var image = new Texture2D(size, size, TextureFormat.RGBA32, false);
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;
        try
        {
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            image.ReadPixels(new Rect(0, 0, size, size), 0, 0);
            image.Apply();
            var pixels = image.GetPixels32();
            var minX = size;
            var minY = size;
            var maxX = -1;
            var maxY = -1;
            for (var y = 0; y < size; y++)
            for (var x = 0; x < size; x++)
            {
                if (pixels[y * size + x].a < 8) continue;
                minX = Mathf.Min(minX, x);
                minY = Mathf.Min(minY, y);
                maxX = Mathf.Max(maxX, x);
                maxY = Mathf.Max(maxY, y);
            }

            if (maxX < minX || maxY < minY)
                throw new InvalidOperationException("Clock Guard preview rendered no visible pixels.");

            var cropped = new Texture2D(maxX - minX + 1, maxY - minY + 1, TextureFormat.RGBA32, false);
            cropped.SetPixels(image.GetPixels(minX, minY, cropped.width, cropped.height));
            cropped.Apply();
            Directory.CreateDirectory(Path.GetDirectoryName(output) ?? ".");
            File.WriteAllBytes(output, cropped.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(cropped);
            Debug.Log($"Mindstone: captured current Clock Guard preview to {output}");
        }
        finally
        {
            camera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(renderTexture);
            UnityEngine.Object.DestroyImmediate(cameraObject);
        }

        EditorApplication.Exit(0);
    }

    static string ReadArgument(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (var index = 0; index < args.Length - 1; index++)
            if (args[index] == name) return args[index + 1];
        return null;
    }
}
