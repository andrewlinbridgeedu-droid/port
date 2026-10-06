using UnityEngine;
namespace Mindstone.VFXV1 {
// One bounded mesh/material owner, shared by the encounter and deterministic spell preview.
[DefaultExecutionOrder(200)]
public sealed class GuardianWard : MonoBehaviour, ISpellExtension {
    GameObject shell; MainlineSpellMeshRound2 surface; Transform anchor, bodyAnchor; float started, hitAt=-100; bool external;
    public static GuardianWard Attach(Transform target) {
        var root=new GameObject("Guardian · Arcane Ward"); root.transform.SetParent(target,false);
        var ward=root.AddComponent<GuardianWard>(); ward.anchor=target;
        var animator=target.GetComponentInChildren<Animator>();
        if(animator && animator.isHuman) ward.bodyAnchor=animator.GetBoneTransform(HumanBodyBones.Spine);
        if(!ward.bodyAnchor) foreach(var bone in target.GetComponentsInChildren<Transform>()) if(bone.name=="Hips") { ward.bodyAnchor=bone; break; }
        ward.Build(); return ward;
    }
    void Build() {
        if(shell)return;
        shell=new GameObject("Guardian fitted open armour seams");
        shell.transform.SetParent(transform,false);
        surface=shell.AddComponent<MainlineSpellMeshRound2>();
        started=Time.time;
    }
    public void Impact() { hitAt=Time.time; }
    bool broken;
    public void Break() {
        if(broken)return;
        broken=true;
        StartCoroutine(Shatter());
    }
    System.Collections.IEnumerator Shatter() {
        Impact();
        for(float elapsed=0; elapsed<.7f; elapsed+=Time.deltaTime) {
            if(!shell)yield break;
            Draw(Time.time-started,1-elapsed/.7f,elapsed/.7f);
            yield return null;
        }
        Cleanup();
    }
    public void ImpactAfter(float delay) { CancelInvoke(nameof(Impact)); Invoke(nameof(Impact),delay); }
    void LateUpdate() {
        if(external||broken||!shell)return;
        // Anchor in world units so imported skeleton scale cannot distort the shell.
        transform.position=bodyAnchor ? bodyAnchor.position : anchor.position+Vector3.up*1.25f;
        transform.rotation=Quaternion.identity; transform.localScale=new Vector3(1/anchor.lossyScale.x,1/anchor.lossyScale.y,1/anchor.lossyScale.z);
        Draw(Time.time-started,Mathf.Clamp01((Time.time-started)/.7f),Mathf.Clamp01((Time.time-hitAt)/.8f));
    }
    void Draw(float time,float opacity,float hit) {
        if(!surface)return;
        // An oval shell that wraps the whole body (user, 2026-10-05: 改成一个椭圆的笼罩全身的盾).
        // Meridians of unequal span, width and spacing, so it reads as a living
        // crystal shroud rather than a wireframe globe; it never closes into rings.
        Vector3 up=Vector3.up;
        Vector3 front=Camera.main?(Camera.main.transform.position-transform.position).normalized:Vector3.back;
        front.y=0; if(front.sqrMagnitude<1e-4f)front=Vector3.back; front.Normalize();
        Vector3 right=Vector3.Cross(up,front).normalized;
        // Size from the body's renderers, so a tall armoured guard is wrapped
        // whole and a small puppet is not swimming in it.
        Vector3 center=transform.position+up*.05f;
        float rx=.82f, ry=1.22f;
        if(anchor){
            bool any=false; var b=new Bounds(anchor.position,Vector3.zero);
            foreach(var r in anchor.GetComponentsInChildren<Renderer>()){ if(!r || r.GetComponentInParent<GuardianWard>()) continue; if(!any){b=r.bounds;any=true;} else b.Encapsulate(r.bounds); }
            if(any && b.size.y>.5f){ center=b.center+up*.05f; rx=Mathf.Max(b.extents.x,b.extents.z)*1.12f+.08f; ry=b.extents.y*1.08f+.08f; }
        }
        float pulse=1-Mathf.Clamp01(hit),flow=.95f+.05f*Mathf.Sin(time*1.7f);
        float breathe=1f+.035f*Mathf.Sin(time*1.3f)+pulse*.08f;
        float loosen=broken?(1-opacity)*.5f:0;
        surface.Begin(time,pulse*.35f);
        float[] azimuth={-62f,-27f,8f,41f,74f,-96f,106f};
        float[] span={.92f,.78f,.98f,.84f,.72f,.6f,.66f};
        float[] widths={.16f,.11f,.19f,.13f,.10f,.09f,.08f};
        const float k=1.3333f; // cubic Bezier reach for a half ellipse
        for(int i=0;i<azimuth.Length;i++){
            float a=azimuth[i]*Mathf.Deg2Rad;
            Vector3 dir=(right*Mathf.Sin(a)+front*Mathf.Cos(a)).normalized;
            float facing=Mathf.Clamp01(Vector3.Dot(dir,front)*.5f+.65f); // back meridians dimmer
            float r=rx*breathe*(1+loosen), h=ry*breathe;
            float lo=-(span[i]), hi=span[i];
            Vector3 bottom=center+up*(h*lo), top=center+up*(h*hi);
            Vector3 reach=dir*r*k*Mathf.Sin(Mathf.Acos(Mathf.Clamp(span[i],0,1)))+dir*r*k*(1-span[i]);
            Vector3 bulge=dir*r*k;
            Vector3 p1=bottom+bulge*.9f+dir*r*(1-span[i])*.4f, p2=top+bulge*.9f+dir*r*(1-span[i])*.4f;
            bottom+=dir*r*Mathf.Sqrt(Mathf.Max(0,1-span[i]*span[i]))*.55f; top+=dir*r*Mathf.Sqrt(Mathf.Max(0,1-span[i]*span[i]))*.55f;
            var tint=new Color(.30f+.22f*pulse,.70f+.14f*pulse,.95f,opacity*facing*(.42f+.3f*pulse));
            Vector3 across=Vector3.Cross(up,dir).normalized;
            surface.Ribbon(bottom,p1,p2,top,across+front*.2f,widths[i]*flow*(1+pulse*.3f)*(1-loosen*.5f),tint,i*2.19f);
        }
        // Two short, offset girdle arcs round the chest and hips: open, unequal, never a full ring.
        for(int g=0;g<2;g++){
            float y=g==0?.38f:-.34f, r=rx*breathe*Mathf.Sqrt(1-(y/ry)*(y/ry))*(1+loosen);
            float a0=(g==0?-70f:-20f)*Mathf.Deg2Rad, a1=(g==0?35f:95f)*Mathf.Deg2Rad;
            Vector3 c=center+up*y;
            Vector3 P(float a){return c+(right*Mathf.Sin(a)+front*Mathf.Cos(a))*r;}
            float am=(a0+a1)*.5f, q=(a1-a0)*.5f; float kk=1.3333f*Mathf.Tan(q*.5f)/1f;
            Vector3 t0=(right*Mathf.Cos(a0)-front*Mathf.Sin(a0))*r*kk, t1=(right*Mathf.Cos(a1)-front*Mathf.Sin(a1))*r*kk;
            var tint=new Color(.5f+.2f*pulse,.82f,1f,opacity*(.30f+.25f*pulse));
            surface.Ribbon(P(a0),P(a0)+t0,P(a1)-t1,P(a1),up+front*.15f,(g==0?.07f:.055f)*flow,tint,9f+g*3.1f);
        }
        surface.End();
    }
    public void Initialize(SpellSpec spell,SpellLayerSpec layer,int seed) { external=true;Build(); }
    public void Sample(in SpellSample sample) {
        transform.position=sample.Target+Vector3.up*.8f;
        float p=sample.NormalizedTime;
        Draw(sample.AbsoluteTime,Mathf.SmoothStep(0,1,p/.18f)*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.75f,1,p))),Mathf.Clamp01((p-.38f)*2.5f));
    }
    public void Interrupt() { Cleanup(); }
    public void Cleanup() { if(shell){shell.SetActive(false);Destroy(shell);}shell=null;surface=null; }
    void OnEnable() { if(anchor&&!external&&!shell){broken=false;Build();} }
    void OnDisable() { CancelInvoke();StopAllCoroutines();Cleanup();broken=false; }
    void OnDestroy() { Cleanup(); }
}
}
