using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// A single authored crater or continuous fault decal, plus a few solid stone chips.
/// Samples the existing fire phase; owns no impact or damage timing.
public sealed class HoundGroundFracture : MonoBehaviour
{
    Transform ground;
    Mesh decalMesh, pebbleMesh;
    Material groundMaterial, pebbleMaterial;
    Texture2D craterTexture, faultTexture;
    readonly List<Transform> pebbles=new List<Transform>();
    int lastVariant=-1;
    static float Noise(int i)=>Mathf.Repeat(Mathf.Sin(i*127.1f+43.7f)*43758.5453f,1);
    void Awake()
    {
        var shader=Resources.Load<Shader>("EnemySignature/HoundGroundFracture");
        if(!shader){Debug.LogError("Hound painted ground shader missing");return;}
        craterTexture=Resources.Load<Texture2D>("EnemySignature/HoundCraterDecal");
        faultTexture=Resources.Load<Texture2D>("EnemySignature/HoundFaultDecal");
        groundMaterial=new Material(shader){name="Owned painted hound ground",renderQueue=2982};
        pebbleMaterial=new Material(shader){name="Owned low raised stone chips",renderQueue=2983};
        pebbleMaterial.SetFloat("_Rock",1);
        decalMesh=new Mesh{name="Single continuous hound ground surface"};
        decalMesh.vertices=new[]{new Vector3(-.5f,0,0),new Vector3(.5f,0,0),new Vector3(.5f,0,1),new Vector3(-.5f,0,1)};
        decalMesh.uv=new[]{new Vector2(0,0),new Vector2(1,0),new Vector2(1,1),new Vector2(0,1)};
        decalMesh.triangles=new[]{0,2,1,0,3,2};decalMesh.RecalculateNormals();decalMesh.RecalculateBounds();
        ground=CreateRenderer("Authored continuous ground fracture",decalMesh,groundMaterial);
        // Each chip is a closed, asymmetric solid with distinct top and bottom vertices.
        pebbleMesh=new Mesh{name="Owned irregular solid stone"};
        Vector3[] hull={new Vector3(-.61f,0,-.42f),new Vector3(.48f,-.08f,-.37f),new Vector3(.55f,.04f,.35f),new Vector3(-.39f,.07f,.57f),new Vector3(-.11f,.58f,.04f),new Vector3(.06f,-.34f,-.05f)};
        int[] faces={0,4,1,1,4,2,2,4,3,3,4,0,1,5,0,2,5,1,3,5,2,0,5,3};
        var v=new Vector3[faces.Length];var t=new int[faces.Length];
        for(int i=0;i<faces.Length;i++){v[i]=hull[faces[i]];t[i]=i;}
        pebbleMesh.vertices=v;pebbleMesh.triangles=t;pebbleMesh.RecalculateNormals();pebbleMesh.RecalculateBounds();
        for(int i=0;i<9;i++)pebbles.Add(CreateRenderer("Small raised fracture stone "+i,pebbleMesh,pebbleMaterial));
    }
    Transform CreateRenderer(string name,Mesh mesh,Material material)
    {
        var go=new GameObject(name);go.transform.SetParent(transform,false);
        go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
        return go.transform;
    }
    public void Draw(int variant,int phase,float p,Vector3 source,Vector3 target)
    {
        if(!ground||!groundMaterial)return;
        p=Mathf.Clamp01(p);bool wave=(variant&1)!=0;
        if(lastVariant!=(variant&1)){
            lastVariant=variant&1;var texture=wave?faultTexture:craterTexture;
            groundMaterial.mainTexture=texture;ground.gameObject.SetActive(texture!=null);
            if(!texture)Debug.LogWarning("Hound ground artwork missing: "+(wave?"HoundFaultDecal":"HoundCraterDecal"));
        }
        Vector3 axis=target-source;axis.y=0;float length=Mathf.Max(.3f,axis.magnitude);axis=axis.sqrMagnitude>.001f?axis.normalized:Vector3.forward;
        Quaternion rotation=Quaternion.LookRotation(axis);
        float fade=phase==2?1-Mathf.SmoothStep(0,1,Mathf.Clamp01((p-.82f)/.18f)):1;
        float open=phase==0?Mathf.Lerp(.035f,.13f,p):phase==1?Mathf.Lerp(.13f,1,Mathf.SmoothStep(0,1,Mathf.Clamp01(p*1.8f))):1;
        Vector3 pos;
        if(wave){pos=target-axis*1.65f;pos.y=.022f;ground.position=pos;ground.rotation=rotation;ground.localScale=new Vector3(3.3f,1,3.3f);}
        else{float depth=3.2f*Mathf.Lerp(.72f,1,open);pos=target-axis*(depth*.5f);pos.y=.022f;ground.position=pos;ground.rotation=rotation;ground.localScale=new Vector3(3.9f*open,1,depth);}
        groundMaterial.SetFloat("_Wave",wave?1:0);
        groundMaterial.SetFloat("_Reveal",phase==0?0:phase==1?Mathf.SmoothStep(0,1,Mathf.Clamp01(p/.7f)):1);
        groundMaterial.SetFloat("_Open",open);
        // After the eruption the dark crater is residue, not the subject: let it
        // settle to a lighter scorch so the rising fire keeps the frame.
        float residue=phase==2?Mathf.Lerp(1f,.45f,Mathf.SmoothStep(0,1,Mathf.Clamp01(p/.3f))):1f;
        groundMaterial.SetFloat("_Opacity",fade*residue);
        groundMaterial.SetFloat("_Glow",phase==0?.2f:phase==1?Mathf.Lerp(.35f,1.2f,p):1.2f*fade);
        groundMaterial.SetFloat("_Age",phase+p);
        pebbleMaterial.SetFloat("_Opacity",fade);
        for(int i=0;i<pebbles.Count;i++){
            float u=(i+.55f)/pebbles.Count;
            float age=wave?(phase==0?-1:phase==1?(p-u)*1.6f:1.6f*(1-u)+p):(phase==0?-1:phase==1?p*.9f: .9f+p);
            pebbles[i].gameObject.SetActive(!wave&&age>=0);if(wave||age<0)continue;
            Vector3 c;
            if(wave)c=Vector3.Lerp(source,target,u)+rotation*Vector3.right*((i%2==0?-1:1)*(.39f+Noise(i+6)*.2f));
            else{float angle=i*2.39996f;c=target+rotation*new Vector3(Mathf.Cos(angle)*(1.25f+Noise(i)*.35f),0,Mathf.Sin(angle)*(1.0f+Noise(i+4)*.22f));}
            float hop=Mathf.Sin(Mathf.Clamp01(age/.65f)*Mathf.PI)*(.09f+Noise(i+8)*.12f);
            float size=.075f+Noise(i+31)*.07f;
            c.y=.022f+size*.34f+hop;
            pebbles[i].position=c;pebbles[i].rotation=Quaternion.Euler(Noise(i)*90+age*100,Noise(i+3)*180,Noise(i+7)*70);
            pebbles[i].localScale=new Vector3(size,size*.8f,size*.85f);
        }
    }
    void OnDestroy(){if(groundMaterial)Destroy(groundMaterial);if(pebbleMaterial)Destroy(pebbleMaterial);if(decalMesh)Destroy(decalMesh);if(pebbleMesh)Destroy(pebbleMesh);}
}
