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
    static Mesh BuildOpenAegis(){
        // Protection is an overlapping, asymmetric cuirass of broad curled fins.
        // No four-corner silhouette or complete engraved ring survives as a border.
        var mesh=new Mesh{name="Archive asymmetric layered cuirass folds"};
        var vertices=new List<Vector3>();var uv=new List<Vector2>();var colors=new List<Color>();var triangles=new List<int>();
        for(int lobe=0;lobe<3;lobe++)for(int j=0;j<36;j++)for(int cross=0;cross<10;cross++){
            int n=vertices.Count;
            for(int corner=0;corner<4;corner++){
                float u=(j+(corner==1||corner==2?1:0))/36f;
                float v=(cross+(corner>=2?1:0))/10f,x=v*2-1;
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.52f);
                float width=(lobe==0?.34f:lobe==1?.29f:.24f)*taper*(.84f+.12f*Mathf.Sin(u*8.8f+lobe)+.08f*Mathf.Sin(u*19.3f-lobe));
                Vector3 a=lobe==0?new Vector3(-.40f,-.27f,.02f):lobe==1?new Vector3(.39f,.23f,.18f):new Vector3(-.16f,-.48f,.26f);
                Vector3 d=lobe==0?new Vector3(-.05f,.52f,.01f):lobe==1?new Vector3(.06f,-.39f,.16f):new Vector3(.47f,-.09f,.21f);
                Vector3 side=lobe==0?new Vector3(.90f,-.28f,0):lobe==1?new Vector3(.93f,.36f,0):new Vector3(-.41f,.89f,0);
                Vector3 bow=lobe==0?new Vector3(-.11f,.04f,.11f):lobe==1?new Vector3(.10f,.02f,.13f):new Vector3(.05f,-.09f,.10f);
                Vector3 center=Vector3.Lerp(a,d,u)+bow*Mathf.Sin(u*Mathf.PI);
                float uneven=x*width*(1+.14f*x*Mathf.Sin(u*10+lobe));
                float curled=(.065f+width*.27f)*Mathf.Sin(v*Mathf.PI)+width*x*Mathf.Sin(u*5.5f+lobe)*.38f;
                vertices.Add(center+side*uneven+Vector3.forward*curled);
                uv.Add(new Vector2(v,u));colors.Add(new Color(.88f+lobe*.04f,.95f,1,.88f));
            }
            triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
        }
        mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();mesh.RecalculateBounds();return mesh;
    }
    public void SetArchive(Transform target,string value) {
        Clear(); if(value=="clear" || !target)return; actor=target; phase=value; began=Time.time;
        if(value=="guard") {
            var go=new GameObject("Archive layered open cuirass ward");go.transform.SetParent(transform,false);objects.Add(go);shield=go.transform;
            shieldMesh=BuildOpenAegis();
            shieldMesh.RecalculateBounds();go.AddComponent<MeshFilter>().sharedMesh=shieldMesh;
            shieldMaterial=new Material(Resources.Load<Shader>("EnemySignature/ArchiveAegis"));materials.Add(shieldMaterial);
            shieldMaterial.mainTexture=Resources.Load<Texture2D>("EnemySignature/ArchiveAegisV2");
            go.AddComponent<MeshRenderer>().sharedMaterial=shieldMaterial;
            // The first rendered frame can precede Update; place the fold at
            // its owner immediately so it never flashes at the scene origin.
            var camera=Camera.main;
            Vector3 center=target.position+Vector3.up*1.95f;
            Vector3 towardViewer=camera?camera.transform.position-center:Vector3.back;
            towardViewer.y=0;
            shield.position=center+towardViewer.normalized*1.25f;
            if(camera)shield.rotation=camera.transform.rotation;
            shield.localScale=Vector3.one*2.32f;
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
            if(camera)shield.rotation=camera.transform.rotation*Quaternion.Euler(Mathf.Sin(t*.8f)*6,Mathf.Sin(t*1.1f)*9,Mathf.Sin(t*.6f)*7);
            shieldMaterial.SetFloat("_ShimmerTime",t);
            // The defensive folds gather close, snap open, then settle around
            // the wearer. This is presentation only; the native guard timing
            // and damage contract are untouched.
            float open=Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.17f));
            float settle=Mathf.SmoothStep(0,1,Mathf.Clamp01((t-.17f)/.25f));
            float size=Mathf.Lerp(Mathf.Lerp(2.32f,5.10f,open),3.70f,settle);
            float deploy=Mathf.Exp(-Mathf.Pow((t-.17f)/.17f,2));
            shieldMaterial.SetFloat("_DeployPulse",deploy);
            shield.localScale=Vector3.one*(size+Mathf.Sin(t*1.7f)*.035f);
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
