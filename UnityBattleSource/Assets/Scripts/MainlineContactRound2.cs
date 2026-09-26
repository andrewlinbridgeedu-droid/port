using UnityEngine;

// Exact replacement of the old presentation-only Play(target,memory) hook.
public sealed class MainlineContactRound2 : MonoBehaviour
{
    MainlineDistinct20260925 distinct;
    Transform recipient;bool memory,charged;float age;MainlineSpellMeshRound2 mesh;BattlePrototype battle;
    public static void Play(Transform target,bool core,bool eliteCharge=false){
        if(!target)return;var root=new GameObject(core?"Memory shard contact":eliteCharge?"Elite charged blade rupture":"Guard oblique contact tear");
        var fx=root.AddComponent<MainlineContactRound2>();fx.recipient=target;fx.memory=core;fx.charged=eliteCharge&&!core;
        fx.mesh=root.AddComponent<MainlineSpellMeshRound2>();fx.battle=FindFirstObjectByType<BattlePrototype>();fx.Draw();
    }
    void Update(){age+=Time.deltaTime;if(age>=.65f||!recipient||!recipient.gameObject.activeInHierarchy||(battle&&!battle.NativeCombatEnabled)){gameObject.SetActive(false);Destroy(gameObject);return;}Draw();}
    void Draw(){
        if(!recipient||!mesh)return;
        if(memory){if(!distinct)distinct=gameObject.AddComponent<MainlineDistinct20260925>();distinct.Memory(recipient.position+Vector3.up*1.05f,age,true);return;}
        var cam=Camera.main;Vector3 r=cam?cam.transform.right:Vector3.right,u=cam?cam.transform.up:Vector3.up,f=cam?cam.transform.forward:Vector3.forward;
        Vector3 p=recipient.position+Vector3.up*1.05f;float t=EnemyImpactEnvelope20260921.Sample(age/.65f),open=1-Mathf.Exp(-t*7),fade=Mathf.Pow(1-t,1.6f);
        mesh.Begin(age,Mathf.Exp(-t*9));
        if(memory){
            // Three offset torn memory folds, not six spokes sharing a hub.
            // Broad interiors keep the blue material and contact area readable.
            float span=.20f+open*1.65f,width=.32f+open*.68f;
            Vector3 q=p-f*.08f;
            mesh.Ribbon(q+(-r*1.15f-u*.38f)*span,q+(-r*.64f+u*.20f)*span,
                q+(r*.18f+u*.63f)*span,q+(r*.97f+u*.40f)*span,u,.37f*width,new Color(.38f,.62f,1,fade),.7f);
            q=p+f*.12f;
            mesh.Ribbon(q+(-r*.74f+u*.40f)*span,q+(-r*.28f+u*.61f)*span,
                q+(r*.48f-u*.15f)*span,q+(r*.62f-u*.58f)*span,r+u*.3f,.28f*width,new Color(.24f,.48f,.88f,fade),2.3f);
            q=p-f*.21f;
            mesh.Ribbon(q+(r*.50f+u*.20f)*span,q+r*.96f*span,
                q+(r*1.05f-u*.42f)*span,q+(r*1.24f-u*.27f)*span,u,.24f*width,new Color(.53f,.76f,1,fade),4.1f);
        }else if(charged){
            // The elite's retained force tears one heavy, open pressure wedge.
            // Ordinary guard attacks keep their smaller red oblique contact.
            float span=.22f+open*2.25f;
            Vector3 q=p-f*.13f;
            mesh.RibbonContinuous(q-r*.28f-u*.47f*span,
                q-r*.82f*span+u*.31f*span,
                q+r*.37f*span+u*.81f*span,
                q+r*1.07f*span-u*.36f*span,u+f*.3f,.36f+open*.72f,
                new Color(.68f,.10f,.035f,fade*.96f),1.4f);
            q=p+f*.15f;
            mesh.RibbonContinuous(q-r*.65f*span-u*.18f*span,
                q-r*.19f*span+u*.42f*span,
                q+r*.52f*span+u*.63f*span,
                q+r*.85f*span-u*.25f*span,r+u*.32f,.13f+open*.25f,
                new Color(1,.63f,.17f,fade*.94f),3.6f);
            q=p-f*.26f;
            mesh.RibbonContinuous(q-r*.43f*span-u*.39f*span,
                q-r*.47f*span-u*.03f*span,
                q+r*.27f*span-u*.48f*span,
                q+r*.73f*span-u*.74f*span,u+f*.2f,.17f+open*.30f,
                new Color(.22f,.035f,.075f,fade*.76f),5.1f);
        }else{
            // The ordinary guard keeps one red oblique slash, now with a
            // substantial torn interior and a short hot edge at true contact.
            float reach=.52f+open*1.96f;
            mesh.RibbonContinuous(p-r*reach-u*.32f,p-r*reach*.64f+u*.73f,
                p+r*reach*.46f+u*.68f,p+r*reach-u*.43f,u,.32f+open*.24f,
                new Color(.88f,.12f,.035f,fade*.94f),4);
            mesh.RibbonContinuous(p-r*reach*.56f-u*.22f,p-r*reach*.24f+u*.28f,
                p+r*reach*.38f+u*.41f,p+r*reach*.69f-u*.32f,u,.10f+open*.10f,
                new Color(1,.69f,.25f,fade*.89f),1);
            mesh.RibbonContinuous(p-r*reach*.51f-u*.47f,p-r*reach*.18f-u*.10f,
                p+r*reach*.45f-u*.34f,p+r*reach*.76f-u*.61f,u,.13f+open*.13f,
                new Color(.26f,.025f,.055f,fade*.70f),6.2f);
        }
        mesh.End();
    }
}

// A moving folded memory page links the core somersault to its existing
// single native contact.  This component never reports combat contact.
public sealed class MainlineMemoryTransitRound2 : MonoBehaviour
{
    Transform source,target;MainlineSpellMeshRound2 surface;MainlineDistinct20260925 distinct;float age;
    public static MainlineMemoryTransitRound2 Create(Transform from,Transform to){
        if(!from||!to)return null;
        var root=new GameObject("Core memory page in transit");
        var fx=root.AddComponent<MainlineMemoryTransitRound2>();fx.source=from;fx.target=to;
        fx.surface=root.AddComponent<MainlineSpellMeshRound2>();return fx;
    }
    void Update(){
        if(!source||!target||!source.gameObject.activeInHierarchy||!target.gameObject.activeInHierarchy||age>.44f){Clear();return;}
        age+=Time.deltaTime;
        float p=Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.38f));
        var camera=Camera.main;Vector3 r=camera?camera.transform.right:Vector3.right;
        Vector3 f=camera?camera.transform.forward:Vector3.forward,u=Vector3.up;
        Vector3 a=source.position+u*1.12f,b=target.position+u*1.06f;
        Vector3 c=Vector3.Lerp(a,b,p)+u*Mathf.Sin(p*Mathf.PI)*.53f+r*Mathf.Sin(p*5.7f)*.16f;
        float fade=Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.08f))
            *(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((age-.35f)/.09f)));
        if(!distinct)distinct=gameObject.AddComponent<MainlineDistinct20260925>();
        distinct.Memory(c,age,false);
    }
    public void Clear(){if(!gameObject)return;gameObject.SetActive(false);Destroy(gameObject);}
}
