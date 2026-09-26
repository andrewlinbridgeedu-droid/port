using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

/// Renders the installed Fool model into transparent, north-facing frames for
/// the iOS Simulator's SpriteKit compatibility layer. The device build keeps
/// using the live Animator; these frames make simulator review show the same
/// authored FBX pose instead of silently holding the idle portrait.
public static class FoolPresentationSpriteRenderer
{
    const int OutputSize = 512;
    const int RenderLayer = 31;
    const string ScenePath = "Assets/Scenes/BattlePrototype.unity";
    const string FoolRoot = "Assets/Models/Fool/";
    const string GuardRoot = "Assets/Models/ClockGuard/";

    static readonly float[] IdlePhases = { 0.02f, 0.27f, 0.52f, 0.77f };
    static readonly float[] CastPhases = { 0.02f, 0.18f, 0.36f, 0.56f, 0.76f, 0.94f };
    static readonly float[] GuardIdlePhases = { 0.02f, 0.27f, 0.52f, 0.77f };
    // Match the live Animator: sample the authored spin attack in forward time.
    static readonly float[] GuardAttackPhases =
    {
        0.02f, 0.10f, 0.18f, 0.26f, 0.34f, 0.42f, 0.50f,
        0.58f, 0.66f, 0.74f, 0.82f, 0.90f, 0.98f
    };

    public static void Render()
    {
        var outputDirectory = ReadArgument("-previewOutputDir");
        if (string.IsNullOrWhiteSpace(outputDirectory))
            throw new ArgumentException("Missing required -previewOutputDir argument.");

        outputDirectory = Path.GetFullPath(outputDirectory);
        Directory.CreateDirectory(outputDirectory);
        var assetCatalogRoot = ReadArgument("-assetCatalogRoot");
        if (!string.IsNullOrWhiteSpace(assetCatalogRoot))
            assetCatalogRoot = Path.GetFullPath(assetCatalogRoot);

        Install3DAssets.Install();
        EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);

        var fool = GameObject.Find("Fool_Imported");
        if (fool == null)
            throw new InvalidOperationException("Fool_Imported was not installed in the battle scene.");

        fool.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
        SetLayerRecursively(fool, RenderLayer);
        foreach (var animator in fool.GetComponentsInChildren<Animator>(true))
        {
            animator.applyRootMotion = false;
            animator.enabled = false;
        }

        var idlePath = FindFile(FoolRoot, "Combat_Stance");
        var castPath = FindFile(FoolRoot, "mage_soell_cast_4");
        var idleClip = FindClip(idlePath);
        var castClip = FindClip(castPath);

        var guard = FindEnemy(EnemyBattleIds.ClockGuardPrimary);
        if (guard == null || guard.Model == null)
            throw new InvalidOperationException("Clock Guard was not installed in the battle scene.");
        // Configure the guard up front, but keep it out of the Fool captures.
        // Both models intentionally share the isolated render layer, so only
        // one may be active while its clip is sampled.
        guard.EnemyRoot.gameObject.SetActive(false);
        guard.EnemyRoot.position = Vector3.zero;
        guard.EnemyRoot.rotation = Quaternion.identity;
        guard.MotionRoot.localPosition = Vector3.zero;
        guard.MotionRoot.localRotation = Quaternion.identity;
        guard.HoverMotion?.StopAndReset();
        SetLayerRecursively(guard.VisualRoot.gameObject, RenderLayer);
        var guardAnimator = guard.Model.GetComponentInChildren<Animator>(true);
        if (guardAnimator == null)
            throw new InvalidOperationException("Clock Guard model has no Animator.");
        var guardHorizontalAnchor = guardAnimator.isHuman
            ? guardAnimator.GetBoneTransform(HumanBodyBones.Hips)
            : FindTransform(guardAnimator.transform, "Hips");
        if (guardHorizontalAnchor == null)
            throw new InvalidOperationException("Clock Guard model has no hips anchor.");
        foreach (var animator in guard.Model.GetComponentsInChildren<Animator>(true))
        {
            animator.applyRootMotion = false;
            animator.enabled = false;
        }

        var guardIdlePath = FindFile(GuardRoot, "Combat_Stance");
        var guardAttackToken = ReadArgument("-guardAttackToken") ?? "Axe_Spin_Attack";
        var guardAttackPath = FindFile(GuardRoot, guardAttackToken);
        var guardIdleClip = FindClip(guardIdlePath);
        var guardAttackClip = FindClip(guardAttackPath);
        var guardAttackPhases = Environment.GetCommandLineArgs().Contains("-denseGuardAnalysis")
            ? Enumerable.Range(0, 41).Select(index => index / 40f).ToArray()
            : GuardAttackPhases;

        var cameraObject = new GameObject("Fool Sprite Camera");
        var camera = cameraObject.AddComponent<Camera>();
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0f, 0f, 0f, 0f);
        camera.orthographic = true;
        camera.orthographicSize = 1.08f;
        camera.nearClipPlane = 0.01f;
        camera.farClipPlane = 30f;
        camera.allowHDR = false;
        camera.allowMSAA = true;
        camera.cullingMask = 1 << RenderLayer;
        camera.transform.position = new Vector3(0f, 1.12f, -8f);
        camera.transform.LookAt(new Vector3(0f, 1.12f, 0f));

        CreateLight("Fool Sprite Key", new Color(1f, 0.90f, 0.76f), 1.22f,
            Quaternion.Euler(35f, -32f, 0f));
        CreateLight("Fool Sprite Fill", new Color(0.48f, 0.60f, 1f), 0.72f,
            Quaternion.Euler(42f, 145f, 0f));
        CreateLight("Fool Sprite Rim", new Color(0.78f, 0.42f, 1f), 0.88f,
            Quaternion.Euler(18f, 205f, 0f));

        var previousAmbientMode = RenderSettings.ambientMode;
        var previousAmbientLight = RenderSettings.ambientLight;
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.34f, 0.36f, 0.44f, 1f);

        try
        {
            AnimationMode.StartAnimationMode();
            RenderClip(
                fool,
                idleClip,
                IdlePhases,
                camera,
                outputDirectory,
                "fool-idle-n",
                assetCatalogRoot,
                "FoolUnityCombatIdleN",
                "fool-unity-combat-idle-n");
            RenderClip(
                fool,
                castClip,
                CastPhases,
                camera,
                outputDirectory,
                "fool-cast-n",
                assetCatalogRoot,
                "FoolUnityCombatCastN",
                "fool-unity-combat-cast-n");

            AnimationMode.StopAnimationMode();

            // Simulator cannot embed the iPhoneOS UnityFramework. Sample the
            // exact same Animator states used by the live Clock Guard. Direct
            // AnimationMode sampling applies the FBX's baked body translation
            // even when applyRootMotion is false; that made the formation actor
            // slide left and right during its turn. Animator sampling matches
            // device behavior and keeps extracted root motion off the model.
            fool.SetActive(false);
            guard.EnemyRoot.gameObject.SetActive(true);
            // Keep one wider camera for every guard frame so the complete turn
            // and blade arc fit without changing scale between sampled poses.
            camera.orthographicSize = 2.18f;
            camera.transform.position = new Vector3(0f, 1.18f, -8f);
            camera.transform.LookAt(new Vector3(0f, 1.18f, 0f));
            var guardHorizontalAnchorX = RenderAnimatorState(
                guardAnimator,
                "Base Layer.Meshy · Idle",
                GuardIdlePhases,
                camera,
                outputDirectory,
                "clock-guard-idle",
                assetCatalogRoot,
                "ClockGuardUnityCombatIdle",
                "clock-guard-unity-combat-idle",
                guardHorizontalAnchor,
                null);
            _ = RenderAnimatorState(
                guardAnimator,
                "Base Layer.Meshy · Attack",
                guardAttackPhases,
                camera,
                outputDirectory,
                "clock-guard-attack",
                assetCatalogRoot,
                "ClockGuardUnityCombatAttack",
                "clock-guard-unity-combat-attack",
                guardHorizontalAnchor,
                guardHorizontalAnchorX);
        }
        finally
        {
            if (AnimationMode.InAnimationMode())
                AnimationMode.StopAnimationMode();
            RenderSettings.ambientMode = previousAmbientMode;
            RenderSettings.ambientLight = previousAmbientLight;
            UnityEngine.Object.DestroyImmediate(cameraObject);
        }

        Debug.Log(
            $"Mindstone: rendered Fool and Clock Guard simulator frames to {outputDirectory}; "
            + $"FoolCast={castClip.length:0.###}s, GuardAttack={guardAttackClip.length:0.###}s");
    }

    static float RenderAnimatorState(
        Animator animator,
        string stateName,
        float[] phases,
        Camera camera,
        string outputDirectory,
        string prefix,
        string assetCatalogRoot,
        string assetNamePrefix,
        string assetFilePrefix,
        Transform horizontalAnchor,
        float? horizontalAnchorReferenceX)
    {
        var stateHash = Animator.StringToHash(stateName);
        if (!animator.HasState(0, stateHash))
            throw new InvalidOperationException($"Animator state not found: {stateName}");

        var previousEnabled = animator.enabled;
        var previousSpeed = animator.speed;
        var previousRootMotion = animator.applyRootMotion;
        var cameraPosition = camera.transform.position;
        var resolvedAnchorX = horizontalAnchorReferenceX;
        try
        {
            animator.enabled = true;
            animator.speed = 0f;
            animator.applyRootMotion = false;
            animator.Rebind();
            animator.Update(0f);

            for (var index = 0; index < phases.Length; index++)
            {
                animator.Play(stateHash, 0, phases[index]);
                animator.Update(0f);
                resolvedAnchorX ??= horizontalAnchor.position.x;
                camera.transform.position = cameraPosition
                    + Vector3.right * (horizontalAnchor.position.x - resolvedAnchorX.Value);
                var outputPath = Path.Combine(outputDirectory, $"{prefix}-{index + 1:00}.png");
                Capture(camera, outputPath);
                if (!string.IsNullOrWhiteSpace(assetCatalogRoot))
                {
                    InstallFrame(
                        outputPath,
                        assetCatalogRoot,
                        $"{assetNamePrefix}{index + 1:00}",
                        $"{assetFilePrefix}-{index + 1:00}.png");
                }
            }
        }
        finally
        {
            camera.transform.position = cameraPosition;
            animator.applyRootMotion = previousRootMotion;
            animator.speed = previousSpeed;
            animator.enabled = previousEnabled;
        }
        return resolvedAnchorX
            ?? throw new InvalidOperationException($"Animator state has no samples: {stateName}");
    }

    static void RenderClip(
        GameObject fool,
        AnimationClip clip,
        float[] phases,
        Camera camera,
        string outputDirectory,
        string prefix,
        string assetCatalogRoot,
        string assetNamePrefix,
        string assetFilePrefix)
    {
        for (var index = 0; index < phases.Length; index++)
        {
            AnimationMode.BeginSampling();
            AnimationMode.SampleAnimationClip(fool, clip, clip.length * phases[index]);
            AnimationMode.EndSampling();
            var outputPath = Path.Combine(outputDirectory, $"{prefix}-{index + 1:00}.png");
            Capture(camera, outputPath);
            if (!string.IsNullOrWhiteSpace(assetCatalogRoot))
            {
                InstallFrame(
                    outputPath,
                    assetCatalogRoot,
                    $"{assetNamePrefix}{index + 1:00}",
                    $"{assetFilePrefix}-{index + 1:00}.png");
            }
        }
    }

    static void InstallFrame(
        string renderedPath,
        string assetCatalogRoot,
        string assetName,
        string fileName)
    {
        var imageSet = Path.Combine(assetCatalogRoot, $"{assetName}.imageset");
        Directory.CreateDirectory(imageSet);
        File.Copy(renderedPath, Path.Combine(imageSet, fileName), true);
        File.WriteAllText(
            Path.Combine(imageSet, "Contents.json"),
            "{\n"
            + "  \"images\" : [\n"
            + "    {\n"
            + $"      \"filename\" : \"{fileName}\",\n"
            + "      \"idiom\" : \"universal\",\n"
            + "      \"scale\" : \"1x\"\n"
            + "    },\n"
            + "    {\n"
            + "      \"idiom\" : \"universal\",\n"
            + "      \"scale\" : \"2x\"\n"
            + "    },\n"
            + "    {\n"
            + "      \"idiom\" : \"universal\",\n"
            + "      \"scale\" : \"3x\"\n"
            + "    }\n"
            + "  ],\n"
            + "  \"info\" : {\n"
            + "    \"author\" : \"xcode\",\n"
            + "    \"version\" : 1\n"
            + "  }\n"
            + "}\n");
    }

    static void Capture(Camera camera, string outputPath)
    {
        var renderTexture = new RenderTexture(
            OutputSize,
            OutputSize,
            24,
            RenderTextureFormat.ARGB32,
            RenderTextureReadWrite.sRGB)
        {
            antiAliasing = 4
        };
        var image = new Texture2D(OutputSize, OutputSize, TextureFormat.RGBA32, false);
        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;

        try
        {
            camera.targetTexture = renderTexture;
            camera.Render();
            RenderTexture.active = renderTexture;
            image.ReadPixels(new Rect(0, 0, OutputSize, OutputSize), 0, 0);
            image.Apply();
            File.WriteAllBytes(outputPath, image.EncodeToPNG());
        }
        finally
        {
            camera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
            UnityEngine.Object.DestroyImmediate(image);
            UnityEngine.Object.DestroyImmediate(renderTexture);
        }
    }

    static void CreateLight(string name, Color color, float intensity, Quaternion rotation)
    {
        var lightObject = new GameObject(name);
        lightObject.transform.rotation = rotation;
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.color = color;
        light.intensity = intensity;
        light.shadows = LightShadows.None;
        light.cullingMask = 1 << RenderLayer;
    }

    static void SetLayerRecursively(GameObject root, int layer)
    {
        root.layer = layer;
        foreach (Transform child in root.transform)
            SetLayerRecursively(child.gameObject, layer);
    }

    static Transform FindTransform(Transform root, string name)
    {
        if (string.Equals(root.name, name, StringComparison.OrdinalIgnoreCase))
            return root;
        foreach (Transform child in root)
        {
            var match = FindTransform(child, name);
            if (match != null) return match;
        }
        return null;
    }

    static AnimationClip FindClip(string path)
    {
        if (string.IsNullOrEmpty(path))
            throw new FileNotFoundException("Missing presentation animation path.");
        return AssetDatabase.LoadAllAssetsAtPath(path)
            .OfType<AnimationClip>()
            .FirstOrDefault(clip => !clip.name.StartsWith("__preview__", StringComparison.Ordinal))
            ?? throw new FileNotFoundException("Could not resolve presentation animation clip.", path);
    }

    static EnemyHandle FindEnemy(string battleEnemyId)
    {
        return UnityEngine.Object.FindObjectsByType<EnemyHandle>(
                FindObjectsInactive.Include,
                FindObjectsSortMode.None)
            .FirstOrDefault(handle => handle.BattleEnemyId == battleEnemyId);
    }

    static string FindFile(string root, string contains)
    {
        var absoluteRoot = Path.Combine(Directory.GetCurrentDirectory(), root);
        var match = Directory.GetFiles(absoluteRoot, "*.fbx", SearchOption.AllDirectories)
            .FirstOrDefault(path => Path.GetFileNameWithoutExtension(path)
                .IndexOf(contains, StringComparison.OrdinalIgnoreCase) >= 0);
        if (match == null) return null;
        return root + Path.GetRelativePath(absoluteRoot, match).Replace('\\', '/');
    }

    static string ReadArgument(string name)
    {
        var arguments = Environment.GetCommandLineArgs();
        for (var index = 0; index < arguments.Length - 1; index++)
        {
            if (string.Equals(arguments[index], name, StringComparison.Ordinal))
                return arguments[index + 1];
        }
        return null;
    }
}
