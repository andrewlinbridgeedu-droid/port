using System;
using System.Collections;
using UnityEngine;

/// Owns one actor's animation and spell lifetime; concurrent enemies never cancel each other.
public sealed class SignatureEnemyPresentation : MonoBehaviour
{
    public EnemySignatureSpellVFX.Kind kind;
    Animator animator;
    EnemySignatureSpellVFX effects;
    Transform castBone;
    int generation;
    int nextVariant;
    bool casting;
    MainlineBodyRound2 body;
    public bool IsCasting => casting;
    public bool CalibrationSuppressed { get; set; }
    public int Epoch => generation;
    public int LastVariant { get; private set; }
    public Vector3 SourceAnchor => castBone ? castBone.position : transform.position + Vector3.up;

    void EnsureReady()
    {
        if (!animator) animator = GetComponentInChildren<Animator>(true);
        if (!effects) effects = gameObject.AddComponent<EnemySignatureSpellVFX>();
        if (!castBone)
        {
            var wanted = kind == EnemySignatureSpellVFX.Kind.Hound ? "Jaw"
                : kind == EnemySignatureSpellVFX.Kind.Matriarch ? "Hand.R" : "Cabinet";
            foreach (var t in GetComponentsInChildren<Transform>(true))
                if (t.name == wanted) { castBone = t; break; }
        }
    }
    void OnEnable() {
        nextVariant = 0; EnsureReady(); PlayState("Meshy · Idle");
        if (Application.isPlaying) CalibrateRestPose();
    }
    // Imported FBX animation bounds can be expressed in an axis-transformed root
    // frame. Measure the actual skin matrices instead of fitting that box.
    // Bone matrices already contain scale: BakeMesh + TransformPoint would apply it twice.
    public void CalibrateRestPose()
    {
        if (CalibrationSuppressed) return;
        EnsureReady();
        var handle = GetComponent<EnemyHandle>();
        if (!handle || !handle.Profile || !handle.Formation || !handle.VisualRoot) return;
        if (animator) { animator.Play("Meshy · Idle",0,0); animator.Update(0); }
        var wanted = handle.Formation.ReferenceWorldHeight * handle.Profile.ReferenceHeightRatio;
        if (!TryBakedBounds(handle, out var before) || before.size.y < .0001f) return;
        handle.VisualRoot.localScale *= wanted / before.size.y;
        if (!TryBakedBounds(handle, out var fitted)) return;
        handle.VisualRoot.localPosition += Vector3.up * -fitted.min.y;
        var health = handle.HealthBarAnchor.localPosition; health.y = wanted + .18f; handle.HealthBarAnchor.localPosition = health;
        Debug.Log($"SIGNATURE_CALIBRATE {handle.ProfileEnemyId} before={before.size.y:F3} target={wanted:F3} scale={handle.VisualRoot.localScale} floor={fitted.min.y:F3}");
    }
    static bool TryBakedBounds(EnemyHandle handle, out Bounds bounds)
    {
        bounds = default; bool found = false;
        foreach (var skin in handle.Model.GetComponentsInChildren<SkinnedMeshRenderer>(true)) {
            var mesh = skin.sharedMesh;
            if (!mesh) continue;
            var bones = skin.bones; var bind = mesh.bindposes;
            var vertices = mesh.vertices; var weights = mesh.boneWeights;
            var matrices = new Matrix4x4[bones.Length];
            for (int b = 0; b < bones.Length; b++)
                matrices[b] = handle.MotionRoot.worldToLocalMatrix * bones[b].localToWorldMatrix * bind[b];
            for (int i = 0; i < vertices.Length; i++) {
                var w = weights[i]; var v = vertices[i];
                var point = matrices[w.boneIndex0].MultiplyPoint3x4(v) * w.weight0
                    + matrices[w.boneIndex1].MultiplyPoint3x4(v) * w.weight1
                    + matrices[w.boneIndex2].MultiplyPoint3x4(v) * w.weight2
                    + matrices[w.boneIndex3].MultiplyPoint3x4(v) * w.weight3;
                if (!found) { bounds = new Bounds(point,Vector3.zero); found = true; } else bounds.Encapsulate(point);
            }
        }
        return found;
    }
    void OnDisable() => Cancel();
    public void Cancel()
    {
        generation++; casting = false;
        if(body)body.Stop();
        if (effects) effects.CancelAll();
        if (animator && gameObject.activeInHierarchy) PlayState("Meshy · Idle");
    }
    public void PlayState(string state)
    {
        EnsureReady();
        if (animator && animator.HasState(0, Animator.StringToHash(state)))
            animator.CrossFadeInFixedTime(state, .09f, 0);
    }
    public IEnumerator Cast(Func<Vector3> target, Action release, Action contact, int forcedVariant = -1, Action completed = null)
    {
        Cancel(); EnsureReady();
        var stamp = generation;
        var variant = forcedVariant >= 0 ? forcedVariant % 2 : nextVariant++ % 2;
        LastVariant = variant; casting = true;
        animator?.ResetTrigger("Hit"); animator?.ResetTrigger("Attack");
        PlayState(variant == 0 ? "Charge" : "Charge2");
        body=MainlineBodyRound2.Get(gameObject);
        body.Begin(kind==EnemySignatureSpellVFX.Kind.Hound?MainlineBodyRound2.Pose.Hound:kind==EnemySignatureSpellVFX.Kind.Matriarch?MainlineBodyRound2.Pose.Silk:MainlineBodyRound2.Pose.Archivist,variant!=0,1.4f,2.05f,2.85f);
        Debug.Log($"SIGNATURE_CAST kind={kind} variant={variant} actor={name}");
        var sequence=effects.Play(kind, () => SourceAnchor, target,
            () => { if (stamp != generation || !isActiveAndEnabled) return;
                PlayState(variant == 0 ? "Cast" : "Cast2"); release?.Invoke(); },
            () => { if (stamp == generation && isActiveAndEnabled) contact?.Invoke(); }, variant);
        float elapsed=0;
        try {while(sequence.MoveNext()){if(stamp!=generation)yield break;body.Sample(elapsed);elapsed+=Time.deltaTime;yield return sequence.Current;}}
        finally{(sequence as IDisposable)?.Dispose();if(stamp==generation&&body)body.Stop();}
        if (stamp == generation && isActiveAndEnabled) { casting = false; PlayState("Meshy · Idle"); completed?.Invoke(); }
    }
}
