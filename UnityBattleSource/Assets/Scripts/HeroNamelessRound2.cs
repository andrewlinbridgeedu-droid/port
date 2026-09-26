using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// One declaration per actual owner. The three porcelain memories contract inward;
/// this is an all-living state gesture, not an additional damaging area explosion.
public sealed class HeroNamelessRound2 : MonoBehaviour
{
    const float ContactTime=.96f,EndTime=1.95f;
    int generation;
    GameObject root;
    HeroSpellVolume volume;
    readonly HeroPorcelainRound2[] masks=new HeroPorcelainRound2[3];
    readonly Vector3[] scales=new Vector3[3];
    Mesh veilMesh;
    Material veilMaterial;
    readonly List<Vector3> vertices=new List<Vector3>(3600);
    readonly List<Color> colors=new List<Color>(3600);
    readonly List<Vector2> uv=new List<Vector2>(3600);
    readonly List<int> triangles=new List<int>(5400);
    Vector3 right,up,forward;

    public IEnumerator Play(Func<Vector3> caster,Func<Vector3> target,Action onContact,Func<bool> targetValid=null)
    {
        Clear();int run=generation;
        if(caster==null||target==null)yield break;
        root=new GameObject("H10 target-owned porcelain declaration");root.transform.SetParent(transform,true);
        volume=new HeroSpellVolume(root.transform,10,ContactTime);
        for(int i=0;i<3;i++)
        {
            // A multi-target declaration needs four separate focal portraits;
            // large side faces previously merged into one white wall.
            masks[i]=new HeroPorcelainRound2(root.transform,i==0?2.02f:i==1?.93f:.84f,
                i==0?new Color(1,.72f,.30f):i==1?new Color(.75f,.35f,.92f):new Color(.94f,.41f,.44f));
            masks[i].EnablePortraitReadability();
            masks[i].TintPortraitSurface(i==0?new Color(.89f,.60f,.69f):
                i==1?new Color(.59f,.37f,.77f):new Color(1,.68f,.43f),i==0?.58f:.72f);
            if(masks[i].Root)scales[i]=masks[i].Root.localScale;
        }
        var shader=Shader.Find("Sprites/Default");
        if(shader)
        {
            var node=new GameObject("Three deep curling memory veils");node.transform.SetParent(root.transform,false);
            veilMesh=new Mesh{name="H10 folded asymmetric veils"};veilMesh.MarkDynamic();
            veilMaterial=new Material(shader){name="H10 plum velvet and gilt hems",renderQueue=3018};
            node.AddComponent<MeshFilter>().sharedMesh=veilMesh;
            var renderer=node.AddComponent<MeshRenderer>();renderer.sharedMaterial=veilMaterial;renderer.shadowCastingMode=ShadowCastingMode.Off;
        }
        float elapsed=0;bool contacted=false;
        try
        {
            while(elapsed<EndTime&&run==generation)
            {
                if(targetValid!=null&&!targetValid())yield break;
                Vector3 s=caster(),t=target();Draw(elapsed,s,t);volume.Sample(elapsed,s,t);
                if(!contacted&&elapsed>=ContactTime){contacted=true;onContact?.Invoke();if(run!=generation)yield break;}
                yield return null;elapsed+=Time.deltaTime;
            }
            if(!contacted&&run==generation&&(targetValid==null||targetValid())){contacted=true;onContact?.Invoke();}
        }
        finally{if(run==generation)Clear();}
    }

    void Draw(float time,Vector3 source,Vector3 target)
    {
        var camera=Camera.main;right=camera?camera.transform.right:Vector3.right;
        up=camera?camera.transform.up:Vector3.up;forward=camera?camera.transform.forward:Vector3.forward;
        float appear=Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.21f)/.36f));
        float declare=Mathf.Pow(Mathf.Clamp01((time-.75f)/.21f),2.4f);
        float dissolve=Mathf.Clamp01((time-ContactTime)/(EndTime-ContactTime));
        float close=Mathf.SmoothStep(0,1,Mathf.Clamp01((time-ContactTime)/.36f));
        Vector3 stage=Vector3.Lerp(source,target,.88f)+up*1.05f-forward*.72f;
        Vector3 center=Vector3.Lerp(stage,target+up*.92f-forward*.90f,declare);
        for(int i=0;i<3;i++)
        {
            if(masks[i]==null||!masks[i].Root)continue;
            float side=i==0?0:i==1?-.79f:.83f;
            Vector3 point=center+right*side*(1-declare*.12f)*(1-close*.31f)
                +up*(i==0?.16f:i==1?-.27f:.39f)+forward*(i==0?-.32f:.13f+i*.12f)
                +up*Mathf.Sin(time*3.7f+i*1.4f)*.065f+up*dissolve*.46f;
            masks[i].Root.position=point;
            Vector3 face=camera?camera.transform.position-point:-forward;
            masks[i].Root.rotation=Quaternion.LookRotation(face,up)*Quaternion.Euler(i==0?-3:5,
                (i==0?-4:i==1?12:-15)*(1-declare*.50f)+close*(i==1?5:-3),i==0?-4:i==1?9:-11);
            masks[i].Root.localScale=scales[i]*(.88f+.12f*appear)*(1-dissolve*.18f);
            float alpha=Mathf.SmoothStep(0,1,Mathf.Clamp01((time-.18f-i*.055f)/.20f))
                *(1-Mathf.SmoothStep(0,1,Mathf.Clamp01((dissolve-.22f)/.78f)));
            masks[i].Sample(time,alpha,Mathf.SmoothStep(0,1,Mathf.Clamp01((dissolve-.18f)/.82f)),time>=ContactTime?Mathf.Exp(-(time-ContactTime)*9):0);
        }
        if(!veilMesh)return;
        vertices.Clear();colors.Clear();uv.Clear();triangles.Clear();
        float strength=Mathf.Clamp01(time/.25f)*(1-dissolve);
        for(int i=0;i<3;i++)Veil(center,i,time,appear,strength,close);
        // Unequal flakes fold toward the local memory, never radiate as damage rays.
        for(int i=0;i<23;i++)
        {
            float flow=Mathf.Repeat(Noise(i+9)+time*.38f,1),side=i%2==0?-1:1;
            Vector3 p=center+right*side*(.23f+(1-flow)*(.60f+Noise(i)*.62f))
                +up*((Noise(i+21)-.5f)*2.15f+flow*.34f)+forward*(.10f+Noise(i+63)*.38f);
            Vector3 along=(up*.8f+right*side*.24f).normalized*(.016f+Noise(i+41)*.025f);
            Vector3 cross=right*(.007f+Noise(i+81)*.009f);
            float a=strength*appear*Mathf.Sin(flow*Mathf.PI)*.8f;
            Add(p-along-cross,p+along*.75f-cross*.3f,p+along*.4f+cross*.7f,p-along*.6f+cross,
                new Color(1,.59f+Noise(i+11)*.2f,.28f,a));
        }
        veilMesh.Clear();veilMesh.SetVertices(vertices);veilMesh.SetColors(colors);veilMesh.SetUVs(0,uv);
        veilMesh.SetTriangles(triangles,0);veilMesh.RecalculateBounds();
    }

    void Veil(Vector3 center,int seed,float time,float appear,float strength,float close)
    {
        const int length=28,width=10;
        float side=seed==1?1:-1;
        for(int j=0;j<length;j++)for(int k=0;k<width;k++)
        {
            float u=j/(float)length,v=k/(float)width;
            float brightness=.26f+Mathf.Pow(Mathf.Max(0,Mathf.Cos(v*6.8f+u*3.7f-time*2+seed)),4)*.84f;
            float hem=k==0||k==width-1?Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*9.1f-time*3+seed)),5)*.78f:0;
            float inlay=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*15.7f+v*8.2f+seed*2.1f-time*2.4f)),7)*.22f;
            float alpha=strength*appear*Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.65f)*(.83f-hem*.16f);
            Color shade=Color.Lerp(new Color(.22f,.022f,.15f,alpha),new Color(.70f,.12f,.35f,alpha),brightness);
            shade=Color.Lerp(shade,new Color(1,.65f,.23f,alpha),Mathf.Max(hem,inlay));
            Add(VeilPoint(center,seed,side,u,v,time,close),VeilPoint(center,seed,side,u+1f/length,v,time,close),
                VeilPoint(center,seed,side,u+1f/length,v+1f/width,time,close),VeilPoint(center,seed,side,u,v+1f/width,time,close),shade);
        }
    }
    Vector3 VeilPoint(Vector3 c,int seed,float side,float u,float v,float time,float close)
    {
        float envelope=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.8f);
        float wave=u*(4.7f+seed*.8f)-time*1.8f+seed*2.1f;
        Vector3 center=c+right*side*(.47f+seed*.11f+Mathf.Sin(wave)*.19f)*(1-close*.36f)
            +up*((.62f-u)*(2.3f-seed*.24f))+forward*(.45f+seed*.22f+Mathf.Sin(wave*.7f)*.18f);
        float half=(seed==0?.42f:seed==1?.31f:.22f)*envelope;
        float edge=.79f+Mathf.Sin(u*18.7f+seed)*.13f+Mathf.Sin(u*37.2f-seed)*.07f;
        float across=(v-.5f)*2*half*edge;
        float roll=wave*.44f+close*1.6f+v*1.9f;
        return center+right*across*Mathf.Cos(roll)+forward*(across*Mathf.Sin(roll)+Mathf.Sin(v*6.8f+wave)*half*.21f);
    }
    void Add(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Color color)
    {
        int n=vertices.Count;vertices.Add(a);vertices.Add(b);vertices.Add(c);vertices.Add(d);
        for(int i=0;i<4;i++)colors.Add(color);uv.Add(Vector2.zero);uv.Add(Vector2.right);uv.Add(Vector2.one);uv.Add(Vector2.up);
        triangles.Add(n);triangles.Add(n+1);triangles.Add(n+2);triangles.Add(n);triangles.Add(n+2);triangles.Add(n+3);
    }
    static float Noise(int i)=>Mathf.Repeat(Mathf.Sin(i*17.37f+4.19f)*4321.77f,1);
    public void Clear()
    {
        generation++;volume?.Dispose();volume=null;
        for(int i=0;i<masks.Length;i++){masks[i]?.Dispose();masks[i]=null;}
        if(root){root.SetActive(false);Destroy(root);}root=null;
        if(veilMesh)Destroy(veilMesh);veilMesh=null;if(veilMaterial)Destroy(veilMaterial);veilMaterial=null;
    }
    void OnDisable()=>Clear();
    void OnDestroy()=>Clear();
}
