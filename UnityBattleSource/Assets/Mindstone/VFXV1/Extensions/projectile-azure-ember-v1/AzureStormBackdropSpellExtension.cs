using System.Collections.Generic;
using UnityEngine;

namespace Mindstone.VFXV1
{
    /// <summary>
    /// Short-lived storm dressing for the Azure Ember prototype.  It sits
    /// behind the actors, darkens the arena with a cloud card, and redraws a
    /// deterministic set of lightning branches during the impact beat.
    /// </summary>
    public sealed class AzureStormBackdropSpellExtension : MonoBehaviour, ISpellExtension
    {
        readonly List<GameObject> owned = new();
        readonly List<LineRenderer> bolts = new();
        Material cloudMaterial;
        Material boltMaterial;
        Material rainMaterial;
        Transform root;
        SpellLayerSpec layer;
        int seed;
        bool ready;

        public void Initialize(SpellSpec spell, SpellLayerSpec layerSpec, int deterministicSeed)
        {
            layer = layerSpec;
            seed = deterministicSeed;
            root = new GameObject("VFX V1 · Azure storm backdrop").transform;
            root.SetParent(transform, false);
            cloudMaterial = MakeMaterial("Storm cloud", "Sprites/Default", 2960);
            var cloudTexture = Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke_Lighting");
            if (cloudTexture != null)
                cloudMaterial.mainTexture = cloudTexture;
            cloudMaterial.color = new Color(0.025f, 0.045f, 0.115f, 0.72f);

            boltMaterial = MakeMaterial("Storm lightning", "Sprites/Default", 4300);
            boltMaterial.color = new Color(0.35f, 0.78f, 1f, 1f);
            rainMaterial = MakeMaterial("Storm rain", "Sprites/Default", 4050);
            rainMaterial.color = new Color(0.25f, 0.52f, 0.84f, 0.22f);
            for (var i = 0; i < 5; i++)
                bolts.Add(CreateBolt($"Lightning branch {i}"));
            ready = true;
        }

        public void Sample(in SpellSample sample)
        {
            if (!ready)
                return;
            var camera = sample.Camera != null ? sample.Camera : Camera.main;
            if (camera == null)
                return;

            var center = sample.Target + Vector3.up * 2.2f;
            var facing = camera.transform.rotation;
            var backdrop = EnsureQuad("Storm cloud bank", cloudMaterial);
            backdrop.transform.SetPositionAndRotation(center + camera.transform.forward * 2.8f, facing);
            backdrop.transform.localScale = new Vector3(8.8f, 8.6f, 1f);
            var stormRamp = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(sample.NormalizedTime / 0.25f));
            var decay = 1f - Mathf.Clamp01((sample.NormalizedTime - 0.76f) / 0.24f);
            cloudMaterial.color = new Color(0.012f, 0.025f, 0.075f, 0.18f + stormRamp * 0.42f * decay);

            // Lightning is clustered around the contact beat.  The small
            // deterministic phase offsets keep branches from strobing as one
            // perfectly uniform line.
            var flash = Mathf.Clamp01((Mathf.Sin((sample.AbsoluteTime + seed * 0.0017f) * 30f) - 0.78f) * 4.5f);
            flash *= Mathf.Clamp01((sample.NormalizedTime - 0.30f) / 0.25f)
                * Mathf.Clamp01((0.92f - sample.NormalizedTime) / 0.28f);
            for (var i = 0; i < bolts.Count; i++)
            {
                var bolt = bolts[i];
                var start = sample.Target + camera.transform.right * ((i - 2) * 0.72f)
                    + Vector3.up * (3.7f + (i % 2) * 0.24f)
                    + camera.transform.forward * (0.55f + i * 0.03f);
                var end = sample.Target + camera.transform.right * ((i - 2) * 0.22f)
                    + Vector3.up * (0.22f + (i % 3) * 0.08f)
                    + camera.transform.forward * (0.52f + i * 0.03f);
                var bend = Vector3.Lerp(start, end, 0.46f)
                    + camera.transform.right * Mathf.Sin(seed + i * 2.7f) * 0.30f;
                bolt.positionCount = 5;
                bolt.SetPosition(0, start);
                bolt.SetPosition(1, Vector3.Lerp(start, bend, 0.42f));
                bolt.SetPosition(2, bend);
                bolt.SetPosition(3, Vector3.Lerp(bend, end, 0.58f));
                bolt.SetPosition(4, end);
                var alpha = flash * (0.55f + i * 0.07f);
                bolt.startColor = new Color(0.45f, 0.82f, 1f, alpha);
                bolt.endColor = new Color(0.95f, 0.98f, 1f, alpha * 0.86f);
                bolt.startWidth = 0.018f + flash * 0.035f;
                bolt.endWidth = 0.008f + flash * 0.018f;
                bolt.enabled = alpha > 0.01f;
            }

            // Thin rain streaks give the background motion between flashes.
            var rain = EnsureQuad("Rain veil", rainMaterial);
            rain.transform.SetPositionAndRotation(center + camera.transform.forward * 2.45f, facing);
            rain.transform.localScale = new Vector3(8.8f, 8.6f, 1f);
            rainMaterial.color = new Color(0.18f, 0.36f, 0.72f, 0.04f + stormRamp * 0.08f * decay);
        }

        public void Interrupt() => Cleanup();

        public void Cleanup()
        {
            for (var i = 0; i < owned.Count; i++)
                if (owned[i] != null)
                    Destroy(owned[i]);
            owned.Clear();
            bolts.Clear();
            if (cloudMaterial != null) Destroy(cloudMaterial);
            if (boltMaterial != null) Destroy(boltMaterial);
            if (rainMaterial != null) Destroy(rainMaterial);
            cloudMaterial = null;
            boltMaterial = null;
            rainMaterial = null;
            ready = false;
        }

        LineRenderer CreateBolt(string name)
        {
            var go = new GameObject(name);
            go.transform.SetParent(root, false);
            owned.Add(go);
            var line = go.AddComponent<LineRenderer>();
            line.material = boltMaterial;
            line.alignment = LineAlignment.View;
            line.textureMode = LineTextureMode.Stretch;
            line.numCapVertices = 2;
            line.enabled = false;
            return line;
        }

        GameObject EnsureQuad(string name, Material material)
        {
            for (var i = 0; i < owned.Count; i++)
                if (owned[i] != null && owned[i].name == name)
                    return owned[i];
            var quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
            quad.name = name;
            quad.transform.SetParent(root, false);
            quad.GetComponent<Renderer>().material = material;
            var collider = quad.GetComponent<Collider>();
            if (collider != null) Destroy(collider);
            owned.Add(quad);
            return quad;
        }

        static Material MakeMaterial(string name, string shaderName, int queue)
        {
            var shader = Shader.Find(shaderName) ?? Shader.Find("Unlit/Color");
            var material = new Material(shader) { name = name };
            material.renderQueue = queue;
            if (material.HasProperty("_Cull"))
                material.SetInt("_Cull", 0);
            return material;
        }
    }
}
