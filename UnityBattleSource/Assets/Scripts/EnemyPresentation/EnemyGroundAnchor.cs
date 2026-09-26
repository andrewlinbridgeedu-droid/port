using UnityEngine;

/// Keeps an enemy's ground-selection anchor at the visible feet. Humanoid
/// models use their authored foot bones; non-humanoid models fall back to the
/// renderer footprint. No screen-space or enemy-specific pixel offsets exist.
[DisallowMultipleComponent]
public sealed class EnemyGroundAnchor : MonoBehaviour
{
    [SerializeField] Transform model;
    [SerializeField] Transform targetAnchor;
    [SerializeField] Transform leftFoot;
    [SerializeField] Transform rightFoot;
    [SerializeField] Vector3 leftSoleInFootSpace;
    [SerializeField] Vector3 rightSoleInFootSpace;
    [SerializeField] bool hasCalibratedSoles;
    [SerializeField] float surfaceLift = 0.008f;

    Renderer[] renderers;
    SkinnedMeshRenderer[] skinnedRenderers;

    public void Configure(Transform modelTransform, Transform anchor)
    {
        model = modelTransform;
        targetAnchor = anchor;
        var animator = model != null ? model.GetComponentInChildren<Animator>(true) : null;
        if (animator != null && animator.isHuman)
        {
            leftFoot = animator.GetBoneTransform(HumanBodyBones.LeftFoot);
            rightFoot = animator.GetBoneTransform(HumanBodyBones.RightFoot);
        }
        else
        {
            leftFoot = null;
            rightFoot = null;
        }
        renderers = model != null ? model.GetComponentsInChildren<Renderer>(true) : null;
        skinnedRenderers = model != null
            ? model.GetComponentsInChildren<SkinnedMeshRenderer>(true)
            : null;
        hasCalibratedSoles = TryCalibrateSoles();
        Refresh();
    }

    public void Refresh()
    {
        if (targetAnchor == null || model == null)
            return;

        if (TryGetGroundContact(out var contact))
        {
            contact.y += surfaceLift;
            targetAnchor.position = contact;
        }
    }

    public bool TryGetGroundContact(out Vector3 contact)
    {
        contact = default;
        if (model == null)
            return false;

        if (leftFoot != null && rightFoot != null)
        {
            var leftContact = hasCalibratedSoles
                ? leftFoot.TransformPoint(leftSoleInFootSpace)
                : leftFoot.position;
            var rightContact = hasCalibratedSoles
                ? rightFoot.TransformPoint(rightSoleInFootSpace)
                : rightFoot.position;
            contact = (leftContact + rightContact) * 0.5f;
            contact.y = Mathf.Min(leftContact.y, rightContact.y);
            return true;
        }

        if (!TryGetRendererBounds(out var bounds))
            return false;
        contact = new Vector3(bounds.center.x, bounds.min.y, bounds.center.z);
        return true;
    }

    bool TryGetRendererBounds(out Bounds bounds)
    {
        bounds = new Bounds();
        if (renderers == null || renderers.Length == 0)
            renderers = model.GetComponentsInChildren<Renderer>(true);
        var hasBounds = false;
        for (var index = 0; index < renderers.Length; index++)
        {
            var renderer = renderers[index];
            if (renderer == null || !renderer.enabled)
                continue;
            if (!hasBounds)
            {
                bounds = renderer.bounds;
                hasBounds = true;
            }
            else
            {
                bounds.Encapsulate(renderer.bounds);
            }
        }
        return hasBounds;
    }

    bool TryCalibrateSoles()
    {
        if (leftFoot == null
            || rightFoot == null
            || skinnedRenderers == null
            || skinnedRenderers.Length == 0
            || !TryGetRendererBounds(out var bounds))
        {
            return false;
        }

        var modelHeight = Mathf.Max(0.1f, bounds.size.y);
        if (!TryFindSoleContact(leftFoot, modelHeight, out var leftContact)
            || !TryFindSoleContact(rightFoot, modelHeight, out var rightContact))
        {
            return false;
        }

        leftSoleInFootSpace = leftFoot.InverseTransformPoint(leftContact);
        rightSoleInFootSpace = rightFoot.InverseTransformPoint(rightContact);
        return true;
    }

    bool TryFindSoleContact(Transform foot, float modelHeight, out Vector3 contact)
    {
        contact = default;
        var searchRadii = new[] { modelHeight * 0.10f, modelHeight * 0.18f };
        for (var radiusIndex = 0; radiusIndex < searchRadii.Length; radiusIndex++)
        {
            var radius = Mathf.Max(0.08f, searchRadii[radiusIndex]);
            var radiusSquared = radius * radius;
            var minimumY = float.PositiveInfinity;
            var candidates = new System.Collections.Generic.List<Vector3>();

            for (var rendererIndex = 0; rendererIndex < skinnedRenderers.Length; rendererIndex++)
            {
                var renderer = skinnedRenderers[rendererIndex];
                if (renderer == null || renderer.sharedMesh == null)
                    continue;
                var bakedMesh = new Mesh();
                renderer.BakeMesh(bakedMesh);
                var vertices = bakedMesh.vertices;
                for (var vertexIndex = 0; vertexIndex < vertices.Length; vertexIndex++)
                {
                    var world = renderer.transform.TransformPoint(vertices[vertexIndex]);
                    var horizontal = new Vector2(
                        world.x - foot.position.x,
                        world.z - foot.position.z);
                    if (horizontal.sqrMagnitude > radiusSquared)
                        continue;
                    if (world.y > foot.position.y + modelHeight * 0.08f
                        || world.y < foot.position.y - modelHeight * 0.24f)
                    {
                        continue;
                    }
                    minimumY = Mathf.Min(minimumY, world.y);
                    candidates.Add(world);
                }
                DestroyMesh(bakedMesh);
            }

            if (candidates.Count == 0 || float.IsInfinity(minimumY))
                continue;
            var soleBand = Mathf.Max(0.006f, modelHeight * 0.012f);
            var sum = Vector3.zero;
            var count = 0;
            for (var index = 0; index < candidates.Count; index++)
            {
                if (candidates[index].y > minimumY + soleBand)
                    continue;
                sum += candidates[index];
                count++;
            }
            if (count > 0)
            {
                contact = sum / count;
                return true;
            }
        }
        return false;
    }

    static void DestroyMesh(Mesh mesh)
    {
        if (Application.isPlaying)
            UnityEngine.Object.Destroy(mesh);
        else
            UnityEngine.Object.DestroyImmediate(mesh);
    }

    void LateUpdate() => Refresh();
}
