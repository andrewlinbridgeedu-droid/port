using System;
using System.Collections.Generic;
using UnityEngine;

/// Presentation only. Called once for confirmed positive damage, never schedules combat.
/// Remove last frame's additive offsets in Update, before animation/idle evaluate;
/// apply after idle in LateUpdate. No actor root movement or Animator clock changes.
[DisallowMultipleComponent, DefaultExecutionOrder(1100)]
public sealed class EnemyImpactFeedback : MonoBehaviour
{
    struct Joint { public Transform bone; public Vector3 axis; public Quaternion before, applied; public bool written; }
    struct Flash { public Renderer renderer; public MaterialPropertyBlock before; }
    readonly List<Joint> joints = new List<Joint>();
    readonly List<Flash> flashes = new List<Flash>();
    EnemyHandle handle;
    Transform actor;
    EarlyEnemyIdlePresence.IdleArchetype kind;
    float started, strength;
    bool playing;
    bool dying;
    GameObject burst;
    Mesh burstMesh;
    Material burstMaterial;
    Transform scaleTarget;
    Vector3 scaleBefore, scaleApplied;
    bool scaleWritten;
    static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
    static readonly int ColorID = Shader.PropertyToID("_Color");
    public int ImpactCount { get; private set; }
    public bool IsPlaying => playing;
    public int PlayCount => ImpactCount;
    public Transform VisibleActor => actor;
    public int MappedJointCount => joints.Count;
    public float LastIntensity => strength;
    public static EnemyImpactFeedback For(EnemyHandle enemy)
    {
        if (enemy == null) return null;
        var result = enemy.GetComponent<EnemyImpactFeedback>();
        if (result == null) result = enemy.gameObject.AddComponent<EnemyImpactFeedback>();
        result.handle = enemy;
        return result;
    }
    public static EnemyImpactFeedback Install(EnemyHandle enemy) => For(enemy);

    public void Play(string skillID, float intensity = 1f)
    {
        Clear();
        if (handle == null || !handle.gameObject.activeInHierarchy) return;
        var presence = handle.GetComponent<EarlyEnemyIdlePresence>();
        actor = presence != null ? presence.VisibleActor : handle.Model;
        if (actor == null || !actor.gameObject.activeInHierarchy) return;
        kind = presence != null ? presence.Archetype : EarlyEnemyIdlePresence.IdleArchetype.Humanoid;
        CacheJoints();
        float weight = skillID == "basic" ? .68f
            : skillID == "fool_skill_07" || skillID == "fool_skill_10" ? 1.4f
            : skillID == "fool_skill_05" || skillID == "fool_skill_08" ? 1.18f
            : skillID == "fool_skill_02" ? .85f : 1.05f;
        strength = Mathf.Clamp(intensity * weight, .35f, 1.5f);
        started = Time.time;
        playing = true;
        dying = false;
        ImpactCount++;
        CreateBurst(skillID ?? "");
    }
    void CacheJoints()
    {
        joints.Clear();
        bool hound = kind == EarlyEnemyIdlePresence.IdleArchetype.Hound;
        bool heavy = kind == EarlyEnemyIdlePresence.IdleArchetype.MechanicalGuard;
        Add(new Vector3(hound ? -11 : heavy ? -5 : -13, 0, 3), "Chest", "Cabinet", "Spine2", "Spine", "UpperBody");
        Add(new Vector3(hound ? 13 : 9, -5, 0), "Head", "head");
        Add(new Vector3(4, 0, 5), "Neck");
        if (!hound)
        {
            Add(new Vector3(0, -4, -9), "UpperArm.L", "LeftUpperArm", "LeftArm");
            Add(new Vector3(0, 4, 9), "UpperArm.R", "RightUpperArm", "RightArm");
        }
        if (kind == EarlyEnemyIdlePresence.IdleArchetype.MemoryLeech)
            for (int i = 0; i < 7; i++) Add(new Vector3(0, (i % 2 == 0 ? 16 : -16), 5), "segment_" + i.ToString("00"));
        scaleTarget = kind == EarlyEnemyIdlePresence.IdleArchetype.FogGhost || kind == EarlyEnemyIdlePresence.IdleArchetype.LivingCore ? actor : null;
    }
    void Add(Vector3 axis, params string[] names)
    {
        var all = actor.GetComponentsInChildren<Transform>(true);
        foreach (var name in names) foreach (var bone in all)
        {
            if (!(bone.name.Equals(name, StringComparison.OrdinalIgnoreCase) || bone.name.EndsWith(":" + name, StringComparison.OrdinalIgnoreCase))) continue;
            if (joints.Exists(j => j.bone == bone)) return;
            joints.Add(new Joint { bone = bone, axis = axis }); return;
        }
    }
    void Update() => RestoreFrame();
    void LateUpdate()
    {
        if (!playing) return;
        if (!dying && (actor == null || !actor.gameObject.activeInHierarchy || handle == null || !handle.gameObject.activeInHierarchy)) { Clear(); return; }
        float elapsed = Time.time - started;
        if (elapsed >= .43f) { Clear(); return; }
        // A fast compression, brief visual hold, then damped recovery; no gameplay stun.
        float pose = elapsed < .045f ? Mathf.SmoothStep(0, 1, elapsed / .045f)
            : elapsed < .105f ? 1f : Mathf.Exp(-(elapsed - .105f) * 11f) * Mathf.Cos((elapsed - .105f) * 16f);
        pose *= strength;
        if (dying) pose = 0;
        for (int i = 0; i < joints.Count; i++)
        {
            var j = joints[i]; if (j.bone == null || dying) continue;
            j.before = j.bone.localRotation; j.applied = j.before * Quaternion.Euler(j.axis * pose);
            j.bone.localRotation = j.applied; j.written = true; joints[i] = j;
        }
        if (scaleTarget != null && !dying)
        {
            scaleBefore = scaleTarget.localScale;
            float amount = kind == EarlyEnemyIdlePresence.IdleArchetype.FogGhost ? .13f : .07f;
            scaleApplied = Vector3.Scale(scaleBefore, new Vector3(1 + amount * pose, 1 - amount * pose, 1 + amount * .4f * pose));
            scaleTarget.localScale = scaleApplied; scaleWritten = true;
        }
        if (!dying && elapsed < .085f) ApplyFlash(1f - elapsed / .085f);
        if (burst != null)
        {
            float t = Mathf.Clamp01(elapsed / .3f);
            burst.transform.localScale = Vector3.one * Mathf.Lerp(.65f, 1.65f, t);
            burstMaterial.SetFloat("_Opacity", Mathf.Pow(1 - t, 2));
        }
    }
    void ApplyFlash(float amount)
    {
        foreach (var r in actor.GetComponentsInChildren<Renderer>(false))
        {
            if (!r.enabled || r is ParticleSystemRenderer || r is LineRenderer) continue;
            var material = r.sharedMaterial; if (material == null) continue;
            var before = new MaterialPropertyBlock(); r.GetPropertyBlock(before);
            var block = new MaterialPropertyBlock(); r.GetPropertyBlock(block);
            foreach (int id in new[] { BaseColor, ColorID })
            {
                if (!material.HasProperty(id)) continue;
                Color old = before.HasColor(id) ? before.GetColor(id) : material.GetColor(id);
                Color bright = Color.Lerp(old, new Color(1.7f, 1.28f, .9f, old.a), .7f * amount);
                bright.a = old.a; block.SetColor(id, bright);
            }
            r.SetPropertyBlock(block); flashes.Add(new Flash { renderer = r, before = before });
        }
    }
    void RestoreFrame()
    {
        for (int i = 0; i < joints.Count; i++)
        {
            var j = joints[i];
            if (j.written && j.bone != null && Quaternion.Angle(j.bone.localRotation, j.applied) < .001f) j.bone.localRotation = j.before;
            j.written = false; joints[i] = j;
        }
        if (scaleWritten && scaleTarget != null && (scaleTarget.localScale - scaleApplied).sqrMagnitude < .0000001f) scaleTarget.localScale = scaleBefore;
        scaleWritten = false;
        foreach (var f in flashes) if (f.renderer != null) f.renderer.SetPropertyBlock(f.before);
        flashes.Clear();
    }
    void CreateBurst(string skill)
    {
        var shader = Resources.Load<Shader>("Shaders/EnemyContactImpact");
        if (shader == null) return;
        Bounds bounds = new Bounds(actor.position, Vector3.zero); bool found = false;
        foreach (var r in actor.GetComponentsInChildren<Renderer>(false))
        { if (!r.enabled || r is ParticleSystemRenderer || r is LineRenderer) continue; if (!found) { bounds = r.bounds; found = true; } else bounds.Encapsulate(r.bounds); }
        if (!found) return;
        float radius = Mathf.Clamp(bounds.size.y * .19f, .12f, .6f);
        var camera = Camera.main;
        Vector3 towardCamera = camera != null ? (camera.transform.position - bounds.center).normalized : Vector3.back;
        burst = new GameObject("Confirmed enemy contact");
        burst.transform.position = bounds.center + towardCamera * Mathf.Min(bounds.extents.magnitude * .45f, .4f);
        burst.transform.rotation = camera != null ? camera.transform.rotation : Quaternion.identity;
        burstMaterial = new Material(shader); burstMaterial.SetFloat("_Opacity", 1);
        burst.AddComponent<MeshRenderer>().sharedMaterial = burstMaterial;
        var vertices = new List<Vector3>(); var colors = new List<Color>(); var triangles = new List<int>();
        Color edge = skill == "fool_skill_01" ? new Color(1.5f, .55f, 2f, 1) : new Color(1.7f, .83f, .27f, 1);
        // Compact pointed core and unequal radial slivers, never a screen-covering disk.
        for (int i = 0; i < 12; i++)
        {
            float angle = i * Mathf.PI * 2 / 12 + ImpactCount * .71f;
            Vector3 direction = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0);
            Vector3 side = new Vector3(-direction.y, direction.x, 0);
            float length = radius * (i % 3 == 0 ? 1.45f : .75f);
            int start = vertices.Count;
            vertices.Add(direction * radius * .12f - side * radius * .045f);
            vertices.Add(direction * length);
            vertices.Add(direction * radius * .12f + side * radius * .045f);
            colors.Add(new Color(2.6f, 2.1f, 1.6f, 1)); colors.Add(new Color(edge.r, edge.g, edge.b, 0)); colors.Add(edge);
            triangles.Add(start); triangles.Add(start + 1); triangles.Add(start + 2);
        }
        burstMesh = new Mesh { name = "Enemy impact slivers" }; burstMesh.SetVertices(vertices); burstMesh.SetColors(colors); burstMesh.SetTriangles(triangles, 0); burstMesh.RecalculateBounds();
        burst.AddComponent<MeshFilter>().sharedMesh = burstMesh;
    }
    /// Stop pose/flash before death fade; keep the already-confirmed contact tail.
    public void BeginDeath()
    {
        RestoreFrame(); dying = true;
    }
    public void Clear()
    {
        RestoreFrame(); playing = false; dying = false;
        if (burst != null) { burst.SetActive(false); Destroy(burst); }
        if (burstMesh != null) Destroy(burstMesh);
        if (burstMaterial != null) Destroy(burstMaterial);
        burst = null; burstMesh = null; burstMaterial = null;
    }
    void OnDisable() => Clear();
    void OnDestroy() => Clear();
}
