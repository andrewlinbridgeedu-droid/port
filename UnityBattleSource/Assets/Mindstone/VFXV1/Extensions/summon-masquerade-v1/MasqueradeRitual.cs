using UnityEngine;
namespace Mindstone.VFXV1 {
public sealed class MasqueradeRitual:MonoBehaviour,ISpellExtension {
 LineRenderer[] lines;Material material;string role;
 public void Initialize(SpellSpec spell,SpellLayerSpec layer,int seed){role=layer.role;material=new Material(Resources.Load<Shader>("Mindstone/VFXV1/ArcanaFilament"));lines=new LineRenderer[role=="core"?2:role=="direction"?3:6];for(int i=0;i<lines.Length;i++){var g=new GameObject("Gilded invocation");g.transform.SetParent(transform,false);var l=g.AddComponent<LineRenderer>();l.sharedMaterial=material;l.useWorldSpace=true;l.positionCount=48;l.numCapVertices=3;l.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;lines[i]=l;}}
 public void Sample(in SpellSample s){float p=s.NormalizedTime;float a=Mathf.Sin(Mathf.Clamp01(p)*Mathf.PI);var cam=Camera.main;var r=cam?cam.transform.right:Vector3.right;var u=cam?cam.transform.up:Vector3.up;var f=cam?cam.transform.forward:Vector3.forward;
  for(int i=0;i<lines.Length;i++){var l=lines[i];float angle=i*2.399963f;for(int j=0;j<48;j++){float q=j/47f;Vector3 pos;
   if(role=="core"){float t=q*Mathf.PI*1.42f+i*2.2f;float radius=(.34f+i*.18f)*(1+.10f*Mathf.Sin(t*2.3f+i))*Mathf.SmoothStep(0,1,p*4);pos=s.Source+(r*Mathf.Cos(t)+u*Mathf.Sin(t))*radius+f*Mathf.Sin(t*3+p*8)*.12f;}
   else if(role=="direction"){float t=q*Mathf.PI*2+p*3+i*.628f;pos=s.Source+r*(Mathf.Cos(t)*(.48f+p*.44f))+u*(q*1.8f-.85f)+f*Mathf.Sin(t)*.5f;}
   else {float t=q*Mathf.PI*1.25f+i;var v=r*Mathf.Cos(angle)+u*Mathf.Sin(angle);float snap=1-Mathf.Exp(-p*9);pos=s.Source+v*(.15f+snap*(.42f+(i%3)*.19f))+(r*Mathf.Cos(t)*.075f+u*Mathf.Sin(t)*.16f)*(1-q)+f*Mathf.Sin(angle)*.35f;}
   l.SetPosition(j,pos);
  }l.widthMultiplier=(role=="core"?.074f:role=="direction"?.069f:.059f)*(1+.45f*Mathf.Sin(Mathf.Clamp01(p*3)*Mathf.PI));var c=i%3==0?new Color(1.14f,.82f,.32f,a):new Color(.74f,.34f,1.12f,a*.8f);l.startColor=c;l.endColor=c;}
 }
 public void Interrupt()=>Cleanup();public void Cleanup(){if(lines!=null)foreach(var l in lines)if(l)Destroy(l.gameObject);lines=null;if(material)Destroy(material);material=null;}void OnDestroy()=>Cleanup();
}
}
