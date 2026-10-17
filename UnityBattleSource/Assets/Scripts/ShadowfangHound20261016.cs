using UnityEngine;

// The early hound's body (2026-10-16, user on the v51 review: 已经很好了 … 按这个接进游戏).
// Shadowfang: the Meshy hound rebuilt in Blender with alpha-textured hair cards (875 cards,
// head cap and tail, the body's own charcoal), its own skin and fur materials, and the
// authored clips through an override of the hound controller (CombatTempoPresentation).
//
// The fur bends on the GPU (ShadowfangFurCards shader); this component only feeds it: a
// constant light breeze, an occasional gust, and the body's inertia through a damped spring
// so the fur trails a lunge, overshoots and settles. The body mesh itself never deforms.
// It also gives the breath its source: between the jaws, in the head's own space.
[DefaultExecutionOrder(31999)]
public sealed class ShadowfangHound20261016 : MonoBehaviour
{
    public const string ModelPath = "CombatTempo/Shadowfang/Shadowfang";
    public const string ControllerPath = "CombatTempo/Shadowfang/Shadowfang";
    const string BodyMaterialPath = "CombatTempo/Shadowfang/ShadowfangBody";
    const string FurMaterialPath = "CombatTempo/Shadowfang/ShadowfangFur";
    // Rest distance Hips→Head and the model's length, in Blender units (fur-cards-v51-report.json).
    const float BlenderHipsToHead = 1.6137f, BlenderSize = 3.0f;
    const int FurMaterialIndex = 1;
    static readonly int WindId = Shader.PropertyToID("_FurWind"), DragId = Shader.PropertyToID("_FurDrag"),
        AmbientId = Shader.PropertyToID("_FurAmbient"), UnitId = Shader.PropertyToID("_FurWorldUnit");

    public float Breeze = .08f;     // always on, bend share at the tip
    public float Gust = .3f;        // an occasional gust, bend share at the tip
    public float GustEvery = 8.5f;  // seconds between gust starts
    public float DragGain = .3f;    // bend share per (body size / second) of motion

    SkinnedMeshRenderer skin;
    MaterialPropertyBlock block;
    Transform chest, head;
    Vector3 noseLocal, lastChest, drag, dragVelocity, windDirection = Vector3.right;
    bool hasLast;
    float age, size, phase;

    public float WorldUnit { get; private set; } = 1;
    /// Between the jaws; follows the head as it lifts and sweeps.
    public Vector3 Mouth => head ? head.TransformPoint(noseLocal) : transform.position;

    public static ShadowfangHound20261016 Of(EnemyHandle handle) =>
        handle && handle.Model ? handle.Model.GetComponent<ShadowfangHound20261016>() : null;

    /// Dresses a freshly placed (already scaled and aligned) Shadowfang model.
    public static ShadowfangHound20261016 Install(GameObject model)
    {
        var body = Resources.Load<Material>(BodyMaterialPath);
        var fur = Resources.Load<Material>(FurMaterialPath);
        if (!body || !fur) { Debug.LogError("SHADOWFANG_MATERIAL_MISSING"); return null; }
        foreach (var skin in model.GetComponentsInChildren<SkinnedMeshRenderer>()) {
            var slots = new Material[skin.sharedMesh ? skin.sharedMesh.subMeshCount : 1];
            for (int i = 0; i < slots.Length; i++) slots[i] = i == FurMaterialIndex ? fur : body;
            skin.sharedMaterials = slots;
            // Bounds from the clips, not recomputed from the skin every frame (2026-10-17, iPhone 13).
            skin.updateWhenOffscreen = false;
        }
        return model.GetComponent<ShadowfangHound20261016>() ?? model.AddComponent<ShadowfangHound20261016>();
    }

    void Awake()
    {
        skin = GetComponentInChildren<SkinnedMeshRenderer>();
        block = new MaterialPropertyBlock();
        Transform hips = null, neck = null;
        foreach (var t in GetComponentsInChildren<Transform>()) {
            if (t.name == "Chest") chest = t;
            else if (t.name == "Hips") hips = t;
            else if (t.name == "Neck") neck = t;
            else if (t.name == "Head") head = t;
        }
        // World size from the skeleton, not the skin bounds (FBX bounds can span the clips).
        WorldUnit = hips && head ? Vector3.Distance(hips.position, head.position) / BlenderHipsToHead : 1;
        size = WorldUnit * BlenderSize;
        if (head && neck) {
            var forward = (head.position - neck.position).normalized;
            noseLocal = head.InverseTransformPoint(head.position + forward * .36f * WorldUnit - Vector3.up * .18f * WorldUnit);
        }
        // Across the screen reads best: the camera's right, flattened.
        var cam = Camera.main;
        if (cam) { windDirection = cam.transform.right; windDirection.y = 0; windDirection.Normalize(); }
        // A fixed offset, not UnityEngine.Random: presentation must not consume the battle's random stream.
        phase = GustEvery * .6f;
        Apply(Vector3.zero, Vector3.zero);
    }

    void LateUpdate()
    {
        float dt = Mathf.Min(Time.deltaTime, .05f);
        age += dt;
        // Gusts: rise over half a second, blow for two and a half, die away over a second.
        float g = Mathf.Repeat(age + phase, GustEvery);
        float gust = g < .5f ? Mathf.SmoothStep(0, 1, g / .5f) : g < 3f ? 1 : g < 4f ? Mathf.SmoothStep(1, 0, g - 3f) : 0;
        float strength = gust * Gust * (.8f + .2f * Mathf.Sin(age * 2.3f));
        var target = Vector3.zero;
        if (chest && dt > 0) {
            if (hasLast) target = Vector3.ClampMagnitude(-(chest.position - lastChest) / dt / Mathf.Max(size, 1e-4f) * DragGain, .45f);
            lastChest = chest.position; hasLast = true;
        }
        int steps = Mathf.Max(1, Mathf.CeilToInt(dt * 240)); float h = dt / steps;
        for (int k = 0; k < steps; k++) {
            dragVelocity += (90f * (target - drag) - 9f * dragVelocity) * h;
            drag += dragVelocity * h;
        }
        if (float.IsNaN(drag.x) || float.IsNaN(drag.y) || float.IsNaN(drag.z)) drag = dragVelocity = Vector3.zero;
        Apply(windDirection * strength, drag);
    }

    void Apply(Vector3 wind, Vector3 inertia)
    {
        if (!skin) return;
        skin.GetPropertyBlock(block, FurMaterialIndex);
        block.SetVector(WindId, wind);
        block.SetVector(DragId, inertia);
        block.SetFloat(AmbientId, Breeze);
        block.SetFloat(UnitId, WorldUnit);
        skin.SetPropertyBlock(block, FurMaterialIndex);
    }
}
