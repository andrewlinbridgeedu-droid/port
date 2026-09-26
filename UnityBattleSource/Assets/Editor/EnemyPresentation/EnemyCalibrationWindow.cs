using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public sealed class EnemyCalibrationWindow : EditorWindow
{
    EnemyVisualProfile profile;
    EnemyFormationProfile formation;
    SerializedObject serializedProfile;
    EnemyHandle previewHandle;
    string selectedSlotId;
    float hoverPreviewPhase;
    Vector2 scroll;
    readonly List<string> validationErrors = new();
    readonly List<string> previewErrors = new();

    [MenuItem("Mindstone/Enemy Calibration")]
    static void Open()
    {
        GetWindow<EnemyCalibrationWindow>("Enemy Calibration");
    }

    void OnEnable()
    {
        formation = AssetDatabase.LoadAssetAtPath<EnemyFormationProfile>(Install3DAssets.FormationAssetPath);
        profile = Selection.activeObject as EnemyVisualProfile
            ?? AssetDatabase.LoadAssetAtPath<EnemyVisualProfile>(Install3DAssets.GuardProfileAssetPath);
        BindProfile();
        EditorApplication.delayCall += RebuildPreview;
    }

    void OnDisable()
    {
        EditorApplication.delayCall -= RebuildPreview;
        DestroyPreview();
    }

    void OnGUI()
    {
        scroll = EditorGUILayout.BeginScrollView(scroll);
        EditorGUILayout.LabelField("Runtime-backed enemy calibration", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "The preview is built by EnemyPresenter. EnemyRoot owns formation, MotionRoot owns hover, and VisualRoot owns orientation/height calibration.",
            MessageType.Info);

        EditorGUI.BeginChangeCheck();
        var nextProfile = (EnemyVisualProfile)EditorGUILayout.ObjectField(
            "Visual Profile", profile, typeof(EnemyVisualProfile), false);
        var nextFormation = (EnemyFormationProfile)EditorGUILayout.ObjectField(
            "Formation", formation, typeof(EnemyFormationProfile), false);
        if (EditorGUI.EndChangeCheck())
        {
            profile = nextProfile;
            formation = nextFormation;
            BindProfile();
            RebuildPreview();
        }

        if (profile == null || formation == null)
        {
            EditorGUILayout.HelpBox(
                "Select an EnemyVisualProfile and EnemyFormationProfile. Run Mindstone > Install 3D Battle Assets to generate the approved Clock Guard/Core assets.",
                MessageType.Warning);
            EditorGUILayout.EndScrollView();
            return;
        }

        DrawSlotSelector();
        DrawProfileFields();

        hoverPreviewPhase = EditorGUILayout.Slider("Hover Preview Phase", hoverPreviewPhase, 0f, 1f);
        if (previewHandle?.HoverMotion != null)
        {
            var period = profile.Hover != null ? profile.Hover.Period : 0f;
            previewHandle.HoverMotion.EvaluateAtElapsed(hoverPreviewPhase * Mathf.Max(0f, period));
        }

        EditorGUILayout.Space();
        using (new EditorGUILayout.HorizontalScope())
        {
            if (GUILayout.Button("Reset Preview")) RebuildPreview();
            if (GUILayout.Button("Save Assets")) SaveAssets();
        }

        DrawValidation();
        EditorGUILayout.EndScrollView();
    }

    void DrawSlotSelector()
    {
        var slots = formation.Slots;
        var labels = new string[slots.Count];
        var selectedIndex = 0;
        for (var i = 0; i < slots.Count; i++)
        {
            labels[i] = slots[i]?.SlotId ?? "<null>";
            if (labels[i] == selectedSlotId) selectedIndex = i;
        }

        if (labels.Length == 0)
        {
            EditorGUILayout.HelpBox("Formation has no slots.", MessageType.Error);
            return;
        }

        var nextIndex = EditorGUILayout.Popup("Formation Slot", selectedIndex, labels);
        var nextSlot = labels[Mathf.Clamp(nextIndex, 0, labels.Length - 1)];
        if (nextSlot != selectedSlotId)
        {
            selectedSlotId = nextSlot;
            RebuildPreview();
        }
    }

    void DrawProfileFields()
    {
        if (serializedProfile == null) return;
        serializedProfile.Update();
        EditorGUI.BeginChangeCheck();
        EditorGUILayout.PropertyField(serializedProfile.FindProperty("orientationSteps"), true);
        EditorGUILayout.PropertyField(serializedProfile.FindProperty("referenceHeightRatio"));
        EditorGUILayout.PropertyField(serializedProfile.FindProperty("slotOffset"));
        EditorGUILayout.PropertyField(serializedProfile.FindProperty("hover"), true);
        EditorGUILayout.PropertyField(serializedProfile.FindProperty("anchors"), true);
        if (EditorGUI.EndChangeCheck())
        {
            serializedProfile.ApplyModifiedProperties();
            RebuildPreview();
        }
    }

    void BindProfile()
    {
        serializedProfile = profile != null ? new SerializedObject(profile) : null;
        selectedSlotId = profile != null ? profile.DefaultSlotId : string.Empty;
    }

    void RebuildPreview()
    {
        DestroyPreview();
        previewErrors.Clear();
        if (profile == null || formation == null) return;

        if (!EnemyPresenter.TryPresent(
                new EnemyPresentationRequest
                {
                    Profile = profile,
                    Formation = formation,
                    SlotId = selectedSlotId,
                    BattleEnemyId = "enemy-calibration-preview",
                    EnableMotion = false
                },
                out previewHandle,
                previewErrors))
            return;

        previewHandle.EnemyRoot.name = $"Enemy Calibration Preview [{profile.EnemyId}]";
        SetPreviewHideFlags(previewHandle.EnemyRoot, HideFlags.DontSaveInEditor);
        Selection.activeTransform = previewHandle.EnemyRoot;
        SceneView.lastActiveSceneView?.FrameSelected();
        SceneView.RepaintAll();
    }

    void DrawValidation()
    {
        validationErrors.Clear();
        validationErrors.AddRange(previewErrors);
        formation.Validate(validationErrors);
        profile.Validate(formation, validationErrors);
        if (previewHandle != null)
        {
            ValidateAnchor(previewHandle.ShieldAnchor, "ShieldAnchor");
            ValidateAnchor(previewHandle.TargetAnchor, "TargetAnchor");
            ValidateAnchor(previewHandle.HealthBarAnchor, "HealthBarAnchor");
            ValidateAnchor(previewHandle.DamageTextAnchor, "DamageTextAnchor");
            ValidateAnchor(previewHandle.EffectAnchor, "EffectAnchor");
        }

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Validation", EditorStyles.boldLabel);
        if (validationErrors.Count == 0)
        {
            EditorGUILayout.HelpBox("No validation errors.", MessageType.Info);
            return;
        }

        for (var i = 0; i < validationErrors.Count; i++)
            EditorGUILayout.HelpBox(validationErrors[i], MessageType.Error);
    }

    void ValidateAnchor(Transform anchor, string anchorName)
    {
        if (anchor == null)
            validationErrors.Add($"Preview is missing {anchorName}.");
        else if (anchor.parent != previewHandle.MotionRoot)
            validationErrors.Add($"{anchorName} must be a direct child of MotionRoot.");
    }

    void SaveAssets()
    {
        serializedProfile?.ApplyModifiedProperties();
        EditorUtility.SetDirty(profile);
        EditorUtility.SetDirty(formation);
        AssetDatabase.SaveAssets();
        RebuildPreview();
    }

    void DestroyPreview()
    {
        if (previewHandle == null) return;
        var root = previewHandle.EnemyRoot != null
            ? previewHandle.EnemyRoot.gameObject
            : previewHandle.gameObject;
        previewHandle = null;
        DestroyImmediate(root);
    }

    static void SetPreviewHideFlags(Transform root, HideFlags flags)
    {
        root.gameObject.hideFlags = flags;
        for (var i = 0; i < root.childCount; i++)
            SetPreviewHideFlags(root.GetChild(i), flags);
    }
}
