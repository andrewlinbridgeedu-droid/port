using UnityEngine;
using UnityEngine.Rendering;

/// One bounded 3D density field, ray integrated through its actual box volume.
public sealed class HoundVolumetricInferno : MonoBehaviour
{
    Material material;Mesh mesh;Transform volume;HoundGroundFracture fracture;
    void Awake()
    {
        fracture=gameObject.AddComponent<HoundGroundFracture>();
        var shader=Resources.Load<Shader>("EnemySignature/HoundVolumetricInferno");
        if(!shader){Debug.LogError("HoundVolumetricInferno shader missing");return;}
        var go=new GameObject("Hound continuous fire volume");go.transform.SetParent(transform,false);volume=go.transform;
        mesh=new Mesh{name="Hound volumetric bounds"};
        mesh.vertices=new[]{new Vector3(-.5f,-.5f,-.5f),new Vector3(.5f,-.5f,-.5f),new Vector3(.5f,.5f,-.5f),new Vector3(-.5f,.5f,-.5f),new Vector3(-.5f,-.5f,.5f),new Vector3(.5f,-.5f,.5f),new Vector3(.5f,.5f,.5f),new Vector3(-.5f,.5f,.5f)};
        mesh.triangles=new[]{0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5};mesh.RecalculateBounds();
        material=new Material(shader){name="Hound owned volume",renderQueue=3017};
        material.SetTexture("_Fire",Resources.Load<Texture2D>("Effects/HellHound/Texture/Fire_Single"));
        go.AddComponent<MeshFilter>().sharedMesh=mesh;var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    }
    public void Draw(int variant,int phase,float p,Vector3 source,Vector3 target)
    {
        if(fracture)fracture.Draw(variant,phase,p,source,target);
        if(!volume||!material)return;
        bool wave=(variant&1)!=0;
        p=Mathf.Clamp01(p);
        float fade=phase==0?0:phase==1?Mathf.SmoothStep(0,1,Mathf.Clamp01(p/.20f)):Mathf.Pow(1-p,.9f);
        float height=phase==0?.08f:phase==1?Mathf.Lerp(.08f,wave?2.7f:3.2f,Mathf.SmoothStep(0,1,Mathf.Clamp01(p/.76f))):Mathf.Lerp(wave?2.7f:3.2f,.10f,Mathf.SmoothStep(0,1,p));
        float width=phase<2?(wave?2.8f:3.05f):Mathf.Lerp(wave?2.8f:3.05f,.12f,Mathf.SmoothStep(0,1,p));
        Vector3 center=target;center.y=.035f+height*.5f;
        volume.position=center;
        volume.rotation=Quaternion.Euler(0,(phase+p)*(wave?245:205),0);
        float rupture=phase==2?1+1.15f*Mathf.Sin(Mathf.Clamp01(p*2.5f)*Mathf.PI):1;
        volume.localScale=new Vector3(width*1.18f*rupture,height*1.16f,width*1.18f*rupture);
        material.SetFloat("_Age",phase+p);material.SetFloat("_Opacity",fade*1.16f);material.SetFloat("_Wave",wave?1:0);

    }
    void OnDestroy(){if(material)Destroy(material);if(mesh)Destroy(mesh);}
}
