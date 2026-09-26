using System.Collections.Generic;
using UnityEngine;

// Isolated, deterministic review effect. Does not schedule or apply combat damage.
public sealed class IceThunderTrial : MonoBehaviour
{
    sealed class Part { public Transform tr; public Material mat; public Vector3 p,s,velocity,spin,center; public Quaternion q; public int kind; public float phase,opacity; }
    readonly List<Part> parts = new List<Part>();
    readonly List<Mesh> meshes = new List<Mesh>();
    readonly List<Material> materials = new List<Material>();
    public Texture2D GroundArt;
    public string StableTargetId;
    public const float ContactTime = .50f;
    uint seed;
    float R(){seed=1664525u*seed+1013904223u;return (seed&0xffffff)/16777215f;}
    float R(float a,float b){return Mathf.Lerp(a,b,R());}
    // Explicit, ordinal UTF-16 hashing: string.GetHashCode is not stable across runtimes.
    public static uint SeedForIdentity(string targetId)
    {
        if(string.IsNullOrEmpty(targetId))throw new System.ArgumentException("A stable target identity is required.",nameof(targetId));
        unchecked
        {
            uint hash=2166136261u;
            foreach(char c in targetId){hash=(hash^(byte)c)*16777619u;hash=(hash^(byte)(c>>8))*16777619u;}
            hash^=hash>>16;hash*=0x7feb352du;hash^=hash>>15;hash*=0x846ca68bu;hash^=hash>>16;
            return hash;
        }
    }
    public void Build(Vector3[] targets)
    {
        Clear(); seed=91837;
        if(targets==null)return;
        uint stableSeed=string.IsNullOrEmpty(StableTargetId)?91837u:SeedForIdentity(StableTargetId);
        for(int k=0;k<targets.Length;k++)
        {
            Vector3 p=targets[k];
            // Use the full stable identity seed for detail, not the four-slot silhouette index.
            // Reordering, moving or rebuilding the same recipient cannot change its shape.
            // The adapter supplies a stable ID and one target. The ordinal salt is only
            // for legacy direct multi-target previews; no seed depends on world position.
            uint identitySeed=unchecked(stableSeed+(uint)k*104729u);
            int variant=(int)(identitySeed&3u);
            seed=identitySeed;
            // Four authored, asymmetric zig-zag silhouettes; substantial faceted bolt rather than a cylinder.
            float[][] paths={new[]{0f,.45f,-.24f,.62f,.04f,-.38f,.16f,0f},new[]{0f,-.34f,-.11f,.49f,-.29f,.32f,-.12f,0f},new[]{0f,.22f,.65f,-.26f,.18f,-.48f,-.20f,0f},new[]{0f,-.51f,.13f,.41f,-.55f,.05f,.35f,0f}};
            Vector3[] c=new Vector3[8];
            for(int j=0;j<8;j++)
            {
                // Same base slot still gets its own irregular interior bends/depth. Keep
                // endpoint anchors, descent heights and all Sample timing intact.
                float bend=j==0||j==7?0:R(-.14f,.14f),depth=j==0||j==7?0:R(-.12f,.12f);
                c[j]=new Vector3(paths[variant][j]+bend,new[]{8.5f,7.9f,6.25f,5.70f,3.95f,2.3f,.8f,0f}[j],j==7?0:Mathf.Sin(j*2.3f+variant)*.24f+depth);
            }
            float[] widths=new float[8];for(int j=0;j<8;j++)widths[j]=new[]{.08f,.20f,.09f,.25f,.10f,.19f,.14f,.055f}[j]*(.9f+variant*.07f)*(j==0||j==7?1:R(.91f,1.09f));
            for(int layer=0;layer<3;layer++)
            {
                float ratio=layer==0?.85f:layer==1?.50f:.10f;
                Add(Tube(c,widths,ratio),p,Vector3.one,layer==0?new Color(.04f,.3f,1):layer==1?new Color(.18f,.8f,1):new Color(.85f,1,1),layer==0?1.1f:layer==1?1.25f:2.4f,0,0,layer==0?.65f:1);
            }
            for(int j=2;j<6;j+=2)
            {
                float side=(j==2?1:-1);Vector3 b=c[j]+new Vector3(side*.75f,-.4f,R(-.25f,.3f)),end=b+new Vector3(-side*.12f,-.7f,.1f);
                Add(Tube(new[]{c[j],b,end},new[]{.06f,.03f,.003f},1),p,Vector3.one,new Color(.38f,.86f,1),2.1f,0,0,.9f);
                // Unequal fine forks break away in depth, not a row of parallel side bars.
                Vector3 fork=Vector3.Lerp(c[j],b,.62f);
                Add(Tube(new[]{fork,fork+new Vector3(side*.19f,-.34f,-.28f),fork+new Vector3(side*.44f,-.78f,-.16f)},new[]{.023f,.012f,.001f},1),p,Vector3.one,new Color(.18f,.65f,1),1.6f,0,0,.70f);
            }
            int count=7+variant%2;
            for(int j=0;j<count;j++)
            {
                float a=R(0,Mathf.PI*2),rad=R(.50f,1.17f);
                Vector3 pos=p+new Vector3(Mathf.Cos(a)*rad,.02f,Mathf.Sin(a)*rad);
                Part part=Add(Crystal(),pos,new Vector3(R(.08f,.15f),R(.40f,1.0f),R(.09f,.18f)),Color.white,.9f,1,R(0,.13f),.96f);
                part.q=Quaternion.Euler(Mathf.Sin(a)*R(15,40),R(0,360),-Mathf.Cos(a)*R(15,40));
                part.center=p;part.spin=new Vector3(Mathf.Sin(a)*R(7,16),R(-9,9),-Mathf.Cos(a)*R(7,16));
            }
            if(GroundArt)
            {
                Part flower=Add(GroundQuad(),p+Vector3.up*.04f,Vector3.one*3.7f,Color.white,.82f,5,0,.96f);
                flower.mat.SetTexture("_MainTex",GroundArt);
                flower.q=Quaternion.Euler(0,variant*37f,0);
            }
            for(int j=0;j<(GroundArt?0:5);j++)
            {
                float a=R(0,Mathf.PI*2), len=R(.65f,2.2f);
                Vector3 dir=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a));
                Mesh slash=GroundSlash(dir,len,R(.07f,.23f));
                Add(slash,p+Vector3.up*R(.045f,.075f),Vector3.one, j%3==0?new Color(.05f,.4f,1):new Color(.45f,.95f,1),2.4f,2,R(0,.07f),.92f);
            }
            for(int j=0;j<30;j++)
            {
                float a=R(0,6.283185f); Vector3 direction=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a));
                Part part=Add(Crystal(),p+Vector3.up*.15f,new Vector3(R(.022f,.05f),R(.09f,.22f),R(.025f,.07f)),Color.white,1.05f,3,R(0,.12f),.96f);
                part.velocity=direction*R(5f,11f)+Vector3.up*R(2.4f,5.5f);part.spin=new Vector3(R(-220,220),R(-180,180),R(-260,260));
            }
            // Disconnected forked ground cues, keeping the full visual silhouette irregular.
            for(int j=0;j<5;j++)
            {float a=R(0,6.283185f);Add(GroundSlash(new Vector3(Mathf.Cos(a),0,Mathf.Sin(a)),R(.5f,1.1f),.045f),p+Vector3.up*.035f,Vector3.one,new Color(.12f,.62f,1),1.4f,4,R(0,.08f),.75f);}
        }
        Sample(0);
    }
    Part Add(Mesh mesh,Vector3 p,Vector3 s,Color color,float gain,int kind,float phase,float opacity)
    {
        var go=new GameObject("Thunder_"+kind);go.transform.SetParent(transform,false);go.transform.position=p;
        var mat=new Material(Shader.Find(kind==0?"Mistport/IceThunderBolt":"Mistport/TrialSurface"));mat.SetColor("_Color",color);mat.SetFloat("_Gain",gain);mat.SetFloat("_Opacity",opacity);materials.Add(mat);if(kind==0 && GroundArt)mat.SetTexture("_MainTex",GroundArt);
        if(kind==1||kind==3||kind==5){mat.shader=Shader.Find("Mistport/IceCrystalTrial");if(GroundArt)mat.SetTexture("_MainTex",GroundArt);mat.SetFloat("_Ground",kind==5?1:0);mat.SetFloat("_Seed",R(0,20));}
        go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<MeshRenderer>().sharedMaterial=mat;
        var part=new Part{tr=go.transform,mat=mat,p=p,s=s,q=Quaternion.identity,kind=kind,phase=phase,opacity=opacity};parts.Add(part);return part;
    }
    public void Sample(float t)
    {
        foreach(var a in parts)
        {
            float alpha=0,scale=1;Vector3 pos=a.p;Quaternion q=a.q;Vector3 shape=Vector3.one;
            if(a.kind==0){alpha=Mathf.Clamp01((t-.24f)/.02f)*(1-Mathf.Clamp01((t-.65f)/.32f));a.mat.SetFloat("_Head",Mathf.Clamp01((t-.24f)/.25f));a.mat.SetFloat("_Phase",t);}
            if(a.kind==1){float dt=t-ContactTime-a.phase;scale=Mathf.Lerp(.04f,2.3f,Mathf.Clamp01(dt/.055f));if(dt>.055f)scale=Mathf.Lerp(2.3f,1,Mathf.Clamp01((dt-.055f)/.28f));alpha=Mathf.Clamp01(dt/.02f)*(1-Mathf.Clamp01((t-2.05f)/.4f));
                float peel=Mathf.Clamp01(dt/.055f)*(1-Mathf.Clamp01((dt-.055f)/.28f));
                pos+=(a.p-a.center)*peel*.24f;q=a.q*Quaternion.Euler(a.spin*peel);
                // Height keeps the 2.3 peak; faces stay slender and fan outward around planted bases.
                shape=new Vector3(.72f+.28f*scale,scale,.78f+.22f*scale);scale=1;}
            if(a.kind==2){float dt=t-.5f-a.phase;scale=Mathf.Lerp(.12f,1.4f,Mathf.Clamp01(dt/.05f));alpha=Mathf.Clamp01(dt/.018f)*(1-Mathf.Clamp01((dt-.1f)/.42f));}
            if(a.kind==3){float dt=Mathf.Max(0,t-ContactTime-a.phase);float flight=.16f*(1-Mathf.Exp(-dt*10))+dt*.38f;pos+=a.velocity*flight+Vector3.down*(3.7f*dt*dt);q=Quaternion.Euler(a.spin*dt);alpha=t<ContactTime+a.phase?0:1-Mathf.Clamp01((dt-.45f)/.62f);}
            if(a.kind==4){alpha=Mathf.Clamp01((t-a.phase)/.08f)*(1-Mathf.Clamp01((t-.23f)/.14f));scale=.6f+t*1.1f;}
            if(a.kind==5){float dt=t-ContactTime;scale=Mathf.Lerp(.3f,1.13f,Mathf.Clamp01(dt/.05f));if(dt>.05f)scale=Mathf.Lerp(1.13f,.82f,Mathf.Clamp01((dt-.05f)/.40f));alpha=Mathf.Clamp01(dt/.02f)*(1-Mathf.Clamp01((t-.65f)/.30f));}
            a.tr.gameObject.SetActive(alpha>.001f);a.tr.position=pos;a.tr.rotation=q;a.tr.localScale=Vector3.Scale(a.s,shape)*scale;a.mat.SetFloat("_Opacity",alpha*a.opacity);
            if(a.kind==1||a.kind==3||a.kind==5)a.mat.SetFloat("_Phase",t);
        }
    }
    Mesh Mesh(Vector3[] v,int[] ix,Color[] colors=null){var m=new Mesh();m.name="IceThunderTrialMesh";m.vertices=v;m.triangles=ix;if(colors!=null)m.colors=colors;m.RecalculateNormals();m.RecalculateBounds();meshes.Add(m);return m;}
    Mesh Tube(Vector3[] centers,float[] radii,float ratio)
    {
        var smoothC=new List<Vector3>();var smoothR=new List<float>();for(int n=0;n<centers.Length-1;n++){for(int step=0;step<6;step++){float u=step/6f;var a=centers[Mathf.Max(0,n-1)];var b=centers[n];var c=centers[n+1];var d=centers[Mathf.Min(centers.Length-1,n+2)];var point=.5f*((2*b)+(-a+c)*u+(2*a-5*b+4*c-d)*u*u+(-a+3*b-3*c+d)*u*u*u);float fine=Mathf.Sin(u*Mathf.PI)*.035f;point+=new Vector3(Mathf.Sin(n*17+step*3)*fine,0,Mathf.Cos(n*11+step*7)*fine);smoothC.Add(point);smoothR.Add(Mathf.Lerp(radii[n],radii[n+1],u)*(1+Mathf.Sin(n*23+step*3)*.13f));}}smoothC.Add(centers[centers.Length-1]);smoothR.Add(radii[radii.Length-1]);centers=smoothC.ToArray();radii=smoothR.ToArray();
        const int sides=12;var v=new Vector3[centers.Length*sides];var uv=new Vector2[v.Length];var ix=new List<int>();
        for(int i=0;i<centers.Length;i++)
        {
            Vector3 tangent=(centers[Mathf.Min(i+1,centers.Length-1)]-centers[Mathf.Max(i-1,0)]).normalized;
            Vector3 u=Vector3.Cross(tangent,Vector3.forward).normalized,w=Vector3.Cross(tangent,u);
            for(int j=0;j<sides;j++){int id=i*sides+j;float a=j*6.283185f/sides;v[id]=centers[i]+(u*Mathf.Cos(a)+w*Mathf.Sin(a))*radii[i]*ratio;uv[id]=new Vector2(j/(float)sides,1-centers[i].y/8.5f);if(i>0){int n=i*sides+(j+1)%sides;ix.AddRange(new[]{id,n,id-sides,n,n-sides,id-sides});}}
        }
        Mesh m=Mesh(v,ix.ToArray());m.uv=uv;return m;
    }
    Mesh Crystal()
    {
        var v=new[]{new Vector3(-1,0,-.6f),new Vector3(.6f,0,-1),new Vector3(1,0,.5f),new Vector3(-.5f,0,1),new Vector3(-.8f,.72f,-.48f),new Vector3(.48f,.68f,-.8f),new Vector3(.8f,.7f,.4f),new Vector3(-.4f,.65f,.8f),new Vector3(R(-.25f,.28f),R(.96f,1.25f),R(-.24f,.17f))};
        for(int i=4;i<8;i++)v[i]=new Vector3(v[i].x*R(.78f,1.15f),v[i].y*R(.82f,1.12f),v[i].z*R(.8f,1.1f));
        int[] faces={0,4,1,1,4,5,1,5,2,2,5,6,2,6,3,3,6,7,3,7,0,0,7,4,4,8,5,5,8,6,6,8,7,7,8,4};
        Color[] palette={new Color(.025f,.13f,.42f),new Color(.17f,.55f,.8f),new Color(.76f,.97f,1),new Color(.08f,.30f,.6f),new Color(.45f,.8f,.95f),Color.white};
        var verts=new Vector3[faces.Length];var colors=new Color[faces.Length];var indices=new int[faces.Length];
        for(int j=0;j<faces.Length;j++){verts[j]=v[faces[j]];colors[j]=palette[(j/6)%palette.Length];indices[j]=j;}return Mesh(verts,indices,colors);
    }
    Mesh GroundQuad()
    {
        const int nxy=32;var vv=new Vector3[(nxy+1)*(nxy+1)];var uv=new Vector2[vv.Length];var ix=new List<int>();for(int y=0;y<=nxy;y++)for(int x=0;x<=nxy;x++){int n=y*(nxy+1)+x;float u=x/(float)nxy,v=y/(float)nxy;float shape=Mathf.Sin(v*Mathf.PI)*Mathf.Sin(u*Mathf.PI);vv[n]=new Vector3((u-.5f)*(1+.11f*Mathf.Sin(v*9)),shape*(.035f+.055f*Mathf.Sin(u*11+v*7)),(v-.5f)*(1+.09f*Mathf.Sin(u*13)));uv[n]=new Vector2(u,v);if(x<nxy&&y<nxy)ix.AddRange(new[]{n,n+nxy+1,n+1,n+1,n+nxy+1,n+nxy+2});}Mesh m=Mesh(vv,ix.ToArray());m.uv=uv;return m;
    }
    Mesh GroundSlash(Vector3 d,float length,float width){Vector3 s=Vector3.Cross(Vector3.up,d)*width;return Mesh(new[]{d*.2f-s,d*.2f+s,d*length*.52f+s*.5f,d*length,d*length*.57f-s*.8f},new[]{0,1,2,0,2,4,2,3,4});}
    static void Release(Object value){if(value){if(Application.isPlaying)Destroy(value);else DestroyImmediate(value);}}
    void Clear(){foreach(var p in parts)if(p.tr){p.tr.gameObject.SetActive(false);Release(p.tr.gameObject);}parts.Clear();foreach(var m in meshes)Release(m);meshes.Clear();foreach(var m in materials)Release(m);materials.Clear();}
    void OnDisable(){foreach(var p in parts)if(p.tr)p.tr.gameObject.SetActive(false);}
    void OnDestroy(){Clear();}
}
