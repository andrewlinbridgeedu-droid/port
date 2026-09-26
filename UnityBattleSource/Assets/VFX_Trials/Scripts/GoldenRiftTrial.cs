using System.Collections.Generic;
using UnityEngine;

// Independent, deterministic visual study. No damage or production routes.
public sealed class GoldenRiftTrial : MonoBehaviour
{
    readonly List<Mesh> meshes = new List<Mesh>();
    readonly List<Material> materials = new List<Material>();
    readonly List<Piece> pieces = new List<Piece>();
    readonly List<Transform> owned = new List<Transform>();
    readonly List<Material> curlMaterials = new List<Material>();
    sealed class Piece { public Transform tr; public Vector3 pos, scale, velocity; public Quaternion rot; public float start, life, spin; public bool flying; }
    public Texture2D SurfaceArt { get; set; }
    Material floodMaterial; Transform floodTransform; Material artMaterial; Transform artTransform; Material heat;
    float length;
    Material dark, edge, hot, white, rock;
    static readonly float[] Z = {0,.055f,.14f,.23f,.29f,.43f,.53f,.60f,.74f,.80f,.93f,1};
    static readonly float[] L = {.32f,.58f,.44f,.95f,.72f,.79f,1.13f,.82f,.94f,.70f,1.04f,.60f};
    static readonly float[] R = {.39f,.44f,.77f,.58f,.91f,.68f,.82f,1.10f,.73f,1.04f,.79f,.56f};
    Material Mat(string n,Color c,float gain=1) { var m=new Material(Shader.Find("Mistport/TrialSurface")); m.name=n; m.SetColor("_Color",c);m.SetFloat("_Gain",gain);m.SetFloat("_Opacity",1);materials.Add(m);return m; }
    public float WidthFactor=1f;
    public const float ContactTime=.84f;
 public void Build(Vector3 origin, Vector3 target)
    {
        Clear();
        transform.position=origin;var d=target-origin;d.y=0;length=Mathf.Max(1,d.magnitude);transform.rotation=Quaternion.LookRotation(d.sqrMagnitude>.01f?d:Vector3.forward);
        dark=Mat("Rift opaque abyss",new Color(.009f,.035f,.045f,1));rock=Mat("Basalt teal walls",new Color(.018f,.095f,.105f,1));
        edge=Mat("Liquid gold lip",new Color(1,.60f,.055f,1),1.1f);hot=Mat("Orange heat beneath lip",new Color(1,.105f,.007f,1),1.0f);white=Mat("Gold white fracture",new Color(1,.91f,.54f,1),1.6f);
        if(SurfaceArt){rock.shader=Shader.Find("Mistport/RiftRockTrial");rock.SetTexture("_MainTex",SurfaceArt);}
        heat=new Material(Shader.Find("Mistport/TrialHeat"));heat.SetTexture("_MainTex",Resources.Load<Texture2D>("Effects/HellHound/Texture/Fire_Single"));materials.Add(heat);
        if(SurfaceArt)
        {
            artMaterial=new Material(Shader.Find("Mistport/GoldenRiftArt"));artMaterial.SetTexture("_MainTex",SurfaceArt);artMaterial.SetFloat("_TargetU",length/(length+4f));materials.Add(artMaterial);
            const int nx=128,nz=192;var vv=new Vector3[(nx+1)*(nz+1)];var uv=new Vector2[vv.Length];var idx=new List<int>();for(int j=0;j<=nz;j++)for(int i=0;i<=nx;i++){int n=j*(nx+1)+i;vv[n]=new Vector3((i/(float)nx-.5f)*10f*WidthFactor,.035f,j/(float)nz*(length+4f));uv[n]=new Vector2(j/(float)nz,i/(float)nx);if(j<nz&&i<nx)idx.AddRange(new[]{n,n+nx+1,n+1,n+1,n+nx+1,n+nx+2});}
            var art=MeshObject("Textured displaced rupture",vv,idx.ToArray(),artMaterial);artTransform=art;art.GetComponent<MeshFilter>().sharedMesh.uv=uv;art.GetComponent<MeshFilter>().sharedMesh.bounds=new Bounds(new Vector3(0,.7f,(length+4f)*.5f),new Vector3(Mathf.Max(1,12*WidthFactor),5,length+9));
            BuildCurls();
        }
        for(int i=0;i<(SurfaceArt?0:Z.Length-1);i++)
        {
            float z0=Z[i]*length,z1=Z[i+1]*length;float birth=.18f+Z[i]*.65f;
            if(!SurfaceArt) Make("Continuous dark aperture "+i,new[]{new Vector3(-L[i],.022f,z0),new Vector3(R[i],.022f,z0),new Vector3(R[i+1],.022f,z1),new Vector3(-L[i+1],.022f,z1)},new[]{0,2,1,0,3,2},dark,birth);
            for(int s=-1;s<=1;s+=2)
            {
                float x0=s*(s<0?L[i]:R[i]),x1=s*(s<0?L[i+1]:R[i+1]);
                float h0=.035f+.05f*Noise(i*3+s+20),h1=.04f+.09f*Noise(i*9+s+50);
                float width=.065f+.085f*Noise(i*17+s+90);
                Vector3 a=new Vector3(x0,.025f,z0),b=new Vector3(x1,.025f,z1),c=b+new Vector3(s*width,h1,0),e=a+new Vector3(s*width,h0,0);
                Make("Jagged risen wall",new[]{a,b,c,e},new[]{0,1,2,0,2,3},rock,birth);
                Make("Molten exposed seam",new[]{a+Vector3.up*.007f,b+Vector3.up*.007f,Vector3.Lerp(b,c,.72f),Vector3.Lerp(a,e,.72f)},new[]{0,1,2,0,2,3},hot,birth);
                Vector3 off=new Vector3(s*(.055f+.045f*Noise(i+8)), -.045f,0);
                Make("Broad golden torn lip",new[]{e,c,c+off,e+off},new[]{0,1,2,0,2,3},edge,birth);
                Make("White hot sharp lip",new[]{e,c,c+off*.17f+Vector3.up*.009f,e+off*.17f+Vector3.up*.009f},new[]{0,1,2,0,2,3},white,birth);
                if(!SurfaceArt && (i+s+12)%3==0)
                {
                    Vector3 mid=Vector3.Lerp(e,c,.30f+.3f*Noise(i));
                    Vector3 tip=mid+new Vector3(s*(.45f+.5f*Noise(i+50)),.03f,.15f+.28f*Noise(i+51));
                    Make("Asymmetric branching gold fracture",new[]{e,c,tip,mid+new Vector3(s*.13f,.01f,-.26f)},new[]{0,1,2,0,2,3},edge,birth+.04f);
                }
            }
        }
        floodMaterial=new Material(Shader.Find("Mistport/RiftFlood"));materials.Add(floodMaterial);floodMaterial.SetTexture("_MainTex",SurfaceArt);
        var fv=new Vector3[65*33];var fu=new Vector2[fv.Length];var fi=new List<int>();
        for(int j=0;j<=64;j++)for(int i=0;i<=32;i++) {int n=j*33+i;float u=i/32f,v=j/64f;fv[n]=new Vector3((u-.5f)*11,.065f,v*(length+1.4f));fu[n]=new Vector2(u,v);if(j<64&&i<32)fi.AddRange(new[]{n,n+33,n+1,n+1,n+33,n+34});}
        floodTransform=MeshObject("Broad molten battlefield flood",fv,fi.ToArray(),floodMaterial);floodTransform.GetComponent<MeshFilter>().sharedMesh.uv=fu;
        // Unequal contact rays at the far end, separate from the travelling ground front.
        for(int i=0;i<0;i++) {
            float a=i*2.39996f,r=.25f+Noise(i+909)*.50f;
            Vector3 c=new Vector3(0,1.15f,length),tip=c+new Vector3(Mathf.Cos(a)*r,Mathf.Sin(a)*r,0);
            Vector3 w=new Vector3(-Mathf.Sin(a),Mathf.Cos(a),0)*(.025f+Noise(i+911)*.035f);
            var tr=MeshObject("Far contact flash",new[]{c-w,c+w,tip},new[]{0,1,2},white);
            pieces.Add(new Piece{tr=tr,pos=Vector3.zero,scale=Vector3.one,rot=Quaternion.identity,start=.79f,life=.21f});
        }
        // Large individual flying slabs, with different widths and thicknesses.
        for(int i=0;i<0;i++)
        {
            float n=Noise(i+201),side=i%2==0?-1:1;float z=length*(.12f+.84f*Noise(i+202));
            Vector3 p=new Vector3(side*(.5f+.30f*n),.07f,z);
            var tr=Shard("Broken crust slab "+i,.10f+.16f*Noise(i+210),.20f+.32f*Noise(i+211),.09f+.19f*n,rock);
            tr.localPosition=p;tr.localRotation=Quaternion.Euler(Noise(i+215)*25,Noise(i+216)*180,side*20);
            pieces.Add(new Piece{tr=tr,pos=p,scale=Vector3.one,rot=tr.localRotation,start=.83f+Noise(i+219)*.10f,life=.85f+Noise(i+220)*.5f,flying=true,velocity=new Vector3(side*(1.2f+n*1.6f),2.5f+Noise(i+224)*3,Noise(i+225)*1.8f),spin=(Noise(i+229)-.5f)*430});
        }
        // Needle chips depart in broad, uneven directional fans; no radial wheel.
        for(int i=0;i<24;i++)
        {
            float side=i%2==0?-1:1;Vector3 p=new Vector3(side*.55f,.2f,length*(.16f+.82f*Noise(i+500)));
            var tr=Shard("Incandescent chip "+i,.013f+.031f*Noise(i+501),.12f+.28f*Noise(i+502),.014f,white);
            tr.localPosition=p;tr.localRotation=Quaternion.Euler(25,Noise(i+504)*180,Noise(i+505)*80);
            pieces.Add(new Piece{tr=tr,pos=p,rot=tr.localRotation,scale=Vector3.one,start=.85f+.10f*Noise(i+507),life=.38f+.52f*Noise(i+508),flying=true,velocity=new Vector3(side*(1.5f+3*Noise(i+509)),1+5*Noise(i+510),(Noise(i+511)-.1f)*4),spin=300});
        }
        Sample(0);
    }
    Transform Shard(string name,float w,float h,float depth,Material material)
    {
        return MeshObject(name,new[]{new Vector3(-w,0,0),new Vector3(w*.7f,0,h*.15f),new Vector3(w*.45f,0,h*.74f),new Vector3(-w*.35f,0,h),new Vector3(0,depth,h*.43f)},new[]{0,4,1,1,4,2,2,4,3,3,4,0,0,1,2,0,2,3},material);
    }
    void Make(string name,Vector3[] vertices,int[] triangles,Material m,float start)
    {
        var tr=MeshObject(name,vertices,triangles,m);pieces.Add(new Piece{tr=tr,pos=Vector3.zero,scale=Vector3.one,rot=Quaternion.identity,start=start,life=2.6f});
    }
    Transform MeshObject(string name,Vector3[] vertices,int[] triangles,Material m)
    {
        var g=new GameObject(name);g.transform.SetParent(transform,false);owned.Add(g.transform);var mesh=new Mesh{name=name};mesh.vertices=vertices;mesh.triangles=triangles;var cc=new Color[vertices.Length];for(int q=0;q<cc.Length;q++)cc[q]=Color.Lerp(new Color(.35f,.49f,.52f),Color.white,(q%3)*.5f);mesh.colors=cc;var grainUV=new Vector2[vertices.Length];for(int q=0;q<grainUV.Length;q++)grainUV[q]=new Vector2((q%3)*.5f,(q%2));mesh.uv=grainUV;mesh.RecalculateNormals();mesh.RecalculateBounds();meshes.Add(mesh);g.AddComponent<MeshFilter>().sharedMesh=mesh;var mr=g.AddComponent<MeshRenderer>();mr.sharedMaterial=m;if(name.Contains("heat")||name.Contains("Heat")){mr.sharedMaterial=heat;var uv=new Vector2[vertices.Length];var b=mesh.bounds;for(int q=0;q<uv.Length;q++)uv[q]=new Vector2(Mathf.InverseLerp(b.min.x,b.max.x,vertices[q].x),Mathf.InverseLerp(b.min.y,b.max.y,vertices[q].y));mesh.uv=uv;}return g.transform;
    }
    void BuildCurls()
    {
        // Unequal, short ribbons grow from the red shoulder of the existing continuous fissure.
        // Their geometry already tapers and turns in depth; no rectangular heat-sheet silhouette.
        float[] starts={.13f,.24f,.38f,.47f,.61f,.70f,.82f};
        for(int k=0;k<starts.Length;k++)
        {
            float side=k%2==0?-1:1,extent=.09f+Noise(k+620)*.10f;
            const int rows=28,cols=8;
            var v=new Vector3[(rows+1)*(cols+1)];var uv=new Vector2[v.Length];var domain=new Vector2[v.Length];var ix=new List<int>();
            for(int j=0;j<=rows;j++)for(int i=0;i<=cols;i++)
            {
                int n=j*(cols+1)+i;float a=j/(float)rows,b=i/(float)cols;
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(a*Mathf.PI)),.7f);
                float u=starts[k]+(a-.5f)*extent;
                float center=side*(.105f+.020f*Mathf.Sin(u*21+k));
                float breadth=(.038f+.013f*Mathf.Sin(a*8+k))*taper;
                float across=center+(b-.5f)*breadth*2;
                float turn=Mathf.Sin(a*2.5f+b*1.7f+k*.31f);
                v[n]=new Vector3(across*10*WidthFactor,.065f+taper*(.16f+.12f*turn)*Mathf.Sin(b*Mathf.PI),u*(length+4f));
                uv[n]=new Vector2(u,across+.5f);domain[n]=new Vector2(a,b);
                if(i<cols&&j<rows)ix.AddRange(new[]{n,n+cols+1,n+1,n+1,n+cols+1,n+cols+2});
            }
            var mat=new Material(Shader.Find("Mistport/GoldenRiftArt"));
            mat.SetTexture("_MainTex",SurfaceArt);mat.SetFloat("_Layer",1);mat.SetFloat("_Seed",k*1.73f);mat.SetFloat("_TargetU",length/(length+4f));
            materials.Add(mat);curlMaterials.Add(mat);
            var tr=MeshObject("Low curling ember fold "+k,v,ix.ToArray(),mat);
            var mesh=tr.GetComponent<MeshFilter>().sharedMesh;mesh.uv=uv;mesh.uv2=domain;
            var bounds=mesh.bounds;bounds.Expand(new Vector3(2*WidthFactor,2.6f,1.4f));mesh.bounds=bounds;
            pieces.Add(new Piece{tr=tr,pos=Vector3.zero,scale=Vector3.one,rot=Quaternion.identity,start=.18f+(starts[k]-extent*.5f)*.65f,life=2.2f});
        }
    }
    static float Noise(int seed){float n=Mathf.Sin(seed*127.13f+9.73f)*43758.5453f;return n-Mathf.Floor(n);}
    public void Sample(float t)
    {
        if(floodMaterial)floodMaterial.SetFloat("_FxTime",t);if(floodTransform)floodTransform.gameObject.SetActive(false);
        if(artMaterial)artMaterial.SetFloat("_FxTime",t);if(artTransform)artTransform.gameObject.SetActive(t>0&&t<2.2f);
        foreach(var material in curlMaterials)material.SetFloat("_FxTime",t);
        foreach(var p in pieces)
        {
            float age=t-p.start;bool visible=age>=0 && t<2.5f && age<p.life;p.tr.gameObject.SetActive(visible);if(!visible)continue;
            if(p.flying)
            {
                float flight=.13f*(1-Mathf.Exp(-age*12))+age*.48f;
                p.tr.localPosition=p.pos+p.velocity*flight+Vector3.down*(3.2f*age*age);p.tr.localRotation=p.rot*Quaternion.Euler(age*p.spin,age*p.spin*.42f,age*p.spin*.71f);
                p.tr.localScale=p.scale*Mathf.Clamp01((p.life-age)/.18f);
            }
            else
            {
                float emerge=Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.085f));float blast= Mathf.Exp(-Mathf.Pow((t-.94f)/.095f,2));float fade=1-Mathf.SmoothStep(0,1,Mathf.Clamp01((t-(1.55f+(p.start-.18f)*.85f))/.40f)); if(p.life<1)fade=1-Mathf.SmoothStep(0,1,Mathf.Clamp01((age-.22f)/.28f));
                p.tr.localScale=new Vector3((emerge+blast*.30f)*fade,emerge+blast*.8f,1);
            }
        }
    }
    static void Release(Object value){if(value){if(Application.isPlaying)Destroy(value);else DestroyImmediate(value);}}
    void Clear(){foreach(var tr in owned)if(tr){tr.gameObject.SetActive(false);Release(tr.gameObject);}owned.Clear();pieces.Clear();foreach(var m in meshes)Release(m);meshes.Clear();foreach(var m in materials)Release(m);materials.Clear();curlMaterials.Clear();artMaterial=null;artTransform=null;floodMaterial=null;floodTransform=null;}
    void OnDisable(){foreach(var tr in owned)if(tr)tr.gameObject.SetActive(false);}
    void OnDestroy(){Clear();}
}
