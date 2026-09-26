using System;
using System.Collections.Generic;
using UnityEngine;

public enum EnemyOrientationAxis
{
    X,
    Y,
    Z
}

[Serializable]
public struct EnemyOrientationStep
{
    [SerializeField] EnemyOrientationAxis axis;
    [SerializeField] float degrees;

    public EnemyOrientationAxis Axis => axis;
    public float Degrees => degrees;

    public EnemyOrientationStep(EnemyOrientationAxis axis, float degrees)
    {
        this.axis = axis;
        this.degrees = degrees;
    }

    public Quaternion ToQuaternion()
    {
        return Quaternion.AngleAxis(degrees, AxisVector(axis));
    }

    public void Validate(string context, int index, List<string> errors)
    {
        if (!Enum.IsDefined(typeof(EnemyOrientationAxis), axis))
            errors.Add($"{context}: orientation step {index} has an invalid axis.");
        if (!EnemyVisualProfile.IsFinite(degrees))
            errors.Add($"{context}: orientation step {index} has non-finite degrees.");
    }

    static Vector3 AxisVector(EnemyOrientationAxis value)
    {
        switch (value)
        {
            case EnemyOrientationAxis.X: return Vector3.right;
            case EnemyOrientationAxis.Y: return Vector3.up;
            default: return Vector3.forward;
        }
    }
}

[Serializable]
public sealed class EnemyHoverConfiguration
{
    [SerializeField] bool enabled;
    [SerializeField, Min(0f)] float amplitude;
    [SerializeField] float period = 4.2f;

    public bool Enabled => enabled;
    public float Amplitude => amplitude;
    public float Period => period;

    public EnemyHoverConfiguration()
    {
    }

    public EnemyHoverConfiguration(bool enabled, float amplitude, float period)
    {
        this.enabled = enabled;
        this.amplitude = amplitude;
        this.period = period;
    }

    public void Configure(bool shouldHover, float hoverAmplitude, float hoverPeriod)
    {
        enabled = shouldHover;
        amplitude = hoverAmplitude;
        period = hoverPeriod;
    }

    public void Validate(string context, List<string> errors)
    {
        if (!EnemyVisualProfile.IsFinite(amplitude) || amplitude < 0f)
            errors.Add($"{context}: hover amplitude must be finite and non-negative.");
        if (!EnemyVisualProfile.IsFinite(period) || period <= 0f)
            errors.Add($"{context}: hover period must be finite and greater than zero.");
    }
}

[Serializable]
public sealed class EnemyAnchorConfiguration
{
    [SerializeField] Vector3 shield = new(0f, 1f, 0f);
    [SerializeField] Vector3 target = Vector3.zero;
    [SerializeField] Vector3 healthBar = new(0f, 2f, 0f);
    [SerializeField] Vector3 damageText = new(0f, 1.7f, 0f);
    [SerializeField] Vector3 effect = new(0f, 1f, 0f);

    public Vector3 Shield => shield;
    public Vector3 Target => target;
    public Vector3 HealthBar => healthBar;
    public Vector3 DamageText => damageText;
    public Vector3 Effect => effect;

    public EnemyAnchorConfiguration()
    {
    }

    public EnemyAnchorConfiguration(
        Vector3 shield,
        Vector3 target,
        Vector3 healthBar,
        Vector3 damageText,
        Vector3 effect)
    {
        this.shield = shield;
        this.target = target;
        this.healthBar = healthBar;
        this.damageText = damageText;
        this.effect = effect;
    }

    public void Configure(
        Vector3 shieldPosition,
        Vector3 targetPosition,
        Vector3 healthBarPosition,
        Vector3 damageTextPosition,
        Vector3 effectPosition)
    {
        shield = shieldPosition;
        target = targetPosition;
        healthBar = healthBarPosition;
        damageText = damageTextPosition;
        effect = effectPosition;
    }

    public void Validate(string context, List<string> errors)
    {
        ValidateVector(shield, "ShieldAnchor", context, errors);
        ValidateVector(target, "TargetAnchor", context, errors);
        ValidateVector(healthBar, "HealthBarAnchor", context, errors);
        ValidateVector(damageText, "DamageTextAnchor", context, errors);
        ValidateVector(effect, "EffectAnchor", context, errors);
    }

    static void ValidateVector(Vector3 value, string anchorName, string context, List<string> errors)
    {
        if (!EnemyVisualProfile.IsFinite(value.x)
            || !EnemyVisualProfile.IsFinite(value.y)
            || !EnemyVisualProfile.IsFinite(value.z))
            errors.Add($"{context}: {anchorName} contains a non-finite coordinate.");
    }
}

[CreateAssetMenu(menuName = "Mistport/Enemy Visual Profile", fileName = "EnemyVisualProfile")]
public sealed class EnemyVisualProfile : ScriptableObject
{
    [SerializeField] string enemyId;
    [SerializeField] GameObject prefab;
    [SerializeField] RuntimeAnimatorController animatorController;
    [SerializeField] List<EnemyOrientationStep> orientationSteps = new();
    [SerializeField] float referenceHeightRatio = 1f;
    [SerializeField] string defaultSlotId;
    [SerializeField] Vector3 slotOffset;
    [SerializeField] EnemyHoverConfiguration hover = new();
    [SerializeField] EnemyAnchorConfiguration anchors = new();

    public string EnemyId => enemyId;
    public GameObject Prefab => prefab;
    public RuntimeAnimatorController AnimatorController => animatorController;
    public IReadOnlyList<EnemyOrientationStep> OrientationSteps => orientationSteps;
    public float ReferenceHeightRatio => referenceHeightRatio;
    public string DefaultSlotId => defaultSlotId;
    public Vector3 SlotOffset => slotOffset;
    public EnemyHoverConfiguration Hover => hover;
    public EnemyAnchorConfiguration Anchors => anchors;

    public Quaternion BuildOrientationCorrection()
    {
        var correction = Quaternion.identity;
        // Steps are multiplied left-to-right exactly as listed. This preserves
        // non-commutative authored order without relying on Euler conversion.
        if (orientationSteps == null) return correction;
        for (var i = 0; i < orientationSteps.Count; i++)
            correction = correction * orientationSteps[i].ToQuaternion();
        return correction;
    }

    public void Configure(
        string stableEnemyId,
        GameObject modelPrefab,
        RuntimeAnimatorController controller,
        IEnumerable<EnemyOrientationStep> orderedOrientationSteps,
        float heightRatio,
        string slotId,
        Vector3 perEnemySlotOffset,
        EnemyHoverConfiguration hoverConfiguration,
        EnemyAnchorConfiguration anchorConfiguration)
    {
        enemyId = stableEnemyId;
        prefab = modelPrefab;
        animatorController = controller;
        orientationSteps = orderedOrientationSteps == null
            ? new List<EnemyOrientationStep>()
            : new List<EnemyOrientationStep>(orderedOrientationSteps);
        referenceHeightRatio = heightRatio;
        defaultSlotId = slotId;
        slotOffset = perEnemySlotOffset;
        hover = hoverConfiguration ?? new EnemyHoverConfiguration();
        anchors = anchorConfiguration ?? new EnemyAnchorConfiguration();
    }

    public void Validate(EnemyFormationProfile formation, List<string> errors)
    {
        var context = string.IsNullOrWhiteSpace(enemyId) ? name : enemyId;
        if (string.IsNullOrWhiteSpace(enemyId))
            errors.Add($"{name}: enemy ID is empty.");
        if (prefab == null)
            errors.Add($"{context}: model prefab is missing.");
        if (!IsFinite(referenceHeightRatio) || referenceHeightRatio <= 0f)
            errors.Add($"{context}: reference height ratio must be finite and greater than zero.");
        if (string.IsNullOrWhiteSpace(defaultSlotId))
            errors.Add($"{context}: default formation slot ID is empty.");
        else if (formation != null && !formation.TryGetSlot(defaultSlotId, out _))
            errors.Add($"{context}: formation slot '{defaultSlotId}' does not exist.");

        if (!IsFinite(slotOffset.x) || !IsFinite(slotOffset.y) || !IsFinite(slotOffset.z))
            errors.Add($"{context}: slot offset contains a non-finite coordinate.");

        if (orientationSteps == null)
        {
            errors.Add($"{context}: ordered orientation step list is missing.");
        }
        else
        {
            for (var i = 0; i < orientationSteps.Count; i++)
                orientationSteps[i].Validate(context, i, errors);
        }

        hover?.Validate(context, errors);
        anchors?.Validate(context, errors);
    }

    public static void ValidateCollection(
        IReadOnlyList<EnemyVisualProfile> profiles,
        EnemyFormationProfile formation,
        List<string> errors)
    {
        if (profiles == null)
        {
            errors.Add("Enemy visual profile collection is null.");
            return;
        }

        var ids = new HashSet<string>(StringComparer.Ordinal);
        for (var i = 0; i < profiles.Count; i++)
        {
            var profile = profiles[i];
            if (profile == null)
            {
                errors.Add($"Enemy visual profile index {i} is null.");
                continue;
            }

            profile.Validate(formation, errors);
            if (!string.IsNullOrWhiteSpace(profile.EnemyId) && !ids.Add(profile.EnemyId))
                errors.Add($"Duplicate enemy ID '{profile.EnemyId}'.");
        }
    }

    internal static bool IsFinite(float value)
    {
        return !float.IsNaN(value) && !float.IsInfinity(value);
    }
}
