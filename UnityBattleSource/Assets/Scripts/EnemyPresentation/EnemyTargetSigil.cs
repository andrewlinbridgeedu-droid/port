using System.Collections.Generic;
using UnityEngine;

public enum EnemyTargetSigilState
{
    Hidden,
    Pending,
    Selected
}

/// Camera-facing target marker positioned from the enemy's current visible pose.
/// The legacy class name is retained for bridge/scene compatibility.
[DisallowMultipleComponent]
public sealed class EnemyTargetSigil : MonoBehaviour
{
    [SerializeField] EnemyTargetSigilState state;
    [SerializeField] Transform model;
    [SerializeField] GameObject visualRoot;
    [SerializeField] Transform boundsSpace;
    [SerializeField] Bounds calibratedBounds;
    [SerializeField] bool hasCalibratedBounds;
    [SerializeField] float bobAmplitudeViewport = 0.0032f;
    [SerializeField] float bobPeriod = 2.8f;

    readonly List<LineRenderer> glyphLines = new();
    Renderer[] renderers;
    Animator humanoidAnimator;
    ParticleSystem magicParticles;
    SpriteRenderer ornamentSprite;
    float previewAnimationPhase = float.NaN;

    static readonly HumanBodyBones[] TargetFrameBones =
    {
        HumanBodyBones.Head,
        HumanBodyBones.Neck,
        HumanBodyBones.Chest,
        HumanBodyBones.Hips,
        HumanBodyBones.LeftShoulder,
        HumanBodyBones.RightShoulder,
        HumanBodyBones.LeftHand,
        HumanBodyBones.RightHand,
        HumanBodyBones.LeftFoot,
        HumanBodyBones.RightFoot,
        HumanBodyBones.LeftToes,
        HumanBodyBones.RightToes
    };

    public EnemyTargetSigilState State => state;

    public void SetPreviewAnimationPhase(float normalizedPhase)
    {
        previewAnimationPhase = Mathf.Repeat(normalizedPhase, 1f);
        RefreshLayout();
    }

    public void Configure(
        Transform modelTransform,
        Transform calibratedBoundsSpace,
        Bounds finalPresentedBounds)
    {
        model = modelTransform;
        renderers = model != null ? model.GetComponentsInChildren<Renderer>(true) : null;
        humanoidAnimator = FindHumanoidAnimator(model);
        boundsSpace = calibratedBoundsSpace;
        calibratedBounds = finalPresentedBounds;
        hasCalibratedBounds = boundsSpace != null
            && calibratedBounds.size.sqrMagnitude > 0.000001f;
        if (state != EnemyTargetSigilState.Hidden)
            RefreshLayout();
    }

    // Retained so existing installer/profile code remains source compatible.
    public void ConfigureRadius(float unusedWorldRadius) { }

    public void SetState(EnemyTargetSigilState value)
    {
        state = value;
        if (value == EnemyTargetSigilState.Hidden)
        {
            if (visualRoot != null)
                visualRoot.SetActive(false);
            return;
        }

        EnsureVisual();
        visualRoot.SetActive(true);
        ApplyPalette();
        RefreshLayout();
        if (magicParticles != null)
        {
            magicParticles.Simulate(0.72f, true, true, true);
            magicParticles.Play(true);
        }
    }

    void EnsureVisual()
    {
        if (visualRoot != null)
            return;
        visualRoot = new GameObject("TargetOrnamentVisual");
        visualRoot.transform.SetParent(transform, false);
        glyphLines.Add(CreateGlyphLine("VioletHalo", 5, false));
        glyphLines.Add(CreateGlyphLine("GoldenRim", 5, false));
        glyphLines.Add(CreateGlyphLine("MemoryEye", 33, false));
        glyphLines.Add(CreateGlyphLine("EyePupil", 2, false));
        glyphLines.Add(CreateGlyphLine("TargetPointer", 3, false));
        for (var index = 0; index < glyphLines.Count; index++)
            glyphLines[index].enabled = false;
        ornamentSprite = CreateOrnamentSprite();
        magicParticles = CreateMagicParticles();
    }

    LineRenderer CreateGlyphLine(string name, int positionCount, bool loop)
    {
        var lineObject = new GameObject(name);
        lineObject.transform.SetParent(visualRoot.transform, false);
        var line = lineObject.AddComponent<LineRenderer>();
        line.useWorldSpace = true;
        line.loop = loop;
        line.positionCount = positionCount;
        line.startWidth = 0.014f;
        line.endWidth = 0.014f;
        line.numCapVertices = 3;
        line.numCornerVertices = 3;
        line.alignment = LineAlignment.View;
        var shader = Shader.Find("Sprites/Default") ?? Shader.Find("Unlit/Color");
        if (shader != null)
        {
            line.sharedMaterial = new Material(shader)
            {
                color = Color.white,
                renderQueue = 3100
            };
        }
        return line;
    }

    SpriteRenderer CreateOrnamentSprite()
    {
        var texture = Resources.Load<Texture2D>("EnemyPresentation/target-memory-eye-v1");
        if (texture == null)
            return null;
        var spriteObject = new GameObject("MemoryEyeSprite");
        spriteObject.transform.SetParent(visualRoot.transform, false);
        var spriteRenderer = spriteObject.AddComponent<SpriteRenderer>();
        spriteRenderer.sprite = Sprite.Create(
            texture,
            new Rect(0f, 0f, texture.width, texture.height),
            new Vector2(0.5f, 0.5f),
            100f,
            0,
            SpriteMeshType.FullRect);
        spriteRenderer.sortingOrder = 19;
        return spriteRenderer;
    }

    ParticleSystem CreateMagicParticles()
    {
        var particleObject = new GameObject("MemoryDust");
        particleObject.transform.SetParent(visualRoot.transform, false);
        var particles = particleObject.AddComponent<ParticleSystem>();
        var main = particles.main;
        main.duration = 2.4f;
        main.loop = true;
        main.prewarm = true;
        main.startLifetime = new ParticleSystem.MinMaxCurve(0.65f, 1.35f);
        main.startSpeed = new ParticleSystem.MinMaxCurve(0.002f, 0.018f);
        main.startSize = new ParticleSystem.MinMaxCurve(0.010f, 0.022f);
        main.startRotation = new ParticleSystem.MinMaxCurve(0f, Mathf.PI * 2f);
        main.startColor = new ParticleSystem.MinMaxGradient(
            new Color(0.54f, 0.24f, 1f, 0.72f),
            new Color(1f, 0.76f, 0.30f, 0.86f));
        main.simulationSpace = ParticleSystemSimulationSpace.Local;
        main.maxParticles = 24;

        var emission = particles.emission;
        emission.rateOverTime = 8f;
        var shape = particles.shape;
        shape.shapeType = ParticleSystemShapeType.Circle;
        shape.radius = 0.05f;
        shape.radiusThickness = 0.35f;

        var colorOverLifetime = particles.colorOverLifetime;
        colorOverLifetime.enabled = true;
        var alpha = new Gradient();
        alpha.SetKeys(
            new[]
            {
                new GradientColorKey(Color.white, 0f),
                new GradientColorKey(Color.white, 1f)
            },
            new[]
            {
                new GradientAlphaKey(0f, 0f),
                new GradientAlphaKey(0.92f, 0.22f),
                new GradientAlphaKey(0.58f, 0.66f),
                new GradientAlphaKey(0f, 1f)
            });
        colorOverLifetime.color = alpha;

        var noise = particles.noise;
        noise.enabled = true;
        noise.strength = 0.018f;
        noise.frequency = 0.65f;
        noise.scrollSpeed = 0.25f;

        var particleRenderer = particleObject.GetComponent<ParticleSystemRenderer>();
        particleRenderer.renderMode = ParticleSystemRenderMode.Billboard;
        particleRenderer.sortingOrder = 20;
        var shader = Shader.Find("Sprites/Default") ?? Shader.Find("Particles/Standard Unlit");
        if (shader != null)
        {
            var material = new Material(shader)
            {
                color = Color.white,
                renderQueue = 3095
            };
            material.mainTexture = CreateSoftParticleTexture();
            particleRenderer.sharedMaterial = material;
        }
        particles.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        return particles;
    }

    static Texture2D CreateSoftParticleTexture()
    {
        const int size = 32;
        var texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
        {
            name = "TargetMarkerSoftParticle",
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear
        };
        var pixels = new Color[size * size];
        for (var y = 0; y < size; y++)
        {
            for (var x = 0; x < size; x++)
            {
                var normalized = new Vector2(
                    (x + 0.5f) / size * 2f - 1f,
                    (y + 0.5f) / size * 2f - 1f);
                var alpha = Mathf.Pow(Mathf.Clamp01(1f - normalized.magnitude), 2.2f);
                pixels[y * size + x] = new Color(1f, 1f, 1f, alpha);
            }
        }
        texture.SetPixels(pixels);
        texture.Apply(false, true);
        return texture;
    }

    void ApplyPalette()
    {
        var selected = state == EnemyTargetSigilState.Selected;
        var colors = selected
            ? new[]
            {
                new Color(0.56f, 0.20f, 1f, 0.24f),
                new Color(1f, 0.72f, 0.30f, 0.92f),
                new Color(0.72f, 0.42f, 1f, 0.88f),
                new Color(1f, 0.88f, 0.52f, 1f),
                new Color(1f, 0.70f, 0.28f, 0.86f)
            }
            : new[]
            {
                new Color(0.28f, 0.60f, 1f, 0.18f),
                new Color(0.60f, 0.82f, 1f, 0.56f),
                new Color(0.42f, 0.68f, 1f, 0.52f),
                new Color(0.78f, 0.92f, 1f, 0.72f),
                new Color(0.56f, 0.78f, 1f, 0.48f)
            };
        for (var index = 0; index < glyphLines.Count; index++)
        {
            glyphLines[index].startColor = colors[index];
            glyphLines[index].endColor = colors[index];
        }
        if (ornamentSprite != null)
        {
            ornamentSprite.color = state == EnemyTargetSigilState.Selected
                ? new Color(1f, 1f, 1f, 0.94f)
                : new Color(0.72f, 0.86f, 1f, 0.68f);
        }
    }

    void RefreshLayout()
    {
        if (visualRoot == null
            || model == null
            || state == EnemyTargetSigilState.Hidden)
        {
            return;
        }
        var camera = Camera.main;
        if (camera == null || !TryGetViewportRect(camera, out var viewportRect))
            return;

        const float overlayDepth = 2f;
        var worldHeight = 2f * overlayDepth
            * Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad * 0.5f);
        SetLineWidth(glyphLines[0], worldHeight * 0.0046f);
        SetLineWidth(glyphLines[1], worldHeight * 0.0017f);
        SetLineWidth(glyphLines[2], worldHeight * 0.0015f);
        SetLineWidth(glyphLines[3], worldHeight * 0.0024f);
        SetLineWidth(glyphLines[4], worldHeight * 0.0017f);

        // Keep the marker a stable physical size on portrait screens. It is
        // deliberately screen-facing: the 2D battle plate has no real floor.
        var radiusX = 0.030f;
        var radiusY = radiusX * camera.aspect;
        var center = new Vector2(
            viewportRect.center.x,
            Mathf.Min(
                0.955f,
                viewportRect.yMax
                + radiusY * 3.3f
                + Mathf.Sin(GetAnimationRadians()) * bobAmplitudeViewport));
        SetDiamond(camera, glyphLines[0], center, radiusX * 1.08f, radiusY * 1.08f, overlayDepth);
        SetDiamond(camera, glyphLines[1], center, radiusX * 0.90f, radiusY * 0.90f, overlayDepth);
        SetEllipse(camera, glyphLines[2], center, radiusX * 0.54f, radiusY * 0.28f, overlayDepth);
        SetPupil(camera, glyphLines[3], center, radiusY, overlayDepth);
        SetPointer(camera, glyphLines[4], center, radiusX, radiusY, overlayDepth);
        if (ornamentSprite != null && ornamentSprite.sprite != null)
        {
            var markerWorld = camera.ViewportToWorldPoint(
                new Vector3(center.x, center.y, overlayDepth));
            ornamentSprite.transform.SetPositionAndRotation(
                markerWorld,
                camera.transform.rotation);
            var desiredWorldHeight = worldHeight * 0.064f;
            var spriteHeight = ornamentSprite.sprite.bounds.size.y;
            ornamentSprite.transform.localScale = Vector3.one
                * (spriteHeight > 0.0001f ? desiredWorldHeight / spriteHeight : 1f);
        }
        if (magicParticles != null)
        {
            var markerWorld = camera.ViewportToWorldPoint(
                new Vector3(center.x, center.y, overlayDepth));
            var markerRight = camera.ViewportToWorldPoint(
                new Vector3(center.x + radiusX * 1.45f, center.y, overlayDepth));
            magicParticles.transform.SetPositionAndRotation(
                markerWorld,
                camera.transform.rotation);
            var shape = magicParticles.shape;
            shape.radius = Vector3.Distance(markerWorld, markerRight);
        }
    }

    bool TryGetViewportRect(
        Camera camera,
        out Rect viewportRect)
    {
        viewportRect = default;
        if (renderers == null || renderers.Length == 0)
            renderers = model.GetComponentsInChildren<Renderer>(true);

        var minX = float.PositiveInfinity;
        var maxX = float.NegativeInfinity;
        var minY = float.PositiveInfinity;
        var maxY = float.NegativeInfinity;
        var hasProjection = false;
        if (TryGetHumanoidViewportRect(
                camera,
                ref minX,
                ref maxX,
                ref minY,
                ref maxY))
        {
            viewportRect = Rect.MinMaxRect(minX, minY, maxX, maxY);
            return true;
        }

        if (hasCalibratedBounds)
        {
            for (var cornerIndex = 0; cornerIndex < 8; cornerIndex++)
            {
                var localCorner = new Vector3(
                    (cornerIndex & 1) == 0 ? calibratedBounds.min.x : calibratedBounds.max.x,
                    (cornerIndex & 2) == 0 ? calibratedBounds.min.y : calibratedBounds.max.y,
                    (cornerIndex & 4) == 0 ? calibratedBounds.min.z : calibratedBounds.max.z);
                EncapsulateViewportPoint(
                    camera,
                    boundsSpace.TransformPoint(localCorner),
                    ref minX,
                    ref maxX,
                    ref minY,
                    ref maxY,
                    ref hasProjection);
            }
            if (hasProjection)
            {
                viewportRect = Rect.MinMaxRect(minX, minY, maxX, maxY);
                return true;
            }
        }

        for (var rendererIndex = 0; rendererIndex < renderers.Length; rendererIndex++)
        {
            var renderer = renderers[rendererIndex];
            if (renderer == null || !renderer.enabled)
                continue;
            var bounds = renderer.bounds;
            for (var cornerIndex = 0; cornerIndex < 8; cornerIndex++)
            {
                var corner = new Vector3(
                    (cornerIndex & 1) == 0 ? bounds.min.x : bounds.max.x,
                    (cornerIndex & 2) == 0 ? bounds.min.y : bounds.max.y,
                    (cornerIndex & 4) == 0 ? bounds.min.z : bounds.max.z);
                EncapsulateViewportPoint(
                    camera,
                    corner,
                    ref minX,
                    ref maxX,
                    ref minY,
                    ref maxY,
                    ref hasProjection);
            }
        }
        if (!hasProjection)
            return false;
        viewportRect = Rect.MinMaxRect(minX, minY, maxX, maxY);
        return true;
    }

    bool TryGetHumanoidViewportRect(
        Camera camera,
        ref float minX,
        ref float maxX,
        ref float minY,
        ref float maxY)
    {
        if (humanoidAnimator == null)
            humanoidAnimator = FindHumanoidAnimator(model);
        if (humanoidAnimator == null || !humanoidAnimator.isHuman)
            return false;

        var hasProjection = false;
        for (var index = 0; index < TargetFrameBones.Length; index++)
        {
            var bone = humanoidAnimator.GetBoneTransform(TargetFrameBones[index]);
            if (bone == null)
                continue;
            EncapsulateViewportPoint(
                camera,
                bone.position,
                ref minX,
                ref maxX,
                ref minY,
                ref maxY,
                ref hasProjection);
        }

        if (!hasProjection || minX >= maxX || minY >= maxY)
            return false;

        // Bone positions describe joint centres. Add a proportional body-volume
        // margin here before the visual corner padding is applied.
        var width = maxX - minX;
        var height = maxY - minY;
        var horizontalBodyMargin = Mathf.Max(0.008f, width * 0.10f);
        var headMargin = Mathf.Max(0.008f, height * 0.14f);
        var soleMargin = Mathf.Max(0.004f, height * 0.045f);
        minX -= horizontalBodyMargin;
        maxX += horizontalBodyMargin;
        minY -= soleMargin;
        maxY += headMargin;
        return true;
    }

    static Animator FindHumanoidAnimator(Transform root)
    {
        if (root == null)
            return null;
        var animators = root.GetComponentsInChildren<Animator>(true);
        for (var index = 0; index < animators.Length; index++)
        {
            if (animators[index] != null
                && animators[index].avatar != null
                && animators[index].avatar.isValid
                && animators[index].avatar.isHuman)
            {
                return animators[index];
            }
        }
        return null;
    }

    static void EncapsulateViewportPoint(
        Camera camera,
        Vector3 world,
        ref float minX,
        ref float maxX,
        ref float minY,
        ref float maxY,
        ref bool hasProjection)
    {
        var viewport = camera.WorldToViewportPoint(world);
        if (viewport.z <= 0f)
            return;
        minX = Mathf.Min(minX, viewport.x);
        maxX = Mathf.Max(maxX, viewport.x);
        minY = Mathf.Min(minY, viewport.y);
        maxY = Mathf.Max(maxY, viewport.y);
        hasProjection = true;
    }

    static void SetDiamond(
        Camera camera,
        LineRenderer line,
        Vector2 center,
        float radiusX,
        float radiusY,
        float depth)
    {
        SetGlyphPoint(camera, line, 0, center, 0f, radiusY, depth);
        SetGlyphPoint(camera, line, 1, center, radiusX, 0f, depth);
        SetGlyphPoint(camera, line, 2, center, 0f, -radiusY, depth);
        SetGlyphPoint(camera, line, 3, center, -radiusX, 0f, depth);
        SetGlyphPoint(camera, line, 4, center, 0f, radiusY, depth);
    }

    static void SetEllipse(
        Camera camera,
        LineRenderer line,
        Vector2 center,
        float radiusX,
        float radiusY,
        float depth)
    {
        var lastIndex = line.positionCount - 1;
        for (var index = 0; index <= lastIndex; index++)
        {
            var angle = index / (float)lastIndex * Mathf.PI * 2f;
            SetGlyphPoint(
                camera,
                line,
                index,
                center,
                Mathf.Cos(angle) * radiusX,
                Mathf.Sin(angle) * radiusY,
                depth);
        }
    }

    static void SetPupil(
        Camera camera,
        LineRenderer line,
        Vector2 center,
        float radiusY,
        float depth)
    {
        SetGlyphPoint(camera, line, 0, center, 0f, radiusY * 0.20f, depth);
        SetGlyphPoint(camera, line, 1, center, 0f, -radiusY * 0.20f, depth);
    }

    static void SetPointer(
        Camera camera,
        LineRenderer line,
        Vector2 center,
        float radiusX,
        float radiusY,
        float depth)
    {
        SetGlyphPoint(camera, line, 0, center, -radiusX * 0.28f, -radiusY * 1.23f, depth);
        SetGlyphPoint(camera, line, 1, center, 0f, -radiusY * 1.72f, depth);
        SetGlyphPoint(camera, line, 2, center, radiusX * 0.28f, -radiusY * 1.23f, depth);
    }

    static void SetLineWidth(LineRenderer line, float width)
    {
        line.startWidth = width;
        line.endWidth = width;
    }

    static void SetGlyphPoint(
        Camera camera,
        LineRenderer line,
        int index,
        Vector2 center,
        float offsetX,
        float offsetY,
        float depth)
    {
        line.SetPosition(index, camera.ViewportToWorldPoint(
            new Vector3(center.x + offsetX, center.y + offsetY, depth)));
    }

    void LateUpdate()
    {
        RefreshLayout();
        if (ornamentSprite != null && state != EnemyTargetSigilState.Hidden)
        {
            var pulse = 1f + Mathf.Sin(GetAnimationRadians()) * 0.035f;
            ornamentSprite.transform.localScale *= pulse;
        }
    }

    float GetAnimationRadians()
    {
        if (!float.IsNaN(previewAnimationPhase))
            return previewAnimationPhase * Mathf.PI * 2f;
        return Time.unscaledTime / Mathf.Max(0.1f, bobPeriod) * Mathf.PI * 2f;
    }
}
