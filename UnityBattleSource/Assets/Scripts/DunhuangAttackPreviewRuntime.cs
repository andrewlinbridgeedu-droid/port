using System;
using System.Collections;
using System.IO;
using Mindstone.VFXV1;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// Candidate-only capture harness for the Meshy Dunhuang caster. It deliberately
/// reuses the VFX V1 fire layers instead of inventing a second Blender-only
/// renderer, so the preview exercises the same spell stack that can ship in
/// the battle scene.
/// </summary>
[DefaultExecutionOrder(1000)]
public sealed class DunhuangAttackPreviewRuntime : MonoBehaviour
{
    const string CharacterResource =
        "RuntimeModels/DunhuangTestCharacter/DunhuangCelestialWarrior_Attack_v3";
    const string ControllerResource = "RuntimeModels/DunhuangAttackPreview";
    const string SpellId = "projectile-dunhuang-cinder-strike-v1";
    const int FrameCount = 72;
    const int CaptureFps = 24;
    const int SpellLaunchFrame = 12;
    const int SpellContactFrame = 31;

    GameObject caster;
    GameObject enemy;
    Animator casterAnimator;
    SpellBridge spellBridge;
    Camera previewCamera;
    Light impactLight;
    Transform sourceBone;
    Vector3 casterHome;
    Vector3 enemyHome;
    Quaternion enemyHomeRotation;
    Vector3 cameraHomePosition;
    Quaternion cameraHomeRotation;
    RenderTexture captureTexture;
    Texture2D captureImage;
    string outputDirectory;
    int frameIndex;
    int shutdownCountdown;
    bool spellStarted;
    bool initialized;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Bootstrap()
    {
        if (!HasArgument("--preview-dunhuang-attack"))
            return;

        var root = new GameObject("Dunhuang Attack Preview Runtime");
        DontDestroyOnLoad(root);
        root.AddComponent<DunhuangAttackPreviewRuntime>();
    }

    void Awake()
    {
        Application.runInBackground = true;
        Application.targetFrameRate = CaptureFps;
        Time.captureFramerate = CaptureFps;
        outputDirectory = ReadArgument("--dunhuang-output")
            ?? "/private/tmp/dunhuang-unity-attack-v1-frames";
        // The normal battle scene is still used as the build entry point, but
        // this candidate owns its camera, actors, floor, and lighting.
        var roots = SceneManager.GetActiveScene().GetRootGameObjects();
        for (var index = 0; index < roots.Length; index++)
        {
            if (roots[index] != gameObject)
                roots[index].SetActive(false);
        }
        DisableLegacyBattleObjects();
    }

    void Start()
    {
        try
        {
            DisableLegacyBattleObjects();
            BuildPreview();
            initialized = true;
            StartCoroutine(LaunchSpellWhenReady());
        }
        catch (Exception exception)
        {
            Debug.LogException(exception);
            Application.Quit(2);
        }
    }

    void BuildPreview()
    {
        var casterPrefab = Resources.Load<GameObject>(CharacterResource);
        if (casterPrefab == null)
            throw new InvalidOperationException($"Missing character resource: {CharacterResource}");

        caster = Instantiate(casterPrefab);
        caster.name = "DunhuangAttack_Caster";
        caster.transform.SetPositionAndRotation(
            new Vector3(-0.95f, 0f, 0.20f),
            Quaternion.Euler(0f, 180f, 0f));
        caster.transform.localScale = Vector3.one * 1.25f;
        casterHome = caster.transform.position;
        casterAnimator = caster.GetComponentInChildren<Animator>(true)
            ?? caster.AddComponent<Animator>();
        casterAnimator.applyRootMotion = false;
        casterAnimator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        var controller = Resources.Load<RuntimeAnimatorController>(ControllerResource);
        if (controller != null)
            casterAnimator.runtimeAnimatorController = controller;
        if (casterAnimator.runtimeAnimatorController != null)
            casterAnimator.Play("Dunhuang Attack", 0, 0f);
        sourceBone = FindTransform(caster.transform, "hand.L")
            ?? FindTransform(caster.transform, "hand_l")
            ?? FindTransform(caster.transform, "Hand.L");

        // Keep the isolated caster shot focused on the spell. The imported
        // Clock Guard has a different unit scale and would swallow the frame,
        // so use a restrained target dummy for the hit-point read.
        enemy = new GameObject("DunhuangAttack_TargetPoint");
        enemy.name = "DunhuangAttack_TargetDummy";
        enemy.transform.SetPositionAndRotation(
            new Vector3(1.25f, 1.02f, 1.10f),
            Quaternion.identity);
        var targetCore = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        targetCore.name = "DunhuangAttack_TargetCore";
        targetCore.transform.SetParent(enemy.transform, false);
        targetCore.transform.localPosition = Vector3.zero;
        targetCore.transform.localScale = Vector3.one * 0.22f;
        SetMaterialColor(targetCore.GetComponent<Renderer>(),
            new Color(0.42f, 0.008f, 0.002f, 1f));
        var targetLightObject = new GameObject("DunhuangAttack_TargetLight");
        targetLightObject.transform.SetParent(enemy.transform, false);
        targetLightObject.transform.localPosition = new Vector3(0f, 0f, -0.08f);
        var targetLight = targetLightObject.AddComponent<Light>();
        targetLight.type = LightType.Point;
        targetLight.color = new Color(1f, 0.03f, 0.005f);
        targetLight.range = 0.65f;
        targetLight.intensity = 2f;
        enemyHome = enemy.transform.position;
        enemyHomeRotation = enemy.transform.rotation;

        BuildCamera();
        BuildStage();

        spellBridge = gameObject.AddComponent<SpellBridge>();
        impactLight = CreateImpactLight();
        captureTexture = new RenderTexture(1024, 576, 24, RenderTextureFormat.ARGB32)
        {
            name = "Dunhuang Attack Capture RT",
            antiAliasing = 4
        };
        captureTexture.Create();
        captureImage = new Texture2D(1024, 576, TextureFormat.RGBA32, false);
        Directory.CreateDirectory(outputDirectory);
    }

    public Camera PreviewCamera => previewCamera;
    public int CurrentFrame => frameIndex;
    public bool FrameReady => frameIndex < FrameCount;
    public bool Finished => frameIndex >= FrameCount;

    void BuildCamera()
    {
        previewCamera = new GameObject("DunhuangAttack_PreviewCamera")
            .AddComponent<Camera>();
        previewCamera.tag = "MainCamera";
        previewCamera.clearFlags = CameraClearFlags.SolidColor;
        previewCamera.backgroundColor = new Color(0.003f, 0.006f, 0.018f, 1f);
        previewCamera.fieldOfView = 31f;
        previewCamera.nearClipPlane = 0.05f;
        previewCamera.farClipPlane = 100f;
        previewCamera.transform.position = new Vector3(0f, 1.25f, -6.30f);
        previewCamera.transform.LookAt(new Vector3(0.05f, 1.08f, 0.60f));
        previewCamera.enabled = false;
        cameraHomePosition = previewCamera.transform.position;
        cameraHomeRotation = previewCamera.transform.rotation;
    }

    void BuildStage()
    {
        var floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
        floor.name = "DunhuangAttack_StageFloor";
        floor.transform.position = new Vector3(0f, -0.015f, 0.55f);
        floor.transform.localScale = new Vector3(1.8f, 1f, 1.8f);
        SetMaterialColor(floor.GetComponent<Renderer>(),
            new Color(0.002f, 0.006f, 0.015f, 1f));

        var rim = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        rim.name = "DunhuangAttack_ImpactStageRing";
        rim.transform.SetPositionAndRotation(
            new Vector3(1.30f, 0.012f, 1.08f),
            Quaternion.identity);
        rim.transform.localScale = new Vector3(0.46f, 0.012f, 0.46f);
        SetMaterialColor(rim.GetComponent<Renderer>(),
            new Color(0.12f, 0.008f, 0.002f, 1f));
        rim.SetActive(false);

        CreateAreaLight("DunhuangAttack_Key", new Vector3(-2.4f, 3.0f, -2.8f),
            new Color(1.0f, 0.20f, 0.06f), 380f, 2.5f);
        CreateAreaLight("DunhuangAttack_Rim", new Vector3(2.8f, 2.8f, 2.8f),
            new Color(0.12f, 0.24f, 1.0f), 500f, 2.0f);
        CreateAreaLight("DunhuangAttack_Fill", new Vector3(0f, 1.2f, -3.0f),
            new Color(0.18f, 0.28f, 0.75f), 100f, 3.0f);
    }

    Light CreateAreaLight(string name, Vector3 position, Color color,
        float energy, float size)
    {
        var lightObject = new GameObject(name);
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Rectangle;
        light.color = color;
        light.intensity = energy;
        light.range = 12f;
        light.areaSize = new Vector2(size, size);
        lightObject.transform.position = position;
        lightObject.transform.LookAt(new Vector3(0f, 0.9f, 0.6f));
        return light;
    }

    Light CreateImpactLight()
    {
        var lightObject = new GameObject("DunhuangAttack_ImpactLight");
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Point;
        light.color = new Color(1f, 0.10f, 0.01f);
        light.range = 4.5f;
        light.intensity = 0f;
        lightObject.transform.position = new Vector3(1.30f, 1.15f, 1.08f);
        return light;
    }

    IEnumerator LaunchSpellWhenReady()
    {
        while (frameIndex < SpellLaunchFrame)
            yield return null;

        if (spellStarted || spellBridge == null)
            yield break;
        spellStarted = true;
        yield return spellBridge.Play(
            SpellId,
            GetSourcePosition,
            GetTargetPosition,
            weapon: GetSourcePosition,
            impact: GetTargetPosition,
            ground: GetTargetPosition,
            seed: 5317);
    }

    void Update()
    {
        DisableLegacyBattleObjects();
        if (!initialized)
            return;

        ApplyCasterLunge();
        ApplyEnemyRecoil();
        ApplyCameraImpulse();
        ApplyImpactLight();
    }

    void ApplyCasterLunge()
    {
        var t = Mathf.Clamp01(frameIndex / 72f);
        Vector3 offset;
        if (frameIndex < 12)
            offset = Vector3.Lerp(new Vector3(0f, 0f, 0f), new Vector3(-0.08f, 0f, -0.04f), frameIndex / 12f);
        else if (frameIndex < 29)
            offset = Vector3.Lerp(new Vector3(-0.08f, 0f, -0.04f), new Vector3(0.44f, 0.02f, -0.10f), (frameIndex - 12) / 17f);
        else
            offset = Vector3.Lerp(new Vector3(0.44f, 0.02f, -0.10f), Vector3.zero, Mathf.Clamp01((frameIndex - 29) / 28f));
        caster.transform.position = casterHome + offset;
    }

    void ApplyEnemyRecoil()
    {
        var age = frameIndex - SpellContactFrame;
        if (age < 0)
        {
            enemy.transform.SetPositionAndRotation(enemyHome, enemyHomeRotation);
            return;
        }
        var envelope = Mathf.Clamp01(1f - age / 14f);
        enemy.transform.position = enemyHome
            + new Vector3(0.10f * envelope, 0f, -0.05f * envelope);
        enemy.transform.rotation = enemyHomeRotation
            * Quaternion.Euler(0f, 0f, -5.5f * envelope);
    }

    void ApplyCameraImpulse()
    {
        var age = frameIndex - SpellContactFrame;
        if (age < 0 || age > 8)
        {
            previewCamera.transform.SetPositionAndRotation(cameraHomePosition, cameraHomeRotation);
            return;
        }
        var envelope = 1f - age / 9f;
        var local = new Vector3(
            Mathf.Sin(age * 19.0f) * 0.035f * envelope,
            Mathf.Cos(age * 23.0f) * 0.022f * envelope,
            0f);
        previewCamera.transform.position = cameraHomePosition + local;
        previewCamera.transform.rotation = cameraHomeRotation
            * Quaternion.AngleAxis(Mathf.Sin(age * 16f) * 1.05f * envelope, Vector3.forward);
    }

    void ApplyImpactLight()
    {
        var age = frameIndex - SpellContactFrame;
        impactLight.intensity = age < 0 || age > 12
            ? 0f
            : Mathf.Lerp(4f, 0f, Mathf.Clamp01(age / 12f));
    }

    void LateUpdate()
    {
        if (!initialized)
            return;

        if (frameIndex < FrameCount)
        {
            CaptureFrame(frameIndex);
            frameIndex++;
            if (frameIndex >= FrameCount)
                shutdownCountdown = 3;
            return;
        }

        if (shutdownCountdown > 0)
        {
            shutdownCountdown--;
            if (shutdownCountdown == 0)
            {
                spellBridge?.Stop();
                if (captureImage != null)
                    Destroy(captureImage);
                if (captureTexture != null)
                {
                    captureTexture.Release();
                    Destroy(captureTexture);
                }
                Application.Quit(0);
            }
        }
    }

    void CaptureFrame(int index)
    {
        var previousTarget = previewCamera.targetTexture;
        var previousActive = RenderTexture.active;
        try
        {
            previewCamera.targetTexture = captureTexture;
            previewCamera.Render();
            RenderTexture.active = captureTexture;
            captureImage.ReadPixels(new Rect(0f, 0f, 1024f, 576f), 0, 0, false);
            captureImage.Apply(false, false);
            var path = Path.Combine(outputDirectory, $"frame-{index:00}.png");
            File.WriteAllBytes(path, ImageConversion.EncodeToPNG(captureImage));
        }
        finally
        {
            previewCamera.targetTexture = previousTarget;
            RenderTexture.active = previousActive;
        }
    }

    Vector3 GetSourcePosition()
    {
        if (sourceBone != null)
            return sourceBone.position + previewCamera.transform.forward * 0.12f;
        return caster.transform.position + Vector3.up * 1.18f
            + Vector3.right * 0.38f + Vector3.forward * 0.12f;
    }

    Vector3 GetTargetPosition()
    {
        var renderers = enemy.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length == 0)
            return enemy.transform.position + Vector3.up * 1.0f;
        var bounds = renderers[0].bounds;
        for (var index = 1; index < renderers.Length; index++)
            bounds.Encapsulate(renderers[index].bounds);
        return bounds.center + Vector3.forward * 0.12f;
    }

    static Transform FindTransform(Transform root, string name)
    {
        if (root.name.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0)
            return root;
        for (var index = 0; index < root.childCount; index++)
        {
            var result = FindTransform(root.GetChild(index), name);
            if (result != null)
                return result;
        }
        return null;
    }

    static void SetMaterialColor(Renderer renderer, Color color)
    {
        if (renderer == null)
            return;
        var shader = Shader.Find("Standard")
            ?? Shader.Find("Unlit/Color")
            ?? Shader.Find("Universal Render Pipeline/Unlit");
        if (shader == null)
            return;
        var material = new Material(shader)
        {
            name = renderer.name + " · preview material"
        };
        if (material.HasProperty("_Color"))
            material.SetColor("_Color", color);
        if (material.HasProperty("_BaseColor"))
            material.SetColor("_BaseColor", color);
        if (material.HasProperty("_EmissionColor"))
            material.SetColor("_EmissionColor", color * 1.5f);
        renderer.sharedMaterial = material;
    }

    static void DisableLegacyBattleObjects()
    {
        var legacy = UnityEngine.Object.FindObjectsByType<BattlePrototype>(
            FindObjectsInactive.Include,
            FindObjectsSortMode.None);
        for (var index = 0; index < legacy.Length; index++)
        {
            if (legacy[index] != null && legacy[index].gameObject != null)
                legacy[index].gameObject.SetActive(false);
        }

        var names = new[]
        {
            "Fool_Imported",
            "ClockGuard_Imported",
            "ClockCore_Imported",
            "HellHound_Imported",
            "Battle Prototype Runtime"
        };
        for (var index = 0; index < names.Length; index++)
        {
            var objectToHide = GameObject.Find(names[index]);
            if (objectToHide != null)
                objectToHide.SetActive(false);
        }
    }

    static bool HasArgument(string value)
    {
        var args = Environment.GetCommandLineArgs();
        for (var index = 0; index < args.Length; index++)
            if (args[index] == value)
                return true;
        return false;
    }

    static string ReadArgument(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (var index = 0; index + 1 < args.Length; index++)
            if (args[index] == name)
                return args[index + 1];
        return null;
    }

}
