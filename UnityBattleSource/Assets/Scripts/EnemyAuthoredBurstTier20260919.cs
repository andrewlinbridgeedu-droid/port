using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Actor-specific sculpted spell volumes; no contact, callback or clock ownership.
public sealed class EnemyAuthoredBurstTier20260919 : MonoBehaviour
{
    public enum Motif { Clock, Hammer, Convoy, Scribe, Executor, Bearer, Leech }
    MainlineDistinct20260925 distinct;
    Mesh mesh; Material material;
    readonly List<Vector3> v=new List<Vector3>(6000);
    readonly List<Color> c=new List<Color>(6000);
    readonly List<Vector2> uv=new List<Vector2>(6000);
    readonly List<int> ix=new List<int>(9000);
    void Awake(){
        mesh=new Mesh{name="Round2 sculpted ink bronze and pressure"};mesh.MarkDynamic();
        material=new Material(Resources.Load<Shader>("EnemySignature/MainlineInlaidVolumeRound2"));
        var go=new GameObject("Uneven tapered folds and branching inlay");go.transform.SetParent(transform,false);
        go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;
        r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    }
    static float Hash(int i){float x=Mathf.Sin(i*127.1f+31.7f)*43758.5453f;return x-Mathf.Floor(x);}
    void Quad(Vector3 a,Vector3 b,Vector3 d,Vector3 e,Color color,float x0,float x1,float y0,float y1){
        int n=v.Count;v.Add(transform.InverseTransformPoint(a));v.Add(transform.InverseTransformPoint(b));v.Add(transform.InverseTransformPoint(d));v.Add(transform.InverseTransformPoint(e));
        for(int i=0;i<4;i++)c.Add(color);uv.Add(new Vector2(x0,y0));uv.Add(new Vector2(x0,y1));uv.Add(new Vector2(x1,y1));uv.Add(new Vector2(x1,y0));
        ix.Add(n);ix.Add(n+1);ix.Add(n+2);ix.Add(n);ix.Add(n+2);ix.Add(n+3);
    }
    Vector3 Point(Vector3 a,Vector3 b,Vector3 bend,float t){return Vector3.Lerp(a,b,t)+bend*Mathf.Sin(t*Mathf.PI);}
    // Curved pointed silhouette and raised cross-section, not an alpha-noised rectangle.
    void Fold(Vector3 a,Vector3 b,Vector3 bend,Vector3 side,float width,Color color,int seed=0){
        side.Normalize();Vector3 normal=Vector3.Cross(b-a,side).normalized;
        const int count=22;
        for(int j=0;j<count;j++){
            float u0=j/(float)count,u1=(j+1f)/count;
            Vector3 p0=Point(a,b,bend,u0),p1=Point(a,b,bend,u1);
            float w0=Width(u0,seed)*width,w1=Width(u1,seed)*width;
            Vector3 ridge0=p0+normal*w0*.48f,ridge1=p1+normal*w1*.48f;
            Quad(p0-side*w0,p1-side*w1,ridge1,ridge0,color,0,.5f,u0,u1);
            var shade=color;shade.r*=.78f;shade.g*=.86f;shade.b*=.93f;
            Quad(ridge0,ridge1,p1+side*w1*.72f,p0+side*w0*.72f,shade,.5f,1,u0,u1);
        }
    }
    static float Width(float u,int seed){return Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.65f)*(.78f+.17f*Mathf.Sin(u*17+seed)+.10f*Mathf.Sin(u*39+seed*2.3f));}
    public void Draw(Motif motif,float age,Vector3 source,Vector3 target,bool alternate=false){
        if(!mesh)return;
        if(motif!=Motif.Leech){
            mesh.Clear();
            if(!distinct)distinct=gameObject.AddComponent<MainlineDistinct20260925>();
            distinct.Draw(motif,age,source,target,alternate);return;
        }
        if(age>=1)age=1+EnemyImpactEnvelope20260921.Sample((age-1)/.5f)*.5f;
        v.Clear();c.Clear();uv.Clear();ix.Clear();
        material.SetFloat("_Age",age);material.SetFloat("_Motif",motif==Motif.Scribe?1:motif==Motif.Leech?2:motif==Motif.Hammer||motif==Motif.Convoy?3:motif==Motif.Clock?4:0);
        var cam=Camera.main;Vector3 right=cam?cam.transform.right:Vector3.right,up=cam?cam.transform.up:Vector3.up;
        Vector3 forward=target-source;if(forward.sqrMagnitude<.01f)forward=Vector3.forward;forward.Normalize();
        Vector3 floorForward=Vector3.ProjectOnPlane(forward,Vector3.up).normalized;
        if(floorForward.sqrMagnitude<.1f)floorForward=Vector3.forward;
        Vector3 floorSide=Vector3.Cross(Vector3.up,floorForward);
        float flight=Mathf.Clamp01((age-.4f)/.6f),post=Mathf.Max(0,age-1),p=Mathf.Clamp01(post/.5f);
        bool impact=age>=1;
        float fade=impact?Mathf.Pow(1-p,1.4f):Mathf.SmoothStep(0,1,age/.3f);
        float open=impact?Mathf.Sqrt(p):0;
        material.SetFloat("_Impact",impact?Mathf.Exp(-post*13):0);
        Vector3 center=Vector3.Lerp(source,target,flight);
        Color gold=new Color(1,.62f,.21f,fade*.94f),hot=new Color(1,.92f,.64f,fade*.94f);
        if(motif==Motif.Executor){
            if(!alternate){
                // Nib-first puncture; the wound opens on one oblique seam at contact.
                Vector3 axis=impact?(right*.38f+up).normalized:forward;
                float reach=impact?.45f+open*2.8f:.7f+flight*.85f;
                Vector3 start=center-axis*reach,end=center+axis*(impact?reach*.7f:.18f);
                Fold(start,end,right*(impact?open*.3f:.12f),impact?right:up,
                    impact?.43f+open*.39f:.34f,new Color(.52f,.25f,.07f,fade*.90f),2);
                // A narrow molten pen edge rides on the thick bronze nib.
                Fold(start+forward*.045f,end+forward*.045f,right*(impact?open*.3f:.12f),impact?right:up,
                    impact?.14f+open*.16f:.11f,hot,9);
                if(impact)for(int i=0;i<5;i++){
                    float h=Hash(i+8);Vector3 d=(right*(h-.48f)+up*(Hash(i+21)-.4f)).normalized;
                    Fold(target+d*(.18f+open*.5f),target+d*(.5f+open*(1.1f+h)),forward*.18f,Vector3.Cross(forward,d),.11f,hot,i);
                }
            }else{
                // Countermark: one hooked cut and returning barb, never a second X.
                float reach=.75f+open*2.1f;
                Fold(center-right*reach-up*.38f,center+right*reach*.45f-up*.08f,
                    up*(.65f+open*.55f)+forward*.3f,up,.51f+open*.39f,new Color(.47f,.23f,.08f,fade*.91f),7);
                Fold(center-right*reach*.89f-up*.24f+forward*.04f,center+right*reach*.40f+forward*.04f,
                    up*(.51f+open*.42f),up,.15f+open*.16f,hot,17);
                Fold(center+right*reach*.45f,center+right*reach*.18f-up*(.54f+open),
                    right*.28f,forward+right,.30f+open*.18f,gold,13);
            }
        }else if(motif==Motif.Scribe){
            // Unequal cursive ink plumes: no page rectangles or parallel plates.
            for(int i=0;i<3;i++){
                float h=Hash(i+12),length=.72f+h*.55f+open*(1.4f+h);
                Vector3 offset=right*(i==0?-.28f:i==1?.16f:.44f)*(1+open)+forward*(i*.20f);
                // All plumes flow across the pen stroke. Opposing equal bends
                // made an empty oval cage in the first recording.
                Vector3 tip=center+offset+up*length*(i==1?.63f:1)+right*(.48f+open*.6f);
                Fold(center+offset-up*length*.6f-right*.32f,tip,
                    right*(.28f+h*.24f)+forward*(.2f+h*.24f),right+forward*.18f,
                    .51f+h*.20f+open*.32f,new Color(.48f+.12f*h,.12f+.09f*h,.92f,fade*.96f),i+5);
                if(impact&&i!=1)Fold(target+offset,tip+right*.65f,up*.24f,up,.21f,
                    new Color(.84f,.43f,1f,fade*.81f),i);
            }
        }else if(motif==Motif.Clock){
            if(!alternate){
                // Engraved bronze verdict with unequal broken continuations. No clock ring.
                float r=.7f+open*2.6f;
                Fold(center-right*r-up*.2f,center+right*r*.68f+up*r*.5f,
                    up*(.43f+open*.4f)+forward*.27f,up,.68f+open*.40f,
                    new Color(.68f,.31f,.09f,fade*.94f),4);
                Fold(center-right*r*.2f-up*r*.5f,center+up*r*.75f,right*r*.43f,right,
                    .37f+open*.27f,gold,8);
                Fold(center-right*r*.64f+forward*.05f,center+right*r*.46f+up*r*.37f+forward*.05f,
                    up*(.35f+open*.31f),up,.16f+open*.11f,hot,12);
                if(impact)Fold(target+right*.3f,target+right*(1+open*2.7f)-up*.55f,up*.55f,up,.23f,gold,2);
            }else{
                // Copper fingers draw in then impress an irregular palm fissure.
                for(int i=0;i<5;i++){
                    float h=Hash(i+42),x=(h-.48f)*2.4f;
                    Vector3 root=center+right*x*(impact?.4f+open:1-flight*.5f)+up*(.55f+h*.6f);
                    Vector3 tip=center+right*x*.28f-up*(.35f+open*(.55f+h));
                    Fold(root,tip,right*(x*.24f)+forward*(.28f+h*.4f),right,.29f+h*.19f+open*.22f,gold,i+20);
                }
                // Asymmetric palm heel closes the previous empty U-shaped frame.
                Fold(center-right*(.38f+open*.75f)-up*.32f,center+right*(.52f+open*.65f)+up*.14f,
                    up*.16f+forward*.17f,up,.57f+open*.45f,new Color(.72f,.38f,.12f,fade*.94f),3);
            }
        }else if(motif==Motif.Hammer||motif==Motif.Convoy){
            bool convoy=motif==Motif.Convoy;
            if(!impact)Fold(center-forward*.72f,center+forward*.25f,up*.25f,
                convoy?floorSide:right,.59f,new Color(.83f,.48f,.16f,fade*.94f),5);
            else{
                Vector3 ground=target;ground.y=Mathf.Max(.04f,target.y-(convoy?0:.82f));
                int count=convoy?7:9;
                for(int i=0;i<count;i++){
                    float h=Hash(i+31),a=Hash(i+19)*6.28f;
                    Vector3 d=convoy?(floorForward+floorSide*(h-.5f)*1.2f).normalized:floorSide*Mathf.Cos(a)+floorForward*Mathf.Sin(a);
                    Vector3 side=Vector3.Cross(Vector3.up,d);
                    float reach=.4f+open*(1.6f+Hash(i+5)*2.8f);
                    Vector3 origin=ground+(convoy?floorSide*(Hash(i+70)-.5f)*1.45f:d*.12f);
                    Fold(origin,origin+d*reach+Vector3.up*(.18f+open*(convoy?.21f:1.0f)*h),
                        side*(h-.4f)*.48f,side,.38f+Hash(i+2)*.34f,
                        new Color(.84f,.45f+.18f*h,.12f,fade*.95f),i);
                    if(i%2==0)Fold(origin+d*reach*.43f,origin+d*reach*.76f+side*(h+.25f)*.7f,
                        Vector3.up*.14f,side,.10f,hot,i+21);
                }
            }
        }else if(motif==Motif.Bearer){
            // Palm heel and thumb pressure fold, unlike sharp weapon or paper.
            float r=.45f+open*1.8f;
            Fold(center-right*r,center+right*r*.65f+up*.3f,up*r*.39f+forward*.32f,up,
                .58f+open*.45f,gold,6);
            Fold(center-right*.12f-up*r*.55f,center+up*r*.75f,right*r*.7f,right,
                .36f+open*.28f,new Color(.85f,.41f,.12f,fade*.92f),11);
            if(impact)for(int i=0;i<4;i++){
                Vector3 d=(right*(Hash(i+13)-.5f)+up*(Hash(i+2)-.3f)).normalized;
                Fold(target+d*.28f,target+d*(.65f+open*(1.3f+Hash(i))),forward*.2f,
                    Vector3.Cross(forward,d),.16f,gold,i);
            }
        }else{
            // Digestive ligaments curl into irregular lobes, not a sphere or leaf triad.
            for(int i=0;i<5;i++){
                float h=Hash(i+5);Vector3 d=(right*(h-.45f)+up*(Hash(i+20)-.35f)+forward*.18f).normalized;
                Vector3 a=impact?target+d*.1f:center-forward*(.75f+h*.45f);
                Vector3 b=impact?target+d*(.55f+open*(1.2f+h*1.3f)):center+d*.13f;
                Vector3 bend=up*(.13f+h*.32f)+right*(h-.5f)*.6f;
                Vector3 side=Vector3.Cross(forward,d)+up*.2f;
                Fold(a,b,bend,side,.27f+h*.20f,new Color(.30f,.62f,.065f,fade*.85f),i+16);
                Fold(a+forward*.05f,b+forward*.05f,bend*.82f,side,.095f+h*.07f,
                    new Color(.83f,1f,.29f,fade*.90f),i+29);
            }
        }
        mesh.Clear();mesh.SetVertices(v);mesh.SetColors(c);mesh.SetUVs(0,uv);mesh.SetTriangles(ix,0);mesh.RecalculateBounds();
    }
    void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
}
