using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// Sculpted poison and smoke presentation only. Original charge/travel/contact timing is unchanged.
public sealed class EmeraldRevenantSpell : MonoBehaviour
{
    const float ChargeDuration=.24f, TravelDuration=.78f, ImpactDuration=.20f;
    int playId, variant;
    GameObject effectRoot;
    CloudLayer shadow, mist, fire;
    SpellSceneLighting sceneLighting;
    EmeraldPoisonSeeds poisonSeeds;
    EmeraldToxicVolume toxicVolume;
    MainlineSpellMeshRound2 goldenCurls;
    Vector3 cameraRight, cameraUp, cameraForward, flightAxis;
    // Fixed-step render capture must use the same clock as actor animation.
    // Normal runtime still uses unscaled time exactly as before.
    static float PresentationStep {
        get {
#if UNITY_EDITOR || UNITY_STANDALONE
            if(Time.captureFramerate>0)return Time.deltaTime;
#endif
            return Time.unscaledDeltaTime;
        }
    }
    static float PresentationTime {
        get {
#if UNITY_EDITOR || UNITY_STANDALONE
            if(Time.captureFramerate>0)return Time.time;
#endif
            return Time.unscaledTime;
        }
    }
    public int Variant => variant;
    public void SetVariant(int value) { variant=Mathf.Abs(value%2); }

    // Three bounded batches; no individual particle GameObjects, lights, lines or geometric seals.
    sealed class CloudLayer
    {
        readonly Mesh mesh;
        readonly Material material;
        readonly List<Vector3> vertices=new List<Vector3>(512);
        readonly List<Color> colors=new List<Color>(512);
        readonly List<Vector2> uv=new List<Vector2>(512);
        readonly List<int> indices=new List<int>(768);
        public CloudLayer(Transform parent,Shader shader,Texture2D texture,string name,int queue,bool additive)
        {
            var go=new GameObject(name);go.transform.SetParent(parent,false);
            mesh=new Mesh { name=name+" mesh" };mesh.MarkDynamic();
            material=new Material(shader) { name=name+" material", mainTexture=texture, renderQueue=queue };
            material.SetFloat("_Shape",additive?3:0);
            material.SetFloat("_DstBlend",(float)BlendMode.OneMinusSrcAlpha);
            go.AddComponent<MeshFilter>().sharedMesh=mesh;
            var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
            r.lightProbeUsage=LightProbeUsage.Off;r.reflectionProbeUsage=ReflectionProbeUsage.Off;
        }
        public void Clear() {vertices.Clear();colors.Clear();uv.Clear();indices.Clear();}
        public void Add(Vector3 c,Vector3 x,Vector3 y,Color color,int tile)
        {
            int n=vertices.Count;
            vertices.Add(c-x-y);vertices.Add(c+x-y);vertices.Add(c+x+y);vertices.Add(c-x+y);
            for(int i=0;i<4;i++)colors.Add(color);
            float a=tile<0?0:(tile%2)*.5f,b=tile<0?0:(tile/2)*.5f,k=tile<0?1:.5f;
            uv.Add(new Vector2(a,b));uv.Add(new Vector2(a+k,b));uv.Add(new Vector2(a+k,b+k));uv.Add(new Vector2(a,b+k));
            indices.Add(n);indices.Add(n+1);indices.Add(n+2);indices.Add(n);indices.Add(n+2);indices.Add(n+3);
        }
        public void Upload() {mesh.Clear();mesh.SetVertices(vertices);mesh.SetColors(colors);mesh.SetUVs(0,uv);mesh.SetTriangles(indices,0);mesh.RecalculateBounds();}
        public void Dispose() {UnityEngine.Object.Destroy(mesh);UnityEngine.Object.Destroy(material);}
    }
    void CreateClouds()
    {
        ClearClouds();
        var shader=Resources.Load<Shader>("EnemySignature/SignatureSprite");
        var smokeTexture=Resources.Load<Texture2D>("Effects/HellHound/Texture/Smoke");
        var flameTexture=smokeTexture;
        if(shader==null||smokeTexture==null||flameTexture==null) {
            Debug.LogError("Emerald organic smoke/fire resources are missing.");return;
        }
        effectRoot=new GameObject(variant==0?"Rolling soul fog":"Compressed emerald eruption");
        goldenCurls=effectRoot.AddComponent<MainlineSpellMeshRound2>();
        shadow=new CloudLayer(effectRoot.transform,shader,smokeTexture,"Deep shadow smoke",3012,false);
        mist=new CloudLayer(effectRoot.transform,shader,smokeTexture,"Lit emerald smoke",3013,false);
        fire=new CloudLayer(effectRoot.transform,shader,flameTexture,"Brief poison pressure puffs",3015,false);
    }
    static float Noise(int seed) => Mathf.Repeat(Mathf.Sin(seed*127.1f+31.7f)*43758.5453f,1f);
    void Puff(CloudLayer layer,Vector3 position,float width,float height,float rotation,Color color,int tile=-1)
    {
        var x=(cameraRight*Mathf.Cos(rotation)+cameraUp*Mathf.Sin(rotation))*width*.5f;
        var y=(-cameraRight*Mathf.Sin(rotation)+cameraUp*Mathf.Cos(rotation))*height*.5f;
        layer.Add(position,x,y,color,tile);
    }
    void Draw(Vector3 source,Vector3 target,int phase,float progress)
    {
        if(shadow==null)return;
        if(phase==1&&(target-source).sqrMagnitude>.001f)flightAxis=(target-source).normalized;
        if(phase==2&&flightAxis.sqrMagnitude>.001f)source=target-flightAxis;
        float p=phase==2?EnemyImpactEnvelope20260921.Sample(progress):Mathf.Clamp01(progress),fade=phase==2?Mathf.Pow(1-p,.85f):1;
        if(!poisonSeeds)poisonSeeds=effectRoot.AddComponent<EmeraldPoisonSeeds>();
        poisonSeeds.Draw(variant,phase,p,source,target);
        if(!toxicVolume) toxicVolume=effectRoot.AddComponent<EmeraldToxicVolume>();
        Vector3 gasHead=phase==0?source:phase==1?Vector3.Lerp(source,target,p):target;
        float scale=phase==0?.4f+p*.8f:phase==1?(variant==0?1.5f+p*1.3f:1.8f-p*.8f):2.1f+Mathf.Sqrt(p)*5.3f;
        toxicVolume.Configure(gasHead, new Vector3(scale*1.55f,scale*.90f,scale*1.15f), phase+p,
            phase==2?fade*1.6f:phase==0?p*.75f:1.25f, variant==1&&phase==2?(1-p)*2f:0);

        var cam=Camera.main;cameraRight=cam?cam.transform.right:Vector3.right;cameraUp=cam?cam.transform.up:Vector3.up;cameraForward=cam?cam.transform.forward:Vector3.forward;
        var axis=(target-source).normalized;if(axis.sqrMagnitude<.001f)axis=Vector3.forward;
        // Preserve the approved green volume and full-body charge. Gold-green
        // folds now articulate its skin and contact rupture instead of merely
        // raising emission throughout a uniform green cloud.
        if(goldenCurls){
            goldenCurls.Begin(phase+p,phase==2?Mathf.Exp(-p*9):0,phase==0?0:2);
            int curls=variant==0?5:7;
            for(int i=0;i<curls;i++){
                float h=Noise(i+43),k=Noise(i+17);Vector3 d=(cameraRight*(h-.48f)+cameraUp*(k-.35f)).normalized;
                Vector3 side=Vector3.Cross(axis,d).normalized;
                Vector3 start=phase==2?target+d*.15f:gasHead-axis*(phase==0?.65f+h*.8f:1.14f+h*.96f)+d*.2f;
                Vector3 end=phase==2?target+d*(.6f+Mathf.Sqrt(p)*(2.0f+h*1.6f)):gasHead+d*(phase==0?.12f:.32f);
                Color tint=i%3==0?new Color(.95f,.84f,.27f,fade*.86f):new Color(.30f,.78f,.20f,fade*.82f);
                float width=phase==0?.08f+h*.09f:phase==1?.33f+h*.22f:.43f+h*.31f;
                Vector3 bend=side*(phase==0?.28f+h*.36f:.46f+h*.56f);
                goldenCurls.RibbonContinuous(start,start+bend,end+bend*.65f,end,side,width,tint,i);
                if(phase>0&&i%2==0)
                    goldenCurls.RibbonContinuous(start+axis*.055f,start+bend*.81f+axis*.055f,
                        end+bend*.42f+axis*.055f,end+axis*.055f,side,width*.24f,
                        new Color(.89f,1f,.54f,fade*.91f),i+11);
            }
            goldenCurls.End();
        }
        shadow.Clear();mist.Clear();fire.Clear();
        Vector3 head=phase==0?source:phase==1?Vector3.Lerp(source,target,p):target;
        if(!sceneLighting)sceneLighting=GetComponent<SpellSceneLighting>()??gameObject.AddComponent<SpellSceneLighting>();
        sceneLighting.Draw(head,new Color(.035f,1f,.34f),phase==2?(variant==0?1.2f:2.1f)*fade:.30f,3f);
        int count=variant==0?(phase==2?20:12):(phase==2?9:6);
        for(int i=0;i<count;i++){
            float age=Noise(i+7),nx=Noise(i+81)*2-1,ny=Noise(i+147)*2-1,nz=Noise(i+238)*2-1;
            Vector3 center;float size,opacity;
            if(phase==0){center=source+cameraRight*nx*.55f+cameraUp*(ny*.3f-.25f);size=.28f+age*.3f;opacity=p*.13f;}
            else if(phase==1){float along=Mathf.Clamp01(p-age*.25f);center=Vector3.Lerp(source,target,along)+cameraRight*nx*.35f+cameraUp*ny*.25f;
                size=variant==0?.38f+age*.45f:.20f+age*.22f;opacity=variant==0?.20f:.10f;}
            else{float radius=(variant==0?.45f:.10f)+Mathf.Sqrt(p)*(variant==0?2.2f:1.2f);
                center=target+cameraRight*nx*radius+cameraUp*(ny*radius*.55f+p*.4f)+axis*nz*.5f;
                size=(variant==0?.95f:.35f)+age*(variant==0?1.1f:.32f)+p*.30f;opacity=(variant==0?.32f:.17f)*fade;}
            float rotation=Noise(i+27)*6.28f+PresentationTime*.20f;
            Puff(shadow,center+cameraForward*.10f,size,size*1.1f,rotation,new Color(.009f,.035f,.025f,opacity),i%4);
            Puff(mist,center-cameraForward*.035f+cameraUp*.04f,size*.78f,size*.88f,rotation+.24f,new Color(.03f,.26f+age*.13f,.10f,opacity*.65f),i%4);
            if(phase==2&&p<.35f&&i<4){
                Vector3 splash=target+cameraRight*nx*(.2f+p*1.7f)+cameraUp*ny*.4f;
                Puff(fire,splash,.48f+p*.65f,.44f+p*.55f,rotation,new Color(.45f,.85f,.61f,(1-p/.35f)*.5f),i%4);
            }
        }
        shadow.Upload();mist.Upload();fire.Upload();
    }

    public IEnumerator PlayCharge(Func<Vector3> source,Func<Vector3> target)
    {
        int id=Begin();CreateClouds();float elapsed=0;
        while(elapsed<ChargeDuration&&id==playId) {
            Draw(Read(source,Vector3.zero),Read(target,Vector3.forward*3),0,elapsed/ChargeDuration);
            elapsed+=PresentationStep;yield return null;
        }
    }
    public IEnumerator Fly(Func<Vector3> source,Func<Vector3> target)
    {
        int id=playId;if(shadow==null)CreateClouds();
        var launch=Read(source,Vector3.zero);var destination=Read(target,launch+Vector3.forward*3);float elapsed=0;
        while(elapsed<TravelDuration&&id==playId) {
            elapsed+=PresentationStep;
            Draw(launch,destination,1,Mathf.SmoothStep(0,1,Mathf.Clamp01(elapsed/TravelDuration)));yield return null;
        }
    }
    public IEnumerator PlayImpact(Func<Vector3> target,Action contact=null)
    {
        int id=playId;var destination=Read(target,Vector3.zero);if(shadow==null)CreateClouds();
        Draw(destination-Vector3.forward,destination,2,0);contact?.Invoke();
        if(id!=playId)yield break;
        float elapsed=0;
        while(elapsed<ImpactDuration&&id==playId) {
            elapsed+=PresentationStep;Draw(destination-Vector3.forward,destination,2,elapsed/ImpactDuration);yield return null;
        }
        if(id==playId)ClearClouds();
    }
    void ClearClouds() {
        if(effectRoot!=null) {effectRoot.SetActive(false);Destroy(effectRoot);}
        if(sceneLighting)sceneLighting.Clear();
        effectRoot=null;shadow?.Dispose();mist?.Dispose();fire?.Dispose();shadow=null;mist=null;fire=null;
        poisonSeeds=null;toxicVolume=null;goldenCurls=null;flightAxis=Vector3.zero;
    }
    public void StopRoot() {playId++;ClearClouds();}
    int Begin() {StopRoot();return playId;}
    static Vector3 Read(Func<Vector3> getter,Vector3 fallback)=>getter!=null?getter():fallback;
    void OnDisable() {StopRoot();}
    void OnDestroy() {StopRoot();}
}
