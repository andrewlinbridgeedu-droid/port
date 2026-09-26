using UnityEngine;
namespace Mindstone.VFXV1 {
public sealed class ArcanaSeal : MonoBehaviour, ISpellExtension {
    LineRenderer[] lines; Material material; string role;
    GameObject[] clouds; Material[] cloudMaterials;
    public void Initialize(SpellSpec spell, SpellLayerSpec layer, int seed) {
        role=layer.role;
        material=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaFilament"));
        lines=new LineRenderer[role=="core"?21:role=="impact-front"?64:12];
        if(role=="impact-front") {
            clouds=new GameObject[19]; cloudMaterials=new Material[19];
            for(int i=0;i<clouds.Length;i++) {
                var cloud=GameObject.CreatePrimitive(PrimitiveType.Quad);
                cloud.name="Arcana explosion bloom"; cloud.transform.SetParent(transform,false);
                Destroy(cloud.GetComponent<Collider>());
                var m=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaBurst"));
                cloud.GetComponent<Renderer>().sharedMaterial=m;
                cloudMaterials[i]=m;clouds[i]=cloud;cloud.SetActive(false);
            }
        }
        for(int i=0;i<lines.Length;i++) {
            var go=new GameObject("Arcana engraving"); go.transform.SetParent(transform,false);
            var line=go.AddComponent<LineRenderer>(); lines[i]=line;
            line.sharedMaterial=material; line.positionCount=48; line.useWorldSpace=true;
            line.numCapVertices=3; line.widthMultiplier=.035f;
            line.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
        }
    }
    public void Sample(in SpellSample sample) {
        float p=sample.NormalizedTime;
        Vector3 center=sample.Target;
        var cam=Camera.main; Vector3 right=cam?cam.transform.right:Vector3.right;
        Vector3 up=cam?cam.transform.up:Vector3.up;
        Vector3 forward=cam?cam.transform.forward:Vector3.forward;
        if(clouds!=null) {
            float t=Mathf.Clamp01((p-.43f)/.5f);
            for(int i=0;i<clouds.Length;i++) {
                clouds[i].SetActive(p>=.43f && t<1);
                float angle=i*2.399963f;
                float travel=i==0?0:Mathf.Sqrt(t)*(1.1f+(i%4)*.28f);
                clouds[i].transform.position=center+(right*Mathf.Cos(angle)+up*Mathf.Sin(angle))*travel-forward*(.15f+i*.007f);
                clouds[i].transform.rotation=cam?cam.transform.rotation:Quaternion.identity;
                float size=i==0?2.8f+3*t:(.9f+(i%3)*.3f)*(1+t);
                clouds[i].transform.localScale=Vector3.one*size;
                Color c=i%3==0?new Color(1,.65f,.18f):new Color(.7f,.15f,1);
                c.a=(i==0?1.4f:.45f)*Mathf.Pow(1-t,2);
                cloudMaterials[i].SetColor("_Color",c);
            }
        }
        for(int i=0;i<lines.Length;i++) {
            var line=lines[i]; float alpha;
            if(role=="core") {
                alpha=Mathf.Sin(Mathf.Clamp01(p/.65f)*Mathf.PI);
                float radius=(1.15f-i*.13f)*(1-.45f*Mathf.SmoothStep(0,1,p/.55f));
                for(int j=0;j<48;j++) {
                    float a=j/47f*Mathf.PI*1.72f+p*3+i*2.1f;
                    if(i<3) line.SetPosition(j,center+(right*Mathf.Cos(a)+up*Mathf.Sin(a))*radius+forward*.15f);
                    else {
                        float angle=(i-3)*Mathf.PI*2/18+p*.8f;
                        Vector3 radial=right*Mathf.Cos(angle)+up*Mathf.Sin(angle);
                        Vector3 tangent=-right*Mathf.Sin(angle)+up*Mathf.Cos(angle);
                        float phase=j/47f;
                        float x=1-4*Mathf.Abs(phase-.5f);
                        float y=1-4*Mathf.Abs(Mathf.Repeat(phase+.25f,1)-.5f);
                        line.SetPosition(j,center+radial*(.95f-.3f*p+x*.09f)+tangent*y*.04f-forward*.1f);
                    }
                }
                line.widthMultiplier=i==0?.14f:.085f;
            } else if(role=="direction") {
                float t=Mathf.Clamp01((p-.06f-i*.012f)/.55f);
                alpha=Mathf.Pow(Mathf.Sin(t*Mathf.PI),.6f);
                for(int j=0;j<48;j++) {
                    float f=j/47f;
                    float trail=Mathf.Clamp01(t-f*.3f);
                    float a=trail*Mathf.PI*3.5f+i*Mathf.PI/6;
                    float radius=Mathf.Sin(trail*Mathf.PI)*1.15f;
                    Vector3 orbit=(right*Mathf.Cos(a)+up*Mathf.Sin(a))*radius;
                    line.SetPosition(j,Vector3.Lerp(sample.Source,center,trail)+orbit-forward*.25f);
                }
                line.widthMultiplier=i%3==0?.48f:.22f;
            } else {
                float t=Mathf.Clamp01((p-.43f)/.57f);
                alpha=Mathf.Sin(Mathf.Min(1,t*3)*Mathf.PI*.5f)*(1-t);
                float a=i*2.399963f;
                Vector3 axis=(right*Mathf.Cos(a)+up*Mathf.Sin(a)+forward*Mathf.Sin(i*3.1f)*.6f).normalized;
                for(int j=0;j<48;j++) {
                    float f=j/47f;
                    float radius=.12f+Mathf.Sqrt(t)*2.8f;
                    if(i<3) {
                        float ringAngle=f*Mathf.PI*2;
                        line.SetPosition(j,center+(right*Mathf.Cos(ringAngle)+up*Mathf.Sin(ringAngle))*(radius*(1-i*.13f)));
                    } else line.SetPosition(j,center+axis*(radius+f*.9f*(1-t))+up*Mathf.Sin(f*4+i)*t*.12f);
                }
                line.widthMultiplier=(i%4==0?.36f:.14f)*(1-t);
            }
            Color color=role=="core"||i%4==0?new Color(1,.73f,.32f):new Color(.75f,.25f,1);
            color.a=alpha;
            line.startColor=color; color.a=0; line.endColor=color;
        }
    }
    public void Interrupt(){Cleanup();}
    public void Cleanup(){if(clouds!=null)foreach(var c in clouds)if(c)Destroy(c);clouds=null;if(cloudMaterials!=null)foreach(var m in cloudMaterials)if(m)Destroy(m);cloudMaterials=null;if(lines!=null)foreach(var l in lines)if(l)Destroy(l.gameObject);lines=null;if(material)Destroy(material);material=null;}
    void OnDestroy(){Cleanup();}
}
}
