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
    // Redrawn 2026-10-03 (user on the phone: 这团打过来的雾太规则了，重新设计). The travelling
    // cloud was a box-bounded gas volume sliding along as one smooth band, ringed by round
    // pods and wrapped in curling gold ribbons. Now it is many smoke puffs of uneven size and
    // aspect heaped low and front-heavy along the course: a dark core, lit emerald flanks, a
    // few sickly yellow-green hot spots, a leading edge whose puffs churn on their own, a
    // thinning trail and stray spores. On contact it bursts over the target in uneven billows
    // that rise, spread and thin. The battlefield mist that lingers afterwards is drawn
    // elsewhere and is unchanged.
    void Draw(Vector3 source,Vector3 target,int phase,float progress)
    {
        if(shadow==null)return;
        if(phase==1&&(target-source).sqrMagnitude>.001f)flightAxis=(target-source).normalized;
        if(phase==2&&flightAxis.sqrMagnitude>.001f)source=target-flightAxis;
        float p=phase==2?EnemyImpactEnvelope20260921.Sample(progress):Mathf.Clamp01(progress),fade=phase==2?Mathf.Pow(1-p,.85f):1;
        var cam=Camera.main;cameraRight=cam?cam.transform.right:Vector3.right;cameraUp=cam?cam.transform.up:Vector3.up;cameraForward=cam?cam.transform.forward:Vector3.forward;
        var axis=target-source;axis.y=0;axis=axis.sqrMagnitude>.001f?axis.normalized:Vector3.forward;
        var lateral=Vector3.Cross(Vector3.up,axis).normalized;
        Vector3 head=phase==0?source:phase==1?Vector3.Lerp(source,target,p):target;
        if(!sceneLighting)sceneLighting=GetComponent<SpellSceneLighting>()??gameObject.AddComponent<SpellSceneLighting>();
        sceneLighting.Draw(head,new Color(.035f,1f,.34f),phase==2?(variant==0?1.2f:2.1f)*fade:.30f,3f);
        shadow.Clear();mist.Clear();fire.Clear();
        float now=PresentationTime;
        bool dense=variant==0;
        // 169.68 still read as one round dark lump: the puffs were similar in size, crowded
        // round the head and all carried the dark layer. Now sizes run from a few large
        // billows to many small ones, the cloud is spread wide and ragged with gaps, only
        // its core is dark, the rest is lit emerald thinning to pale edges, and the trailing
        // puffs rise and thin, so its outline is never a regular shape.
        // The compressed eruption is tighter and as dense; at .22 it all but vanished (169.69).
        int count=dense?38:28;
        float span=dense?2.4f:1.3f,wide=dense?1.35f:.75f;
        for(int i=0;i<count;i++){
            float n0=Noise(i+7),n1=Noise(i+81),n2=Noise(i+147),n3=Noise(i+238),n4=Noise(i+311),n5=Noise(i+401);
            float back=Mathf.Pow(n0,1.4f),core=Mathf.Clamp01(1-back*1.6f-Mathf.Abs(n1-.5f)*1.2f);
            float big=n4*n4;
            Vector3 center;float size,opacity;
            if(phase==0){
                center=source+lateral*(n1-.5f)*wide*(1-.4f*p)+Vector3.up*((n2-.4f)*.7f)+axis*(n3-.5f)*.4f;
                size=(.18f+big*.7f)*(.45f+.75f*p);opacity=p*(.12f+.2f*core);
            }else if(phase==1){
                float lag=back*span*(.5f+.5f*p),churn=now*(.6f+n1*1.1f)+n2*6.28f;
                var jitter=(lateral*Mathf.Sin(churn)+Vector3.up*Mathf.Cos(churn*1.3f))*.1f*(1+back);
                center=head-axis*lag+lateral*(n1-.5f)*2f*wide*(.55f+.7f*back)
                    +Vector3.up*((n2-.3f)*(dense?1f:.7f)+back*(.4f+n5*.8f)*p)+jitter;
                size=(dense?.22f:.16f)+big*(dense?1.15f:.7f)+p*.15f*n5;
                // The compressed eruption is a tight, brighter knot (it lost its gas volume and pods,
                // and at the rolling fog's strength it barely showed, 169.70).
                opacity=(dense?.34f:.52f)*(.3f+.7f*(1-back))*(.55f+.45f*n5)*Mathf.Clamp01(p*5f);
            }else{
                float reach=(dense?.4f:.2f)+Mathf.Sqrt(p)*(dense?2.6f:1.7f)*(.4f+n0*.9f);
                var dir=(lateral*(n1-.5f)*2.4f+Vector3.up*(n2*1.1f)+axis*(n3-.5f)*.9f).normalized;
                center=target+dir*reach+Vector3.up*p*(.3f+n5*.6f);
                size=(dense?.3f:.18f)+big*(dense?1.3f:.6f)+p*(.4f+n0*.7f);
                opacity=(dense?.36f:.3f)*fade*(.4f+.6f*n3);
            }
            float rotation=n3*6.28f+now*(n1<.5f?-.3f:.3f)*(.4f+n4);
            float aspect=.7f+n2*.6f;
            // Dark only in the core; the rest is lit gas.
            if(core>.35f)
                Puff(shadow,center+cameraForward*.10f,size*aspect,size*(2-aspect),rotation,new Color(.006f,.03f,.02f,opacity*core),i%4);
            float lit=.3f+n5*.4f+(1-core)*.15f;
            Puff(mist,center-cameraForward*.035f+cameraUp*.06f*size,size*.85f*(2-aspect),size*.8f*aspect,rotation+.6f,
                new Color(.05f+lit*.12f,lit,.12f+n1*.08f,opacity*(.6f+.4f*(1-core))),(i+1)%4);
            if(i%(dense?4:2)==0&&phase>0)
                Puff(fire,center-cameraForward*.06f+cameraUp*.1f*size,size*.4f,size*.36f,rotation+1.1f,new Color(.62f,.98f,.3f,opacity*(phase==2?.85f:dense?.6f:.9f)),(i+2)%4);
        }
        // Stray spores: small dark specks of uneven shape drifting through and out of the cloud.
        int spores=dense?14:9;
        for(int i=0;i<spores;i++){
            float n0=Noise(i+501),n1=Noise(i+523),n2=Noise(i+547),n3=Noise(i+571);
            Vector3 c=phase==2?target+(lateral*(n0-.5f)*2.6f+Vector3.up*(n1*1.4f)+axis*(n2-.5f))*(.3f+Mathf.Sqrt(p)*1.6f)
                :head-axis*Mathf.Pow(n0,1.5f)*span+lateral*(n1-.5f)*1.6f+Vector3.up*(n2-.2f)*.9f;
            float size=.06f+n3*.1f;
            Puff(shadow,c-cameraForward*.08f,size,size*(.7f+n2*.6f),n1*6.28f+now*2f,new Color(.01f,.06f,.03f,(phase==0?p:1)*.55f*fade),i%4);
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
        flightAxis=Vector3.zero;
    }
    public void StopRoot() {playId++;ClearClouds();}
    int Begin() {StopRoot();return playId;}
    static Vector3 Read(Func<Vector3> getter,Vector3 fallback)=>getter!=null?getter():fallback;
    void OnDisable() {StopRoot();}
    void OnDestroy() {StopRoot();}
}
