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
        Vector3 right=anchor?anchor.right:Vector3.right,up=Vector3.up;
        Vector3 front=Camera.main?(Camera.main.transform.position-transform.position).normalized:Vector3.back;
        Vector3 center=transform.position+up*.30f+front*.20f;
        float pulse=1-Mathf.Clamp01(hit),flow=.94f+.06f*Mathf.Sin(time*2.1f);
        surface.Begin(time,pulse*.35f);
        // Four open, unequal folds follow the body, never a spherical membrane,
        // closed perimeter, repeated ribs or a detached display plate.
        for(int i=0;i<4;i++){
            float side=i%2==0?-1:1,h=i<2?.42f:.04f;
            Vector3 start=center+right*side*(i<2?.47f:.23f)+up*(h-.23f);
            Vector3 end=center+right*side*(i<2?.24f:.06f)+up*(h+.23f+(i%2)*.07f);
            float loosen=broken?(1-opacity)*.16f:0;
            start+=right*side*loosen;end+=up*loosen;
            var tint=new Color(.25f+.22f*pulse,.67f+.15f*pulse,.86f,opacity*(.45f+.3f*pulse));
            surface.Ribbon(start,start+up*.17f+front*.035f,end+right*side*.11f-front*.025f,end,
                right+front*.35f,(i<2?.06f:.042f)*flow*(1+pulse*.25f),tint,i*2.19f);
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
