using System;
using System.Collections.Generic;
using UnityEngine;

public static class EnemyFormationSlotIds
{
    public const string FrontLeft = "FrontLeft";
    public const string FrontCenter = "FrontCenter";
    public const string FrontRight = "FrontRight";
    public const string RearLeft = "RearLeft";
    public const string RearCenter = "RearCenter";
    public const string RearRight = "RearRight";
    public const string AirRearLeft = "AirRearLeft";
    public const string AirRearRight = "AirRearRight";
    public const string CenterBoss = "CenterBoss";
}

/// <summary>
/// Clock Plaza is the reference battlefield for every enemy formation.
/// X changes only the lane, Z changes only the row, and Y changes only the
/// elevation. Enemy-specific profiles must not compensate for formation here.
/// </summary>
public static class EnemyFormationLayout
{
    public const float FrontRowZ = 12f;
    public const float RearRowZ = 17f;
    public const float FrontLaneX = 1.45f;
    public const float RearLaneX = 1.8f;
    public const float AirborneY = 1.15f;

    public static List<EnemyFormationSlot> CreateClockPlazaSlots()
    {
        return new List<EnemyFormationSlot>
        {
            new(EnemyFormationSlotIds.FrontLeft, new Vector3(-FrontLaneX, 0f, FrontRowZ), EnemyFormationElevation.Grounded),
            new(EnemyFormationSlotIds.FrontCenter, new Vector3(0f, 0f, FrontRowZ), EnemyFormationElevation.Grounded),
            new(EnemyFormationSlotIds.FrontRight, new Vector3(FrontLaneX, 0f, FrontRowZ), EnemyFormationElevation.Grounded),
            new(EnemyFormationSlotIds.RearLeft, new Vector3(-RearLaneX, 0f, RearRowZ), EnemyFormationElevation.Grounded),
            new(EnemyFormationSlotIds.RearCenter, new Vector3(0f, 0f, RearRowZ), EnemyFormationElevation.Grounded),
            new(EnemyFormationSlotIds.RearRight, new Vector3(RearLaneX, 0f, RearRowZ), EnemyFormationElevation.Grounded),
            new(EnemyFormationSlotIds.AirRearLeft, new Vector3(-RearLaneX, AirborneY, RearRowZ), EnemyFormationElevation.Airborne),
            new(EnemyFormationSlotIds.AirRearRight, new Vector3(RearLaneX, AirborneY, RearRowZ), EnemyFormationElevation.Airborne),
            new(EnemyFormationSlotIds.CenterBoss, new Vector3(0f, 0f, FrontRowZ), EnemyFormationElevation.Grounded)
        };
    }
}

public enum EnemyFormationElevation
{
    Grounded,
    Airborne
}

[Serializable]
public sealed class EnemyFormationSlot
{
    [SerializeField] string slotId;
    [SerializeField] Vector3 worldPosition;
    [SerializeField] EnemyFormationElevation elevation;

    public string SlotId => slotId;
    public Vector3 WorldPosition => worldPosition;
    public EnemyFormationElevation Elevation => elevation;
    public bool IsAirborne => elevation == EnemyFormationElevation.Airborne;

    public EnemyFormationSlot(string stableSlotId, Vector3 position, EnemyFormationElevation slotElevation)
    {
        slotId = stableSlotId;
        worldPosition = position;
        elevation = slotElevation;
    }

    public void Configure(string stableSlotId, Vector3 position, EnemyFormationElevation slotElevation)
    {
        slotId = stableSlotId;
        worldPosition = position;
        elevation = slotElevation;
    }
}

[CreateAssetMenu(menuName = "Mistport/Enemy Formation Profile", fileName = "EnemyFormationProfile")]
public sealed class EnemyFormationProfile : ScriptableObject
{
    [SerializeField] float referenceWorldHeight = 2.88f;
    [SerializeField] List<EnemyFormationSlot> slots = new();

    public float ReferenceWorldHeight => referenceWorldHeight;
    public IReadOnlyList<EnemyFormationSlot> Slots =>
        (IReadOnlyList<EnemyFormationSlot>)slots ?? Array.Empty<EnemyFormationSlot>();

    public bool TryGetSlot(string slotId, out EnemyFormationSlot slot)
    {
        if (slots == null)
        {
            slot = null;
            return false;
        }
        for (var i = 0; i < slots.Count; i++)
        {
            var candidate = slots[i];
            if (candidate != null && string.Equals(candidate.SlotId, slotId, StringComparison.Ordinal))
            {
                slot = candidate;
                return true;
            }
        }

        slot = null;
        return false;
    }

    public void Configure(float normalizedReferenceHeight, IEnumerable<EnemyFormationSlot> formationSlots)
    {
        referenceWorldHeight = normalizedReferenceHeight;
        slots = formationSlots == null
            ? new List<EnemyFormationSlot>()
            : new List<EnemyFormationSlot>(formationSlots);
    }

    public void Validate(List<string> errors)
    {
        if (!EnemyVisualProfile.IsFinite(referenceWorldHeight) || referenceWorldHeight <= 0f)
            errors.Add($"{name}: reference world height must be finite and greater than zero.");

        if (slots == null)
        {
            errors.Add($"{name}: formation slot collection is missing.");
            return;
        }

        var ids = new HashSet<string>(StringComparer.Ordinal);
        for (var i = 0; i < slots.Count; i++)
        {
            var slot = slots[i];
            if (slot == null)
            {
                errors.Add($"{name}: formation slot index {i} is null.");
                continue;
            }

            if (string.IsNullOrWhiteSpace(slot.SlotId))
                errors.Add($"{name}: formation slot index {i} has an empty ID.");
            else if (!ids.Add(slot.SlotId))
                errors.Add($"{name}: duplicate formation slot ID '{slot.SlotId}'.");

            var position = slot.WorldPosition;
            if (!EnemyVisualProfile.IsFinite(position.x)
                || !EnemyVisualProfile.IsFinite(position.y)
                || !EnemyVisualProfile.IsFinite(position.z))
                errors.Add($"{name}: slot '{slot.SlotId}' contains a non-finite position.");
            if (slot.IsAirborne && position.y <= 0f)
                errors.Add($"{name}: airborne slot '{slot.SlotId}' must have a positive Y position.");
        }

        ValidateStrictRow(
            errors,
            "front",
            EnemyFormationSlotIds.FrontLeft,
            EnemyFormationSlotIds.FrontCenter,
            EnemyFormationSlotIds.FrontRight);
        ValidateStrictRow(
            errors,
            "rear",
            EnemyFormationSlotIds.RearLeft,
            EnemyFormationSlotIds.RearCenter,
            EnemyFormationSlotIds.RearRight,
            EnemyFormationSlotIds.AirRearLeft,
            EnemyFormationSlotIds.AirRearRight);
    }

    void ValidateStrictRow(List<string> errors, string rowName, params string[] slotIds)
    {
        float? rowDepth = null;
        for (var index = 0; index < slotIds.Length; index++)
        {
            if (!TryGetSlot(slotIds[index], out var slot))
                continue;
            if (rowDepth == null)
            {
                rowDepth = slot.WorldPosition.z;
                continue;
            }
            if (Mathf.Abs(slot.WorldPosition.z - rowDepth.Value) > 0.001f)
                errors.Add($"{name}: {rowName} row slots must share one Z depth.");
        }
    }
}
