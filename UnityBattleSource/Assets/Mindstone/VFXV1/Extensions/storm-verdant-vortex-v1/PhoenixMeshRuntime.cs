using UnityEngine;
using UnityEngine.Rendering;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// Runtime presentation for the supplied static phoenix FBX. The asset is
    /// kept as one coherent mesh; a small vertex deformation in
    /// PhoenixSpellMesh.shader provides the wing beat without requiring a
    /// Blender re-rig or a new animation clip.
    /// </summary>
    internal sealed class PhoenixMeshRuntime
    {
        const string ModelResource =
            "Mindstone/VFXV1/Spells/storm-verdant-vortex-v1/Phoenix/MeshyPhoenix";
        const string ShaderResource =
            "Mindstone/VFXV1/Spells/storm-verdant-vortex-v1/Phoenix/PhoenixSpellMesh";
        const string BaseColorResource =
            "Mindstone/VFXV1/Spells/storm-verdant-vortex-v1/Phoenix/MeshyPhoenix_BaseColor";
        const string NormalResource =
            "Mindstone/VFXV1/Spells/storm-verdant-vortex-v1/Phoenix/MeshyPhoenix_Normal";
        const string MetallicResource =
            "Mindstone/VFXV1/Spells/storm-verdant-vortex-v1/Phoenix/MeshyPhoenix_Metallic";
        const string RoughnessResource =
            "Mindstone/VFXV1/Spells/storm-verdant-vortex-v1/Phoenix/MeshyPhoenix_Roughness";

        readonly Transform parent;
        readonly GameObject pivot = null;
        readonly GameObject instance = null;
        readonly Renderer[] renderers = null;
        readonly Material[] materials = null;
        readonly Vector3 sourceRootScale = Vector3.one;
        readonly Vector3 sourceBoundsCenter = Vector3.zero;
        readonly float sourceHeight = 1f;
        readonly float sourceMeshScale = 1f;
        readonly int deterministicSeed;

        public bool IsAvailable { get; } = false;

        public PhoenixMeshRuntime(Transform owner, int seed)
        {
            parent = owner;
            deterministicSeed = seed;
            var prefab = Resources.Load<GameObject>(ModelResource);
            var shader = Resources.Load<Shader>(ShaderResource)
                ?? Shader.Find("Mindstone/VFXV1/Phoenix Spell Mesh");
            var baseColor = Resources.Load<Texture2D>(BaseColorResource);
            var normal = Resources.Load<Texture2D>(NormalResource);
            var metallic = Resources.Load<Texture2D>(MetallicResource);
            var roughness = Resources.Load<Texture2D>(RoughnessResource);

            if (prefab == null || shader == null || baseColor == null
                || normal == null || metallic == null || roughness == null)
            {
                Debug.LogError("[VFX V1] Phoenix mesh stack is incomplete: "
                    + $"model={(prefab != null)} shader={(shader != null)} "
                    + $"base={(baseColor != null)} normal={(normal != null)} "
                    + $"metallic={(metallic != null)} roughness={(roughness != null)}");
                return;
            }

            pivot = new GameObject("VFX V1 · Phoenix model pivot");
            pivot.transform.SetParent(owner, false);
            instance = Object.Instantiate(prefab, pivot.transform);
            instance.name = "VFX V1 · Meshy phoenix static asset";
            sourceRootScale = instance.transform.localScale;
            if (Mathf.Abs(sourceRootScale.x) < 0.0001f)
                sourceRootScale = Vector3.one;

            renderers = instance.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0)
            {
                Debug.LogError("[VFX V1] Phoenix FBX has no Renderer component.");
                SpellBackends.DestroyOwned(pivot);
                return;
            }

            var sourceBounds = BuildLocalBounds(pivot.transform, renderers);
            sourceBoundsCenter = sourceBounds.center;
            sourceHeight = Mathf.Max(sourceBounds.size.y, 0.0001f);
            sourceMeshScale = Mathf.Max(Mathf.Abs(sourceRootScale.x), 0.0001f);

            materials = new Material[renderers.Length];
            for (var index = 0; index < renderers.Length; index++)
            {
                var material = new Material(shader)
                {
                    name = $"Runtime Phoenix Mesh {index}",
                    hideFlags = HideFlags.DontSave,
                    renderQueue = 3506
                };
                material.SetTexture("_MainTex", baseColor);
                material.SetTexture("_NormalMap", normal);
                material.SetTexture("_MetallicTex", metallic);
                material.SetTexture("_RoughnessTex", roughness);
                material.SetColor("_BaseTint", new Color(1.0f, 0.34f, 0.025f, 1f));
                material.SetColor("_DeepColor", new Color(0.16f, 0.006f, 0.001f, 1f));
                material.SetColor("_GoldColor", new Color(1.0f, 0.27f, 0.012f, 1f));
                material.SetColor("_HotColor", new Color(1.0f, 0.94f, 0.44f, 1f));
                material.SetColor("_RimColor", new Color(1.0f, 0.52f, 0.035f, 1f));
                material.SetFloat("_EmissionBoost", 1.45f);
                material.SetFloat("_RimPower", 2.25f);
                material.SetFloat("_MeshScale", sourceMeshScale);
                material.SetFloat("_ExplosionSeed", deterministicSeed + index * 17.0f);
                material.SetFloat("_ExplosionSize", sourceHeight * 1.18f);
                materials[index] = material;
                renderers[index].sharedMaterials = new[] { material };
                renderers[index].sortingOrder = 9;
                renderers[index].shadowCastingMode = ShadowCastingMode.Off;
                renderers[index].receiveShadows = false;
                renderers[index].allowOcclusionWhenDynamic = false;
                renderers[index].enabled = false;
            }

            // Center the imported mesh once. Subsequent samples move and
            // rotate the pivot, so the model stays stable during travel.
            instance.transform.localPosition = -sourceBoundsCenter;
            pivot.SetActive(false);
            IsAvailable = true;
        }

        public void Sample(Vector3 center, Vector3 cameraUp, Vector3 cameraForward,
            float targetHeight, float visibility, float phase, float time,
            float explosion)
        {
            if (!IsAvailable || pivot == null || instance == null)
                return;
            if (visibility <= 0.001f || targetHeight <= 0.001f)
            {
                Hide();
                return;
            }

            var forward = cameraForward.sqrMagnitude > 0.0001f
                ? -cameraForward.normalized
                : Vector3.back;
            var up = cameraUp.sqrMagnitude > 0.0001f
                ? cameraUp.normalized
                : Vector3.up;
            pivot.SetActive(true);
            pivot.transform.position = center;
            pivot.transform.rotation = Quaternion.LookRotation(forward, up);

            var fit = targetHeight / sourceHeight;
            instance.transform.localScale = sourceRootScale * fit;
            instance.transform.localPosition = -sourceBoundsCenter * fit;

            var phaseValue = phase + time * 4.6f;
            var wingBeat = Mathf.Lerp(0.070f, 0.135f, Mathf.Clamp01(visibility));
            var wingSpread = Mathf.Lerp(0.020f, 0.065f, Mathf.Clamp01(visibility));
            var opacity = Mathf.Clamp01(visibility * 0.94f);
            var meshScale = sourceMeshScale * fit;
            var explode = Mathf.Clamp01(explosion);
            for (var index = 0; index < materials.Length; index++)
            {
                var material = materials[index];
                if (material == null)
                    continue;
                material.SetFloat("_Opacity", opacity);
                material.SetFloat("_Phase", phaseValue);
                material.SetFloat("_WingFlap", wingBeat);
                material.SetFloat("_WingSpread", wingSpread);
                material.SetFloat("_MeshScale", meshScale);
                material.SetFloat("_Explode", explode);
                material.SetFloat("_ExplosionSize", sourceHeight * 1.18f);
                material.SetFloat("_EmissionBoost", 1.35f + opacity * 0.28f);
            }
            for (var index = 0; index < renderers.Length; index++)
                if (renderers[index] != null)
                    renderers[index].enabled = true;
        }

        public void Hide()
        {
            if (pivot == null)
                return;
            pivot.SetActive(false);
            if (renderers == null)
                return;
            for (var index = 0; index < renderers.Length; index++)
                if (renderers[index] != null)
                    renderers[index].enabled = false;
        }

        public void Dispose()
        {
            if (materials != null)
                for (var index = 0; index < materials.Length; index++)
                    if (materials[index] != null)
                        SpellBackends.DestroyOwned(materials[index]);
            if (pivot != null)
                SpellBackends.DestroyOwned(pivot);
        }

        static Bounds BuildLocalBounds(Transform root, Renderer[] values)
        {
            var result = new Bounds();
            var hasBounds = false;
            for (var index = 0; index < values.Length; index++)
            {
                var world = values[index].bounds;
                var corners = new[]
                {
                    new Vector3(world.min.x, world.min.y, world.min.z),
                    new Vector3(world.min.x, world.min.y, world.max.z),
                    new Vector3(world.min.x, world.max.y, world.min.z),
                    new Vector3(world.min.x, world.max.y, world.max.z),
                    new Vector3(world.max.x, world.min.y, world.min.z),
                    new Vector3(world.max.x, world.min.y, world.max.z),
                    new Vector3(world.max.x, world.max.y, world.min.z),
                    new Vector3(world.max.x, world.max.y, world.max.z)
                };
                for (var corner = 0; corner < corners.Length; corner++)
                {
                    var local = root.InverseTransformPoint(corners[corner]);
                    if (!hasBounds)
                    {
                        result = new Bounds(local, Vector3.zero);
                        hasBounds = true;
                    }
                    else
                    {
                        result.Encapsulate(local);
                    }
                }
            }
            return hasBounds ? result : new Bounds(Vector3.zero, Vector3.one);
        }
    }
}
