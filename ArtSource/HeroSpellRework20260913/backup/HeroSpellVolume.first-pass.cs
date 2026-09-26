using System;
using UnityEngine;
/// Three intersecting, depth-separated flame sheets sampled by their owner.
/// Owns no clock, coroutine or callback; parent cancellation is authoritative.
public sealed class HeroSpellVolume : IDisposable
{
    GameObject root; Mesh mesh; readonly Material[] mats=new Material[3]; readonly Transform[] sheets=new Transform[3]; readonly int kind; readonly float contact; SpellSceneLighting light;
    public HeroSpellVolume(Transform parent,int skill,float contact)
    {
        kind=skill;this.contact=contact;var shader=Resources.Load<Shader>("EnemySignature/HeroSpellVolume");if(!shader)return;
        root=new GameObject("Spatial spell energy "+skill);root.transform.SetParent(parent,false);light=root.AddComponent<SpellSceneLighting>();
        mesh=new Mesh{name="Spell volume sheet"};mesh.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};mesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};mesh.triangles=new[]{0,2,1,0,3,2};mesh.RecalculateBounds();
        Color tint=skill==9?new Color(.04f,.55f,.85f):skill==7||skill==5?new Color(.7f,.23f,.035f):skill==8?new Color(.7f,.04f,.18f):new Color(.30f,.07f,.9f);
        for(int i=0;i<3;i++){var go=new GameObject("Flame depth "+i);go.transform.SetParent(root.transform,false);sheets[i]=go.transform;go.AddComponent<MeshFilter>().sharedMesh=mesh;var m=new Material(shader);m.SetFloat("_Kind",skill);m.SetFloat("_Contact",contact);m.SetFloat("_Layer",i);m.SetColor("_Tint",tint);mats[i]=m;go.AddComponent<MeshRenderer>().sharedMaterial=m;}
    }
    public void Sample(float time,Vector3 source,Vector3 target)
    {
        if(!root)return;var cam=Camera.main;Quaternion facing=cam?cam.transform.rotation:Quaternion.identity;Vector3 depth=facing*Vector3.forward;
        Vector3 center=kind==2?source+Vector3.up*.6f:kind==9?source:target;
        float hit=Mathf.Exp(-Mathf.Max(0,time-contact)*6f)*Mathf.SmoothStep(0,1,Mathf.InverseLerp(contact-.03f,contact+.02f,time));
        if(light)light.Draw(center,kind==9?new Color(.18f,.65f,1):kind==7||kind==5?new Color(1,.46f,.12f):new Color(.6f,.24f,1),hit*2.8f+Mathf.Sin(Mathf.Clamp01(time/contact)*Mathf.PI)*.55f,6);
        float width=kind==10?4.1f:kind==8?3.6f:3.0f,height=kind==10?4.6f:3.6f;
        if(kind==6){center=(source+target)*.5f;Vector3 delta=target-source;Vector3 cameraRight=facing*Vector3.right,cameraUp=facing*Vector3.up;float angle=Mathf.Atan2(Vector3.Dot(delta,cameraUp),Vector3.Dot(delta,cameraRight))*Mathf.Rad2Deg;facing*=Quaternion.Euler(0,0,angle);width=Mathf.Max(2,delta.magnitude+1.2f);height=1.9f;}
        for(int i=0;i<3;i++){sheets[i].position=center+depth*((i-1)*.22f);sheets[i].rotation=facing*Quaternion.Euler(0,(i-1)*19,0);sheets[i].localScale=new Vector3(width,height,1);mats[i].SetFloat("_TimeBeat",time);}
    }
    public void Dispose(){if(light)light.Clear();light=null;if(root){root.SetActive(false);UnityEngine.Object.Destroy(root);}root=null;foreach(var m in mats)if(m)UnityEngine.Object.Destroy(m);if(mesh)UnityEngine.Object.Destroy(mesh);mesh=null;}
}
