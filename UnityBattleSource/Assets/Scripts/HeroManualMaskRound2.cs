using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Presentation only: the native owner still supplies remaining charges and lifetime.
/// A living costumed echo intercepts locally; no damage, target or clock mutation.
[DefaultExecutionOrder(950)]
public sealed class HeroManualMaskRound2 : MonoBehaviour
{
    sealed class Part { public SkinnedMeshRenderer source; public Transform copy; public Mesh mesh; }
    readonly List<Part> parts=new List<Part>();
    readonly List<Material> materials=new List<Material>();
    readonly List<Color> colors=new List<Color>();
    readonly List<Transform> chips=new List<Transform>();
    readonly List<Mesh> chipMeshes=new List<Mesh>();
    GameObject root;
    Transform actor;
    HeroPorcelainRound2 mask;
    FoolSkillChoreography choreography;
    Material chipMaterial;
    float born,hitAt=-100,fadeAt,expiresAt=float.PositiveInfinity;
    bool fading;
    Vector3 chipOrigin;
    public bool IsActive=>root;
    Vector3 Offset=>(Camera.main?Camera.main.transform.right:Vector3.right)*-.72f+Vector3.forward*.65f;
    public Vector3 Impact=>actor?actor.position+Offset+Vector3.up*.85f:transform.position;

    public void SetLifetime(float seconds) { expiresAt=Time.time+Mathf.Max(0,seconds); }

    public void Deploy(Transform source)
    {
        Clear();if(!source||!source.gameObject.activeInHierarchy)return;
        actor=source;born=Time.time;hitAt=-100;expiresAt=float.PositiveInfinity;fading=false;
        root=new GameObject("R01 living porcelain interception");
        root.transform.SetParent(transform,false);
        choreography=FoolSkillChoreography.Install(source);
        // A manual defence must not replace a currently striking arm action.
        if(!source.GetComponentInChildren<CombatTempoAnimatedBody>()&&choreography&&!choreography.IsPlaying)choreography.Begin(FoolSkillChoreography.ManualMaskID);
        mask=new HeroPorcelainRound2(root.transform,.68f,new Color(1,.72f,.34f));
        foreach(var renderer in source.GetComponentsInChildren<SkinnedMeshRenderer>())
        {
            if(!renderer.enabled||!renderer.sharedMesh||renderer.name.StartsWith("FoolRibbon"))continue;
            var go=new GameObject("Costumed guard echo · "+renderer.name);go.transform.SetParent(root.transform,false);
            var mesh=new Mesh{name="R01 live posed skin"};mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh=mesh;
            var echo=go.AddComponent<MeshRenderer>();echo.shadowCastingMode=ShadowCastingMode.Off;echo.receiveShadows=false;
            var copies=renderer.sharedMaterials;
            for(int i=0;i<copies.Length;i++)
            {
                var material=HeroHuntingEchoMaterial.Create(copies[i],0);
                if(!material)continue;
                material.name="R01 detailed translucent costume";
                material.SetColor("_RimColor",new Color(.65f,.37f,.95f));material.SetFloat("_RimStrength",.85f);
                colors.Add(material.color);materials.Add(material);copies[i]=material;
            }
            echo.sharedMaterials=copies;
            parts.Add(new Part{source=renderer,copy=go.transform,mesh=mesh});
        }
    }

    public void Parry() { if (root && !fading) hitAt = Time.time; }

    public void Hit(int remaining)
    {
        if(!root||fading)return;
        hitAt=Time.time;chipOrigin=Impact+Vector3.up*.46f;
        ClearChips();
        var shader=Resources.Load<Shader>("Effects/Fool/HeroPorcelainRound2");
        if(shader)
        {
            chipMaterial=new Material(shader){name="R01 chipped porcelain",renderQueue=3022};
            chipMaterial.SetColor("_Color",new Color(.89f,.85f,.98f));
            chipMaterial.SetColor("_Gilt",new Color(1,.7f,.26f));
            for(int i=0;i<(remaining<=0?13:5);i++)
            {
                var chip=new GameObject("Uneven porcelain flake "+i);chip.transform.SetParent(root.transform,false);
                var mesh=Chip(i);chipMeshes.Add(mesh);
                chip.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=chip.AddComponent<MeshRenderer>();
                renderer.sharedMaterial=chipMaterial;renderer.shadowCastingMode=ShadowCastingMode.Off;
                chips.Add(chip.transform);
            }
        }
        if(remaining<=0){fading=true;fadeAt=Time.time;}
    }

    void LateUpdate()
    {
        if(!root)return;
        if(!actor||!actor.gameObject.activeInHierarchy||Time.time>=expiresAt){Clear();return;}
        float age=Time.time-born,hitAge=Mathf.Max(0,Time.time-hitAt);
        float fade=fading?Mathf.Clamp01(1-(Time.time-fadeAt)/.55f):Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.28f));
        if(!fading)fade*=Mathf.Clamp01((expiresAt-Time.time)/.8f);
        float response=Mathf.Exp(-hitAge*13),recoil=Mathf.Sin(Mathf.Clamp01(hitAge/.24f)*Mathf.PI)*.15f;
        var camera=Camera.main;Vector3 right=camera?camera.transform.right:Vector3.right;
        Vector3 shift=Offset-Vector3.forward*recoil+Vector3.up*(Mathf.Sin(age*2.2f)*.018f);
        for(int i=0;i<materials.Count;i++)
        {
            Color color=colors[i];color.a*=fade*.48f;materials[i].color=color;
            materials[i].SetColor("_RimColor",Color.Lerp(new Color(.65f,.37f,.95f),new Color(1,.73f,.28f),response));
            materials[i].SetFloat("_RimStrength",.85f+response*.72f);
        }
        foreach(var part in parts)
        {
            if(!part.source||!part.copy)continue;
            // Bake in unscaled renderer space, then apply exactly one source scale.
            part.source.BakeMesh(part.mesh,false);
            part.copy.SetPositionAndRotation(part.source.transform.position+shift,part.source.transform.rotation);
            part.copy.localScale=part.source.transform.lossyScale;
        }
        if(mask!=null&&mask.Root)
        {
            mask.Root.position=actor.position+shift+Vector3.up*1.32f+right*(.18f+Mathf.Sin(age*1.7f)*.035f);
            mask.Root.rotation=(camera?camera.transform.rotation:Quaternion.identity)*Quaternion.Euler(-8-response*12,194+Mathf.Sin(age*1.2f)*6,-5-response*9);
            mask.Sample(age,fade,fading?Mathf.Clamp01((Time.time-fadeAt)/.5f):0,response);
        }
        if(chipMaterial)
        {
            float flakeFade=Mathf.Clamp01(1-hitAge/.55f);
            chipMaterial.SetFloat("_Fade",flakeFade);chipMaterial.SetFloat("_Clock",age);
            chipMaterial.SetFloat("_Dissolve",1-flakeFade);chipMaterial.SetFloat("_Response",response);
            for(int i=0;i<chips.Count;i++)
            {
                float n=Noise(i+3),turn=(Noise(i+19)*2-1)*1.7f;
                Vector3 direction=right*turn+Vector3.up*(.13f+n*.45f)+Vector3.back*(.14f+Noise(i+41)*.35f);
                chips[i].position=chipOrigin+direction*(1-Mathf.Exp(-hitAge*10))*(fading?.72f:.38f)-Vector3.up*hitAge*hitAge*.85f;
                chips[i].rotation=(camera?camera.transform.rotation:Quaternion.identity)*Quaternion.Euler(i*37+hitAge*230,i*71+hitAge*160,i*19);
                chips[i].localScale=Vector3.one*(.055f+n*.082f);
            }
            if(flakeFade<=0)ClearChips();
        }
        if(fading&&fade<=0)Clear();
    }

    static float Noise(int i)=>Mathf.Repeat(Mathf.Sin(i*17.37f+4.19f)*4321.77f,1);
    static Mesh Chip(int seed)
    {
        // Small curled, thick porcelain splinters, not square particle plates.
        const int count=7;var vertices=new Vector3[count*2];var triangles=new List<int>();
        for(int i=0;i<count;i++)
        {
            float a=(i+Noise(seed*9+i)*.4f)*Mathf.PI*2/count;
            float radius=.28f+Noise(seed*13+i+2)*.24f;
            vertices[i]=new Vector3(Mathf.Cos(a)*radius,Mathf.Sin(a)*radius*(.9f+Noise(seed)*.7f),Mathf.Sin(a*2+seed)*.11f);
            vertices[i+count]=vertices[i]+Vector3.forward*.06f;
            if(i>1){triangles.Add(0);triangles.Add(i);triangles.Add(i-1);triangles.Add(count);triangles.Add(count+i-1);triangles.Add(count+i);}
            int b=(i+1)%count;triangles.Add(i);triangles.Add(b);triangles.Add(i+count);triangles.Add(b);triangles.Add(b+count);triangles.Add(i+count);
        }
        var mesh=new Mesh{name="R01 irregular thick chip"};mesh.vertices=vertices;mesh.SetTriangles(triangles,0);
        var uv=new Vector2[vertices.Length];for(int i=0;i<uv.Length;i++)uv[i]=new Vector2(vertices[i].x+.5f,vertices[i].y+.5f);mesh.uv=uv;
        mesh.RecalculateNormals();mesh.RecalculateBounds();return mesh;
    }
    void ClearChips()
    {
        foreach(var chip in chips)if(chip){chip.gameObject.SetActive(false);Destroy(chip.gameObject);}chips.Clear();
        foreach(var mesh in chipMeshes)if(mesh)Destroy(mesh);chipMeshes.Clear();
        if(chipMaterial)Destroy(chipMaterial);chipMaterial=null;
    }
    public void Clear()
    {
        if(choreography&&choreography.CurrentSkill==FoolSkillChoreography.ManualMaskID)choreography.Clear();choreography=null;
        ClearChips();mask?.Dispose();mask=null;
        if(root){root.SetActive(false);Destroy(root);}root=null;
        foreach(var part in parts)if(part.mesh)Destroy(part.mesh);parts.Clear();
        foreach(var material in materials)if(material)Destroy(material);materials.Clear();colors.Clear();actor=null;
    }
    void OnDisable()=>Clear();
    void OnDestroy()=>Clear();
}
