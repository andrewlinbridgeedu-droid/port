using UnityEngine;
// Presentation sampling only: never modifies combat time or invokes a contact.
public static class EnemyImpactEnvelope20260921 {
 public static float Sample(float p) {
  p=Mathf.Clamp01(p);
  if(p<.12f)return p*.08f;
  if(p<.19f)return Mathf.Lerp(.0096f,.45f,Mathf.SmoothStep(0,1,(p-.12f)/.07f));
  return Mathf.Lerp(.45f,1,Mathf.Clamp01((p-.19f)/.81f));
 }
 public static float Burst(float p) { return Mathf.Sin(Mathf.Clamp01((p-.10f)/.25f)*Mathf.PI); }
}
