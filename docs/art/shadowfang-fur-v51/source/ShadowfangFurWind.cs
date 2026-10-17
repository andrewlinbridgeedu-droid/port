using UnityEngine;

// Isolated review (v49): drives the hair cards' GPU bend (ShadowfangFurCards
// shader). The body never deforms here; only the cards' own vertices move.
// Wind comes in gusts from Direction; the body's own motion adds inertia
// through a damped spring, so the fur trails a lunge, overshoots and settles.
[DefaultExecutionOrder(31999)]
public sealed class ShadowfangFurWind : MonoBehaviour
{
    // Rest distance Hips→Head and the model's length, in Blender units
    // (shadowfang-actions-v49.blend, fur-cards-v49-report.json).
    const float BlenderHipsToHead = 1.6137f, BlenderSize = 3.0003f;
    static readonly int WindId = Shader.PropertyToID("_FurWind"), DragId = Shader.PropertyToID("_FurDrag"),
        AmbientId = Shader.PropertyToID("_FurAmbient"), UnitId = Shader.PropertyToID("_FurWorldUnit");

    public Vector3 Direction = Vector3.right;
    public bool Breeze = true;        // false: no wind and no breeze, for the still comparison
    public float Gust = .45f;         // bend share at the tip during a gust
    public float Ambient = .08f;      // always-on breeze while Breeze is on
    public float DragGain = .3f;      // bend share per (body size / second) of motion
    public int FurMaterialIndex = 1;

    SkinnedMeshRenderer skin;
    MaterialPropertyBlock block;
    Transform chest;
    Vector3 lastChest, drag, dragVelocity;
    bool hasLast;
    float elapsed, size;

    public float CurrentWind { get; private set; }
    public float PeakResponse { get; private set; }
    public bool Finite { get; private set; } = true;
    public float WorldUnit { get; private set; }

    void Awake()
    {
        skin = GetComponentInChildren<SkinnedMeshRenderer>();
        block = new MaterialPropertyBlock();
        Transform hips = null, head = null;
        foreach (var t in GetComponentsInChildren<Transform>())
        {
            if (t.name == "Chest") chest = t;
            if (t.name == "Hips") hips = t;
            if (t.name == "Head") head = t;
        }
        // World size from the skeleton, not the skin bounds (FBX bounds can span the clips).
        WorldUnit = hips && head ? Vector3.Distance(hips.position, head.position) / BlenderHipsToHead : 1;
        size = WorldUnit * BlenderSize;
        Apply(Vector3.zero, Vector3.zero, 0);
    }

    public void ResetTrial()
    {
        elapsed = 0; PeakResponse = 0; Finite = true; CurrentWind = 0;
        drag = dragVelocity = Vector3.zero; hasLast = false;
        Apply(Vector3.zero, Vector3.zero, Breeze ? Ambient : 0);
    }

    void LateUpdate()
    {
        float dt = Mathf.Min(Time.deltaTime, .05f);
        elapsed += dt;
        float gust = !Breeze ? 0 : elapsed < .6f ? 0 : elapsed < 6.2f ? Mathf.SmoothStep(0, 1, (elapsed - .6f) / .45f)
            : Mathf.SmoothStep(1, 0, (elapsed - 6.2f) / .6f);
        CurrentWind = gust;
        float strength = gust * Gust * (.8f + .2f * Mathf.Sin(elapsed * 2.3f));
        // Inertia: the chest's velocity, as a share of the body size per second.
        var target = Vector3.zero;
        if (chest && dt > 0)
        {
            if (hasLast) target = Vector3.ClampMagnitude(-(chest.position - lastChest) / dt / Mathf.Max(size, 1e-4f) * DragGain, .45f);
            lastChest = chest.position; hasLast = true;
        }
        int steps = Mathf.Max(1, Mathf.CeilToInt(dt * 240)); float h = dt / Mathf.Max(steps, 1);
        for (int k = 0; k < steps; k++)
        {
            dragVelocity += (90f * (target - drag) - 9f * dragVelocity) * h;
            drag += dragVelocity * h;
        }
        if (!IsFinite(drag)) { Finite = false; drag = dragVelocity = Vector3.zero; }
        if (!Breeze) drag = dragVelocity = Vector3.zero;
        PeakResponse = Mathf.Max(PeakResponse, strength + drag.magnitude);
        Apply(Direction.normalized * strength, drag, Breeze ? Ambient : 0);
    }

    static bool IsFinite(Vector3 v) => !(float.IsNaN(v.x) || float.IsNaN(v.y) || float.IsNaN(v.z) || float.IsInfinity(v.x) || float.IsInfinity(v.y) || float.IsInfinity(v.z));

    void Apply(Vector3 wind, Vector3 inertia, float ambient)
    {
        if (!skin) return;
        skin.GetPropertyBlock(block, FurMaterialIndex);
        block.SetVector(WindId, wind);
        block.SetVector(DragId, inertia);
        block.SetFloat(AmbientId, ambient);
        block.SetFloat(UnitId, WorldUnit);
        skin.SetPropertyBlock(block, FurMaterialIndex);
    }

    void OnDisable() => Apply(Vector3.zero, Vector3.zero, 0);
}
