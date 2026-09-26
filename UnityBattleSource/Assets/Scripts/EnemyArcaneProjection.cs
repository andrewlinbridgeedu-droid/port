using UnityEngine;
using UnityEngine.Rendering;

/// Authored, world-anchored energy around physical enemy spells; never owns hits.
public sealed class EnemyArcaneProjection : MonoBehaviour
{
    Material material;
    Mesh mesh;
    Transform surface;
    void Awake()
    {
        var shader=Resources.Load<Shader>("EnemySignature/EnemyArcaneProjection");
        if(!shader) { Debug.LogError("Enemy arcane projection shader missing"); return; }
        var go=new GameObject("Enemy world anchored energy");
        go.transform.SetParent(transform,false);surface=go.transform;
        mesh=new Mesh{name="Enemy arcane projection mesh"};
        mesh.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};
        mesh.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};mesh.triangles=new[]{0,2,1,0,3,2};mesh.RecalculateBounds();
        material=new Material(shader){name="Enemy arcane projection owned"};
        go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=material;
        renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
    }
    public void Draw(int kind,int phase,float progress,Vector3 source,Vector3 target)
    {
        var cam=Camera.main;if(!cam||!surface||!material)return;
        float distance=cam.nearClipPlane+.16f;
        float height=cam.orthographic?cam.orthographicSize*2:2*distance*Mathf.Tan(cam.fieldOfView*Mathf.Deg2Rad*.5f);
        surface.position=cam.transform.TransformPoint(new Vector3(0,0,distance));surface.rotation=cam.transform.rotation;
        surface.localScale=new Vector3(height*cam.aspect,height,1);
        material.SetFloat("_Kind",kind);material.SetFloat("_Phase",phase);material.SetFloat("_Progress",progress);
        material.SetFloat("_Aspect",cam.aspect);
        material.SetVector("_Source",cam.WorldToViewportPoint(source));material.SetVector("_Target",cam.WorldToViewportPoint(target));
    }
    void OnDestroy(){if(material)Destroy(material);if(mesh)Destroy(mesh);}
}
