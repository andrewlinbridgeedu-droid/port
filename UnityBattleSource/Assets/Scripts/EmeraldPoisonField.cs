using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Native combat owns poison ticks. This field only displays the authoritative
// increasing intensity messages, persists until cleared, and is destroyed on reset/exit.
public sealed class EmeraldPoisonField : MonoBehaviour
{
    GameObject root;
    Mesh mesh;
    EmeraldToxicVolume volume;
    Material material;
    Func<Vector3> anchor;
    int intensityLevel;
    float density;
    public int IntensityLevel => intensityLevel;
    public bool IsActive => root != null;
    float age, pulse;
    readonly List<Vector3> vertices = new List<Vector3>(256);
    readonly List<Vector2> uvs = new List<Vector2>(256);
    readonly List<Color> colors = new List<Color>(256);
    readonly List<int> indices = new List<int>(384);
    public void SetRemaining(int value, Func<Vector3> position) => SetIntensity(value, position);
    public void SetIntensity(int value, Func<Vector3> position)
    {
        if(value<=0) { Clear(); return; }
        if(!root)
        {
            var shader=Resources.Load<Shader>("EnemySignature/EmeraldPoisonFog");
            if(!shader) { Debug.LogError("EmeraldPoisonField: shader missing"); return; }
            root=new GameObject("Emerald persistent poison field");
            mesh=new Mesh { name="Emerald persistent poison cloud mesh" }; mesh.MarkDynamic();
            material=new Material(shader) { name="Emerald organic rolling wisps" };
            root.AddComponent<MeshFilter>().sharedMesh=mesh;
            var renderer=root.AddComponent<MeshRenderer>(); renderer.sharedMaterial=material;
            renderer.shadowCastingMode=ShadowCastingMode.Off; renderer.receiveShadows=false;
            volume=root.AddComponent<EmeraldToxicVolume>();
            age=0;
        }
        if(intensityLevel!=value) pulse=1f;
        intensityLevel=value; anchor=position;
    }
    void Update()
    {
        if(!root || anchor==null) return;
        age+=Time.deltaTime; pulse=Mathf.Max(0,pulse-Time.deltaTime*2.4f);
        // Smooth changes follow native tick levels. Never expire a field locally.
        float targetDensity=1f-Mathf.Exp(-Mathf.Max(0,intensityLevel-1)*.16f);
        density=Mathf.MoveTowards(density,targetDensity,Time.deltaTime*.28f);
        Vector3 target=anchor();
        // Anchor is 0.85 m above the player floor. The poison rolls around ankles,
        // progressively rising to the knees, while the silhouette stays readable.
        // The box only lends depth.  Visible contour comes from individual
        // rising poison banks below, never from a level green screen stripe.
        volume.Configure(target-Vector3.up*.57f, new Vector3(8.6f,Mathf.Lerp(.86f,1.34f,density),6.6f),age,
            Mathf.SmoothStep(0,1,age/1.2f)*(Mathf.Lerp(.13f,.38f,density)+pulse*.025f),0);
        material.SetFloat("_FlowAge",age);
        var camera=Camera.main;
        Vector3 right=camera?camera.transform.right:Vector3.right;
        Vector3 up=camera?camera.transform.up:Vector3.up;
        Vector3 forward=camera?camera.transform.forward:Vector3.forward;
        float appear=Mathf.SmoothStep(0,1,age/.65f);
        vertices.Clear();uvs.Clear();colors.Clear();indices.Clear();
        // Broken banks rather than a ceiling/screen tint. Each wisp has its own
        // lifetime envelope, curl, depth and scale; no fixed atlas rectangles.
        for(int i=0;i<42;i++)
        {
            float n=N(i), cycle=Mathf.Repeat(age*(.070f+N(i+29)*.046f)+n,1);
            float life=Mathf.Pow(Mathf.Sin(cycle*Mathf.PI),.8f);
            float lane=(N(i+71)-.5f)*8.5f+Mathf.Sin(age*.31f+i*1.7f)*.63f;
            float depth=N(i+8)*6.2f-2.7f;
            float height=-.78f+N(i+5)*.28f+cycle*Mathf.Lerp(.37f,.86f,density);
            Vector3 c=target+right*lane+Vector3.up*height+forward*depth;
            c+=right*Mathf.Sin(cycle*5.2f+i)*.34f;
            float size=(1.35f+N(i+14)*1.36f)*Mathf.Lerp(.67f,1.24f,cycle);
            float rotation=Mathf.Sin(age*.19f+i*1.83f)*.38f;
            Vector3 x=(right*Mathf.Cos(rotation)+up*Mathf.Sin(rotation))*size*.80f;
            Vector3 y=(-right*Mathf.Sin(rotation)+up*Mathf.Cos(rotation))*size*(.27f+N(i+37)*.20f);
            int k=vertices.Count; vertices.Add(c-x-y);vertices.Add(c+x-y);vertices.Add(c+x+y);vertices.Add(c-x+y);
            float alpha=appear*life*Mathf.Lerp(.15f,.29f,density);
            Color dark=new Color(.025f,.19f,.085f,alpha*.9f);
            Color bright=Color.Lerp(new Color(.13f,.47f,.18f,alpha),new Color(.52f,.72f,.14f,alpha),N(i+17));
            colors.Add(dark);colors.Add(Color.Lerp(dark,bright,.44f));colors.Add(bright);colors.Add(Color.Lerp(dark,bright,.75f));
            uvs.Add(Vector2.zero);uvs.Add(Vector2.right);uvs.Add(Vector2.one);uvs.Add(Vector2.up);
            indices.Add(k);indices.Add(k+1);indices.Add(k+2);indices.Add(k);indices.Add(k+2);indices.Add(k+3);
        }
        mesh.Clear();mesh.SetVertices(vertices);mesh.SetUVs(0,uvs);mesh.SetColors(colors);mesh.SetTriangles(indices,0);mesh.RecalculateBounds();
    }
    static float N(int i) => Mathf.Repeat(Mathf.Sin(i*127.1f+31.7f)*43758.5453f,1f);
    public void Clear()
    {
        if(root) {root.SetActive(false);Destroy(root);} root=null;
        if(mesh)Destroy(mesh);if(material)Destroy(material);mesh=null;material=null;
        intensityLevel=0;density=0;anchor=null;age=0;pulse=0;volume=null;
    }
    void OnDisable(){Clear();}
    void OnDestroy(){Clear();}
}
