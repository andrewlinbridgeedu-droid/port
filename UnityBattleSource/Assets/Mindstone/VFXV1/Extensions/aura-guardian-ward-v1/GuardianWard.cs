using UnityEngine;
namespace Mindstone.VFXV1 {
// The Q1 guard's control-seal ward: one oval light shield round the whole body
// (user, 2026-10-05). The old four hairline seams were invisible on the phone.
[DefaultExecutionOrder(200)]
public sealed class GuardianWard : MonoBehaviour, ISpellExtension {
    OvalLightShield shell; Transform anchor; float started, hitAt=-100; bool external, broken;
    public static GuardianWard Attach(Transform target) {
        var root=new GameObject("Guardian · Arcane Ward"); root.transform.SetParent(target,false);
        var ward=root.AddComponent<GuardianWard>(); ward.anchor=target;
        ward.Build(); return ward;
    }
    void Build() {
        if(shell)return;
        shell=OvalLightShield.Attach(anchor?anchor:transform,OvalLightShield.Preset.Ward);
        started=Time.time;
    }
    public void Impact() { hitAt=Time.time; if(shell)shell.Impact(); }
    public void Break() {
        if(broken)return;
        broken=true;
        if(shell)shell.Break();
        shell=null;
    }
    public void ImpactAfter(float delay) { CancelInvoke(nameof(Impact)); Invoke(nameof(Impact),delay); }
    void LateUpdate() {
        if(external||broken||!shell)return;
        shell.SetOpacity(Mathf.Clamp01((Time.time-started)/.7f));
    }
    public void Initialize(SpellSpec spell,SpellLayerSpec layer,int seed) { external=true;Build(); }
    public void Sample(in SpellSample sample) {
        if(!shell)return;
        float p=sample.NormalizedTime;
        shell.SetOpacity(Mathf.SmoothStep(0,1,p/.18f)*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.75f,1,p))));
    }
    public void Interrupt() { Cleanup(); }
    public void Cleanup() { if(shell){Destroy(shell.gameObject);} shell=null; }
    void OnEnable() { if(anchor&&!external&&!shell){broken=false;Build();} }
    void OnDisable() { CancelInvoke();Cleanup();broken=false; }
    void OnDestroy() { Cleanup(); }
}
}
