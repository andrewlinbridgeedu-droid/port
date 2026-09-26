using UnityEngine;
[RequireComponent(typeof(Camera))] public sealed class TrialBloom:MonoBehaviour {
 Material m;void OnRenderImage(RenderTexture src,RenderTexture dst){if(!m)m=new Material(Shader.Find("Hidden/MistportTrialBloom"));var a=RenderTexture.GetTemporary(src.width/4,src.height/4,0,RenderTextureFormat.ARGBHalf);var b=RenderTexture.GetTemporary(src.width/4,src.height/4,0,RenderTextureFormat.ARGBHalf);Graphics.Blit(src,a,m,0);for(int i=0;i<2;i++){m.SetVector("_Axis",new Vector4(1,0));Graphics.Blit(a,b,m,1);m.SetVector("_Axis",new Vector4(0,1));Graphics.Blit(b,a,m,1);}m.SetTexture("_Bloom",a);Graphics.Blit(src,dst,m,2);RenderTexture.ReleaseTemporary(a);RenderTexture.ReleaseTemporary(b);}
 void OnDestroy(){if(m)Destroy(m);}
}
