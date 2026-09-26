using UnityEngine;
/// A temporary child of EnemySignature's root. Root deactivation synchronously
/// releases the projection; it never owns timing, gameplay or hit callbacks.
public sealed class CrimsonStageProjection : MonoBehaviour
{
    Mesh mesh;Material material;Transform surface;
    bool Ensure()
    {
        if(material)return true;var shader=Resources.Load<Shader>("EnemySignature/CrimsonStageProjection");if(!shader)return false;
        mesh=new Mesh{name="Crimson stage projection owned mesh"};mesh.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};mesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};mesh.triangles=new[]{0,2,1,0,3,2};mesh.RecalculateBounds();
        var go=new GameObject("Crimson tide camera surface");go.transform.SetParent(transform,false);surface=go.transform;go.AddComponent<MeshFilter>().sharedMesh=mesh;material=new Material(shader){name="Crimson stage projection owned material"};go.AddComponent<MeshRenderer>().sharedMaterial=material;return true;
    }
    public void Sample(int variant,int phase,float progress,Vector3 source,Vector3 target)
    {
        if(!Ensure())return;var cam=Camera.main;if(!cam){surface.gameObject.SetActive(false);return;}surface.gameObject.SetActive(true);
        float distance=cam.nearClipPlane+.16f;float height=cam.orthographic?cam.orthographicSize*2:2*distance*Mathf.Tan(cam.fieldOfView*Mathf.Deg2Rad*.5f);
        surface.position=cam.transform.TransformPoint(new Vector3(0,0,distance));surface.rotation=cam.transform.rotation;surface.localScale=new Vector3(height*cam.aspect,height,1);
        material.SetVector("_Source",cam.WorldToViewportPoint(source));material.SetVector("_Target",cam.WorldToViewportPoint(target));material.SetFloat("_Aspect",cam.aspect);material.SetFloat("_Phase",phase);material.SetFloat("_Progress",progress);material.SetFloat("_Variant",variant%2);
    }
    void Release(){if(surface){surface.gameObject.SetActive(false);Destroy(surface.gameObject);}surface=null;if(mesh)Destroy(mesh);mesh=null;if(material)Destroy(material);material=null;}
    void OnDisable(){Release();}void OnDestroy(){Release();}
}
