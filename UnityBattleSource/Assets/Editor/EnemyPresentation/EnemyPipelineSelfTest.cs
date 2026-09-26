using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class EnemyPipelineSelfTest
{
    const float PositionTolerance = 0.0001f;
    const float HeightTolerance = 0.001f;

    [MenuItem("Mindstone/Validate Enemy Pipeline")]
    public static void RunFromMenu()
    {
        RunBatch();
    }

    public static void RunBatch()
    {
        var errors = new List<string>();
        RunDeterministicPresenterChecks(errors);
        ValidateInstalledMigrationAssets(errors);
        if (errors.Count > 0)
        {
            var message = "Enemy pipeline validation failed:\n- " + string.Join("\n- ", errors);
            Debug.LogError(message);
            throw new InvalidOperationException(message);
        }

        Debug.Log("Mindstone: enemy pipeline validation passed.");
    }

    static void RunDeterministicPresenterChecks(List<string> errors)
    {
        var source = GameObject.CreatePrimitive(PrimitiveType.Cube);
        source.name = "EnemyPipelineSelfTestSource";
        var inactiveChild = GameObject.CreatePrimitive(PrimitiveType.Cube);
        inactiveChild.name = "InactiveRenderer";
        inactiveChild.transform.SetParent(source.transform, false);
        inactiveChild.transform.localPosition = new Vector3(0f, 2f, 0f);
        inactiveChild.SetActive(false);
        source.SetActive(false);

        var formation = ScriptableObject.CreateInstance<EnemyFormationProfile>();
        formation.name = "SelfTestFormation";
        formation.Configure(2f, new[]
        {
            new EnemyFormationSlot(EnemyFormationSlotIds.FrontCenter, new Vector3(1f, 0f, 3f), EnemyFormationElevation.Grounded),
            new EnemyFormationSlot(EnemyFormationSlotIds.AirRearLeft, new Vector3(-1f, 1f, 4f), EnemyFormationElevation.Airborne)
        });

        var profile = ScriptableObject.CreateInstance<EnemyVisualProfile>();
        profile.name = "SelfTestProfile";
        profile.Configure(
            "self-test-enemy",
            source,
            null,
            new[]
            {
                new EnemyOrientationStep(EnemyOrientationAxis.Y, 90f),
                new EnemyOrientationStep(EnemyOrientationAxis.Z, 15f)
            },
            1f,
            EnemyFormationSlotIds.FrontCenter,
            Vector3.zero,
            new EnemyHoverConfiguration(true, 0.055f, 4.2f),
            new EnemyAnchorConfiguration(
                new Vector3(0f, 1f, 0f),
                Vector3.zero,
                new Vector3(0f, 2.2f, 0f),
                new Vector3(0f, 1.8f, 0f),
                new Vector3(0f, 1f, 0f)));

        EnemyHandle handle = null;
        try
        {
            handle = EnemyPresenter.Present(new EnemyPresentationRequest
            {
                Profile = profile,
                Formation = formation,
                SlotId = EnemyFormationSlotIds.FrontCenter,
                BattleEnemyId = "self-test-battle-enemy",
                EnableMotion = false
            });

            ValidateHeight(handle, 2f, errors, "first setup");
            ValidateStandardHierarchy(handle, errors);
            var firstScale = handle.VisualRoot.localScale;
            var firstVisualPosition = handle.VisualRoot.localPosition;
            var firstRootPosition = handle.EnemyRoot.position;

            handle = EnemyPresenter.Present(new EnemyPresentationRequest
            {
                Profile = profile,
                Formation = formation,
                SlotId = EnemyFormationSlotIds.FrontCenter,
                BattleEnemyId = "self-test-battle-enemy",
                ExistingEnemyRoot = handle.EnemyRoot.gameObject,
                EnableMotion = false
            });

            ValidateHeight(handle, 2f, errors, "repeated setup");
            ValidateStandardHierarchy(handle, errors);
            AssertApproximately(firstScale, handle.VisualRoot.localScale, PositionTolerance, "Repeated setup changed normalized scale.", errors);
            AssertApproximately(firstVisualPosition, handle.VisualRoot.localPosition, PositionTolerance, "Repeated setup changed visual alignment.", errors);
            AssertApproximately(firstRootPosition, handle.EnemyRoot.position, PositionTolerance, "Repeated setup changed formation position.", errors);

            for (var i = 0; i < 10; i++)
            {
                EnemyPresenter.Reposition(handle, EnemyFormationSlotIds.AirRearLeft, true, errors);
                EnemyPresenter.Reposition(handle, EnemyFormationSlotIds.FrontCenter, false, errors);
            }
            AssertApproximately(firstRootPosition, handle.EnemyRoot.position, PositionTolerance, "Repeated encounter switching accumulated a root offset.", errors);
            AssertApproximately(firstScale, handle.VisualRoot.localScale, PositionTolerance, "Repeated encounter switching accumulated scale.", errors);

            ValidateHover(handle, errors);
        }
        catch (Exception exception)
        {
            errors.Add($"Deterministic presenter setup threw: {exception.Message}");
        }
        finally
        {
            if (handle != null && handle.EnemyRoot != null)
                UnityEngine.Object.DestroyImmediate(handle.EnemyRoot.gameObject);
            UnityEngine.Object.DestroyImmediate(source);
            UnityEngine.Object.DestroyImmediate(profile);
            UnityEngine.Object.DestroyImmediate(formation);
        }

        ValidateInvalidProfiles(errors);
    }

    static void ValidateHeight(EnemyHandle handle, float expectedHeight, List<string> errors, string context)
    {
        if (!EnemyPresenter.TryCalculateRendererBounds(handle.MotionRoot, handle.VisualRoot.gameObject, out var bounds))
        {
            errors.Add($"{context}: renderer bounds are unavailable.");
            return;
        }
        if (Mathf.Abs(bounds.size.y - expectedHeight) > HeightTolerance)
            errors.Add($"{context}: normalized height was {bounds.size.y}, expected {expectedHeight}.");
        if (Mathf.Abs(bounds.min.y) > HeightTolerance)
            errors.Add($"{context}: lowest renderer point was {bounds.min.y}, expected slot plane 0.");
    }

    static void ValidateHover(EnemyHandle handle, List<string> errors)
    {
        var hover = handle.HoverMotion;
        handle.MotionRoot.localPosition = new Vector3(0.25f, 0.5f, -0.75f);
        handle.MotionRoot.localRotation = Quaternion.Euler(5f, 10f, 15f);
        handle.MotionRoot.localScale = new Vector3(1.1f, 0.9f, 1.2f);
        hover.Configure(0.055f, 4.2f);
        hover.CaptureBaseline();

        var rotation = handle.MotionRoot.localRotation;
        var scale = handle.MotionRoot.localScale;
        var baseline = handle.MotionRoot.localPosition;
        var maxDisplacement = 0f;
        for (var i = 0; i <= 100; i++)
        {
            hover.EvaluateAtElapsed(4.2f * i / 100f);
            var position = handle.MotionRoot.localPosition;
            maxDisplacement = Mathf.Max(maxDisplacement, Mathf.Abs(position.y - baseline.y));
            if (Mathf.Abs(position.x - baseline.x) > PositionTolerance
                || Mathf.Abs(position.z - baseline.z) > PositionTolerance)
                errors.Add("Hover changed MotionRoot X/Z.");
            if (Quaternion.Angle(rotation, handle.MotionRoot.localRotation) > PositionTolerance)
                errors.Add("Hover changed MotionRoot rotation.");
            if ((scale - handle.MotionRoot.localScale).sqrMagnitude > PositionTolerance * PositionTolerance)
                errors.Add("Hover changed MotionRoot scale.");
        }
        if (maxDisplacement > 0.055f + PositionTolerance)
            errors.Add($"Hover displacement {maxDisplacement} exceeded configured amplitude 0.055.");

        hover.Configure(0.055f, 0f);
        hover.CaptureBaseline();
        hover.EvaluateAtElapsed(10f);
        AssertApproximately(baseline, handle.MotionRoot.localPosition, PositionTolerance, "Zero-period hover did not safely remain at baseline.", errors);
        handle.MotionRoot.localRotation = Quaternion.identity;
        handle.MotionRoot.localScale = Vector3.one;
        handle.MotionRoot.localPosition = Vector3.zero;
    }

    static void ValidateStandardHierarchy(EnemyHandle handle, List<string> errors)
    {
        if (handle.BattleEnemyId != "self-test-battle-enemy")
            errors.Add("Repeated setup changed the stable battleEnemyId.");
        if (handle.ProfileEnemyId != "self-test-enemy")
            errors.Add("Repeated setup changed the stable profile enemy ID.");
        if (handle.EnemyRoot != handle.transform)
            errors.Add("EnemyHandle is not owned by EnemyRoot.");
        if (handle.MotionRoot == null || handle.MotionRoot.parent != handle.EnemyRoot)
            errors.Add("MotionRoot is not a direct child of EnemyRoot.");
        if (handle.VisualRoot == null || handle.VisualRoot.parent != handle.MotionRoot)
            errors.Add("VisualRoot is not a direct child of MotionRoot.");
        if (handle.Model == null || handle.Model.parent != handle.VisualRoot)
            errors.Add("Model is not a direct child of VisualRoot.");
        if (handle.MotionRoot != null && handle.MotionRoot.childCount != 6)
            errors.Add($"MotionRoot has {handle.MotionRoot.childCount} children; expected VisualRoot plus five anchors.");
        if (handle.VisualRoot != null && handle.VisualRoot.childCount != 1)
            errors.Add($"VisualRoot has {handle.VisualRoot.childCount} children after repeated setup; expected one Model.");
        ValidateAnchors(handle, errors);
    }

    static void ValidateAnchors(EnemyHandle handle, List<string> errors)
    {
        ValidateAnchor(handle, handle.ShieldAnchor, "ShieldAnchor", errors);
        ValidateAnchor(handle, handle.TargetAnchor, "TargetAnchor", errors);
        ValidateAnchor(handle, handle.HealthBarAnchor, "HealthBarAnchor", errors);
        ValidateAnchor(handle, handle.DamageTextAnchor, "DamageTextAnchor", errors);
        ValidateAnchor(handle, handle.EffectAnchor, "EffectAnchor", errors);
        if (handle.MotionRoot != null
            && handle.MotionRoot.GetComponent<EnemyGroundAnchor>() == null)
            errors.Add("MotionRoot is missing EnemyGroundAnchor.");
        if (handle.TargetAnchor != null
            && handle.TargetAnchor.GetComponent<EnemyTargetSigil>() == null)
            errors.Add("TargetAnchor is missing EnemyTargetSigil.");
    }

    static void ValidateAnchor(EnemyHandle handle, Transform anchor, string name, List<string> errors)
    {
        if (anchor == null)
            errors.Add($"{name} is missing.");
        else if (anchor.parent != handle.MotionRoot)
            errors.Add($"{name} is not a direct child of MotionRoot.");
    }

    static void ValidateInvalidProfiles(List<string> errors)
    {
        var dummyPrefab = new GameObject("ValidationDummyPrefab");
        var badFormation = ScriptableObject.CreateInstance<EnemyFormationProfile>();
        badFormation.name = "BadFormation";
        badFormation.Configure(-1f, new[]
        {
            new EnemyFormationSlot("", Vector3.zero, EnemyFormationElevation.Grounded),
            new EnemyFormationSlot("Duplicate", Vector3.zero, EnemyFormationElevation.Grounded),
            new EnemyFormationSlot("Duplicate", Vector3.zero, EnemyFormationElevation.Grounded),
            new EnemyFormationSlot("BadAir", Vector3.zero, EnemyFormationElevation.Airborne)
        });

        var emptyId = ScriptableObject.CreateInstance<EnemyVisualProfile>();
        emptyId.name = "EmptyId";
        emptyId.Configure(
            "", null, null, null, -1f, "MissingSlot", Vector3.zero,
            new EnemyHoverConfiguration(true, -1f, 0f), new EnemyAnchorConfiguration());
        var duplicateA = ScriptableObject.CreateInstance<EnemyVisualProfile>();
        duplicateA.Configure(
            "duplicate", dummyPrefab, null, null, 1f, "MissingSlot", Vector3.zero,
            new EnemyHoverConfiguration(false, 0f, 1f), new EnemyAnchorConfiguration());
        var duplicateB = ScriptableObject.CreateInstance<EnemyVisualProfile>();
        duplicateB.Configure(
            "duplicate", dummyPrefab, null, null, 1f, "MissingSlot", Vector3.zero,
            new EnemyHoverConfiguration(false, 0f, 1f), new EnemyAnchorConfiguration());

        var found = new List<string>();
        badFormation.Validate(found);
        EnemyVisualProfile.ValidateCollection(
            new[] { emptyId, duplicateA, duplicateB }, badFormation, found);
        RequireValidationMessage(found, "enemy ID is empty", errors);
        RequireValidationMessage(found, "model prefab is missing", errors);
        RequireValidationMessage(found, "reference height ratio", errors);
        RequireValidationMessage(found, "hover period", errors);
        RequireValidationMessage(found, "does not exist", errors);
        RequireValidationMessage(found, "duplicate formation slot ID", errors);
        RequireValidationMessage(found, "formation slot index 0 has an empty ID", errors);
        RequireValidationMessage(found, "Duplicate enemy ID", errors);

        UnityEngine.Object.DestroyImmediate(dummyPrefab);
        UnityEngine.Object.DestroyImmediate(emptyId);
        UnityEngine.Object.DestroyImmediate(duplicateA);
        UnityEngine.Object.DestroyImmediate(duplicateB);
        UnityEngine.Object.DestroyImmediate(badFormation);
    }

    static void RequireValidationMessage(List<string> messages, string fragment, List<string> errors)
    {
        for (var i = 0; i < messages.Count; i++)
        {
            if (messages[i].IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                return;
        }
        errors.Add($"Validation did not report expected condition containing '{fragment}'.");
    }

    static void ValidateInstalledMigrationAssets(List<string> errors)
    {
        var formation = AssetDatabase.LoadAssetAtPath<EnemyFormationProfile>(Install3DAssets.FormationAssetPath);
        var guard = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(Install3DAssets.GuardProfileAssetPath);
        var core = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(Install3DAssets.CoreProfileAssetPath);
        var hound = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(Install3DAssets.HoundProfileAssetPath);
        if (formation == null || guard == null || core == null || hound == null)
        {
            errors.Add("Installed migration assets are missing. Run Mindstone > Install 3D Battle Assets before validation.");
            return;
        }

        formation.Validate(errors);
        var profileGuids = AssetDatabase.FindAssets("t:EnemyVisualProfile");
        var profiles = new List<EnemyVisualProfile>();
        for (var i = 0; i < profileGuids.Length; i++)
        {
            var path = AssetDatabase.GUIDToAssetPath(profileGuids[i]);
            var profile = AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(path);
            if (profile != null) profiles.Add(profile);
        }
        EnemyVisualProfile.ValidateCollection(profiles, formation, errors);

        if (!formation.TryGetSlot(EnemyFormationSlotIds.AirRearLeft, out var airRearLeft))
        {
            errors.Add("Approved AirRearLeft slot is missing.");
        }
        else
        {
            AssertApproximately(new Vector3(-1.8f, 1.15f, 17f), airRearLeft.WorldPosition, PositionTolerance,
                "Approved Clock Core slot position changed.", errors);
            if (!airRearLeft.IsAirborne) errors.Add("Approved Clock Core slot is not marked airborne.");
        }

        if (Mathf.Abs(formation.ReferenceWorldHeight - 2.88f) > PositionTolerance)
            errors.Add("Formation reference height changed from approved guard height 2.88.");
        if (guard.EnemyId != "clock-guard" || core.EnemyId != "clock-core")
            errors.Add("Approved profile enemy IDs changed.");
        if (hound.EnemyId != "hell-hound")
            errors.Add("Hell Hound profile enemy ID changed.");
        if (hound.DefaultSlotId != EnemyFormationSlotIds.FrontCenter)
            errors.Add("Hell Hound default slot is not FrontCenter.");
        if (hound.Hover == null || hound.Hover.Enabled)
            errors.Add("Hell Hound must remain grounded and must not use hover motion.");
        if (Mathf.Abs(guard.ReferenceHeightRatio - 1.02f) > PositionTolerance)
            errors.Add("Clock Guard reference height ratio changed from 1.02.");
        if (Mathf.Abs(core.ReferenceHeightRatio - 0.5865f) > PositionTolerance)
            errors.Add("Clock Core height ratio changed from 0.5865.");
        if (core.Hover == null
            || !core.Hover.Enabled
            || Mathf.Abs(core.Hover.Amplitude - 0.055f) > PositionTolerance
            || Mathf.Abs(core.Hover.Period - 4.2f) > PositionTolerance)
            errors.Add("Clock Core hover migration values do not match amplitude 0.055 and period 4.2s.");
        if (core.DefaultSlotId != EnemyFormationSlotIds.AirRearLeft)
            errors.Add("Clock Core default slot is not AirRearLeft.");

        if (formation.TryGetSlot(EnemyFormationSlotIds.FrontRight, out var frontRight))
            AssertApproximately(
                new Vector3(EnemyFormationLayout.FrontLaneX, 0f, EnemyFormationLayout.FrontRowZ),
                frontRight.WorldPosition,
                PositionTolerance,
                "Approved Clock Guard front-right position changed.", errors);
        else
            errors.Add("Approved FrontRight slot is missing.");
        if (formation.TryGetSlot(EnemyFormationSlotIds.FrontCenter, out var frontCenter))
            AssertApproximately(new Vector3(0f, 0f, EnemyFormationLayout.FrontRowZ), frontCenter.WorldPosition, PositionTolerance,
                "Approved guard-only position changed.", errors);
        else
            errors.Add("Approved FrontCenter slot is missing.");

        AssertStrictRowDepth(
            formation,
            EnemyFormationLayout.FrontRowZ,
            errors,
            EnemyFormationSlotIds.FrontLeft,
            EnemyFormationSlotIds.FrontCenter,
            EnemyFormationSlotIds.FrontRight);
        AssertStrictRowDepth(
            formation,
            EnemyFormationLayout.RearRowZ,
            errors,
            EnemyFormationSlotIds.RearLeft,
            EnemyFormationSlotIds.RearCenter,
            EnemyFormationSlotIds.RearRight,
            EnemyFormationSlotIds.AirRearLeft,
            EnemyFormationSlotIds.AirRearRight);

        var expectedAxes = new[]
        {
            EnemyOrientationAxis.X,
            EnemyOrientationAxis.Y,
            EnemyOrientationAxis.Z,
            EnemyOrientationAxis.Y
        };
        var expectedDegrees = new[] { -15f, 90f, 90f, 90f };
        if (core.OrientationSteps == null || core.OrientationSteps.Count != expectedAxes.Length)
        {
            errors.Add("Clock Core ordered orientation step count changed.");
        }
        else
        {
            for (var i = 0; i < expectedAxes.Length; i++)
            {
                if (core.OrientationSteps[i].Axis != expectedAxes[i]
                    || Mathf.Abs(core.OrientationSteps[i].Degrees - expectedDegrees[i]) > PositionTolerance)
                    errors.Add($"Clock Core orientation step {i} changed from the approved migration sequence.");
            }
        }


        var approvedRotation =
            Quaternion.Euler(-15f, 0f, 0f)
            * Quaternion.Euler(0f, 90f, 0f)
            * Quaternion.AngleAxis(90f, Vector3.forward)
            * Quaternion.Euler(0f, 90f, 0f);
        if (Quaternion.Angle(approvedRotation, core.BuildOrientationCorrection()) > PositionTolerance)
            errors.Add("Clock Core composed orientation no longer matches the approved ordered rotation.");

        const string battleScenePath = "Assets/Scenes/BattlePrototype.unity";
        var battleScene = UnityEngine.SceneManagement.SceneManager.GetSceneByPath(battleScenePath);
        var openedForValidation = !battleScene.isLoaded;
        if (openedForValidation)
            battleScene = EditorSceneManager.OpenScene(battleScenePath, OpenSceneMode.Additive);

        var handles = UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None);
        EnemyHandle installedGuard = null;
        EnemyHandle installedCore = null;
        EnemyHandle installedHound = null;
        for (var i = 0; i < handles.Length; i++)
        {
            if (handles[i].gameObject.scene != battleScene) continue;
            if (handles[i].BattleEnemyId == EnemyBattleIds.ClockGuardPrimary) installedGuard = handles[i];
            if (handles[i].BattleEnemyId == EnemyBattleIds.ClockCorePrimary) installedCore = handles[i];
            if (handles[i].BattleEnemyId == EnemyBattleIds.HellHoundPrimary) installedHound = handles[i];
        }

        if (installedGuard == null || installedCore == null || installedHound == null)
        {
            errors.Add("BattlePrototype scene does not contain all installed EnemyHandle instances.");
        }
        else
        {
            if (installedGuard.FormationSlotId != EnemyFormationSlotIds.FrontCenter)
                errors.Add("Installed Clock Guard slot is not FrontCenter.");
            if (installedCore.FormationSlotId != EnemyFormationSlotIds.AirRearLeft)
                errors.Add("Installed Clock Core slot is not AirRearLeft.");
            ValidateAnchors(installedGuard, errors);
            ValidateAnchors(installedCore, errors);
            ValidateAnchors(installedHound, errors);
        }

        if (openedForValidation)
            EditorSceneManager.CloseScene(battleScene, true);
    }

    static void AssertStrictRowDepth(
        EnemyFormationProfile formation,
        float expectedDepth,
        List<string> errors,
        params string[] slotIds)
    {
        for (var index = 0; index < slotIds.Length; index++)
        {
            if (!formation.TryGetSlot(slotIds[index], out var slot))
            {
                errors.Add($"Strict formation slot '{slotIds[index]}' is missing.");
                continue;
            }
            if (Mathf.Abs(slot.WorldPosition.z - expectedDepth) > PositionTolerance)
                errors.Add(
                    $"Strict formation slot '{slotIds[index]}' depth was "
                    + $"{slot.WorldPosition.z}, expected {expectedDepth}.");
        }
    }

    static void AssertApproximately(
        Vector3 expected,
        Vector3 actual,
        float tolerance,
        string message,
        List<string> errors)
    {
        if ((expected - actual).sqrMagnitude > tolerance * tolerance)
            errors.Add($"{message} Expected {expected}, actual {actual}.");
    }
}
