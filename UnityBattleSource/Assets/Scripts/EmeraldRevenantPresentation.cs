using System.Collections.Generic;
using UnityEngine;

/// Plays the Blender-baked idle, charge and cast clips on the Q5 actor.
public sealed class EmeraldRevenantPresentation : MonoBehaviour
{
    EnemyHandle handle;
    SignatureEnemyPresentation originalSignature;
    GameObject actor;
    Animator animator;
    readonly List<Renderer> hidden = new List<Renderer>();
    readonly List<bool> oldVisibility = new List<bool>();
    Vector3 oldHealthAnchor;
    Vector3 castLocalOffset;
    Transform chestCore;
    bool charging;
    bool installed;
    MainlineBodyRound2 body;
    float bodyAge;
    bool bodyCasting;
    Bounds localVisibleBounds;
    public Bounds VisibleWorldBounds { get {
        if (!actor) return new Bounds(transform.position, Vector3.one);
        var scale=actor.transform.lossyScale;
        return new Bounds(actor.transform.TransformPoint(localVisibleBounds.center),
            Vector3.Scale(localVisibleBounds.size,new Vector3(Mathf.Abs(scale.x),Mathf.Abs(scale.y),Mathf.Abs(scale.z))));
    } }
    public bool IsInstalled => installed && actor != null;
    public Vector3 CastAnchor => chestCore != null ? chestCore.position : actor != null ? actor.transform.TransformPoint(castLocalOffset) : Vector3.zero;

    public void Install(EnemyHandle enemyHandle)
    {
        Restore();
        handle = enemyHandle;
        if (handle == null || handle.EnemyRoot == null) return;
        var prefab = Resources.Load<GameObject>("Enemies/EmeraldRevenant/EmeraldRevenantActor");
        if (prefab == null) { Debug.LogError("Missing Emerald Revenant actor prefab."); return; }
        // The new hound's imported animated bounds are larger than its visible
        // skin. Use the formation contract, never that renderer box, for Q5.
        var motionScale = Mathf.Max(.001f, Mathf.Abs(handle.MotionRoot.lossyScale.y));
        var targetHeight = handle.Formation.ReferenceWorldHeight * (.82f * 1.55f) * motionScale;
        var floor = handle.MotionRoot.position;
        oldHealthAnchor = handle.HealthBarAnchor.localPosition;
        originalSignature = handle.GetComponent<SignatureEnemyPresentation>();
        if (originalSignature) originalSignature.CalibrationSuppressed = true;
        foreach (var renderer in handle.VisualRoot.GetComponentsInChildren<Renderer>(true))
        {
            if (!(renderer is MeshRenderer) && !(renderer is SkinnedMeshRenderer)) continue;
            hidden.Add(renderer); oldVisibility.Add(renderer.enabled); renderer.enabled = false;
        }
        actor = Instantiate(prefab, handle.VisualRoot);
        actor.transform.rotation = Quaternion.Euler(0, 180, 0);
        animator = actor.GetComponentInChildren<Animator>(true);
        foreach (var bone in actor.GetComponentsInChildren<Transform>(true))
            if (bone.name == "ChestCore") { chestCore = bone; break; }
        if (animator != null) { animator.Play("EmeraldIdle", 0, 0); animator.Update(0); animator.enabled = true; animator.applyRootMotion = false; }
        var bounds = BoundsOf(actor.transform);
        actor.transform.localScale *= targetHeight / Mathf.Max(.01f, bounds.size.y);
        bounds = BoundsOf(actor.transform);
        actor.transform.position += new Vector3(floor.x - bounds.center.x,
            floor.y - bounds.min.y, floor.z - bounds.center.z);
        var visibleBounds = BoundsOf(actor.transform);
        castLocalOffset = actor.transform.InverseTransformPoint(visibleBounds.center);
        var visibleScale=actor.transform.lossyScale;
        localVisibleBounds=new Bounds(castLocalOffset,new Vector3(visibleBounds.size.x/Mathf.Max(.001f,Mathf.Abs(visibleScale.x)),visibleBounds.size.y/Mathf.Max(.001f,Mathf.Abs(visibleScale.y)),visibleBounds.size.z/Mathf.Max(.001f,Mathf.Abs(visibleScale.z))));
        var health = oldHealthAnchor; health.y = targetHeight / motionScale + .18f;
        handle.HealthBarAnchor.localPosition = health;
        installed = true;
        Debug.Log($"EMERALD_INSTALLED height={targetHeight:F3} id={handle.BattleEnemyId}");
    }

    public void Charge() {
        charging = true;
        bodyAge=0;bodyCasting=false;
        if(actor){body=MainlineBodyRound2.Get(actor);body.Begin(MainlineBodyRound2.Pose.Emerald,false,1.4f,2.18f,2.8f);}
        if (animator != null) { animator.speed = 1; animator.CrossFadeInFixedTime("EmeraldCharge", .12f); }
    }
    public void Cast() {
        charging = false;
        bodyAge=1.4f;bodyCasting=true;
        if (animator != null) { animator.speed = 1; animator.CrossFadeInFixedTime("EmeraldCast", .08f); }
    }
    public void Release() {
        charging=false;bodyCasting=false;if(body)body.Stop();
        // A cancelled prolonged charge must not leave its Animator frozen.
        if(animator&&animator.speed==0){animator.speed=1;animator.CrossFadeInFixedTime("EmeraldIdle",.12f);}
    }
    void Update(){if(body&&(charging||bodyCasting)){bodyAge+=Time.deltaTime;body.Sample(charging?Mathf.Min(bodyAge,1.39f):bodyAge);if(bodyAge>=2.8f&&!charging){body.Stop();bodyCasting=false;}}}
    void LateUpdate()
    {
        if (!IsInstalled) return;
        foreach (var renderer in hidden) if (renderer != null) renderer.enabled = false;
        if (animator == null || animator.IsInTransition(0)) return;
        var state = animator.GetCurrentAnimatorStateInfo(0);
        if (charging && state.IsName("EmeraldCharge") && state.normalizedTime >= .98f) animator.speed = 0;
        if (!charging && state.IsName("EmeraldCast") && state.normalizedTime >= .97f) {
            animator.speed = 1; animator.CrossFadeInFixedTime("EmeraldIdle", .2f);
        }
        // The baked Idle clip loops itself; resetting at .97 would cut off its seam.
    }

    public void Restore()
    {
        Release();
        if (originalSignature) originalSignature.CalibrationSuppressed = false;
        originalSignature = null;
        if (installed && handle && handle.HealthBarAnchor) handle.HealthBarAnchor.localPosition = oldHealthAnchor;
        if (actor != null) Destroy(actor);
        actor = null; animator = null; chestCore = null; installed = false;
        for (var i = 0; i < hidden.Count; i++) if (hidden[i] != null) hidden[i].enabled = oldVisibility[i];
        hidden.Clear(); oldVisibility.Clear();
    }
    // Imported animation bounds include unused sweep space. Measure the visible
    // skin in world space so feet, scale and HUD share the same real geometry.
    static Bounds BoundsOf(Transform root)
    {
        var bounds = new Bounds(root.position, Vector3.one); var found = false;
        foreach (var renderer in root.GetComponentsInChildren<Renderer>(true)) {
            if (!renderer.enabled) continue;
            if (renderer is SkinnedMeshRenderer skin && skin.sharedMesh != null) {
                var mesh = skin.sharedMesh; var bones = skin.bones; var bind = mesh.bindposes;
                var vertices = mesh.vertices; var weights = mesh.boneWeights;
                if (bones.Length > 0 && bones.Length == bind.Length && weights.Length == vertices.Length) {
                    var matrices = new Matrix4x4[bones.Length];
                    for (int b = 0; b < bones.Length; b++) matrices[b] = bones[b].localToWorldMatrix * bind[b];
                    for (int i = 0; i < vertices.Length; i++) {
                        var w = weights[i]; var v = vertices[i];
                        var point = matrices[w.boneIndex0].MultiplyPoint3x4(v) * w.weight0
                            + matrices[w.boneIndex1].MultiplyPoint3x4(v) * w.weight1
                            + matrices[w.boneIndex2].MultiplyPoint3x4(v) * w.weight2
                            + matrices[w.boneIndex3].MultiplyPoint3x4(v) * w.weight3;
                        if (!found) { bounds = new Bounds(point, Vector3.zero); found = true; }
                        else bounds.Encapsulate(point);
                    }
                    continue;
                }
            }
            if (!(renderer is MeshRenderer) && !(renderer is SkinnedMeshRenderer)) continue;
            if (!found) { bounds = renderer.bounds; found = true; } else bounds.Encapsulate(renderer.bounds);
        }
        return bounds;
    }
    void OnDestroy() { Restore(); }
    void OnDisable(){Release();}
}
