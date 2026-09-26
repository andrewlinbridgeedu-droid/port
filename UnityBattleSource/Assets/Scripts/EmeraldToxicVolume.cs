using UnityEngine;
using UnityEngine.Rendering;
// A genuinely three-dimensional billowing gas volume, shared by the release
// cloud and the native-controlled lingering field. No combat state lives here.
public sealed class EmeraldToxicVolume : MonoBehaviour
{
    Material material; Mesh mesh; Transform volume;
    void Awake()
    {
        var shader=Resources.Load<Shader>("EnemySignature/EmeraldToxicVolume");
        if(!shader) { Debug.LogError("Emerald toxic volume shader missing"); return; }
        var go=new GameObject("Emerald volumetric gas");go.transform.SetParent(transform,false);volume=go.transform;
        mesh=new Mesh{name="Toxic cloud volume bounds"};
        mesh.vertices=new[]{new Vector3(-.5f,-.5f,-.5f),new Vector3(.5f,-.5f,-.5f),new Vector3(.5f,.5f,-.5f),new Vector3(-.5f,.5f,-.5f),new Vector3(-.5f,-.5f,.5f),new Vector3(.5f,-.5f,.5f),new Vector3(.5f,.5f,.5f),new Vector3(-.5f,.5f,.5f)};
        mesh.triangles=new[]{0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5};mesh.RecalculateBounds();
        material=new Material(shader){name="Toxic cloud optical density",renderQueue=3017};
        
        go.AddComponent<MeshFilter>().sharedMesh=mesh;var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    }
    public void Configure(Vector3 center,Vector3 size,float age,float opacity,float burst)
    {
        if(!volume||!material)return;
        volume.position=center;volume.rotation=Quaternion.identity;volume.localScale=size;
        material.SetFloat("_Age",age);material.SetFloat("_Opacity",opacity);material.SetFloat("_Burst",burst);
    }
    void OnDestroy(){if(material)Destroy(material);if(mesh)Destroy(mesh);}
}
