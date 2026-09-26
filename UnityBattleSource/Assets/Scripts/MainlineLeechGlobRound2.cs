using UnityEngine;

// Per-instance wet bolus: actual lobed surface, not a tinted stock sphere.
public sealed class MainlineLeechGlobRound2 : MonoBehaviour
{
    Mesh mesh;Vector3[] rest,points;Material surface;
    void Awake(){
        var filter=GetComponent<MeshFilter>();if(!filter||!filter.sharedMesh)return;
        mesh=Instantiate(filter.sharedMesh);mesh.name="Unequal viscous memory bolus";mesh.MarkDynamic();filter.sharedMesh=mesh;
        rest=mesh.vertices;points=new Vector3[rest.Length];
        var renderer=GetComponent<Renderer>();if(renderer)surface=renderer.sharedMaterial;
    }
    public void Sample(float age){
        if(!mesh)return;
        if(surface)surface.SetFloat("_Age",age);
        for(int i=0;i<rest.Length;i++){
            Vector3 p=rest[i],n=p.normalized;
            float a=Mathf.Atan2(n.z,n.x),b=Mathf.Asin(Mathf.Clamp(n.y,-1f,1f));
            float lobe=1+.19f*Mathf.Sin(a*2.7f+b*2.3f+age*4)+.11f*Mathf.Cos(b*4.7f-a*1.3f-age*3);
            points[i]=new Vector3(p.x*lobe,p.y*(.91f+lobe*.13f),p.z*lobe*1.31f);
        }
        mesh.vertices=points;mesh.RecalculateNormals();mesh.RecalculateBounds();
    }
    void OnDestroy(){if(mesh)Destroy(mesh);}
}
