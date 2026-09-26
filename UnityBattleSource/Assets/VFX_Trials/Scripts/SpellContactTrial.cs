using System;
using System.Collections.Generic;
using UnityEngine;

// Visual contact only: no timeScale, damage, target selection, camera, or callback ownership.
public sealed class SpellContactTrial : MonoBehaviour
{
    sealed class Plume
    {
        public Transform tr;
        public Mesh mesh;
        public Material material;
        public Vector3 center, direction;
        public Quaternion rotation;
        public int index;
        public float seed;
    }
    readonly List<Plume> plumes = new List<Plume>();
    public bool Ice;

    public void Build(Vector3[] targets)
    {
        Clear();
        if (targets == null) return;
        var phoenix = GetComponent<PhoenixWingTrial>();
        var thunder = GetComponent<IceThunderTrial>();
        Texture2D art = Ice ? (thunder ? thunder.GroundArt : null) : (phoenix ? phoenix.Art : null);
        for (int k = 0; k < targets.Length; k++) for (int i = 0; i < 10; i++)
        {
            float seed = i * 1.71f + targets[k].x * .41f + targets[k].z * .23f;
            var g = new GameObject((Ice ? "Forked discharge " : "Peeling gold plume ") + k + " " + i);
            g.transform.SetParent(transform, false);
            g.transform.position = targets[k] + Vector3.up * 1.05f + Vector3.back * .5f;
            Mesh mesh = ContactMesh(i == 0, Ice, seed);
            var material = new Material(Shader.Find("Mistport/SpellContact"));
            material.SetFloat("_Ice", Ice ? 1 : 0); material.SetFloat("_Seed", seed);
            material.SetFloat("_Core", i == 0 ? 1 : 0); material.SetFloat("_UseArt", art ? 1 : 0);
            if (art) material.SetTexture("_MainTex", art);
            g.AddComponent<MeshFilter>().sharedMesh = mesh;
            g.AddComponent<MeshRenderer>().sharedMaterial = material;
            float angle = i * 2.39996f + Mathf.Sin(seed * 1.7f) * .27f;
            var direction = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle) * .7f + .3f, Mathf.Sin(seed * 2.3f) * .23f);
            plumes.Add(new Plume
            {
                tr = g.transform, mesh = mesh, material = material, center = g.transform.localPosition,
                direction = transform.InverseTransformDirection(direction),
                rotation = Quaternion.Inverse(transform.rotation) * Quaternion.Euler(Mathf.Sin(seed) * 18, Mathf.Cos(seed) * 24, angle * Mathf.Rad2Deg),
                index = i, seed = seed
            });
        }
        Sample(0);
    }

    public void Sample(float t)
    {
        float age = t - (Ice ? IceThunderTrial.ContactTime : PhoenixWingTrial.ContactTime);
        foreach (var p in plumes)
        {
            bool visible = age >= 0 && age < .32f;
            p.tr.gameObject.SetActive(visible);
            // Reset even when scrubbing backwards or replaying after the final sample.
            p.tr.localPosition = p.center;
            p.tr.localRotation = p.rotation;
            p.tr.localScale = Vector3.zero;
            if (!visible) continue;
            p.material.SetFloat("_Age", age);
            if (p.index == 0)
            {
                // Preserve the 15ms core/30ms expansion and 5.2 extreme peak; explicitly retract.
                float size = Mathf.Lerp(.35f, 5.2f, Mathf.Clamp01((age - .015f) / .030f));
                if (age > .045f) size = Mathf.Lerp(5.2f, .45f, Mathf.SmoothStep(0, 1, Mathf.Clamp01((age - .045f) / .205f)));
                p.tr.localScale = new Vector3(size * (Ice ? .68f : 1), size * (Ice ? .92f : .69f), 1);
            }
            else
            {
                float size = Mathf.Lerp(1.2f, .12f, Mathf.Clamp01(age / .32f));
                float loosen = Mathf.Clamp01((age - .015f) / .030f);
                float reach = .16f * (1 - Mathf.Exp(-age * 18)) + age * .10f;
                float speed = 6.5f + p.index * .61f;
                p.tr.localPosition = p.center + p.direction * reach * speed;
                p.tr.localRotation = p.rotation * Quaternion.Euler(age * (Ice ? 14 : 72), age * 36, Mathf.Sin(age * 9 + p.seed) * loosen * (Ice ? 7 : 19));
                p.tr.localScale = new Vector3(size * (Ice ? 2.5f : 2.7f), size * (Ice ? .15f : .38f), 1);
            }
        }
    }

    static Mesh ContactMesh(bool core, bool ice, float seed)
    {
        var v = new List<Vector3>(); var uv = new List<Vector2>(); var ix = new List<int>();
        if (core)
        {
            const int count = 36;
            v.Add(new Vector3(0, 0, -.055f)); uv.Add(new Vector2(.5f, .5f));
            for (int j = 0; j <= count; j++)
            {
                float a = j * Mathf.PI * 2 / count;
                // Filled, asymmetric broken mass: deliberately not a circle or a regular star.
                float r = .35f + .085f * Mathf.Sin(a * 3 + seed) + .047f * Mathf.Sin(a * 7 - .6f) + .018f * Mathf.Cos(a * 11 + seed);
                Vector3 point = new Vector3(Mathf.Cos(a) * r, Mathf.Sin(a) * r, Mathf.Sin(a * 3 + seed) * .065f);
                v.Add(point); uv.Add(new Vector2(point.x + .5f, point.y + .5f));
                if (j > 0) ix.AddRange(new[] { 0, j, j + 1 });
            }
        }
        else
        {
            const int count = 24;
            for (int j = 0; j <= count; j++)
            {
                float u = j / (float)count;
                float taper = Mathf.Pow(Mathf.Max(0, Mathf.Sin(u * Mathf.PI)), .7f);
                float width = taper * (.24f + .06f * Mathf.Sin(u * 11 + seed));
                float bend = Mathf.Sin(u * 3.5f + seed * .25f) * u * (ice ? .21f : .43f);
                for (int s = 0; s < 2; s++)
                {
                    v.Add(new Vector3(u - .5f, bend + (s == 0 ? -width : width), Mathf.Sin(u * 4 + seed) * taper * .10f));
                    uv.Add(new Vector2(u, s));
                }
                if (j < count) ix.AddRange(new[] { j * 2, j * 2 + 2, j * 2 + 1, j * 2 + 1, j * 2 + 2, j * 2 + 3 });
            }
        }
        var mesh = new Mesh { name = core ? "Organic contact core" : "Curved tapered discharge" };
        mesh.SetVertices(v); mesh.SetUVs(0, uv); mesh.SetTriangles(ix, 0); mesh.RecalculateBounds();
        return mesh;
    }

    static void Release(UnityEngine.Object value) { if (value) { if (Application.isPlaying) Destroy(value); else DestroyImmediate(value); } }
    void Clear()
    {
        foreach (var p in plumes)
        {
            if (p.tr) { p.tr.gameObject.SetActive(false); Release(p.tr.gameObject); }
            Release(p.mesh); Release(p.material);
        }
        plumes.Clear();
    }
    void OnDisable() { foreach (var p in plumes) if (p.tr) p.tr.gameObject.SetActive(false); }
    void OnDestroy() { Clear(); }

    // One opt-in pose sampler per CAST, never per target. The review recorder supplies the
    // actor and visual clock; this class never searches the scene or modifies shared choreography.
    // Call Restore before animation evaluation; Sample after it; Dispose in recorder finally.
    public sealed class CasterMotion : IDisposable
    {
        public enum Style { Phoenix, Rift, Thunder }
        sealed class Joint
        {
            public Transform bone;
            public string key;
            public Quaternion baseline, appliedRotation;
            public bool applied;
        }
        readonly List<Joint> joints = new List<Joint>();
        readonly Transform actor;
        readonly Style style;
        public int MappedJointCount { get { return joints.Count; } }
        public CasterMotion(Transform actor, Style style)
        {
            this.actor = actor; this.style = style;
            if (!actor) return;
            var animator = actor.GetComponentInChildren<Animator>(true);
            Add("spine", animator, HumanBodyBones.Spine, "Spine");
            Add("chest", animator, HumanBodyBones.Chest, "Spine1", "Chest");
            Add("head", animator, HumanBodyBones.Head, "Head");
            Add("ls", animator, HumanBodyBones.LeftShoulder, "LeftShoulder");
            Add("rs", animator, HumanBodyBones.RightShoulder, "RightShoulder");
            Add("la", animator, HumanBodyBones.LeftUpperArm, "LeftArm", "LeftUpperArm", "UpperArm.L");
            Add("ra", animator, HumanBodyBones.RightUpperArm, "RightArm", "RightUpperArm", "UpperArm.R");
            Add("le", animator, HumanBodyBones.LeftLowerArm, "LeftForeArm", "LeftLowerArm", "Forearm.L");
            Add("re", animator, HumanBodyBones.RightLowerArm, "RightForeArm", "RightLowerArm", "Forearm.R");
            Add("lh", animator, HumanBodyBones.LeftHand, "LeftHand", "Hand.L");
            Add("rh", animator, HumanBodyBones.RightHand, "RightHand", "Hand.R");
        }
        void Add(string key, Animator animator, HumanBodyBones human, params string[] aliases)
        {
            Transform bone = animator && animator.isHuman ? animator.GetBoneTransform(human) : null;
            if (!bone) foreach (var candidate in actor.GetComponentsInChildren<Transform>(true))
            {
                string name = candidate.name; int colon = name.LastIndexOf(':');
                if (colon >= 0) name = name.Substring(colon + 1);
                foreach (var alias in aliases) if (name == alias) { bone = candidate; break; }
                if (bone) break;
            }
            if (bone) joints.Add(new Joint { bone = bone, key = key });
        }
        public void Restore()
        {
            foreach (var j in joints) if (j.applied)
            {
                // Do not overwrite a fresh Animator/shared-owner pose if it was already evaluated.
                if (j.bone && Quaternion.Angle(j.bone.localRotation, j.appliedRotation) < .01f) j.bone.localRotation = j.baseline;
                j.applied = false;
            }
        }
        public void Sample(float t)
        {
            Restore();
            if (!actor || !actor.gameObject.activeInHierarchy || t <= 0 || t >= 2.5f) return;
            float contact = style == Style.Phoenix ? .72f : style == Style.Rift ? .84f : .50f;
            float gather = Smooth(0, Mathf.Min(.30f, contact * .48f), t);
            float release = Smooth(contact - .13f, contact, t);
            float recover = 1 - Smooth(contact + .10f, contact + .46f, t);
            float force = Mathf.Sin(Mathf.Clamp01((t - contact) / .18f) * Mathf.PI) * .18f;
            float weight = gather * recover;
            foreach (var j in joints)
            {
                if (!j.bone) continue;
                Vector3 windup, strike; Poses(j.key, out windup, out strike);
                Vector3 degrees = Vector3.Lerp(windup, strike, release) * weight + strike * force;
                j.baseline = j.bone.localRotation;
                Quaternion actorDelta = Quaternion.Euler(degrees);
                Quaternion worldDelta = actor.rotation * actorDelta * Quaternion.Inverse(actor.rotation);
                Quaternion parent = j.bone.parent ? j.bone.parent.rotation : Quaternion.identity;
                j.bone.localRotation = Quaternion.Inverse(parent) * worldDelta * parent * j.baseline;
                j.appliedRotation = j.bone.localRotation; j.applied = true;
            }
        }
        void Poses(string key, out Vector3 windup, out Vector3 strike)
        {
            windup = Vector3.zero; strike = Vector3.zero;
            if (style == Style.Phoenix)
            {
                switch (key)
                {
                    case "spine": windup=V(7,-18,5); strike=V(8,17,-5); break;
                    case "chest": windup=V(-6,-16,4); strike=V(9,20,-6); break;
                    case "head": windup=V(-4,9,-2); strike=V(3,-8,1); break;
                    case "ls": windup=V(-4,-9,-8); strike=V(8,12,8); break;
                    case "rs": windup=V(-7,-14,11); strike=V(9,17,-9); break;
                    case "la": windup=V(-32,-18,-26); strike=V(-14,30,32); break;
                    case "ra": windup=V(-45,-26,28); strike=V(-30,22,-38); break;
                    case "le": windup=V(-36,-8,-12); strike=V(-8,14,9); break;
                    case "re": windup=V(-52,8,15); strike=V(-10,-12,-8); break;
                    case "lh": windup=V(16,-12,-14); strike=V(-18,12,20); break;
                    case "rh": windup=V(24,10,16); strike=V(-26,-14,-22); break;
                }
            }
            else if (style == Style.Rift)
            {
                switch (key)
                {
                    case "spine": windup=V(-4,-12,6); strike=V(19,10,-4); break;
                    case "chest": windup=V(-12,-13,4); strike=V(21,13,-7); break;
                    case "head": windup=V(-3,7,0); strike=V(8,-5,0); break;
                    case "ls": windup=V(-3,-5,-6); strike=V(6,8,8); break;
                    case "rs": windup=V(-10,-9,8); strike=V(14,8,-11); break;
                    case "la": windup=V(-26,12,-23); strike=V(-5,-20,-28); break;
                    case "ra": windup=V(-88,-12,12); strike=V(24,17,-18); break;
                    case "le": windup=V(-38,0,-5); strike=V(-17,12,4); break;
                    case "re": windup=V(-49,9,7); strike=V(-3,-7,-9); break;
                    case "lh": windup=V(8,8,-12); strike=V(-11,-10,10); break;
                    case "rh": windup=V(26,0,10); strike=V(-29,-8,-15); break;
                }
            }
            else
            {
                switch (key)
                {
                    case "spine": windup=V(-8,7,-2); strike=V(15,-5,2); break;
                    case "chest": windup=V(-14,9,-3); strike=V(20,-9,4); break;
                    case "head": windup=V(-8,-5,0); strike=V(8,4,0); break;
                    case "ls": windup=V(-12,3,-8); strike=V(13,-5,7); break;
                    case "rs": windup=V(-15,-4,10); strike=V(14,6,-9); break;
                    case "la": windup=V(-93,9,-20); strike=V(-12,-15,-34); break;
                    case "ra": windup=V(-104,-12,24); strike=V(-2,15,38); break;
                    case "le": windup=V(-32,-10,-8); strike=V(-6,8,12); break;
                    case "re": windup=V(-39,12,9); strike=V(-4,-8,-14); break;
                    case "lh": windup=V(17,12,-16); strike=V(-25,-12,16); break;
                    case "rh": windup=V(23,-12,18); strike=V(-31,10,-19); break;
                }
            }
        }
        static Vector3 V(float x,float y,float z) { return new Vector3(x,y,z); }
        static float Smooth(float a,float b,float t) { return Mathf.SmoothStep(0,1,Mathf.InverseLerp(a,b,t)); }
        public void Dispose() { Restore(); joints.Clear(); }
    }
}
