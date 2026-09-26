using System;
using System.Collections.Generic;
using UnityEngine;

// D03/D05 authored body gestures and organ-specific light geometry. Visual only:
// recipient healing/empower status and all contact callbacks remain rule-owned.
[DefaultExecutionOrder(1810)]
public sealed class TowerSupportPolish20260920 : MonoBehaviour
{
    readonly Dictionary<string, Transform> joints = new Dictionary<string, Transform>();
    readonly Dictionary<string, Quaternion> rest = new Dictionary<string, Quaternion>();
    readonly Dictionary<string, Vector3> scales = new Dictionary<string, Vector3>();
    readonly List<LineRenderer> strokes = new List<LineRenderer>();
    readonly List<MeshRenderer> organSheets = new List<MeshRenderer>();
    readonly List<Mesh> sheetMeshes = new List<Mesh>();
    readonly List<Vector3[]> sheetVertices = new List<Vector3[]>();
    const int SheetX=16, SheetY=24;
    readonly List<Material> sheetMaterials = new List<Material>();
    Material material;
    EnemyHandle actor;
    Func<Vector3> target;
    string action;
    float age, contact;
    bool held, restored;
    const int Samples = 25;
    readonly Vector3[] points = new Vector3[Samples];
    static Quaternion Face => Camera.main ? Quaternion.LookRotation(Camera.main.transform.forward) : Quaternion.identity;

    public static bool Handles(string species) => species == "shellback" || species == "frilled-naga";

    public static TowerSupportPolish20260920 Create(EnemyHandle actor, string intent, Func<Vector3> target, float contact, Transform owner)
    {
        var obj = new GameObject("D03 D05 distinct organs " + intent);
        obj.transform.SetParent(owner, false);
        var v = obj.AddComponent<TowerSupportPolish20260920>();
        v.actor = actor; v.action = intent; v.target = target; v.contact = Mathf.Max(.1f, contact);
        v.held = intent == "tower_mend_charge" || intent == "tower_crown_charge";
        foreach (var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))
        {
            if (t.name == "Pelvis" || t.name == "Chest" || t.name == "Neck" || t.name == "Head" ||
                t.name.StartsWith("Sac.") || t.name.StartsWith("Crown.") || t.name.StartsWith("Tail") ||
                t.name.StartsWith("UpperArm.") || t.name.StartsWith("Forearm.") || t.name.StartsWith("Hand.") ||
                t.name.StartsWith("Thigh.") || t.name.StartsWith("Shin."))
            {
                v.joints[t.name] = t; v.rest[t.name] = t.localRotation; v.scales[t.name] = t.localScale;
            }
        }
        v.material = new Material(Shader.Find("Sprites/Default"));
        var texture = Resources.Load<Texture2D>("Effects/Mistport/Official/Slashing/Line01");
        if (texture) v.material.mainTexture = texture;
        for (int i = 0; i < 64; i++)
        {
            var lineObject = new GameObject("Organ stroke " + i);
            lineObject.transform.SetParent(obj.transform, false);
            var line = lineObject.AddComponent<LineRenderer>();
            line.sharedMaterial = v.material; line.useWorldSpace = true;
            line.positionCount = Samples; line.numCapVertices = 3;
            line.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            line.receiveShadows = false; line.enabled = false;
            line.widthCurve = new AnimationCurve(new Keyframe(0, .04f), new Keyframe(.18f, .8f), new Keyframe(.52f, 1), new Keyframe(.84f, .7f), new Keyframe(1, .02f));
            v.strokes.Add(line);
        }
        // Retain the authored translucent membrane and carved crown surfaces.
        // Split UV halves let each physical lobe open independently; the line
        // detail is an accent on these broad sheets, not the visual substitute.
        bool shell = intent == "tower_mend" || intent == "tower_mend_charge" || intent == "tower_short_pounce";
        var organTexture = Resources.Load<Texture2D>("ChurchSpellArt/" + (shell ? "mend" : "corona"));
        for (int i = 0; i < 4; i++)
        {
            var sheet = new GameObject("Authored organ membrane " + i);
            sheet.transform.SetParent(obj.transform, false);
            var mesh = new Mesh();
            float u0 = i % 2 == 0 ? 0 : .5f, u1 = u0 + .5f;
            mesh.MarkDynamic();
            var vertices=new Vector3[(SheetX+1)*(SheetY+1)];
            var uv=new Vector2[vertices.Length];var triangles=new int[SheetX*SheetY*6];
            for(int y=0;y<=SheetY;y++)for(int x=0;x<=SheetX;x++){
                int n=y*(SheetX+1)+x;float u=x/(float)SheetX,w=y/(float)SheetY;
                vertices[n]=new Vector3((u-.5f)*.5f,w-.5f,0);uv[n]=new Vector2(Mathf.Lerp(u0,u1,u),w);
                if(x<SheetX&&y<SheetY){int k=(y*SheetX+x)*6;triangles[k]=n;triangles[k+1]=n+1;triangles[k+2]=n+SheetX+2;triangles[k+3]=n;triangles[k+4]=n+SheetX+2;triangles[k+5]=n+SheetX+1;}
            }
            mesh.vertices=vertices;mesh.uv=uv;mesh.triangles=triangles;mesh.RecalculateBounds();
            v.sheetVertices.Add(vertices);
            sheet.AddComponent<MeshFilter>().sharedMesh = mesh;
            Shader shader = Resources.Load<Shader>(i >= 2 ? "Shaders/ChurchLivingSurface" : "Shaders/ChurchFilament");
            var mat = new Material(shader ? shader : Shader.Find("Sprites/Default"));
            mat.mainTexture = organTexture; mat.SetColor("_Color", Color.clear);
            if (mat.HasProperty("_Luma")) mat.SetFloat("_Luma", 0);
            if (mat.HasProperty("_Dst")) mat.SetFloat("_Dst", 10);
            if (mat.HasProperty("_Ribbon")) mat.SetFloat("_Ribbon", 0);
            var renderer = sheet.AddComponent<MeshRenderer>(); renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; renderer.receiveShadows = false;
            v.organSheets.Add(renderer); v.sheetMeshes.Add(mesh); v.sheetMaterials.Add(mat);
        }
        Debug.Log("TOWER_SUPPORT_GESTURE " + intent + " joints=" + v.joints.Count);
        return v;
    }

    public void Tick(float elapsed) { age = action=="tower_short_pounce"||action=="tower_sound_arrow" ? TowerImpactTiming20260921.Sample(elapsed,contact,action=="tower_short_pounce"?.110f:.085f) : elapsed; }
    void Update() { if (held) age += Time.deltaTime; }
    void Pose(string name, Vector3 euler)
    {
        if (joints.TryGetValue(name, out var t) && t) t.localRotation = rest[name] * Quaternion.Euler(euler);
    }
    void Scale(string name, Vector3 multiplier)
    {
        if (joints.TryGetValue(name, out var t) && t) t.localScale = Vector3.Scale(scales[name], multiplier);
    }
    Vector3 Organ(string name, float fallbackHeight)
    {
        return joints.TryGetValue(name, out var t) && t ? t.position : actor.EnemyRoot.position + Vector3.up * fallbackHeight;
    }
    static float Ease(float t) => Mathf.SmoothStep(0, 1, Mathf.Clamp01(t));

    void LateUpdate()
    {
        if (restored || !actor || !actor.gameObject.activeInHierarchy) return;
        float load = held ? Ease(age / .45f) : Ease(age / (contact * .55f));
        float strike = held ? 0 : Ease((age - contact * .68f) / (contact * .32f));
        float recover = held ? 1 : 1 - Ease((age - contact - .13f) / .42f);
        bool mend = action == "tower_mend" || action == "tower_mend_charge";
        bool empower = action == "tower_empower" || action == "tower_crown_charge";
        if (mend)
        {
            // Shoulder girdle rises while the belly is guarded. The back sacs
            // inflate independently, then squeeze on the exact contact beat.
            Pose("Chest", new Vector3(-22 * load + 33 * strike, 0, 0) * recover);
            Pose("Head", new Vector3(14 * load - 8 * strike, 0, 0) * recover);
            foreach (string side in new[] { "L", "R" })
            {
                float sign = side == "L" ? 1 : -1;
                Pose("UpperArm." + side, new Vector3(-48 * load + 18 * strike, 15 * sign * load, 30 * sign * load) * recover);
                Pose("Forearm." + side, new Vector3(-66 * load + 25 * strike, 0, -12 * sign * load) * recover);
                Pose("Hand." + side, new Vector3(25 * load, 0, 0) * recover);
                float pulse = (.06f * Mathf.Sin(age * 9 + (side == "L" ? 0 : .8f))) * load;
                Scale("Sac." + side, Vector3.one + new Vector3(.22f * load - .34f * strike + pulse, .30f * load - .40f * strike + pulse, .17f * load - .25f * strike) * recover);
            }
        }
        else if (action == "tower_short_pounce")
        {
            // Root travel belongs to ChurchDemonPresentation. Only local joints
            // prepare the crouch, plant, thrust and heavy landing here.
            Pose("Chest", new Vector3(25 * load - 54 * strike, 0, 0) * recover);
            Pose("Head", new Vector3(-16 * load + 27 * strike, 0, 0) * recover);
            foreach (string side in new[] { "L", "R" })
            {
                float sign = side == "L" ? 1 : -1;
                Pose("UpperArm." + side, new Vector3(28 * load - 103 * strike, 0, sign * 12 * load) * recover);
                Pose("Forearm." + side, new Vector3(-48 * load + 82 * strike, 0, 0) * recover);
                Pose("Hand." + side, new Vector3(28 * load - 45 * strike, 0, 0) * recover);
                Pose("Thigh." + side, new Vector3(-22 * load + 36 * strike, 0, 0) * recover);
                Pose("Shin." + side, new Vector3(28 * load - 38 * strike, 0, 0) * recover);
                Scale("Sac." + side, Vector3.one + new Vector3(.03f, -.11f, .08f) * strike * recover);
            }
        }
        else if (empower)
        {
            Vector3 localDirection = actor.EnemyRoot.InverseTransformDirection((target == null ? actor.EnemyRoot.position + actor.EnemyRoot.forward : target()) - actor.EnemyRoot.position);
            float yaw = Mathf.Clamp(Mathf.Atan2(localDirection.x, localDirection.z) * Mathf.Rad2Deg, -32, 32);
            Pose("Chest", new Vector3(-28 * load + 8 * strike, yaw * load, 0) * recover);
            Pose("Neck", new Vector3(-18 * load + 7 * strike, -yaw * .25f * load, 0) * recover);
            Pose("Head", new Vector3(8 * load, 0, 0) * recover);
            foreach (string side in new[] { "L", "R" })
            {
                float sign = side == "L" ? 1 : -1;
                float fan = Ease((age - (side == "L" ? .04f : .12f)) / .25f);
                Pose("Crown." + side, new Vector3(-12 * load, sign * 17 * fan, sign * 24 * fan) * recover);
                Scale("Crown." + side, Vector3.one + new Vector3(.08f, .15f, .03f) * fan * recover);
                Pose("UpperArm." + side, new Vector3(-62 * load + 12 * strike, 0, -sign * 42 * load) * recover);
                Pose("Forearm." + side, new Vector3(-35 * load + 14 * strike, 0, sign * 15 * load) * recover);
                Pose("Hand." + side, new Vector3(-22 * load, sign * 24 * load, 0) * recover);
            }
            Pose("TailBase", new Vector3(0, -14 * load, 0) * recover);
            Pose("Tail2", new Vector3(0, 21 * load, 0) * recover);
        }
        else
        {
            // Sound arrow is a neck/chest snap, with both arms bracing low.
            Pose("Chest", new Vector3(-30 * load + 62 * strike, 0, 0) * recover);
            Pose("Neck", new Vector3(-24 * load + 54 * strike, 0, 0) * recover);
            Pose("Head", new Vector3(-16 * load + 31 * strike, 0, 0) * recover);
            foreach (string side in new[] { "L", "R" })
            {
                float sign = side == "L" ? 1 : -1;
                Pose("Crown." + side, new Vector3(0, -sign * 12 * load, sign * (13 * load - 22 * strike)) * recover);
                Pose("UpperArm." + side, new Vector3(25 * load - 15 * strike, 0, sign * 24 * load) * recover);
                Pose("Forearm." + side, new Vector3(-28 * load + 16 * strike, 0, 0) * recover);
            }
            Pose("TailBase", new Vector3(0, -24 * load + 32 * strike, 0) * recover);
            Pose("Tail1", new Vector3(0, 34 * load - 39 * strike, 0) * recover);
            Pose("TailTip", new Vector3(-17 * load, 0, 0) * recover);
        }
        foreach (var line in strokes) line.enabled = false;
        foreach (var sheet in organSheets) sheet.enabled = false;
        if (mend) MendVeins(load, recover);
        else if (empower) CrownFan(load, recover);
        else if (action == "tower_short_pounce") PounceCompression();
        else SonicArrow();
    }

    void Membrane(int side, Vector3 position, Vector2 size, Quaternion rotation, Color tint, float alpha)
    {
        if (alpha <= .005f) return;
        for (int pass = 0; pass < 2; pass++)
        {
            int index = side + pass * 2;
            var sheet = organSheets[index]; sheet.enabled = true;
            // Low-frequency membrane roll carries real depth without warping
            // the fine painted vein texture into a hard extruded plate.
            var vertices=sheetVertices[index];
            bool healing=action=="tower_mend"||action=="tower_mend_charge";
            float bend=healing?.075f:.13f;
            for(int y=0;y<=SheetY;y++)for(int x=0;x<=SheetX;x++){
                float u=x/(float)SheetX,w=y/(float)SheetY;
                float envelope=Mathf.Sin(u*Mathf.PI)*Mathf.Sin(w*Mathf.PI);
                vertices[y*(SheetX+1)+x]=new Vector3((u-.5f)*.5f,w-.5f,
                    envelope*(bend+.045f*Mathf.Sin(w*5-age*5+side*1.6f)));
            }
            sheetMeshes[index].vertices=vertices;sheetMeshes[index].RecalculateBounds();
            sheet.transform.SetPositionAndRotation(position - Face * Vector3.forward * (.015f * pass), rotation);
            sheet.transform.localScale = new Vector3(size.x, size.y, 1) * (pass == 0 ? 1 : 1.009f);
            Color color = tint; color.a = alpha * (pass == 0 ? .95f : .36f);
            sheetMaterials[index].SetColor("_Color", color);
            if (sheetMaterials[index].HasProperty("_Age")) sheetMaterials[index].SetFloat("_Age", age * 1.4f);
        }
    }

    void Stroke(int index, Func<float, Vector3> shape, float width, Color color, float alpha)
    {
        if (alpha <= .005f) return;
        var line = strokes[index]; line.enabled = true; line.widthMultiplier = width;
        color.a = Mathf.Clamp01(alpha); line.startColor = color; line.endColor = color;
        for (int j = 0; j < Samples; j++) points[j] = shape(j / (float)(Samples - 1));
        line.SetPositions(points);
    }
    void MendVeins(float load, float recover)
    {
        // Source only. No beam, travelling cure projectile or premature target
        // green cue; the real positive-HP event owns recipient presentation.
        for (int side = 0; side < 2; side++)
        {
            Vector3 sac = Organ(side == 0 ? "Sac.L" : "Sac.R", 1.8f);
            // Sac bones sit at the back-organ root, inside the torso. Project
            // the membrane forward onto the visible lobe surface, not behind it.
            sac += Vector3.up * .43f - Face * Vector3.forward * .94f;
            float breath = 1 + .09f * Mathf.Sin(age * 9 - side * .8f);
            float sign = side == 0 ? -1 : 1;
            Membrane(side, sac + Face * new Vector3(sign * .15f, .06f, -.05f), new Vector2(1.65f, 1.68f) * breath * (1-.12f*Ease((age-contact)/.08f)),
                Face * Quaternion.Euler(0, 0, -sign * 17), new Color(1, 1, .83f), load * recover);
            for (int j = 0; j < 6; j++)
            {
                int k = j;
                float pulse = .55f + .45f * Mathf.Sin(age * 11 - j * .8f);
                Stroke(side * 6 + j, q => sac + Face * new Vector3((k - 2.5f) * .115f * Mathf.Sin(q * Mathf.PI), (q - .5f) * .88f, -.10f - Mathf.Sin(q * Mathf.PI) * .14f),
                    .052f + .025f * pulse, new Color(1, .96f, .48f), load * recover * (.5f + .5f * pulse));
            }
        }
    }
    void CrownFan(float load, float recover)
    {
        Vector3 head = Organ("Head", 2.1f);
        float unfold = Ease(age / .4f);
        for (int side = 0; side < 2; side++)
        {
            float sign = side == 0 ? -1 : 1;
            Membrane(side, head + Face * new Vector3(sign * (.16f + unfold * .50f), .32f, -.24f), new Vector2(2.3f, 2.15f) * (.72f + unfold * .28f),
                Face * Quaternion.Euler(0, 0, sign * (12 + unfold * 12)), Color.white, load * recover * .92f);
        }
        for (int j = 0; j < 9; j++)
        {
            int k = j;
            float open = Ease((age - Mathf.Abs(j - 4) * .025f) / .33f);
            float angle = (Mathf.Lerp(-70, 70, j / 8f)+4*Mathf.Sin(j*7.1f)) * Mathf.Deg2Rad;
            Vector3 direction = Face * new Vector3(Mathf.Sin(angle), Mathf.Cos(angle), 0);
            Stroke(j, q => head + direction * (.16f + q * .85f * open) - Face * Vector3.forward * .12f + Face * Vector3.right * (Mathf.Sin(q * Mathf.PI) * .06f * (k % 2 == 0 ? 1 : -1)),
                .045f, new Color(1, .4f, .5f), load * recover * .8f);
            Stroke(9 + j, q => head + direction * (.18f + q * .82f * open) - Face * Vector3.forward * .13f,
                .012f, new Color(1, .89f, .60f), load * recover);
        }
    }
    void PounceCompression()
    {
        float post = age - contact;
        if (post < 0 || post > .5f || target == null) return;
        Vector3 end = target();
        Quaternion frame = Face;
        float spread = .3f + 3.4f * Ease(post / .043f);
        float fade = 1 - Ease((post - .10f) / .37f);
        for (int side = 0; side < 2; side++)
        {
            float sign = side == 0 ? -1 : 1;
            float plateFade = 1 - Ease((post - .085f) / .22f);
            Membrane(side, end + frame * new Vector3(sign * (.15f + post * 2.2f), -.25f - post * .6f, -.14f), new Vector2(spread * 1.7f, .8f + spread * .12f),
                frame * Quaternion.Euler(0, 0, sign * (76 - post * 48)), new Color(1, .82f, .52f), plateFade);
        }
        // Broad paired pressure wedges, a forward crush instead of radial fire.
        for (int j = 0; j < 8; j++)
        {
            int k = j; float side = j % 2 == 0 ? -1 : 1;
            Stroke(j, q => end + frame * new Vector3(side * (.18f + q * spread), (k / 2 - 1.5f) * .20f + Mathf.Sin(q * Mathf.PI) * .18f - post * .9f, .06f * k),
                j < 2 ? .14f : .055f, j < 2 ? new Color(1, .90f, .66f) : new Color(.75f, .59f, .32f), fade);
        }
        for (int j = 0; j < 48; j++)
        {
            float t = post - j % 3 * .009f; if (t < 0) continue;
            float side = j % 2 == 0 ? -1 : 1;
            Vector3 velocity = new Vector3(side * (7.8f + j % 7 * .85f), (j / 2 % 7 - 2.2f) * 1.15f, 0);
            Vector3 p = end + frame * new Vector3(velocity.x * t, velocity.y * t - t * t * 5.5f, -.20f);
            Vector3 trail = frame * (velocity + Vector3.down * (11 * t)).normalized * (.22f + j % 4 * .11f);
            float life = 1 - Ease((t - .13f) / .31f);
            Stroke(8 + j, q => p - trail * q, j % 4 == 0 ? .085f : .048f,
                j % 3 == 0 ? new Color(1, .98f, .75f) : new Color(1, .70f, .24f), life);
        }
    }
    void SonicArrow()
    {
        if (target == null) return;
        Vector3 start = Organ("Head", 2.15f), end = target();
        float post = age - contact;
        if (post < 0)
        {
            float travel = Ease((age - contact * .56f) / (contact * .44f));
            Vector3 center = Vector3.Lerp(start, end, travel);
            for (int side = 0; side < 2; side++)
            {
                float sign = side == 0 ? -1 : 1;
                Membrane(side, center + Face * new Vector3(sign * .15f, 0, -.08f), new Vector2(.95f, 1.65f - travel * .3f), Face * Quaternion.Euler(0, 0, sign * 16),
                    new Color(1, .83f, .9f), Ease(age / .12f));
            }
            Quaternion axis = Quaternion.LookRotation((end - start).sqrMagnitude > .001f ? (end - start).normalized : Vector3.forward);
            for (int j = 0; j < 7; j++)
            {
                int k = j; float radius = .18f + j * .065f;
                Stroke(j, q => center + axis * new Vector3(Mathf.Sin((q - .5f) * Mathf.PI * 1.5f) * radius, Mathf.Cos((q - .5f) * Mathf.PI * 1.5f) * radius, -.10f * k - Mathf.Abs(q - .5f) * .35f),
                    j % 2 == 0 ? .075f : .035f, j % 2 == 0 ? new Color(1, .4f, .62f) : new Color(1, .9f, .8f), Ease(age / .12f));
            }
        }
        else
        {
            float spread = 1 + 3.8f * Ease(post / .045f) * (1 - Ease((post - .12f) / .31f));
            float fade = 1 - Ease((post - .12f) / .4f);
            for (int side = 0; side < 2; side++)
            {
                float sign = side == 0 ? -1 : 1;
                Membrane(side, end + Face * new Vector3(sign * (.22f + post * 2.8f), 0, -.10f), new Vector2(spread * .90f, spread * 1.08f),
                    Face * Quaternion.Euler(0, 0, sign * (10 + post * 65)), Color.white, fade);
            }
            for (int j = 0; j < 16; j++)
            {
                int k = j; float side = j % 2 == 0 ? -1 : 1;
                Stroke(j, q => end + Face * new Vector3(side * (.07f + post * 2 + Mathf.Sin(q * Mathf.PI) * (.36f + k / 2 * .055f) * spread), (q - .5f) * 1.55f * spread, -.018f * k),
                    j < 4 ? .11f : .026f, j < 4 ? new Color(1, .65f, .83f) : new Color(1, .30f, .55f), fade * (j < 4 ? 1 : .7f));
            }
            // Bright fragments leave the two opened sound planes in parallel
            // bands, keeping the sonic direction readable instead of a cloud.
            for (int j = 0; j < 32; j++)
            {
                float t = post - j % 4 * .01f; if (t < 0) continue;
                float side = j % 2 == 0 ? -1 : 1;
                float band = (j / 2 % 8 - 3.5f) / 3.5f;
                Vector3 p = end + Face * new Vector3(side * (.18f + t * (6.8f + j % 3)), band * (1.0f + t * 2.3f), -.16f);
                Vector3 trail = Face * new Vector3(side * (.22f + j % 3 * .10f), band * .12f, 0);
                Stroke(16 + j, q => p - trail * q, j % 4 == 0 ? .082f : .045f,
                    j % 3 == 0 ? new Color(1, .96f, .84f) : new Color(1, .65f, .82f), 1 - Ease((t - .14f) / .29f));
            }
        }
    }

    public void Restore()
    {
        if (restored) return;
        restored = true;
        foreach (var entry in joints) if (entry.Value) { entry.Value.localRotation = rest[entry.Key]; entry.Value.localScale = scales[entry.Key]; }
        foreach (var line in strokes) if (line) line.enabled = false;
        foreach (var sheet in organSheets) if (sheet) sheet.enabled = false;
    }
    void OnDisable() { Restore(); }
    void OnDestroy() { Restore(); if (material) Destroy(material); foreach (var mesh in sheetMeshes) if (mesh) Destroy(mesh); foreach (var mat in sheetMaterials) if (mat) Destroy(mat); }
}
