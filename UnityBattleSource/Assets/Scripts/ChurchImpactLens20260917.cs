using UnityEngine;
// Render-only impulse; does not alter actor positions, combat time or camera transform.
[RequireComponent(typeof(Camera))]
public sealed class ChurchImpactLens20260917:MonoBehaviour {
 Camera lens;Object owner;float amount,phase;int requestedFrame;Matrix4x4 saved;bool applied,automaticProjection;
 public static void Request(Object source,float age,float strength){
  var cam=Camera.main;if(!cam)return;
  var fx=cam.GetComponent<ChurchImpactLens20260917>();if(!fx)fx=cam.gameObject.AddComponent<ChurchImpactLens20260917>();
  float a=Mathf.Exp(-Mathf.Max(0,age)*16)*Mathf.Clamp01(strength);
  if(fx.requestedFrame==Time.frameCount&&fx.amount>a)return;
  fx.owner=source;fx.phase=age;fx.amount=a;fx.requestedFrame=Time.frameCount;
 }
 void OnPreCull(){
  lens=GetComponent<Camera>();if(applied)Restore();
  if(!owner||Time.frameCount-requestedFrame>1||amount<.01f)return;
  saved=lens.projectionMatrix;
  // Assigning the saved matrix back unconditionally leaves Unity in custom
  // projection mode: later FOV/aspect changes silently keep the old zoom.
  // Preserve genuinely custom projections, but restore automatic cameras as
  // automatic (including two renders at different aspect ratios in one frame).
  lens.ResetProjectionMatrix();var automatic=lens.projectionMatrix;
  automaticProjection=true;
  for(int i=0;i<16;i++)if(Mathf.Abs(saved[i]-automatic[i])>.00001f){automaticProjection=false;break;}
  var p=saved;
  float zoom=1+amount*.018f;p.m00*=zoom;p.m11*=zoom;
  p.m02+=Mathf.Sin(phase*105)*amount*.009f;p.m12+=Mathf.Cos(phase*83)*amount*.007f;
  lens.projectionMatrix=p;applied=true;
 }
 void OnPostRender(){Restore();}
 void OnDisable(){Restore();owner=null;}
 void Restore(){if(applied&&lens){if(automaticProjection)lens.ResetProjectionMatrix();else lens.projectionMatrix=saved;}applied=false;}
}
