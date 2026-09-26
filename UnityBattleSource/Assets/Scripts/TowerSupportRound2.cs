using System;
using System.Collections.Generic;
using UnityEngine;

// D03/D05 authored body gestures and organ-specific light geometry. Visual only:
// recipient healing/empower status and all contact callbacks remain rule-owned.
[DefaultExecutionOrder(1810)]
public sealed class TowerSupportRound2 : MonoBehaviour
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
    TowerRigRound2 rig;
    TowerSurfaceRound2 delivery;
    EnemyHandle actor;
    Func<Vector3> target;
    string action;
    float age, contact;
    bool held, restored;
    const int Samples = 25;
    readonly Vector3[] points = new Vector3[Samples];
    static Quaternion Face => Camera.main ? Quaternion.LookRotation(Camera.main.transform.forward) : Quaternion.identity;

    public static bool Handles(string species) => species == "shellback" || species == "frilled-naga";

    public static TowerSupportRound2 Create(EnemyHandle actor, string intent, Func<Vector3> target, float contact, Transform owner)
    {
        var obj = new GameObject("D03 D05 distinct organs " + intent);
        obj.transform.SetParent(owner, false);
        var v = obj.AddComponent<TowerSupportRound2>();
        v.actor = actor; v.action = intent; v.target = target; v.contact = Mathf.Max(.1f, contact);
        v.rig = new TowerRigRound2(actor.VisualRoot, v.gameObject);
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
        v.delivery = new TowerSurfaceRound2(obj.transform, 9, "ChurchSpellArt/" + (shell ? "mend" : "corona"), false, shell ? .36f : .30f);
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
    void Update() { if (restored) return; rig?.Reset(); if (held) age += Time.deltaTime; }
    void Pose(string name, Vector3 euler)
    {
        rig.Rotate(name, euler);
    }
    void Scale(string name, Vector3 multiplier)
    {
        rig.Scale(name, multiplier);
    }
    Vector3 Organ(string name, float fallbackHeight)
    {
        return joints.TryGetValue(name, out var t) && t ? t.position : actor.EnemyRoot.position + Vector3.up * fallbackHeight;
    }
    static float Ease(float t) => Mathf.SmoothStep(0, 1, Mathf.Clamp01(t));

    void LateUpdate()
    {
        if (restored || !actor || !actor.gameObject.activeInHierarchy) return;
        rig.Capture(); delivery.Hide();
        float load = held ? Ease(age / .45f) : Ease(age / (contact * .55f));
        float strike = held ? 0 : Ease((age - contact * .68f) / (contact * .32f));
        float recover = held ? 1 : 1 - Ease((age - contact - .13f) / .42f);
        bool mend = action == "tower_mend" || action == "tower_mend_charge";
        bool empower = action == "tower_empower" || action == "tower_crown_charge";
        float crouch = load * (1 - .70f * strike);
        Pose("Pelvis", new Vector3(8 * crouch, mend ? -5 * load + 10 * strike : empower ? 8 * load : -9 * load + 16 * strike, 2 * crouch) * recover);
        if (mend || action == "tower_short_pounce")
        {
            Pose("Thigh.L", new Vector3(-24 * crouch, -4 * load, 0) * recover);
            Pose("Thigh.R", new Vector3(-30 * crouch, 5 * load, 0) * recover);
            Pose("Shin.L", new Vector3(31 * crouch, 0, 0) * recover);
            Pose("Shin.R", new Vector3(38 * crouch, 0, 0) * recover);
            Pose("Foot.L", new Vector3(-7 * crouch, 0, 0) * recover);
            Pose("Foot.R", new Vector3(-9 * crouch, 0, 0) * recover);
            float hop = action == "tower_short_pounce" ? Ease((age-contact*.32f)/(contact*.22f))*(1-Ease((age-contact*.62f)/(contact*.38f))) : 0;
            float landing = action == "tower_short_pounce" ? Ease((age-contact)/.045f)*(1-Ease((age-contact-.10f)/.18f)) : 0;
            rig.ShiftWorld("Pelvis", Vector3.up * ((-.04f*crouch+.17f*hop-.07f*landing)*recover));
        }
        if (mend)
        {
            // Shoulder girdle rises while the belly is guarded. The back sacs
            // inflate independently, then squeeze on the exact contact beat.
            Pose("Chest", new Vector3(-25 * load + 39 * strike, 8 * load - 14 * strike, 3 * load) * recover);
            Pose("Head", new Vector3(14 * load - 8 * strike, 0, 0) * recover);
            foreach (string side in new[] { "L", "R" })
            {
                float sign = side == "L" ? 1 : -1;
                Pose("UpperArm." + side, new Vector3(-48 * load + 18 * strike, 15 * sign * load, 30 * sign * load) * recover);
                Pose("Forearm." + side, new Vector3(-66 * load + 25 * strike, 0, -12 * sign * load) * recover);
                Pose("Hand." + side, new Vector3(25 * load, 0, 0) * recover);
                float pulse = (.055f * Mathf.Sin(age * 7 + (side == "L" ? 0 : 1.2f))) * load;
                Scale("Sac." + side, Vector3.one + new Vector3(.22f * load - .34f * strike + pulse, .30f * load - .40f * strike + pulse, .17f * load - .25f * strike) * recover);
            }
        }
        else if (action == "tower_short_pounce")
        {
            // Root travel belongs to ChurchDemonPresentation. Only local joints
            // prepare the crouch, plant, thrust and heavy landing here.
            Pose("Chest", new Vector3(30 * load - 63 * strike, -8 * load + 13 * strike, 0) * recover);
            Pose("Head", new Vector3(-16 * load + 27 * strike, 0, 0) * recover);
            foreach (string side in new[] { "L", "R" })
            {
                float sign = side == "L" ? 1 : -1;
                Pose("UpperArm." + side, new Vector3(28 * load - 103 * strike, 0, sign * 12 * load) * recover);
                Pose("Forearm." + side, new Vector3(-48 * load + 82 * strike, 0, 0) * recover);
                Pose("Hand." + side, new Vector3(28 * load - 45 * strike, 0, 0) * recover);
                Pose("Thigh." + side, new Vector3(-(side == "L" ? 29 : 35) * load + 40 * strike, sign * 5 * load, 0) * recover);
                Pose("Shin." + side, new Vector3((side == "L" ? 37 : 43) * load - 44 * strike, 0, 0) * recover);
                Scale("Sac." + side, Vector3.one + new Vector3(.03f, -.11f, .08f) * strike * recover);
            }
        }
        else if (empower)
        {
            Vector3 localDirection = actor.EnemyRoot.InverseTransformDirection((target == null ? actor.EnemyRoot.position + actor.EnemyRoot.forward : target()) - actor.EnemyRoot.position);
            float yaw = Mathf.Clamp(Mathf.Atan2(localDirection.x, localDirection.z) * Mathf.Rad2Deg, -32, 32);
            Pose("Chest", new Vector3(-32 * load + 12 * strike, yaw * load, 5 * load - 8 * strike) * recover);
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
            Pose("Tail1", new Vector3(0, 17 * load - 8 * strike, 0) * recover);
            Pose("Tail2", new Vector3(0, 26 * load - 14 * strike, 0) * recover);
            Pose("TailTip", new Vector3(8 * load, -18 * load + 15 * strike, 0) * recover);
        }
        else
        {
            // Sound arrow is a neck/chest snap, with both arms bracing low.
            Pose("Chest", new Vector3(-33 * load + 67 * strike, -12 * load + 22 * strike, 4 * load - 8 * strike) * recover);
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
        if (mend) { MendVeins(load, recover); if (!held) DeliverOrgan(true); }
        else if (empower) { CrownFan(load, recover); if (!held) DeliverOrgan(false); }
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
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(w*Mathf.PI)),.58f);
                float silhouette=taper*(.87f+.10f*Mathf.Sin(w*8.7f+side*1.4f)+.065f*Mathf.Sin(w*21.3f+side));
                vertices[y*(SheetX+1)+x]=new Vector3((u-.5f)*.56f*silhouette+.035f*Mathf.Sin(w*6.5f+side)*taper,w-.5f,
                    envelope*(bend+.065f*Mathf.Sin(w*5-age*4+side*1.6f))+(u-.5f)*(u-.5f)*.11f*Mathf.Sin(w*8+side));
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
        // These source veins remain on the sacs; DeliverOrgan separately owns
        // the amber courier. Only the real positive-HP event owns green HP text.
        for (int side = 0; side < 2; side++)
        {
            Vector3 sac = Organ(side == 0 ? "Sac.L" : "Sac.R", 1.8f);
            // Sac bones sit at the back-organ root, inside the torso. Project
            // the membrane forward onto the visible lobe surface, not behind it.
            sac += Vector3.up * .28f - Face * Vector3.forward * .43f;
            float breath = 1 + .09f * Mathf.Sin(age * 9 - side * .8f);
            float sign = side == 0 ? -1 : 1;
            Membrane(side, sac + Face * new Vector3(sign * .13f, .04f, -.03f), new Vector2(1.58f, 1.34f) * breath * (1-.12f*Ease((age-contact)/.08f)),
                Face * Quaternion.Euler(8, sign * 24, -sign * 28), new Color(1, 1, .83f), load * recover);
            for (int j = 0; j < 5; j++)
            {
                int k = j;
                float pulse = .55f + .45f * Mathf.Sin(age * 11 - j * .8f);
                Stroke(side * 6 + j, q => sac + Face * new Vector3((k - 1.8f) * (.085f+.014f*Mathf.Sin(k*5.1f)) * Mathf.Sin(q * Mathf.PI)+Mathf.Sin(q*6.8f+k*1.9f)*.028f, (q - .5f) * (.76f+.10f*Mathf.Sin(k*3.7f)), -.10f - Mathf.Sin(q * Mathf.PI) * .14f),
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
            // Open scale flames flank the physical frill; keep a broad gap
            // above the head instead of assembling the two halves into a halo.
            Membrane(side, head + Face * new Vector3(sign * (.26f + unfold * .31f), .16f, -.15f), new Vector2(2.05f, 1.51f) * (.72f + unfold * .28f),
                Face * Quaternion.Euler(12, sign * 27, sign * (37 + unfold * 17)), Color.white, load * recover * .92f);
        }
        // Five unequal curved scale veins, each attached to a different crown
        // lobe. They never make an equal-spaced radial fan.
        for (int j = 0; j < 5; j++)
        {
            int k=j; float sign=j%2==0?-1:1;
            float open=Ease((age-.025f*j)/.34f);
            Stroke(j, q => head+Face*new Vector3(sign*(.10f+q*(.38f+.09f*k))+.09f*Mathf.Sin(q*6.3f+k),
                .08f+q*(.58f+.14f*Mathf.Sin(k*2.6f))+.17f*Mathf.Sin(q*Mathf.PI),-.18f-.13f*Mathf.Sin(q*Mathf.PI)),
                j==2?.055f:.032f, j%2==0?new Color(1,.56f,.42f):new Color(1,.85f,.58f),load*recover*open);
        }
    }

    void DeliverOrgan(bool healing)
    {
        if(target==null)return;
        float release=contact*.48f, q=Ease((age-release)/Mathf.Max(.01f,contact-release));
        float post=age-contact, fade=post<0?1:1-Ease(post/.36f);
        if(age<release||fade<=0)return;
        Vector3 source=Organ(healing?"Sac.L":"Head",1.9f);
        if(healing)source+=Vector3.up*.35f;
        Vector3 end=target();
        Vector3 toward=end-source;
        Vector3 sideways=Vector3.Cross(Vector3.up,toward.sqrMagnitude>.001f?toward.normalized:Vector3.forward).normalized;
        // One recipient-bound delivery, with warm painted volume around a
        // narrower light seam. Healing folds inward; crown power opens over
        // the shoulders. Neither path performs a damage-style detonation.
        for(int i=0;i<3;i++)
        {
            float trail=Mathf.Clamp01(q-i*.08f);
            Vector3 p=Vector3.Lerp(source,end,trail)+Vector3.up*Mathf.Sin(trail*Mathf.PI)*(.35f+i*.07f);
            if(post>=0)p=end+Face*new Vector3((i-1)*(healing?.43f:.54f)-post*(healing?.30f:.62f),.18f+post*(healing?.38f:.72f),-.22f);
            delivery.Leaf(i,p,Face*Quaternion.Euler(12,i*19-18,(i-1)*(healing?19:32)-post*55),
                new Vector2(healing?1.05f:1.14f,healing?1.31f:1.40f)*(post<0?.81f:1-post*.70f),
                healing?new Color(1,.87f,.43f):new Color(1,.57f,.72f),fade*(i==0?.94f:.74f),age,.42f,
                new Rect(i%2==0?0:.5f,0,.5f,1),Mathf.Max(0,post));
            delivery.Leaf(3+i,p+Face*new Vector3(0,.05f,-.045f),Face*Quaternion.Euler(8,i*13-13,(i-1)*(healing?17:28)-post*48),
                new Vector2(healing?.43f:.47f,healing?.98f:1.04f)*(post<0?.78f:1-post*.65f),
                healing?new Color(1,.99f,.77f):new Color(1,.88f,.81f),fade*(i==0?.78f:.58f),age,.30f,
                new Rect(i%2==0?0:.5f,0,.5f,1),Mathf.Max(0,post)*1.2f);
            // The courier's three unequal painted folds make the transfer
            // readable between the actual source and the fixed beneficiary.
            // Unlike a damage beam they taper, bend, then fold into the body.
            int k=i;float progress=Mathf.Clamp01(q-i*.06f);
            if(progress>.03f)delivery.Stroke(6+i,u=>{
                    float path=u*progress,bow=Mathf.Sin(path*Mathf.PI);
                    return Vector3.Lerp(source,end,path)+Vector3.up*bow*(healing?.37f+k*.08f:.22f+k*.10f)
                        +sideways*Mathf.Sin(path*(4.1f+k*.7f)+age*2.8f+k*1.3f)*bow*(.17f+k*.035f);
                },(healing?.23f:.26f)-k*.033f,
                healing?k==0?new Color(1,.91f,.51f):new Color(1,.98f,.72f)
                    :k==0?new Color(1,.40f,.63f):new Color(1,.84f,.70f),
                fade*(post<0?1:1-Ease(post/.20f))*(.82f-k*.15f),age,.13f+k*.02f);
        }
    }

    void PounceCompression()
    {
        float post = age - contact;
        if (post < 0 || post > .5f || target == null) return;
        Vector3 end = target(); end.y=.12f;
        Quaternion frame = Face;
        float spread = .3f + 3.4f * Ease(post / .043f);
        float fade = 1 - Ease((post - .10f) / .37f);
        for (int side = 0; side < 2; side++)
        {
            float sign = side == 0 ? -1 : 1;
            float plateFade = 1 - Ease((post - .085f) / .22f);
            Membrane(side, end + new Vector3(sign * (.24f + post * 2.2f), .08f + Mathf.Sin(Mathf.Clamp01(post/.35f)*Mathf.PI)*.14f, -.14f), new Vector2(spread * 2.0f, 1.10f + spread * .16f),
                Quaternion.Euler(67, sign * (19 + post * 21), sign * 7), new Color(1, .82f, .52f), plateFade);
            // Gold-white inner compression is low against the floor rather
            // than reusing the upright healing petals.
            delivery.Leaf(side,end+new Vector3(sign*(.22f+post*1.7f),.095f,-.18f),
                Quaternion.Euler(71,sign*(18+post*18),sign*9),
                new Vector2(spread*.92f, .60f+spread*.11f),new Color(1,.96f,.73f),
                plateFade*.76f,age,.28f,new Rect(side==0?0:.5f,0,.5f,1),post*2);
        }
        // Broad paired pressure wedges, a forward crush instead of radial fire.
        for (int j = 0; j < 8; j++)
        {
            int k = j; float side = j % 2 == 0 ? -1 : 1;
            Stroke(j, q => end + frame * new Vector3(side * (.18f + q * spread), .06f + Mathf.Sin(q * Mathf.PI) * (.16f+.12f*Mathf.Sin(k*3.7f)) - post * .25f, .09f * k + Mathf.Sin(q*6.3f+k)*.14f),
                j < 2 ? .14f : .055f, j < 2 ? new Color(1, .90f, .66f) : new Color(.75f, .59f, .32f), fade);
        }
        for (int j = 0; j < 48; j++)
        {
            float t = post - j % 3 * .009f; if (t < 0) continue;
            float side = j % 2 == 0 ? -1 : 1;
            Vector3 velocity = new Vector3(side * (7.8f + j % 7 * .85f), (.25f+.75f*Mathf.Abs(Mathf.Sin(j*2.7f))) * 2.7f, Mathf.Sin(j*5.4f)*1.4f);
            Vector3 p = end + frame * new Vector3(velocity.x * t, velocity.y * t - t * t * 5.5f, -.20f);
            Vector3 trail = frame * (velocity + Vector3.down * (11 * t)).normalized * (.22f + j % 4 * .11f);
            float life = 1 - Ease((t - .13f) / .31f);
            Stroke(8 + j, q => p - trail * q, j % 4 == 0 ? .085f : .048f,
                j % 3 == 0 ? new Color(1, .98f, .75f) : new Color(1, .70f, .24f), life);
        }
    }
    void SonicArrow()
    {
        if(target==null)return;
        Vector3 start=Organ("Head",2.15f),end=target();
        float post=age-contact;
        float q=Ease((age-contact*.56f)/(contact*.44f));
        float fade=post<0?Ease(age/.12f):1-Ease((post-.12f)/.38f);
        float peak=post<0?1:1+3.8f*Ease(post/.045f)*(1-Ease((post-.12f)/.31f));
        var axis=(end-start).sqrMagnitude>.001f?(end-start).normalized:Vector3.forward;
        var facing=Quaternion.FromToRotation(Vector3.up,axis);
        Vector3 center=post<0?Vector3.Lerp(start,end,q):end;
        for(int i=0;i<3;i++)
        {
            float side=i==0?-1:1;
            Vector3 p=center;
            if(post<0)p-=axis*i*.24f;
            else p+=Face*new Vector3(side*(.10f+post*(1.7f+i*.5f)),(i-1)*.12f,-.08f*i);
            Quaternion rotation=post<0?facing*Quaternion.Euler(0,i*53,side*11):
                Face*Quaternion.Euler(i*7-8,side*(25+post*80),side*(20+i*31+post*42));
            delivery.Leaf(i,p,rotation,new Vector2(post<0?.42f:peak*(.68f+i*.09f),post<0?1.6f:peak*(.78f+i*.14f)),
                i==1?new Color(1,.95f,.81f):new Color(1,.68f,.80f),fade,age,.36f,
                new Rect(i%2==0?0:.5f,0,.5f,1),Mathf.Max(0,post-.10f)*2);
            delivery.Leaf(3+i,p+Face*new Vector3(0,0,-.045f),rotation,
                new Vector2(post<0?.18f:peak*(.25f+i*.04f),post<0?1.32f:peak*(.57f+i*.10f)),
                i==1?new Color(1,1,.88f):new Color(1,.88f,.78f),fade*.80f,age,.28f,
                new Rect(i%2==0?0:.5f,0,.5f,1),Mathf.Max(0,post-.10f)*2);
        }
        // Unequal, nonclosing pressure crests bend around the arrow; no full
        // hoop, parallel rack or pasted full circular crown at contact.
        for(int j=0;j<6;j++)
        {
            int k=j;float side=j%2==0?-1:1;
            Stroke(j,u=>{
                float length=(.62f+.15f*Mathf.Sin(k*4.3f))*peak;
                return center+Face*new Vector3(side*(.10f+Mathf.Sin(u*2.7f+k*.19f)*length+Mathf.Max(0,post)*2),
                    (u-.42f)*(.95f+.23f*k)*peak+.08f*Mathf.Sin(u*7+k),-.06f*k+.15f*Mathf.Sin(u*Mathf.PI));
            },j<2?.075f:.027f,j<2?new Color(1,.81f,.65f):new Color(1,.35f,.63f),fade*(j<2?1:.7f));
        }
        if(post<0)return;
        for(int j=0;j<28;j++)
        {
            float t=post-(j%4)*.011f;if(t<0)continue;
            float a=j*2.39996f,r=t*(4.7f+(j%5)*.81f);
            Vector3 p=end+Face*new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r*.58f-t*t*2,Mathf.Sin(a*1.7f)*t);
            Vector3 tail=Face*new Vector3(Mathf.Cos(a),Mathf.Sin(a)*.58f,0)*(.17f+j%4*.09f);
            Stroke(12+j,u=>p-tail*u,j%4==0?.073f:.032f,
                j%3==0?new Color(1,.94f,.70f):new Color(1,.43f,.70f),1-Ease((t-.14f)/.29f));
        }
    }

    public void Restore()
    {
        if (restored) return;
        restored = true;
        rig?.Reset(); delivery?.Hide();
        foreach (var line in strokes) if (line) line.enabled = false;
        foreach (var sheet in organSheets) if (sheet) sheet.enabled = false;
    }
    void OnDisable() { Restore(); }
    void OnDestroy() { Restore(); delivery?.Dispose(); if (material) Destroy(material); foreach (var mesh in sheetMeshes) if (mesh) Destroy(mesh); foreach (var mat in sheetMaterials) if (mat) Destroy(mat); }
}
