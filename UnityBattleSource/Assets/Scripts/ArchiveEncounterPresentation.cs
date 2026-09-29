using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// Presentation only. Native rules own phase timing, healing and damage.
public sealed class ArchiveEncounterPresentation : MonoBehaviour
{
    readonly List<GameObject> objects = new List<GameObject>();
    readonly List<Material> materials = new List<Material>();
    Transform actor; string phase; float began;
    Transform swelling; Vector3 restingScale;
    int generation;
    Mesh shieldMesh; Transform shield; Material shieldMaterial;
    MainlineSpellMeshRound2 healSurface,stateSurface;
    MainlineBodyRound2 chargeBody;
    MainlineSpellMeshRound2 LocalSurface(string name){var go=new GameObject(name);go.transform.SetParent(transform,false);objects.Add(go);return go.AddComponent<MainlineSpellMeshRound2>();}
    public bool HasPresentation => objects.Count > 0;
    Material Glow(Color color) {
        var shader = Shader.Find("Sprites/Default");
        var material = new Material(shader); material.color = color; materials.Add(material); return material;
    }
    LineRenderer Line(string name, Color color, float width, int count) {
        var go = new GameObject(name); go.transform.SetParent(transform,false); objects.Add(go);
        var line=go.AddComponent<LineRenderer>(); line.material=Glow(color); line.widthMultiplier=width;
        line.positionCount=count; line.useWorldSpace=true; line.numCapVertices=4;
        line.widthCurve=new AnimationCurve(new Keyframe(0,.08f),new Keyframe(.22f,1),new Keyframe(.75f,.75f),new Keyframe(1,.05f));
        return line;
    }
    static Mesh BuildSealedPlates(){
        // Sealed ward: two uneven columns of light feathers shingled top to
        // bottom beside the wearer, outer ends wrapping back round the body.
        // Rounded inner ends, pointed outer tips, varied lengths and droop;
        // no ring, fan of equal ribs or lung-like smooth lobes.
        var mesh=new Mesh{name="Archive sealed plate armour"};
        var vertices=new List<Vector3>();var uv=new List<Vector2>();var centres=new List<Vector3>();var colors=new List<Color>();var triangles=new List<int>();
        const int along=16,across=8;
        // Per plate (top -> bottom): root height, length, droop in degrees.
        // Spacing, length and angle are deliberately uneven on each side.
        var sides=new[]{
            (side:-1f,heights:new[]{.31f,.21f,.075f,-.015f,-.16f},lengths:new[]{.52f,.43f,.48f,.33f,.30f},droops:new[]{-24f,-9f,2f,19f,27f},width:.085f),
            (side:1f,heights:new[]{.24f,.085f,-.005f,-.15f},lengths:new[]{.42f,.49f,.35f,.28f},droops:new[]{-17f,-4f,14f,31f},width:.08f)};
        int plate=0;
        foreach(var col in sides)for(int k=col.lengths.Length-1;k>=0;k--){
            // Lower plates first so each upper plate overlaps the one below it.
            float angle=col.droops[k]*Mathf.Deg2Rad;
            var axis=new Vector3(col.side*Mathf.Cos(angle),-Mathf.Sin(angle),0);
            var perp=new Vector3(-axis.y,axis.x,0)*col.side;
            var root=new Vector3(col.side*(.13f+.012f*k),col.heights[k],-.015f*(col.lengths.Length-k));
            float L=col.lengths[k],W=col.width*(1-.04f*k)*(k%2==0?1.06f:.94f);
            Vector3 Pos(float u,float x){
                float cap=Mathf.Sqrt(Mathf.Max(0f,1-Mathf.Pow(1-Mathf.Min(1f,u/.13f),2)));
                float tip=u>.45f?Mathf.Pow(Mathf.Max(0f,(1-u)/.55f),.85f):1f;
                float w=W*(.92f+.08f*Mathf.Sin(Mathf.PI*u))*Mathf.Min(cap,tip);
                return root+axis*(L*u)+perp*(x*w)
                    +Vector3.forward*(.11f*u*u-.022f*(1-Mathf.Abs(x)))   // wrap back round the body; a forged ridge, not a cushion
                    +perp*(.07f*u*u);                                   // tips sweep up like blade feathers
            }
            var centre=Pos(.5f,0);
            float delay=.06f*(col.lengths.Length-1-k)+(col.side>0?.05f:0f);
            int first=vertices.Count;
            for(int j=0;j<=along;j++)for(int i=0;i<=across;i++){
                float u=j/(float)along,v=i/(float)across;
                vertices.Add(Pos(u,v*2-1));uv.Add(new Vector2(v,u));centres.Add(centre);
                colors.Add(new Color(plate/37f,delay,0,1));
            }
            for(int j=0;j<along;j++)for(int i=0;i<across;i++){
                int a=first+j*(across+1)+i,b=a+1,c=a+across+1,d=c+1;
                triangles.Add(a);triangles.Add(c);triangles.Add(b);triangles.Add(b);triangles.Add(c);triangles.Add(d);
            }
            plate++;
        }
        mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetUVs(1,centres);mesh.SetColors(colors);mesh.SetTriangles(triangles,0);
        mesh.RecalculateNormals();mesh.RecalculateBounds();
        // Plates slide in from behind the spine in the vertex shader.
        mesh.bounds=new Bounds(mesh.bounds.center,mesh.bounds.size+Vector3.one*.4f);
        return mesh;
    }
    public void SetArchive(Transform target,string value) {
        Clear(); if(value=="clear" || !target)return; actor=target; phase=value; began=Time.time;
        if(value=="guard") {
            var go=new GameObject("Archive sealed plate armour");go.transform.SetParent(transform,false);objects.Add(go);shield=go.transform;
            shieldMesh=BuildSealedPlates();
            shieldMesh.RecalculateBounds();go.AddComponent<MeshFilter>().sharedMesh=shieldMesh;
            shieldMaterial=new Material(Resources.Load<Shader>("EnemySignature/ArchiveAegis"));materials.Add(shieldMaterial);
            shieldMaterial.SetFloat("_Open",0);
            shieldMaterial.SetTexture("_Matter",Resources.Load<Texture2D>("SpellSpectacle20260926/SpectacleMatter"));
            var shieldRenderer=go.AddComponent<MeshRenderer>();shieldRenderer.sharedMaterial=shieldMaterial;
            shieldRenderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;shieldRenderer.receiveShadows=false;
            // The first rendered frame can precede Update; place the fold at
            // its owner immediately so it never flashes at the scene origin.
            var camera=Camera.main;
            Vector3 center=target.position+Vector3.up*1.95f;
            Vector3 towardViewer=camera?camera.transform.position-center:Vector3.back;
            towardViewer.y=0;
            shield.position=center+towardViewer.normalized*1.25f;
            if(camera)shield.rotation=camera.transform.rotation;
            shield.localScale=Vector3.one*3.45f;
            return;
        }
        // Open phase is a local etched heart, not three naked gold wires.
        stateSurface=LocalSurface("Open archive engraved heart folds");
    }
    public void SetLeech(Transform target,string value) {
        Clear(); if(value=="off" || !target)return; actor=target; phase=value=="restrained"?"restrained":"leech"; began=Time.time;
        var handle=target.GetComponent<EnemyHandle>();
        swelling=handle ? handle.VisualRoot : null;
        if(swelling)restingScale=swelling.localScale;
        stateSurface=LocalSurface("Leech local violet digestive folds");
        var leech=target.GetComponentInChildren<MemoryLeechPresentation>();
        if(leech&&phase=="leech"){
            chargeBody=MainlineBodyRound2.Get(leech.gameObject);
            chargeBody.Begin(MainlineBodyRound2.Pose.LeechCharge,false,1,10000,10001);
        }
    }
    void Update() {
        // A committed repair acknowledges its scheduled contact even if an actor
        // dies meanwhile. Only explicit cancellation invalidates its generation.
        if(phase=="repair" || phase=="heal")return;
        if(!actor || !actor.gameObject.activeInHierarchy){if(HasPresentation)Clear();return;}
        float t=Time.time-began; var center=actor.position+Vector3.up*(phase=="guard"||phase=="open"?1.95f:1.15f);
        if(phase=="guard" && shield) {
            var camera=Camera.main;
            Vector3 towardViewer=camera?camera.transform.position-center:Vector3.back;
            towardViewer.y=0;
            shield.position=center+towardViewer.normalized*1.25f;
            // Heavy armour: only a slow, small sway.
            if(camera)shield.rotation=camera.transform.rotation*Quaternion.Euler(Mathf.Sin(t*.8f)*2.5f,Mathf.Sin(t*1.1f)*4f,Mathf.Sin(t*.6f)*2f);
            shieldMaterial.SetFloat("_ShimmerTime",t);
            // Plates slide out from behind the wearer one after another, then
            // lock with a short flash and a small kick. Presentation only; the
            // native guard timing and damage contract are untouched.
            float open=Mathf.Clamp01(t/.34f);
            float deploy=Mathf.Exp(-Mathf.Pow((t-.36f)/.09f,2));
            shieldMaterial.SetFloat("_Open",open);
            shieldMaterial.SetFloat("_DeployPulse",deploy);
            shield.localScale=Vector3.one*3.45f*(1+.05f*deploy);
        }
        if(swelling)swelling.localScale=restingScale*(phase=="leech" ? 1+.075f*Mathf.Clamp01(t/2) : 1);
        if(phase=="restrained"&&t>1.1f){Clear();return;}
        if(chargeBody)chargeBody.Sample(t);
        if(stateSurface){
            Vector3 right=Camera.main?Camera.main.transform.right:Vector3.right;
            Vector3 front=Camera.main?Vector3.ProjectOnPlane(Camera.main.transform.position-center,Vector3.up).normalized:Vector3.back;
            center+=front*(phase=="open"?.48f:.18f);
            stateSurface.Begin(t,0,phase=="open"?0:1);
            for(int i=0;i<3;i++){
                float h=Mathf.Repeat(i*.618f+.17f,1);
                if(phase=="open"){
                    Vector3 a=center+right*(h-.5f)*.60f-Vector3.up*(.24f+h*.18f),b=center+right*(h-.5f)*.42f+Vector3.up*(.29f+h*.32f);
                    stateSurface.Ribbon(a,a+right*(.15f+h*.2f)+Vector3.up*.24f,b-right*.18f,b,right+front*.2f,.13f+h*.075f,new Color(.98f,.63f,.22f,.83f),i);
                }else{
                    float gather=Mathf.SmoothStep(0,1,Mathf.Min(t/1.3f,1));
                    Vector3 a=center+right*(i==1?-1:1)*(.46f+h*.44f)*(1-gather*.25f)-Vector3.up*(.22f+h*.35f);
                    Vector3 b=center+right*(h-.5f)*.24f+Vector3.up*(.10f+h*.26f);
                    float fade=phase=="restrained"?1-Mathf.Clamp01(t/1.1f):Mathf.SmoothStep(0,1,t*4);
                    stateSurface.Ribbon(a,a+Vector3.up*(.36f+h*.26f)+front*.16f,b+right*(h-.5f)*.45f,b,right+front*.35f,.13f+h*.14f,new Color(.49f,.24f,.71f,fade*.87f),i+t*.4f);
                }
            }
            stateSurface.End();
        }
        for(int j=0;j<objects.Count;j++) {
            var line=objects[j].GetComponent<LineRenderer>(); if(!line)continue;
            if(phase=="open") {
                for(int k=0;k<line.positionCount;k++) {
                    float f=k/(float)(line.positionCount-1);
                    line.SetPosition(k,center+new Vector3((j-1)*.16f+Mathf.Sin(f*4.7f+j*.8f+t*.7f)*(.10f+j*.035f),f*(.52f+j*.14f)-.25f,-.4f+Mathf.Sin(f*3+j)*.09f));
                }
            } else {
                // Open spiralling strands stream INTO the body. Never draw a
                // full latitude ring, which resembles a target/debug overlay.
                float theta=Mathf.Repeat(j*.618034f+.17f,1)*Mathf.PI*2+t*(.37f+j*.07f);
                for(int k=0;k<line.positionCount;k++) {
                    float f=k/(float)(line.positionCount-1);
                    float radius=Mathf.Lerp(1.20f+Mathf.Repeat(j*.37f,1)*.6f,.18f,f);
                    float angle=theta+f*(.65f+j*.17f)+Mathf.Sin(f*5+j)*.11f;
                    var offset=new Vector3(Mathf.Cos(angle)*radius,Mathf.Sin(angle)*radius*.65f,-.24f-.24f*Mathf.Sin(f*Mathf.PI));
                    line.SetPosition(k,center+offset);
                }
            }
        }
    }
    public IEnumerator Repair(Transform source,Transform recipient,Action contact) {
        int ticket=generation;
        actor=source; phase="repair";
        // Keep the committed cast timing, but no source-to-target tether.
        // Healing visuals are emitted only after native rules confirm positive HP restored.
        for(float t=0;t<.85f;t+=Time.deltaTime){
            if(ticket!=generation)yield break;
            yield return null;
        }
        if(ticket!=generation)yield break;
        // Do not retarget when the frozen recipient disappears. Native resolves
        // this committed cast as a no-op heal and releases its pending action.
        contact?.Invoke();
        if(ticket==generation)Clear();
    }
    static Vector3 RepairAnchor(Transform root) {
        var renderers=root.GetComponentsInChildren<Renderer>();
        Bounds bounds=new Bounds(); bool found=false;
        foreach(var r in renderers) {
            if(!r.enabled || !(r is SkinnedMeshRenderer || r is MeshRenderer))continue;
            if(!found){bounds=r.bounds;found=true;}else bounds.Encapsulate(r.bounds);
        }
        var point=found?bounds.center:root.position+Vector3.up;
        // Lift clear of the model and slightly toward the camera, never ground-level.
        if(Camera.main)point+=(Camera.main.transform.position-point).normalized*.3f;
        return point;
    }
    readonly System.Collections.Generic.List<Material> healedMaterials=new System.Collections.Generic.List<Material>();
    public IEnumerator HealConfirmed(Transform recipient, Color? accent = null) {
        int ticket=generation;actor=recipient;phase="heal";
        var flowRoot=new GameObject("Confirmed local repair stitching");flowRoot.transform.SetParent(transform,false);objects.Add(flowRoot);
        healSurface=flowRoot.AddComponent<MainlineSpellMeshRound2>();var ownedSurface=healSurface;
        var affected=healedMaterials;
        if(recipient) foreach(var renderer in recipient.GetComponentsInChildren<Renderer>())
            foreach(var material in renderer.sharedMaterials)
                if(material && material.HasProperty("_HealPulse") && !affected.Contains(material))affected.Add(material);
        try {
            for(float t=0;t<1.05f;t+=Time.deltaTime){
                if(ticket!=generation || !recipient || !recipient.gameObject.activeInHierarchy)yield break;
                float glow=Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.10f))*(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((t-.35f)/.70f)));
                foreach(var material in affected)if(material)material.SetFloat("_HealPulse",glow*(.19f+.04f*Mathf.Sin(t*8)));
                if(ownedSurface){
                    Vector3 center=RepairAnchor(recipient),right=Camera.main?Camera.main.transform.right:Vector3.right;
                    ownedSurface.Begin(t);
                    for(int i=0;i<5;i++){
                        float h=Mathf.Repeat(i*.618f+.1f,1);Vector3 a=center+right*(h-.5f)*1.22f-Vector3.up*(.60f+h*.13f);
                        Vector3 b=a+Vector3.up*(1.02f+h*.43f)+right*(h-.4f)*.30f;
                        Color ink=accent??new Color(.44f,.87f,.51f);
                        Color seam=i%3==0?new Color(1,.81f,.32f,glow*.86f):
                            new Color(ink.r,ink.g,ink.b,glow*.87f);
                        ownedSurface.RibbonContinuous(a,a+Vector3.up*.42f-right*(.14f+h*.08f),
                            b+right*.20f+Vector3.up*.14f,b,right+Vector3.forward*.24f,
                            .10f+h*.055f,seam,i*1.7f);
                    }
                    ownedSurface.End();
                }
                yield return null;
            }
        } finally {
            if(ticket==generation)foreach(var material in affected)if(material)material.SetFloat("_HealPulse",0);
            if(flowRoot){objects.Remove(flowRoot);flowRoot.SetActive(false);Destroy(flowRoot);}
            if(healSurface==ownedSurface)healSurface=null;
        }
        if(ticket==generation)Clear();
    }
    public void ClearActor(Transform target){
        if(actor!=target)return;
        if(phase=="repair") { foreach(var go in objects)if(go)go.SetActive(false); return; }
        Clear();
    }
    public void Clear(){if(chargeBody)chargeBody.Stop();chargeBody=null;stateSurface=null;foreach(var m in healedMaterials)if(m)m.SetFloat("_HealPulse",0);healedMaterials.Clear();generation++;if(shieldMesh)Destroy(shieldMesh);shieldMesh=null;shield=null;shieldMaterial=null;if(swelling)swelling.localScale=restingScale;swelling=null;StopAllCoroutines();foreach(var go in objects)if(go){go.SetActive(false);Destroy(go);}objects.Clear();foreach(var m in materials)if(m)Destroy(m);materials.Clear();actor=null;phase=null;}
    void OnDisable()=>Clear();
}
