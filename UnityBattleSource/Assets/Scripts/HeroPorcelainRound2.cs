using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Private copies of the authored porcelain model and its material detail.
public sealed class HeroPorcelainRound2 : IDisposable
{
    readonly List<Material> materials=new List<Material>();
    public Transform Root { get; private set; }
    public HeroPorcelainRound2(Transform parent,float height,Color glow)
    {
        var prefab=Resources.Load<GameObject>("Effects/Fool/NamelessDeclaration/MaskActor");
        var shader=Resources.Load<Shader>("Effects/Fool/HeroPorcelainRound2");
        if(!prefab||!shader)return;
        Root=new GameObject("Authored porcelain with moving gilt seams").transform;
        Root.SetParent(parent,false);
        var model=UnityEngine.Object.Instantiate(prefab,Root);
        var renderers=model.GetComponentsInChildren<Renderer>(true);
        if(renderers.Length==0){Dispose();return;}
        Bounds bounds=renderers[0].bounds;
        foreach(var renderer in renderers)bounds.Encapsulate(renderer.bounds);
        model.transform.position+=Root.position-bounds.center;
        Root.localScale=Vector3.one*(height/Mathf.Max(.001f,bounds.size.y));
        foreach(var renderer in renderers)
        {
            var copies=renderer.sharedMaterials;
            for(int i=0;i<copies.Length;i++)
            {
                if(!copies[i])continue;
                var source=copies[i];
                var material=new Material(source){shader=shader,name=source.name+" hero porcelain round2",renderQueue=3021};
                if(source.HasProperty("_BaseMap"))
                {
                    material.SetTexture("_MainTex",source.GetTexture("_BaseMap"));
                    material.SetTextureScale("_MainTex",source.GetTextureScale("_BaseMap"));
                    material.SetTextureOffset("_MainTex",source.GetTextureOffset("_BaseMap"));
                }
                material.SetFloat("_HasNormal",source.HasProperty("_BumpMap")&&source.GetTexture("_BumpMap")?1:0);
                Color color=source.HasProperty("_BaseColor")?source.GetColor("_BaseColor"):
                    source.HasProperty("_Color")?source.GetColor("_Color"):Color.white;
                material.SetColor("_Color",color);material.SetColor("_Gilt",glow);
                material.SetFloat("_Fade",0);material.SetFloat("_Dissolve",0);
                copies[i]=material;materials.Add(material);
            }
            renderer.sharedMaterials=copies;renderer.shadowCastingMode=ShadowCastingMode.Off;
        }
    }
    public void Sample(float time,float fade,float dissolve=0,float response=0)
    {
        foreach(var material in materials)
        {
            material.SetFloat("_Clock",time);material.SetFloat("_Fade",Mathf.Clamp01(fade));
            material.SetFloat("_Dissolve",Mathf.Clamp01(dissolve));material.SetFloat("_Response",Mathf.Clamp01(response));
        }
    }
    // Explicit opt-in for distant identity portraits. Manual guard R01 keeps
    // its original costume/mask response because it never calls this method.
    public void EnablePortraitReadability()
    {
        foreach(var material in materials)
        {
            material.SetFloat("_PortraitFill",1);
            if(material.name.IndexOf("ivory",StringComparison.OrdinalIgnoreCase)>=0)
            {
                Color original=material.GetColor("_Color");
                material.SetColor("_Color",Color.Lerp(original,new Color(.88f,.82f,.74f,original.a),.70f));
            }
        }
    }
    // Used only by authored identity spells after the original porcelain
    // texture is installed.  R01 never opts in, so its approved guard stays put.
    public void TintPortraitSurface(Color tint,float strength)
    {
        foreach(var material in materials)
        {
            Color baseColor=material.GetColor("_Color");
            Color toned=Color.Lerp(baseColor,new Color(tint.r,tint.g,tint.b,baseColor.a),Mathf.Clamp01(strength));
            toned.a=baseColor.a;
            material.SetColor("_Color",toned);
        }
    }
    public void Dispose()
    {
        if(Root){Root.gameObject.SetActive(false);UnityEngine.Object.Destroy(Root.gameObject);}Root=null;
        foreach(var material in materials)if(material)UnityEngine.Object.Destroy(material);materials.Clear();
    }
}
