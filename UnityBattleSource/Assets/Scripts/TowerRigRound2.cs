using System.Collections.Generic;
using UnityEngine;

// Per-instance, additive skeleton poses. Reset before Animator evaluation and
// capture its fresh result before applying the next pose. Never touches actor roots.
public sealed class TowerRigRound2
{
    sealed class Joint
    {
        public Transform transform;
        public Quaternion rotation, writtenRotation;
        public Vector3 position, scale, writtenPosition, writtenScale;
        public bool rotated, shifted, scaled;
    }
    readonly Dictionary<string, Joint> joints = new Dictionary<string, Joint>();
    bool applied;

    public TowerRigRound2(Transform root, GameObject poseOwner)
    {
        var restore = poseOwner.AddComponent<TowerPoseRestoreRound2>();
        restore.rig = this;
        if (!root) return;
        foreach (var t in root.GetComponentsInChildren<Transform>(true))
            if (t.name == "Pelvis" || t.name == "Chest" || t.name == "Neck" || t.name == "Head" ||
                t.name.StartsWith("UpperArm.") || t.name.StartsWith("Forearm.") || t.name.StartsWith("Hand.") ||
                t.name.StartsWith("Thigh.") || t.name.StartsWith("Shin.") || t.name.StartsWith("Foot.") ||
                t.name.StartsWith("Tail") || t.name.StartsWith("Sac.") || t.name.StartsWith("Crown."))
                joints[t.name] = new Joint { transform = t, rotation = t.localRotation, position = t.localPosition, scale = t.localScale };
    }

    public void Capture()
    {
        foreach (var j in joints.Values) if (j.transform)
        {
            j.rotation = j.transform.localRotation;
            j.position = j.transform.localPosition;
            j.scale = j.transform.localScale;
            j.rotated = j.shifted = j.scaled = false;
        }
        applied = true;
    }

    public void Reset()
    {
        if (!applied) return;
        foreach (var j in joints.Values) if (j.transform)
        {
            // A death/animation transition may have replaced our pose already.
            // Never restore over a value owned by a later writer.
            if (j.rotated && Quaternion.Angle(j.transform.localRotation, j.writtenRotation) < .01f)
                j.transform.localRotation = j.rotation;
            if (j.shifted && (j.transform.localPosition - j.writtenPosition).sqrMagnitude < .0000001f)
                j.transform.localPosition = j.position;
            if (j.scaled && (j.transform.localScale - j.writtenScale).sqrMagnitude < .0000001f)
                j.transform.localScale = j.scale;
            j.rotated = j.shifted = j.scaled = false;
        }
        applied = false;
    }

    public void Rotate(string name, Vector3 angles)
    {
        if (joints.TryGetValue(name, out var j) && j.transform)
        {
            j.writtenRotation = j.rotation * Quaternion.Euler(angles);
            j.transform.localRotation = j.writtenRotation; j.rotated = true;
        }
    }
    public void Scale(string name, Vector3 multiplier)
    {
        if (joints.TryGetValue(name, out var j) && j.transform)
        {
            j.writtenScale = Vector3.Scale(j.scale, multiplier);
            j.transform.localScale = j.writtenScale; j.scaled = true;
        }
    }
    public void ShiftWorld(string name, Vector3 displacement)
    {
        if (joints.TryGetValue(name, out var j) && j.transform)
        {
            j.writtenPosition = j.position + (j.transform.parent ? j.transform.parent.InverseTransformVector(displacement) : displacement);
            j.transform.localPosition = j.writtenPosition; j.shifted = true;
        }
    }
    public Transform Find(string name) => joints.TryGetValue(name, out var j) ? j.transform : null;
    public Vector3 Point(string name, Vector3 fallback) { var t = Find(name); return t ? t.position : fallback; }
    public static float Ease(float value) => Mathf.SmoothStep(0, 1, Mathf.Clamp01(value));
}
