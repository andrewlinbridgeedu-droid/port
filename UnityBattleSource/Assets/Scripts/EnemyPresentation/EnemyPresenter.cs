using System;
using System.Collections.Generic;
using UnityEngine;

public sealed class EnemyPresentationRequest
{
    public EnemyVisualProfile Profile { get; set; }
    public EnemyFormationProfile Formation { get; set; }
    public string SlotId { get; set; }
    public string BattleEnemyId { get; set; }
    public Transform Parent { get; set; }
    public GameObject ExistingEnemyRoot { get; set; }
    public GameObject AdoptedModel { get; set; }
    public bool EnableMotion { get; set; } = true;
}

public static class EnemyPresenter
{
    const float BoundsEpsilon = 0.0001f;

    public static EnemyHandle Present(EnemyPresentationRequest request)
    {
        var errors = new List<string>();
        if (!TryPresent(request, out var handle, errors))
            throw new InvalidOperationException(string.Join("\n", errors));
        return handle;
    }

    public static bool TryPresent(
        EnemyPresentationRequest request,
        out EnemyHandle handle,
        List<string> errors)
    {
        handle = null;
        if (errors == null) errors = new List<string>();
        if (!ValidateRequest(request, errors, out var slot))
            return false;

        var rootObject = request.ExistingEnemyRoot != null
            ? request.ExistingEnemyRoot
            : new GameObject($"EnemyRoot [{request.BattleEnemyId}]");
        if (request.Parent != null)
            rootObject.transform.SetParent(request.Parent, false);

        var existingHandle = rootObject.GetComponent<EnemyHandle>();
        handle = existingHandle != null ? existingHandle : rootObject.AddComponent<EnemyHandle>();
        var root = rootObject.transform;
        var motion = EnsureDirectChild(root, "MotionRoot");
        var visual = EnsureDirectChild(motion, "VisualRoot");

        var hover = motion.GetComponent<EnemyHoverMotion>();
        if (hover == null) hover = motion.gameObject.AddComponent<EnemyHoverMotion>();
        hover.StopAndReset();

        ResetOwnedTransform(root);
        ResetOwnedTransform(motion);
        ResetOwnedTransform(visual);
        DestroyPreviousModel(visual, request.AdoptedModel);

        var modelObject = request.AdoptedModel != null
            ? request.AdoptedModel
            : UnityEngine.Object.Instantiate(request.Profile.Prefab);
        modelObject.name = "Model";
        modelObject.transform.SetParent(visual, false);
        ResetOwnedTransform(modelObject.transform);
        modelObject.SetActive(true);

        ApplyAnimatorController(modelObject, request.Profile.AnimatorController);
        visual.localRotation = request.Profile.BuildOrientationCorrection();

        var targetHeight = request.Formation.ReferenceWorldHeight * request.Profile.ReferenceHeightRatio;
        if (!NormalizeHeightAndAlignToSlotPlane(motion, visual, targetHeight, errors))
        {
            if (request.ExistingEnemyRoot == null)
                DestroyObject(rootObject);
            handle = null;
            return false;
        }

        root.position = slot.WorldPosition + request.Profile.SlotOffset;
        root.rotation = Quaternion.identity;

        var anchors = request.Profile.Anchors ?? new EnemyAnchorConfiguration();
        var shield = BindAnchor(motion, "ShieldAnchor", anchors.Shield);
        if (!TryCalculateRendererBounds(motion, visual.gameObject, out var presentedBounds))
        {
            errors.Add("Enemy model bounds became unavailable while binding anchors.");
            if (request.ExistingEnemyRoot == null)
                DestroyObject(rootObject);
            handle = null;
            return false;
        }
        var targetFloorCenter = new Vector3(
            presentedBounds.center.x,
            presentedBounds.min.y,
            presentedBounds.center.z);
        var target = BindAnchor(motion, "TargetAnchor", targetFloorCenter + anchors.Target);
        var groundAnchor = motion.GetComponent<EnemyGroundAnchor>();
        if (groundAnchor == null)
            groundAnchor = motion.gameObject.AddComponent<EnemyGroundAnchor>();
        groundAnchor.Configure(modelObject.transform, target);
        if (!slot.IsAirborne)
        {
            AlignGroundedVisualToSlotPlane(visual, groundAnchor, slot.WorldPosition.y);
            TryCalculateRendererBounds(motion, visual.gameObject, out presentedBounds);
        }
        var targetSigil = target.GetComponent<EnemyTargetSigil>();
        if (targetSigil == null)
            targetSigil = target.gameObject.AddComponent<EnemyTargetSigil>();
        targetSigil.Configure(modelObject.transform, motion, presentedBounds);
        targetSigil.ConfigureRadius(targetHeight * 0.38f);
        targetSigil.SetState(EnemyTargetSigilState.Hidden);
        var healthBar = BindAnchor(motion, "HealthBarAnchor", anchors.HealthBar);
        var damageText = BindAnchor(motion, "DamageTextAnchor", anchors.DamageText);
        var effect = BindAnchor(motion, "EffectAnchor", anchors.Effect);

        var hoverConfig = request.Profile.Hover ?? new EnemyHoverConfiguration();
        hover.Configure(hoverConfig.Amplitude, hoverConfig.Period);
        hover.CaptureBaseline();

        handle.Bind(
            request.BattleEnemyId,
            request.Profile,
            request.Formation,
            slot.SlotId,
            root,
            motion,
            visual,
            modelObject.transform,
            shield,
            target,
            healthBar,
            damageText,
            effect,
            hover);

        // Motion is enabled last, after hierarchy, bounds, slot and anchors are final.
        if (request.EnableMotion && hoverConfig.Enabled)
            hover.CaptureBaselineAndEnable();
        else
            hover.StopAndReset();

        return true;
    }

    public static bool Reposition(
        EnemyHandle handle,
        string slotId,
        bool enableMotion,
        List<string> errors = null)
    {
        if (errors == null) errors = new List<string>();
        if (handle == null
            || handle.Profile == null
            || handle.Formation == null
            || handle.EnemyRoot == null
            || handle.MotionRoot == null)
        {
            errors.Add("Enemy handle is missing its profile, formation, EnemyRoot, or MotionRoot reference.");
            return false;
        }
        if (!handle.Formation.TryGetSlot(slotId, out var slot))
        {
            errors.Add($"Formation slot '{slotId}' does not exist.");
            return false;
        }

        var hover = handle.HoverMotion;
        if (hover != null) hover.StopAndReset();
        handle.EnemyRoot.SetPositionAndRotation(
            slot.WorldPosition + handle.Profile.SlotOffset,
            Quaternion.identity);
        if (handle.MotionRoot != null)
        {
            handle.MotionRoot.localPosition = Vector3.zero;
            handle.MotionRoot.localRotation = Quaternion.identity;
            handle.MotionRoot.localScale = Vector3.one;
        }
        if (!slot.IsAirborne && handle.VisualRoot != null)
        {
            var groundAnchor = handle.MotionRoot.GetComponent<EnemyGroundAnchor>();
            AlignGroundedVisualToSlotPlane(handle.VisualRoot, groundAnchor, slot.WorldPosition.y);
        }

        handle.Bind(
            handle.BattleEnemyId,
            handle.Profile,
            handle.Formation,
            slot.SlotId,
            handle.EnemyRoot,
            handle.MotionRoot,
            handle.VisualRoot,
            handle.Model,
            handle.ShieldAnchor,
            handle.TargetAnchor,
            handle.HealthBarAnchor,
            handle.DamageTextAnchor,
            handle.EffectAnchor,
            hover);

        if (hover != null)
        {
            var hoverConfiguration = handle.Profile.Hover ?? new EnemyHoverConfiguration();
            hover.Configure(hoverConfiguration.Amplitude, hoverConfiguration.Period);
            hover.CaptureBaseline();
            if (enableMotion && hoverConfiguration.Enabled)
                hover.CaptureBaselineAndEnable();
        }
        return true;
    }

    static void AlignGroundedVisualToSlotPlane(
        Transform visual,
        EnemyGroundAnchor groundAnchor,
        float groundWorldY)
    {
        if (visual == null || groundAnchor == null)
            return;
        var animator = visual.GetComponentInChildren<Animator>(true);
        animator?.Update(0f);
        if (!groundAnchor.TryGetGroundContact(out var contact))
            return;
        var worldDelta = groundWorldY - contact.y;
        var parent = visual.parent;
        var localDelta = parent != null
            ? parent.InverseTransformVector(Vector3.up * worldDelta)
            : Vector3.up * worldDelta;
        visual.localPosition += localDelta;
        groundAnchor.Refresh();
    }

    public static bool TryCalculateRendererBounds(Transform relativeTo, GameObject model, out Bounds bounds)
    {
        bounds = default;
        if (relativeTo == null || model == null) return false;
        var renderers = model.GetComponentsInChildren<Renderer>(true);
        var useLeechRestBounds = model.GetComponentInChildren<MemoryLeechPresentation>(true) != null;
        var hasBounds = false;
        for (var i = 0; i < renderers.Length; i++)
        {
            var renderer = renderers[i];
            if (renderer == null) continue;
            var localBounds = renderer.localBounds;
            // This creature's animated bounds include expanded death puddles
            // and are recomputed by Unity on activation. Fit its resting mesh
            // explicitly so activation cannot shrink the actor hundreds-fold.
            if (useLeechRestBounds && renderer is SkinnedMeshRenderer skin && skin.sharedMesh != null)
                localBounds = skin.sharedMesh.bounds;
            if (localBounds.size.sqrMagnitude <= BoundsEpsilon * BoundsEpsilon) continue;
            EncapsulateTransformedBounds(renderer.transform, localBounds, relativeTo, ref bounds, ref hasBounds);
        }
        return hasBounds;
    }

    static bool ValidateRequest(
        EnemyPresentationRequest request,
        List<string> errors,
        out EnemyFormationSlot slot)
    {
        slot = null;
        var initialErrorCount = errors.Count;
        if (request == null)
        {
            errors.Add("Enemy presentation request is null.");
            return false;
        }
        if (request.Profile == null)
            errors.Add("Enemy visual profile is missing.");
        if (request.Formation == null)
            errors.Add("Enemy formation profile is missing.");
        if (string.IsNullOrWhiteSpace(request.BattleEnemyId))
            errors.Add("battleEnemyId is empty.");
        if (errors.Count > initialErrorCount) return false;

        request.Profile.Validate(request.Formation, errors);
        request.Formation.Validate(errors);
        var slotId = string.IsNullOrWhiteSpace(request.SlotId)
            ? request.Profile.DefaultSlotId
            : request.SlotId;
        if (!request.Formation.TryGetSlot(slotId, out slot))
            errors.Add($"Formation slot '{slotId}' does not exist.");
        return errors.Count == initialErrorCount;
    }

    static bool NormalizeHeightAndAlignToSlotPlane(
        Transform motion,
        Transform visual,
        float targetHeight,
        List<string> errors)
    {
        if (!TryCalculateRendererBounds(motion, visual.gameObject, out var initialBounds)
            || initialBounds.size.y <= BoundsEpsilon)
        {
            errors.Add("Enemy model has no usable renderer bounds, including inactive renderers.");
            return false;
        }

        visual.localScale = Vector3.one * (targetHeight / initialBounds.size.y);
        if (!TryCalculateRendererBounds(motion, visual.gameObject, out var scaledBounds)
            || scaledBounds.size.y <= BoundsEpsilon)
        {
            errors.Add("Enemy model renderer bounds became invalid after height normalization.");
            return false;
        }

        visual.localPosition = new Vector3(0f, -scaledBounds.min.y, 0f);
        return true;
    }

    static void ApplyAnimatorController(GameObject model, RuntimeAnimatorController controller)
    {
        if (controller == null) return;
        var animators = model.GetComponentsInChildren<Animator>(true);
        for (var i = 0; i < animators.Length; i++)
        {
            animators[i].runtimeAnimatorController = controller;
            animators[i].applyRootMotion = false;
            animators[i].cullingMode = AnimatorCullingMode.AlwaysAnimate;
        }
    }

    static Transform BindAnchor(Transform motion, string name, Vector3 localPosition)
    {
        var anchor = EnsureDirectChild(motion, name);
        anchor.localPosition = localPosition;
        anchor.localRotation = Quaternion.identity;
        anchor.localScale = Vector3.one;
        return anchor;
    }

    static Transform EnsureDirectChild(Transform parent, string name)
    {
        for (var i = 0; i < parent.childCount; i++)
        {
            var child = parent.GetChild(i);
            if (child.name == name) return child;
        }

        var created = new GameObject(name).transform;
        created.SetParent(parent, false);
        return created;
    }

    static void DestroyPreviousModel(Transform visual, GameObject adoptedModel)
    {
        for (var i = visual.childCount - 1; i >= 0; i--)
        {
            var child = visual.GetChild(i);
            if (adoptedModel != null && child.gameObject == adoptedModel) continue;
            // Runtime Destroy is deferred. Detach first so a same-frame rebuild
            // cannot include the retired model in renderer bounds or hierarchy.
            child.SetParent(null, true);
            child.gameObject.SetActive(false);
            DestroyObject(child.gameObject);
        }
    }

    static void ResetOwnedTransform(Transform value)
    {
        value.localPosition = Vector3.zero;
        value.localRotation = Quaternion.identity;
        value.localScale = Vector3.one;
    }

    static void EncapsulateTransformedBounds(
        Transform source,
        Bounds sourceBounds,
        Transform relativeTo,
        ref Bounds aggregate,
        ref bool hasBounds)
    {
        var center = sourceBounds.center;
        var extents = sourceBounds.extents;
        for (var x = -1; x <= 1; x += 2)
        for (var y = -1; y <= 1; y += 2)
        for (var z = -1; z <= 1; z += 2)
        {
            var localPoint = center + Vector3.Scale(extents, new Vector3(x, y, z));
            var point = relativeTo.InverseTransformPoint(source.TransformPoint(localPoint));
            if (!hasBounds)
            {
                aggregate = new Bounds(point, Vector3.zero);
                hasBounds = true;
            }
            else
            {
                aggregate.Encapsulate(point);
            }
        }
    }

    static void DestroyObject(UnityEngine.Object value)
    {
        if (value == null) return;
        if (Application.isPlaying)
            UnityEngine.Object.Destroy(value);
        else
            UnityEngine.Object.DestroyImmediate(value);
    }
}
