using System;
using UnityEngine;
/// Camera-projected spell compositing follows real anchors, as approved TarotNova
/// does. The owner supplies time/contact and is the only callback authority.
public sealed class HeroSpellVolume : IDisposable
{
    static int liveDeclarations;
    bool registeredDeclaration;
    GameObject root; Mesh mesh; Material material; Transform surface; readonly int kind; readonly float contact; SpellSceneLighting light;
    public HeroSpellVolume(Transform parent,int skill,float contact)
    {
        kind=skill;this.contact=contact;var shader=Resources.Load<Shader>("EnemySignature/HeroSpellVolume");if(!shader)return;
        if(skill==10){liveDeclarations++;registeredDeclaration=true;}
        root=new GameObject("Spatial spell energy "+skill);root.transform.SetParent(parent,false);light=root.AddComponent<SpellSceneLighting>();
        mesh=new Mesh{name="Spell volume sheet"};mesh.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};mesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};mesh.triangles=new[]{0,2,1,0,3,2};mesh.RecalculateBounds();
        var go=new GameObject("World anchored spell projection");go.transform.SetParent(root.transform,false);surface=go.transform;go.AddComponent<MeshFilter>().sharedMesh=mesh;
        material=new Material(shader){name="Hero spell projection owned"};material.SetFloat("_Kind",skill);material.SetFloat("_Contact",contact);material.SetTexture("_Atlas",Resources.Load<Texture2D>("Effects/Fool/FoolTarotVFXAtlas"));if(skill==10)material.SetTexture("_DeclarationArt",Resources.Load<Texture2D>("SpellImpact20260925/GoldContractInk"));go.AddComponent<MeshRenderer>().sharedMaterial=material;
    }
    public void Sample(float time,Vector3 source,Vector3 target)
    {
        if(!root)return;var cam=Camera.main;if(!cam){surface.gameObject.SetActive(false);return;}surface.gameObject.SetActive(true);
        Vector3 center=kind==2?source+Vector3.up*.95f:kind==9?source:target;
        float hit=Mathf.Exp(-Mathf.Max(0,time-contact)*5)*Mathf.SmoothStep(0,1,Mathf.InverseLerp(contact-.025f,contact+.025f,time));
        bool attack=kind>=5&&kind<=7;
        float statePresence=Mathf.SmoothStep(0,1,Mathf.Clamp01(time/(contact*.72f)))
            *(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((time-contact)/.80f)));
        float illumination=attack?hit*3.8f+Mathf.Sin(Mathf.Clamp01(time/contact)*Mathf.PI)*.65f
            :statePresence*.64f+hit*.24f;
        Color hue=kind==9?new Color(.18f,.65f,1):kind==7||kind==5?new Color(1,.46f,.12f)
            :kind==8?new Color(.78f,.17f,.40f):kind==10?new Color(.72f,.29f,.50f):new Color(.6f,.24f,1);
        if(light)light.Draw(center,hue,illumination*(kind==10?.32f:1f),attack?7:kind==10?2.8f:3.7f);
        float distance=cam.nearClipPlane+.14f;float height=cam.orthographic?cam.orthographicSize*2:2*distance*Mathf.Tan(cam.fieldOfView*Mathf.Deg2Rad*.5f);
        surface.position=cam.transform.TransformPoint(new Vector3(0,0,distance));surface.rotation=cam.transform.rotation;surface.localScale=new Vector3(height*cam.aspect,height,1);
        material.SetFloat("_InstanceWeight",kind==10?1f/Mathf.Sqrt(Mathf.Max(1,liveDeclarations)):1f);
        material.SetFloat("_TimeBeat",time);material.SetFloat("_Aspect",cam.aspect);material.SetVector("_Center",cam.WorldToViewportPoint(center));material.SetVector("_SourceUV",cam.WorldToViewportPoint(source));
    }
    public void Dispose(){if(registeredDeclaration){liveDeclarations=Mathf.Max(0,liveDeclarations-1);registeredDeclaration=false;}if(light)light.Clear();light=null;if(root){root.SetActive(false);UnityEngine.Object.Destroy(root);}root=null;if(material)UnityEngine.Object.Destroy(material);material=null;if(mesh)UnityEngine.Object.Destroy(mesh);mesh=null;}
}
