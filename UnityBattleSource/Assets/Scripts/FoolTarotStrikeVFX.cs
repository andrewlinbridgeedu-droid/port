using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// Skill 01's camera overlay is a dedicated offset-rift presentation. It does
/// not share the basic TarotNova material: the skill needs a readable split
/// trajectory, crossed cut and lingering impact fissure of its own.
[DefaultExecutionOrder(950)]
public sealed class FoolTarotStrikeVFX : MonoBehaviour
{
    public const float ContactTime = .6192f;
    public const float Duration = 1.65f * (ContactTime / .58f);
    const float BeatScale = .58f / ContactTime;
    static readonly int Beat = Shader.PropertyToID("_Beat");
    static readonly int Source = Shader.PropertyToID("_Source");
    static readonly int Target = Shader.PropertyToID("_Target");
    static readonly int Aspect = Shader.PropertyToID("_Aspect");
    static readonly int RiftSeed = Shader.PropertyToID("_RiftSeed");
    static readonly int InstanceWeight = Shader.PropertyToID("_InstanceWeight");
    // Per-target copies each add a full-screen rift. Share exposure between the
    // live copies (as the declaration volume does) so two hits keep separate
    // cores instead of summing into one white field.
    static int liveRifts;
    bool registeredRift;
    readonly List<UnityEngine.Object> owned = new List<UnityEngine.Object>();
    GameObject root, surface;
    Material overlay;
    Camera view;
    int generation;
    sealed class PosedEcho { public SkinnedMeshRenderer source; public Mesh mesh; public Transform node; public int copy; }
    readonly List<PosedEcho> posedEchoes=new List<PosedEcho>();
    Vector3 echoOrigin;
    float poseAge;

    public void Clear()
    {
        ++generation;
        if (registeredRift) { liveRifts = Mathf.Max(0, liveRifts - 1); registeredRift = false; }
        if (root) { root.SetActive(false); Destroy(root); }
        foreach (var resource in owned) if (resource) Destroy(resource);
        owned.Clear();posedEchoes.Clear(); root = null; surface = null; overlay = null; view = null;
    }
    void OnDisable() { Clear(); }
    void OnDestroy() { Clear(); }

    public IEnumerator Play(Func<Vector3> source, Func<Vector3> target, Action onContact, Func<Vector3> secondary = null, Transform hero = null, Func<bool> targetValid = null)
    {
        Clear(); int run = generation;
        root = new GameObject("Fool tarot strike runtime");
        root.transform.SetParent(transform, false);
        view = Camera.main;
        Vector3 lastSource = source != null ? source() : transform.position;
        Vector3 lastTarget = target != null ? target() : lastSource;
        // Snapshot the cast's routes: later selection/death cannot redirect its copies.
        Vector3 castOrigin = lastSource;
        echoOrigin=castOrigin;poseAge=0;
        Vector3[] destinations = secondary != null
            ? new[] { lastTarget, secondary() } : new[] { lastTarget };
        int laneCount = destinations.Length;
        var shader = Resources.Load<Shader>("Effects/Fool/FoolSidestepRift");
        if (view && shader)
        {
            overlay = new Material(shader) { name = "Fool sidestep rift overlay (owned)" };
            owned.Add(overlay);
            liveRifts++; registeredRift = true;
            surface = new GameObject("Fool sidestep offset-rift overlay");
            surface.transform.SetParent(root.transform, false);
            var quad = new Mesh { name = "Sidestep rift overlay quad (owned)" }; owned.Add(quad);
            quad.vertices = new[] { new Vector3(-.5f,-.5f,0), new Vector3(.5f,-.5f,0), new Vector3(.5f,.5f,0), new Vector3(-.5f,.5f,0) };
            quad.uv = new[] { Vector2.zero, Vector2.right, Vector2.one, Vector2.up };
            quad.triangles = new[] { 0,2,1,0,3,2 }; quad.RecalculateBounds();
            surface.AddComponent<MeshFilter>().sharedMesh = quad;
            surface.AddComponent<MeshRenderer>().sharedMaterial = overlay;
        }
        // Small procedural shards make the offset readable against bright
        // backgrounds. They are accents only; the independent shader owns the
        // trajectory and crossed impact body.
        var shards = new Transform[laneCount * 4];
        var shardShader = Shader.Find("Sprites/Default");
        if (shardShader)
        {
            Mesh mesh = RiftShardMesh(); owned.Add(mesh);
            var shardMaterial = new Material(shardShader) { name = "Sidestep rift shard (owned)", color = new Color(.72f,.40f,.12f,.65f) };
            owned.Add(shardMaterial);
            for (int i = 0; i < shards.Length; i++)
            {
                var shard = new GameObject("Offset rift shard " + i);
                shard.transform.SetParent(root.transform, false);
                shard.AddComponent<MeshFilter>().sharedMesh = mesh;
                shard.AddComponent<MeshRenderer>().sharedMaterial = shardMaterial;
                shard.SetActive(false); shards[i] = shard.transform;
            }
        }
        var echoes = new List<Transform>();
        var echoMats = new List<Material>();
        if (hero && shardShader)
        {
            // One root means one complete silhouette, irrespective of mesh count.
            for (int lane = 0; lane < laneCount; lane++) for (int copy = 0; copy < 2; copy++)
            {
                var clone = new GameObject($"Sidestep hero clone lane {lane} copy {copy}");
                clone.transform.SetParent(root.transform, false);
                clone.transform.position = castOrigin;
                echoes.Add(clone.transform);
                var mat = new Material(shardShader) { color = new Color(.4f,.10f,.7f,0) };
                owned.Add(mat); echoMats.Add(mat);
                foreach (var skin in hero.GetComponentsInChildren<SkinnedMeshRenderer>())
                {
                    if (!skin.enabled || !skin.gameObject.activeInHierarchy) continue;
                    var baked = new Mesh(); skin.BakeMesh(baked,false); owned.Add(baked);
                    var meshObject = new GameObject(skin.name + " silhouette");
                    meshObject.transform.SetParent(clone.transform, false);
                    meshObject.transform.position = skin.transform.position;
                    meshObject.transform.rotation = skin.transform.rotation;
                    meshObject.transform.localScale = skin.transform.lossyScale;
                    meshObject.AddComponent<MeshFilter>().sharedMesh = baked;
                    var mats = new Material[baked.subMeshCount];
                    for (int m = 0; m < mats.Length; m++) mats[m] = mat;
                    meshObject.AddComponent<MeshRenderer>().sharedMaterials = mats;
                    posedEchoes.Add(new PosedEcho{source=skin,mesh=baked,node=meshObject.transform,copy=copy});
                }
            }
        }
        float elapsed = 0; bool contacted = false;
        while (run == generation && root)
        {
            poseAge=elapsed;
            if (targetValid != null && !targetValid()) { Clear(); yield break; }
            if (target != null) destinations[0] = target();
            if (secondary != null) destinations[1] = secondary();
            Vector3 a = castOrigin + Vector3.up * 1.15f;
            Vector3 b = destinations[0] + Vector3.up * 1.05f;
            SampleRift(HeroVisualBeat.Sample(elapsed, ContactTime, .105f), a, b);
            if (overlay) {
                overlay.SetFloat("_HasSecondary", laneCount == 2 ? 1 : 0);
                if (laneCount == 2) overlay.SetVector("_Secondary", view.WorldToViewportPoint(destinations[1]+Vector3.up*1.05f));
            }
            for (int e = 0; e < echoes.Count; e++) {
                int lane = e / 2, copy = e % 2;
                float t = Mathf.Clamp01((elapsed-.08f-copy*.055f)/.48f);
                float alpha = Mathf.Sin(t*Mathf.PI)*.25f;
                echoes[e].position = Vector3.Lerp(castOrigin, destinations[lane], t)
                    + (view ? view.transform.right : Vector3.right) * Mathf.Sin(t*Mathf.PI) * (copy == 0 ? -.16f : .16f);
                echoMats[e].color = new Color(.4f,.10f,.7f,alpha);
            }
            Vector3 right = view ? view.transform.right : Vector3.right;
            Vector3 forward = view ? view.transform.forward : Vector3.forward;
            Quaternion facing = view ? view.transform.rotation : Quaternion.identity;
            for (int i = 0; i < shards.Length; i++) if (shards[i])
            {
                int shardIndex = i % 4;
                Vector3 laneEnd = destinations[i / 4] + Vector3.up * 1.05f;
                float start = .08f + shardIndex * .028f;
                float finish = ContactTime - .026f;
                bool visible = elapsed >= start && elapsed < finish;
                shards[i].gameObject.SetActive(visible);
                if (!visible) continue;
                float t = Mathf.Clamp01((elapsed - start) / (finish - start));
                float side = shardIndex % 2 == 0 ? 1f : -1f;
                Vector3 control = (a+laneEnd)*.5f + Vector3.up * (.28f + .09f*shardIndex) + right * side * (.16f + .06f*shardIndex);
                float inverse = 1-t;
                shards[i].position = inverse*inverse*a + 2*inverse*t*control + t*t*laneEnd
                    + right*side*Mathf.Sin(t*Mathf.PI)*(.075f + .025f*shardIndex) + forward*((shardIndex-1.5f)*.025f);
                shards[i].rotation = facing * Quaternion.Euler(0f, side*(12f + Mathf.Sin(t*Mathf.PI)*24f), side*(28f+t*250f) + shardIndex*19f);
                float taper = Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.12f)) * (1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.8f,1,t)));
                shards[i].localScale = new Vector3(.70f + .08f*shardIndex, 1.08f + .10f*shardIndex, 1f) * taper;
            }
            // Check before the duration exit: a long frame cannot skip contact.
            // Missing visual resources/camera also never suppress this contract.
            if (!contacted && elapsed >= ContactTime)
            {
                contacted = true; onContact?.Invoke();
                if (run != generation) yield break;
            }
            if (elapsed >= Duration) break;
            yield return null;
            if (run != generation) yield break;
            elapsed += Time.deltaTime;
        }
        if (run == generation) Clear();
    }

    void LateUpdate()
    {
        // Read the finished shoulder/hip pose after choreography (order 900),
        // not the restored Animator pose seen by an Update coroutine. Each of
        // the approved two silhouettes settles into a different actual step.
        foreach(var echo in posedEchoes)
        {
            if(!echo.source||!echo.node||poseAge>.16f+echo.copy*.09f)continue;
            echo.source.BakeMesh(echo.mesh,false);
            echo.node.localPosition=echo.source.transform.position-echoOrigin;
            echo.node.localRotation=echo.source.transform.rotation;
            echo.node.localScale=echo.source.transform.lossyScale;
        }
    }

    void SampleRift(float elapsed, Vector3 source, Vector3 target)
    {
        if (!view || !surface || !overlay) return;
        float distance = view.nearClipPlane + .12f;
        float height = view.orthographic ? view.orthographicSize*2 : 2*distance*Mathf.Tan(view.fieldOfView*Mathf.Deg2Rad*.5f);
        // World transform follows the camera but remains owned by the single root.
        surface.transform.position = view.transform.TransformPoint(new Vector3(0,0,distance));
        surface.transform.rotation = view.transform.rotation;
        surface.transform.localScale = new Vector3(height*view.aspect,height,1);
        overlay.SetFloat(Beat, Mathf.Min(elapsed,Duration)*BeatScale);
        overlay.SetFloat(RiftSeed, generation * 1.37f);
        overlay.SetFloat(Aspect, view.aspect);
        overlay.SetFloat(InstanceWeight, 1f / Mathf.Sqrt(Mathf.Max(1, liveRifts)));
        overlay.SetVector(Source, view.WorldToViewportPoint(source));
        overlay.SetVector(Target, view.WorldToViewportPoint(target));
    }

    static Mesh RiftShardMesh()
    {
        var m = new Mesh { name = "Procedural offset rift shard (owned)" };
        const float w=.055f,h=.30f,d=.012f;
        m.vertices = new[]
        {
            new Vector3(-w,-h,-d),new Vector3(w*.35f,-h,-d),new Vector3(w,h*.42f,-d),new Vector3(-w*.35f,h,-d),
            new Vector3(-w,-h,d),new Vector3(w*.35f,-h,d),new Vector3(w,h*.42f,d),new Vector3(-w*.35f,h,d)
        };
        m.triangles = new[] { 0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7 };
        m.RecalculateNormals();m.RecalculateBounds();return m;
    }
}
