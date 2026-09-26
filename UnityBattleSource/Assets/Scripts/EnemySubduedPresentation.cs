using UnityEngine;

// Native combat has ended this actor's participation, not their life.
// Idle animation and breathing continue; no Death, fade or retreat is played.
[DefaultExecutionOrder(900)]
public sealed class EnemySubduedPresentation : MonoBehaviour
{
    public bool IsSubdued { get; private set; }
    Animator[] animators;
    float[] speeds;
    Transform head;
    Quaternion before, applied;
    bool hasOffset;
    float entered;

    public void Begin()
    {
        if (IsSubdued) return;
        IsSubdued = true;
        entered = Time.time;
        animators = GetComponentsInChildren<Animator>();
        speeds = new float[animators.Length];
        for (int i = 0; i < animators.Length; i++) { speeds[i] = animators[i].speed; animators[i].speed = .65f; }
        foreach (var t in GetComponentsInChildren<Transform>())
            if (t.name.ToLowerInvariant().Contains("head")) { head = t; break; }
    }
    void UndoOffset()
    {
        if (hasOffset && head && Quaternion.Angle(head.localRotation, applied) < .01f) head.localRotation = before;
        hasOffset = false;
    }
    public void Clear()
    {
        UndoOffset();
        if (animators != null) for (int i = 0; i < animators.Length; i++) if (animators[i]) animators[i].speed = speeds[i];
        animators = null; speeds = null; IsSubdued = false;
    }
    void Update() { UndoOffset(); }
    void LateUpdate()
    {
        if (!IsSubdued || !head) return;
        before = head.localRotation;
        float settle = Mathf.SmoothStep(0, 1, (Time.time - entered) / .65f);
        applied = before * Quaternion.Euler((9 + .7f * Mathf.Sin(Time.time * 1.3f)) * settle, 0, 0);
        head.localRotation = applied; hasOffset = true;
    }
    void OnDisable() { Clear(); }
}
