using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class EnemyPresentationPreviewRenderer
{
    const int PreviewWidth = 946;
    const int PreviewHeight = 2048;
    const string ScenePath = "Assets/Scenes/BattlePrototype.unity";

    public static void RenderClockGuard()
    {
        var outputPath = ReadArgument("-previewOutput");
        if (string.IsNullOrWhiteSpace(outputPath))
            throw new ArgumentException("Missing required -previewOutput argument.");

        Install3DAssets.Install();
        EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);

        var guard = FindEnemy(EnemyBattleIds.ClockGuardPrimary);
        var core = FindEnemy(EnemyBattleIds.ClockCorePrimary);
        if (guard == null)
            throw new InvalidOperationException("Clock Guard was not installed in the battle scene.");

        guard.EnemyRoot.gameObject.SetActive(true);
        if (core != null)
            core.EnemyRoot.gameObject.SetActive(false);

        var runtime = new GameObject("Preview Battle Runtime").AddComponent<BattlePrototype>();
        runtime.SendMessage("Start", SendMessageOptions.RequireReceiver);
        HideEditorOnlyArenaGeometry();
        guard.MotionRoot.GetComponent<EnemyGroundAnchor>()?.Refresh();
        var targetSigil = guard.TargetAnchor.GetComponent<EnemyTargetSigil>();
        if (targetSigil == null)
            throw new InvalidOperationException("Clock Guard target sigil was not installed.");

        var camera = Camera.main;
        if (camera == null)
            throw new InvalidOperationException("The formal battle camera was not created.");
        camera.aspect = (float)PreviewWidth / PreviewHeight;
        targetSigil.SetState(EnemyTargetSigilState.Selected);
        var previewPhase = ReadArgument("-previewPhase");
        if (float.TryParse(
                previewPhase,
                System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture,
                out var normalizedPhase))
        {
            targetSigil.SetPreviewAnimationPhase(normalizedPhase);
        }
        if (EnemyPresenter.TryCalculateRendererBounds(
                guard.MotionRoot,
                guard.VisualRoot.gameObject,
                out var guardBounds))
        {
            Debug.Log(
                $"Mindstone preview anchors: target={guard.TargetAnchor.position}, "
                + $"boundsCenter={guardBounds.center}, boundsMin={guardBounds.min}, "
                + $"targetScreen={camera.WorldToScreenPoint(guard.TargetAnchor.position)}");
        }

        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)
            ?? throw new InvalidOperationException("Preview output has no parent directory."));

        var renderTexture = new RenderTexture(PreviewWidth, PreviewHeight, 24, RenderTextureFormat.ARGB32)
        {
            antiAliasing = 1
        };
        var image = new Texture2D(PreviewWidth, PreviewHeight, TextureFormat.RGBA32, false);
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;

        try
        {
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            image.ReadPixels(new Rect(0, 0, PreviewWidth, PreviewHeight), 0, 0);
            image.Apply();
            File.WriteAllBytes(outputPath, image.EncodeToPNG());
            Debug.Log($"Mindstone: wrote Clock Guard preview to {outputPath}");
        }
        finally
        {
            camera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(renderTexture);
        }
    }

    public static void RenderClockEncounter()
    {
        var outputPath = ReadArgument("-previewOutput");
        if (string.IsNullOrWhiteSpace(outputPath))
            throw new ArgumentException("Missing required -previewOutput argument.");

        Install3DAssets.Install();
        EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);

        var guard = FindEnemy(EnemyBattleIds.ClockGuardPrimary);
        var core = FindEnemy(EnemyBattleIds.ClockCorePrimary);
        if (guard == null || core == null)
            throw new InvalidOperationException("Clock Guard/Core were not installed in the battle scene.");

        guard.EnemyRoot.gameObject.SetActive(true);
        core.EnemyRoot.gameObject.SetActive(true);

        // BattlePrototype sizes its camera-attached background during Start.
        // Lock the formal portrait aspect first so the preview uses the same
        // composition as an iPhone instead of creating a landscape-sized quad
        // and cropping it after the fact.
        var previewCamera = Camera.main;
        if (previewCamera == null)
        {
            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            previewCamera = cameraObject.AddComponent<Camera>();
        }
        previewCamera.aspect = (float)PreviewWidth / PreviewHeight;

        var runtime = new GameObject("Preview Battle Runtime").AddComponent<BattlePrototype>();
        runtime.SendMessage("Start", SendMessageOptions.RequireReceiver);
        runtime.UseClockCoreModel();
        HideEditorOnlyArenaGeometry();

        var camera = Camera.main;
        if (camera == null)
            throw new InvalidOperationException("The formal battle camera was not created.");
        camera.aspect = (float)PreviewWidth / PreviewHeight;
        guard.TargetAnchor.GetComponent<EnemyTargetSigil>()?.SetState(EnemyTargetSigilState.Selected);
        core.TargetAnchor.GetComponent<EnemyTargetSigil>()?.SetState(EnemyTargetSigilState.Hidden);

        Debug.Log(
            $"Mindstone encounter preview positions: "
            + $"guardRoot={guard.EnemyRoot.position}, guardMotion={guard.MotionRoot.position}, "
            + $"coreRoot={core.EnemyRoot.position}, coreMotion={core.MotionRoot.position}");

        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)
            ?? throw new InvalidOperationException("Preview output has no parent directory."));

        var renderTexture = new RenderTexture(PreviewWidth, PreviewHeight, 24, RenderTextureFormat.ARGB32)
        {
            antiAliasing = 1
        };
        var image = new Texture2D(PreviewWidth, PreviewHeight, TextureFormat.RGBA32, false);
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;

        try
        {
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            image.ReadPixels(new Rect(0, 0, PreviewWidth, PreviewHeight), 0, 0);
            image.Apply();
            File.WriteAllBytes(outputPath, image.EncodeToPNG());
            Debug.Log($"Mindstone: wrote Clock Guard/Core preview to {outputPath}");
        }
        finally
        {
            camera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(renderTexture);
        }
    }

    public static void RenderHellHoundEncounter()
    {
        var outputPath = ReadArgument("-previewOutput");
        if (string.IsNullOrWhiteSpace(outputPath))
            throw new ArgumentException("Missing required -previewOutput argument.");

        Install3DAssets.Install();
        EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);

        var guard = FindEnemy(EnemyBattleIds.ClockGuardPrimary);
        var core = FindEnemy(EnemyBattleIds.ClockCorePrimary);
        var hound = FindEnemy(EnemyBattleIds.HellHoundPrimary);
        if (hound == null)
            throw new InvalidOperationException("Hell Hound was not installed in the battle scene.");

        // Start with the guard enabled so BattlePrototype can initialise its
        // baseline animator cleanly; UseHellHoundModel hides it immediately.
        if (guard != null) guard.EnemyRoot.gameObject.SetActive(true);
        if (core != null) core.EnemyRoot.gameObject.SetActive(false);
        hound.EnemyRoot.gameObject.SetActive(true);

        var previewCamera = Camera.main;
        if (previewCamera == null)
        {
            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            previewCamera = cameraObject.AddComponent<Camera>();
        }
        previewCamera.aspect = (float)PreviewWidth / PreviewHeight;

        var runtime = new GameObject("Preview Battle Runtime").AddComponent<BattlePrototype>();
        runtime.SendMessage("Start", SendMessageOptions.RequireReceiver);
        runtime.UseHellHoundModel();
        runtime.CreateHellHoundAttackPosePreview();
        HideEditorOnlyArenaGeometry();

        var camera = Camera.main;
        if (camera == null)
            throw new InvalidOperationException("The formal battle camera was not created.");
        camera.aspect = (float)PreviewWidth / PreviewHeight;
        hound.TargetAnchor.GetComponent<EnemyTargetSigil>()?.SetState(EnemyTargetSigilState.Hidden);

        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)
            ?? throw new InvalidOperationException("Preview output has no parent directory."));
        var renderTexture = new RenderTexture(PreviewWidth, PreviewHeight, 24, RenderTextureFormat.ARGB32)
        {
            antiAliasing = 1
        };
        var image = new Texture2D(PreviewWidth, PreviewHeight, TextureFormat.RGBA32, false);
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;

        try
        {
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            image.ReadPixels(new Rect(0, 0, PreviewWidth, PreviewHeight), 0, 0);
            image.Apply();
            File.WriteAllBytes(outputPath, image.EncodeToPNG());
            Debug.Log($"Mindstone: wrote Hell Hound preview to {outputPath}");
        }
        finally
        {
            camera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(renderTexture);
        }
    }

    static EnemyHandle FindEnemy(string battleEnemyId)
    {
        var handles = UnityEngine.Object.FindObjectsByType<EnemyHandle>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        for (var i = 0; i < handles.Length; i++)
        {
            if (handles[i].BattleEnemyId == battleEnemyId)
                return handles[i];
        }
        return null;
    }

    static void HideEditorOnlyArenaGeometry()
    {
        var objects = UnityEngine.Object.FindObjectsByType<GameObject>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        for (var i = 0; i < objects.Length; i++)
        {
            var name = objects[i].name;
            if (name == "Clock Arena" || name.StartsWith("Arena Rune Ring", StringComparison.Ordinal))
                objects[i].SetActive(false);
        }
    }

    static string ReadArgument(string name)
    {
        var arguments = Environment.GetCommandLineArgs();
        for (var i = 0; i < arguments.Length - 1; i++)
        {
            if (string.Equals(arguments[i], name, StringComparison.Ordinal))
                return Path.GetFullPath(arguments[i + 1]);
        }
        return null;
    }
}
