#if UNITY_EDITOR || UNITY_STANDALONE

using System;
using System.Collections;
using System.Collections.Generic;
using Mindstone.VFXV1;
using UnityEngine;

/// <summary>
/// Presentation-only board for the Mistport combat VFX.
///
/// The battle preview remains the source of truth for actor anchors and
/// effect choreography. This component only changes the camera composition,
/// adds a dark presentation board, and runs a second effect layer as a clean
/// hero shot on the right side of the frame.
/// </summary>
public sealed class MistportVFXShowcaseBoard : MonoBehaviour
{
    readonly List<GameObject> boardObjects = new();
    readonly List<Material> boardMaterials = new();
    MistportSpellShowcaseVFX heroVFX;
    SpellBridge heroV1;
    BattlePrototype battleOwner;
    string effectID;
    bool captureReview;
    Coroutine playbackRoutine;
    bool boardReady;
    bool slowMotion;
    bool isPlaying;
    bool offscreenCapture;

    /// <summary>
    /// Exact playback timing for the editor-side RenderTexture capture path.
    /// This avoids guessing an offset from scene startup when the interactive
    /// board and the offscreen reviewer use the same choreography.
    /// </summary>
    public bool PlaybackStarted { get; private set; }
    public float PlaybackClockStart { get; private set; }

    public IEnumerator Play(BattlePrototype battle, string requestedEffectID)
    {
        if (battle == null)
            yield break;

        battleOwner = battle;
        effectID = NormalizeEffectID(requestedEffectID);
        captureReview = HasArgument("--capture-vfx-board-review");
        offscreenCapture = HasArgument("--capture-vfx-board-offscreen");
        if (HasArgument("--capture-vfx-board-sequence"))
            Time.timeScale = 0.12f;

        ConfigureCamera();
        BuildWorldBoard(effectID);
        battleOwner.PrepareVFXShowcaseActors(effectID, -3.45f);

        // Give the imported model one frame to settle at its new presentation
        // anchor before the effect coroutines sample it.
        yield return null;

        heroVFX = gameObject.AddComponent<MistportSpellShowcaseVFX>();
        heroV1 = gameObject.AddComponent<SpellBridge>();
        if (effectID == "fireball")
            heroVFX.NativeFireballScale = 1.65f;
        boardReady = true;
        Replay();
    }

    /// <summary>
    /// Replays both the live character-side effect and the clean hero shot.
    /// The board stays open after the sequence so the artist can inspect it
    /// repeatedly instead of having to relaunch the preview application.
    /// </summary>
    public void Replay()
    {
        if (!boardReady || battleOwner == null || heroVFX == null)
            return;

        if (playbackRoutine != null)
        {
            StopCoroutine(playbackRoutine);
            playbackRoutine = null;
        }

        PlaybackStarted = false;
        PlaybackClockStart = 0f;
        battleOwner.StopVFXShowcaseEffect();
        heroVFX.Stop();
        heroV1?.Stop();
        battleOwner.PrepareVFXShowcaseActors(effectID, -3.45f);
        playbackRoutine = StartCoroutine(PlaySequence());
    }

    public void ToggleSlowMotion()
    {
        slowMotion = !slowMotion;
        Time.timeScale = slowMotion ? 0.30f : 1f;
    }

    IEnumerator PlaySequence()
    {
        isPlaying = true;
        PlaybackStarted = true;
        PlaybackClockStart = Time.time;
        battleOwner.TriggerVFXShowcaseAttack();
        StartCoroutine(battleOwner.PlayVFXShowcaseEffect(effectID));

        var heroSource = effectID == "fireball"
            ? new Vector3(3.45f, 3.72f, 3.80f)
            : effectID == "fireelementalist"
                ? new Vector3(1.80f, 2.90f, 3.80f)
                : new Vector3(1.80f, 1.65f, 3.80f);
        var heroTarget = effectID == "fireball"
            ? new Vector3(3.45f, 0.72f, 3.80f)
            : effectID == "wildwarden"
                ? new Vector3(3.45f, -0.72f, 3.80f)
            : new Vector3(3.45f, 0.66f, 3.80f);

        if (heroV1 != null && heroV1.CanPlay(effectID)
            && SpellBridge.TryGetShowcase(effectID, out var v1Showcase))
        {
            var configuredSource = Vector3Of(v1Showcase.source, new Vector3(3.45f, 1.65f, 3.80f));
            var configuredTarget = Vector3Of(v1Showcase.target, new Vector3(3.45f, 0.66f, 3.80f));
            if (effectID == "storm-verdant-vortex-v1")
            {
                // The spell's runtime axis still comes from the real
                // source-to-target motion.  Give the isolated hero shot a
                // diagonal attack lane so the growing wind cone can be read
                // as propulsion rather than a vertical standing shield.
                configuredSource = new Vector3(2.38f, 0.84f, 3.80f);
                configuredTarget = new Vector3(3.45f, 0.66f, 3.80f);
            }
            else
            {
                configuredSource.x = 3.45f;
                configuredTarget.x = 3.45f;
            }
            var source = (Func<Vector3>)(() => configuredSource);
            var target = (Func<Vector3>)(() => configuredTarget);
            StartCoroutine(heroV1.Play(
                effectID,
                source,
                target,
                mouth: source,
                impact: target,
                ground: target));
        }
        else if (effectID == "fireball")
        {
            StartCoroutine(heroVFX.PlayFireball(
                () => heroSource,
                () => heroTarget));
        }
        else if (effectID == "wildwarden")
        {
            StartCoroutine(heroVFX.PlayWildWarden(
                () => heroTarget));
        }
        else if (effectID == "fireelementalist")
        {
            StartCoroutine(heroVFX.PlayFireElementalist(
                () => heroSource,
                () => heroTarget));
        }
        else
        {
            StartCoroutine(heroVFX.PlaySwordQi(
                () => heroSource,
                () => heroTarget));
        }

        var captureTimes = HasArgument("--capture-vfx-board-sequence")
            ? BuildContinuousCaptureTimes(effectID)
            : GetReviewCaptureTimes(effectID);
        // Capture against one absolute playback clock. The old relative waits
        // accumulated the WaitForEndOfFrame cost after every screenshot, so
        // the fifth review frame could be several render frames late.
        var captureClockStart = Time.time;
        for (var index = 0; index < captureTimes.Length; index++)
        {
            var remaining = captureTimes[index] - (Time.time - captureClockStart);
            if (remaining > 0f)
                yield return new WaitForSeconds(remaining);
            yield return new WaitForEndOfFrame();
            var frameName = HasArgument("--capture-vfx-board-sequence")
                ? $"frame-{index + 1:00}"
                : $"stage-{index + 1}";
            if (!offscreenCapture)
                BattlePrototype.CapturePreviewFrame(
                    $"/private/tmp/mindstone-vfx-board-{effectID}-{frameName}.bmp");
        }

        yield return new WaitForSeconds(0.45f);
        battleOwner.StopVFXShowcaseEffect();
        heroVFX.Stop();
        heroV1?.Stop();
        isPlaying = false;
        PlaybackStarted = false;
        playbackRoutine = null;
        if (captureReview)
            Application.Quit(0);
    }

    void Update()
    {
        if (!boardReady)
            return;

#if ENABLE_INPUT_SYSTEM
        var keyboard = UnityEngine.InputSystem.Keyboard.current;
        if (keyboard != null && keyboard.spaceKey.wasPressedThisFrame)
            Replay();
        if (keyboard != null && keyboard.sKey.wasPressedThisFrame)
            ToggleSlowMotion();
#elif ENABLE_LEGACY_INPUT_MANAGER
        if (Input.GetKeyDown(KeyCode.Space))
            Replay();
        if (Input.GetKeyDown(KeyCode.S))
            ToggleSlowMotion();
#endif
    }

    void OnGUI()
    {
        if (!boardReady)
            return;

        var oldColor = GUI.color;
        var panelRect = new Rect(0f, Screen.height - 112f, Screen.width, 112f);
        GUI.color = new Color(0.018f, 0.026f, 0.034f, 0.96f);
        GUI.Box(panelRect, GUIContent.none);
        GUI.color = Color.white;

        var buttonStyle = new GUIStyle(GUI.skin.button)
        {
            fontSize = 18,
            fontStyle = FontStyle.Bold
        };
        if (GUI.Button(
                new Rect(64f, Screen.height - 84f, 190f, 50f),
                "PLAY / REPLAY",
                buttonStyle))
            Replay();
        if (GUI.Button(
                new Rect(272f, Screen.height - 84f, 190f, 50f),
                slowMotion ? "SLOW x0.30  ON" : "SLOW x0.30",
                buttonStyle))
            ToggleSlowMotion();

        var labelStyle = new GUIStyle(GUI.skin.label)
        {
            fontSize = 14,
            alignment = TextAnchor.MiddleLeft
        };
        GUI.Label(
            new Rect(492f, Screen.height - 80f, 390f, 42f),
            "SPACE: replay     S: slow motion",
            labelStyle);
        GUI.Label(
            new Rect(Screen.width - 196f, Screen.height - 80f, 150f, 42f),
            isPlaying ? "PLAYING" : "READY",
            labelStyle);
        GUI.color = oldColor;
    }

    void ConfigureCamera()
    {
        var camera = Camera.main;
        if (camera == null)
            return;

        camera.transform.position = new Vector3(0f, 0.72f, -17.5f);
        camera.transform.rotation = Quaternion.Euler(4.5f, 0f, 0f);
        camera.fieldOfView = 21f;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.035f, 0.050f, 0.064f, 1f);

        if (QualitySettings.antiAliasing < 2)
            QualitySettings.antiAliasing = 4;
    }

    static string NormalizeEffectID(string requestedEffectID)
    {
        if (SpellRegistry.Contains(requestedEffectID))
            return requestedEffectID;
        if (string.Equals(requestedEffectID, "fireball", StringComparison.OrdinalIgnoreCase))
            return "fireball";
        if (string.Equals(requestedEffectID, "sword", StringComparison.OrdinalIgnoreCase))
            return "sword";
        if (string.Equals(requestedEffectID, "wildwarden", StringComparison.OrdinalIgnoreCase)
            || string.Equals(requestedEffectID, "wild-warden", StringComparison.OrdinalIgnoreCase)
            || string.Equals(requestedEffectID, "nature", StringComparison.OrdinalIgnoreCase))
            return "wildwarden";
        if (string.Equals(requestedEffectID, "fireelementalist", StringComparison.OrdinalIgnoreCase)
            || string.Equals(requestedEffectID, "fire-elementalist", StringComparison.OrdinalIgnoreCase)
            || string.Equals(requestedEffectID, "elementalfire", StringComparison.OrdinalIgnoreCase))
            return "fireelementalist";
        return "sword";
    }

    void BuildWorldBoard(string effectID)
    {
        var accent = effectID == "wildwarden"
            ? new Color(0.38f, 0.86f, 0.20f, 1f)
            : effectID == "storm-frost-tornado-v1"
                ? new Color(0.26f, 0.74f, 0.76f, 1f)
            : effectID == "fireball" || effectID == "fireelementalist"
                ? new Color(0.95f, 0.22f, 0.045f, 1f)
                : new Color(0.95f, 0.28f, 0.055f, 1f);
        var panelColor = new Color(0.055f, 0.075f, 0.090f, 1f);
        var panelEdge = Color.Lerp(panelColor, accent, 0.14f);

        CreatePanel(
            "VFX Board · Character Panel Edge",
            new Vector3(-3.45f, 0.65f, 4.60f),
            new Vector2(6.28f, 7.16f),
            panelEdge);
        CreatePanel(
            "VFX Board · Character Panel",
            new Vector3(-3.45f, 0.65f, 4.54f),
            new Vector2(6.12f, 7.00f),
            panelColor);
        CreatePanel(
            "VFX Board · Hero Panel Edge",
            new Vector3(3.45f, 0.65f, 4.60f),
            new Vector2(6.28f, 7.16f),
            panelEdge);
        CreatePanel(
            "VFX Board · Hero Panel",
            new Vector3(3.45f, 0.65f, 4.54f),
            new Vector2(6.12f, 7.00f),
            panelColor);

        var runtimeBackground = GameObject.Find("Clock Plaza Background");
        if (runtimeBackground != null)
            runtimeBackground.SetActive(false);

        CreatePanel(
            "VFX Board · Center Divider",
            new Vector3(0f, 0.65f, 4.42f),
            new Vector2(0.018f, 6.62f),
            new Color(0.46f, 0.54f, 0.56f, 0.52f));

        var palette = effectID == "storm-frost-tornado-v1"
            ? new[]
            {
                new Color(0.05f, 0.18f, 0.22f, 1f),
                new Color(0.10f, 0.34f, 0.40f, 1f),
                new Color(0.24f, 0.62f, 0.66f, 1f),
                new Color(0.50f, 0.84f, 0.82f, 1f),
                new Color(0.86f, 0.98f, 0.93f, 1f)
            }
            : effectID == "wildwarden"
            ? new[]
            {
                new Color(0.015f, 0.16f, 0.035f, 1f),
                new Color(0.06f, 0.42f, 0.08f, 1f),
                new Color(0.22f, 0.72f, 0.12f, 1f),
                new Color(0.56f, 0.92f, 0.20f, 1f),
                new Color(0.86f, 1f, 0.54f, 1f)
            }
            : effectID == "fireball" || effectID == "fireelementalist"
            ? new[]
            {
                new Color(0.28f, 0.015f, 0.005f, 1f),
                new Color(0.82f, 0.055f, 0.01f, 1f),
                new Color(1f, 0.24f, 0.025f, 1f),
                new Color(1f, 0.62f, 0.10f, 1f),
                new Color(1f, 0.94f, 0.58f, 1f)
            }
            : new[]
            {
                new Color(0.22f, 0.005f, 0.008f, 1f),
                new Color(0.78f, 0.02f, 0.04f, 1f),
                new Color(1f, 0.14f, 0.025f, 1f),
                new Color(1f, 0.48f, 0.08f, 1f),
                new Color(1f, 0.88f, 0.35f, 1f)
            };
        var paletteStart = effectID == "fireball" || effectID == "fireelementalist"
            ? 3.00f
            : 3.16f;
        for (var index = 0; index < palette.Length; index++)
            CreatePanel(
                $"VFX Board · Palette {index + 1}",
                new Vector3(paletteStart + index * 0.20f, -2.48f, 4.41f),
                new Vector2(0.16f, 0.055f),
                palette[index]);
    }

    void CreatePanel(string name, Vector3 position, Vector2 size, Color color)
    {
        var panel = GameObject.CreatePrimitive(PrimitiveType.Quad);
        panel.name = name;
        panel.transform.position = position;
        panel.transform.localScale = new Vector3(size.x, size.y, 1f);
        var collider = panel.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);

        var shader = Shader.Find("Unlit/Color")
            ?? Shader.Find("Sprites/Default")
            ?? Shader.Find("Unlit/Transparent");
        if (shader != null)
        {
            var material = new Material(shader) { color = color };
            panel.GetComponent<Renderer>().material = material;
            boardMaterials.Add(material);
        }
        boardObjects.Add(panel);
    }

    static float[] GetReviewCaptureTimes(string effectID)
    {
        if (SpellBridge.TryGetCaptureTimes(effectID, out var v1Times))
            return v1Times;
        return effectID == "fireball"
            ? new[] { 0.12f, 0.36f, 0.60f, 0.84f, 1.28f }
            : effectID == "wildwarden"
                ? new[] { 0.12f, 0.34f, 0.58f, 0.86f, 1.14f, 1.42f, 1.72f, 2.02f }
                : effectID == "fireelementalist"
                    ? new[] { 0.10f, 0.30f, 0.54f, 0.78f, 1.02f, 1.28f, 1.56f, 1.86f }
            : new[] { 0.10f, 0.52f, 0.96f, 1.18f, 1.82f };
    }

    static float[] BuildContinuousCaptureTimes(string effectID)
    {
        var duration = SpellBridge.Duration(effectID, effectID == "fireball"
            ? 1.62f
            : effectID == "wildwarden"
                ? 2.16f
                : effectID == "fireelementalist"
                    ? 2.30f
                    : 2.05f);
        const int frameCount = 48;
        var times = new float[frameCount];
        for (var index = 0; index < frameCount; index++)
            times[index] = 0.04f + index * (duration - 0.04f) / (frameCount - 1);
        return times;
    }

    static bool HasArgument(string value)
    {
        var arguments = Environment.GetCommandLineArgs();
        for (var index = 0; index < arguments.Length; index++)
            if (arguments[index] == value)
                return true;
        return false;
    }

    static Vector3 Vector3Of(float[] values, Vector3 fallback)
    {
        return values != null && values.Length >= 3
            ? new Vector3(values[0], values[1], values[2])
            : fallback;
    }

    void CleanupBoard()
    {
        if (playbackRoutine != null)
        {
            StopCoroutine(playbackRoutine);
            playbackRoutine = null;
        }

        battleOwner?.StopVFXShowcaseEffect();
        Time.timeScale = 1f;
        slowMotion = false;
        isPlaying = false;
        boardReady = false;

        if (heroVFX != null)
        {
            heroVFX.Stop();
            Destroy(heroVFX);
            heroVFX = null;
        }
        if (heroV1 != null)
        {
            heroV1.Stop();
            Destroy(heroV1);
            heroV1 = null;
        }

        for (var index = 0; index < boardObjects.Count; index++)
        {
            if (boardObjects[index] != null)
                Destroy(boardObjects[index]);
        }
        boardObjects.Clear();

        for (var index = 0; index < boardMaterials.Count; index++)
        {
            if (boardMaterials[index] != null)
                Destroy(boardMaterials[index]);
        }
        boardMaterials.Clear();
        battleOwner = null;
    }

    void OnDestroy()
    {
        CleanupBoard();
    }
}

#endif
