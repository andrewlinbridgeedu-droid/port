using System;
using System.Globalization;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// Enters real Editor Play Mode and captures the formal battle camera. Unlike
/// calling MonoBehaviour.Start in edit mode, this initializes Effekseer and
/// all runtime-only render hooks before the frame is read back.
public static class RuntimePreviewCapture
{
    const string ActiveKey = "Mindstone.RuntimePreview.Active";
    const string OutputKey = "Mindstone.RuntimePreview.Output";
    const string DelayKey = "Mindstone.RuntimePreview.Delay";
    const string SequenceKey = "Mindstone.RuntimePreview.Sequence";
    const string SequenceDirectoryKey = "Mindstone.RuntimePreview.SequenceDirectory";
    const string SequenceTimesKey = "Mindstone.RuntimePreview.SequenceTimes";
    const string SequenceWidthKey = "Mindstone.RuntimePreview.SequenceWidth";
    const string SequenceHeightKey = "Mindstone.RuntimePreview.SequenceHeight";
    static string outputPath;
    static double captureDelay;
    static double playStartedAt;
    static bool enteredPlayMode;
    static bool sequenceCapture;
    static string sequenceDirectory;
    static float[] sequenceTimes;
    static int sequenceIndex;
    static int sequenceWidth;
    static int sequenceHeight;

    [InitializeOnLoadMethod]
    static void RestoreAfterDomainReload()
    {
        if (!SessionState.GetBool(ActiveKey, false)) return;
        outputPath = SessionState.GetString(OutputKey, "");
        captureDelay = SessionState.GetFloat(DelayKey, 1.2f);
        sequenceCapture = SessionState.GetBool(SequenceKey, false);
        sequenceDirectory = SessionState.GetString(SequenceDirectoryKey, "");
        sequenceTimes = ParseTimes(SessionState.GetString(SequenceTimesKey, ""));
        sequenceWidth = SessionState.GetInt(SequenceWidthKey, 2940);
        sequenceHeight = SessionState.GetInt(SequenceHeightKey, 1846);
        sequenceIndex = 0;
        EditorApplication.update -= Update;
        EditorApplication.update += Update;
    }

    public static void Begin()
    {
        outputPath = ReadArgument("-previewOutput");
        captureDelay = double.TryParse(ReadArgument("-previewDelay"), out var value)
            ? value
            : 1.2;
        sequenceDirectory = ReadArgument("-previewSequenceDir");
        sequenceCapture = !string.IsNullOrWhiteSpace(sequenceDirectory);
        sequenceTimes = ParseTimes(ReadArgument("-previewSequenceTimes"))
            ?? new[] { 0.12f, 0.55f, 1.02f, 1.30f, 1.78f };
        sequenceWidth = ParseInt(ReadArgument("-previewSequenceWidth"), 2940);
        sequenceHeight = ParseInt(ReadArgument("-previewSequenceHeight"), 1846);
        sequenceIndex = 0;
        if (!sequenceCapture && string.IsNullOrWhiteSpace(outputPath))
            throw new ArgumentException("Missing -previewOutput.");
        if (sequenceCapture)
            Directory.CreateDirectory(sequenceDirectory);

        SessionState.SetBool(ActiveKey, true);
        SessionState.SetString(OutputKey, outputPath);
        SessionState.SetFloat(DelayKey, (float)captureDelay);
        SessionState.SetBool(SequenceKey, sequenceCapture);
        SessionState.SetString(SequenceDirectoryKey, sequenceDirectory ?? "");
        SessionState.SetString(SequenceTimesKey, string.Join(",", sequenceTimes));
        SessionState.SetInt(SequenceWidthKey, sequenceWidth);
        SessionState.SetInt(SequenceHeightKey, sequenceHeight);
        EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity", OpenSceneMode.Single);
        EditorApplication.update += Update;
        EditorApplication.isPlaying = true;
    }

    static void Update()
    {
        if (!EditorApplication.isPlaying)
        {
            if (enteredPlayMode)
            {
                EditorApplication.update -= Update;
                SessionState.SetBool(ActiveKey, false);
                SessionState.SetBool(SequenceKey, false);
                EditorApplication.Exit(0);
            }
            return;
        }

        if (!enteredPlayMode)
        {
            enteredPlayMode = true;
            playStartedAt = EditorApplication.timeSinceStartup;
            return;
        }
        if (sequenceCapture)
        {
            UpdateSequenceCapture();
            return;
        }
        if (EditorApplication.timeSinceStartup - playStartedAt < captureDelay)
            return;

        CaptureCameraTo(outputPath, 946, 2048);
        EditorApplication.isPlaying = false;
    }

    static void UpdateSequenceCapture()
    {
        var board = UnityEngine.Object.FindFirstObjectByType<MistportVFXShowcaseBoard>();
        if (board == null || !board.PlaybackStarted || sequenceTimes == null)
            return;

        var elapsed = Time.time - board.PlaybackClockStart;
        while (sequenceIndex < sequenceTimes.Length
            && elapsed >= sequenceTimes[sequenceIndex])
        {
            var path = Path.Combine(sequenceDirectory, $"stage-{sequenceIndex + 1}.png");
            CaptureCameraTo(path, sequenceWidth, sequenceHeight);
            sequenceIndex++;
        }

        if (sequenceIndex >= sequenceTimes.Length)
            EditorApplication.isPlaying = false;
    }

    static void CaptureCameraTo(string path, int width, int height)
    {
        var camera = Camera.main ?? throw new InvalidOperationException("Preview camera missing.");
        var previousAspect = camera.aspect;
        camera.aspect = (float)width / height;
        var renderTexture = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
        var image = new Texture2D(width, height, TextureFormat.RGBA32, false);
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;
        try
        {
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            image.Apply();
            Directory.CreateDirectory(Path.GetDirectoryName(path) ?? "/private/tmp");
            File.WriteAllBytes(path, image.EncodeToPNG());
            Debug.Log($"Mindstone: captured runtime preview to {path}");
        }
        finally
        {
            camera.targetTexture = previousTarget;
            camera.aspect = previousAspect;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(renderTexture);
        }
    }

    static float[] ParseTimes(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return null;
        var pieces = raw.Split(',');
        var values = new float[pieces.Length];
        for (var index = 0; index < pieces.Length; index++)
        {
            if (!float.TryParse(
                    pieces[index],
                    NumberStyles.Float,
                    CultureInfo.InvariantCulture,
                    out values[index]))
                return null;
        }
        return values.Length > 0 ? values : null;
    }

    static int ParseInt(string raw, int fallback)
    {
        return int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out var value)
            && value > 0
            ? value
            : fallback;
    }

    static string ReadArgument(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (var i = 0; i < args.Length - 1; i++)
            if (args[i] == name) return args[i + 1];
        return null;
    }
}
