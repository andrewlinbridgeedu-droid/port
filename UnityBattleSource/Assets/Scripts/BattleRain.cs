using UnityEngine;

/// World-space rainfall with ground contact; never draws over the native HUD.
public sealed class BattleRain : MonoBehaviour
{
    const int Count=3200;
    public bool WeatherVisible { get; private set; } = true;
    public void SetWeatherVisible(bool visible) {
        WeatherVisible=visible;
        foreach(var system in new[]{rain,splashes,ripples}) if(system) {
            if(!visible) system.Clear();
            system.gameObject.SetActive(visible);
        }
    }
    readonly System.Random random=new System.Random(7241);
    ParticleSystem rain,splashes,ripples;
    ParticleSystem.Particle[] drops;
    Material rainMaterial,splashMaterial,rippleMaterial;
    Texture2D streakTexture,dropletTexture,rippleTexture;
    float Range(float a,float b)=>a+(b-a)*(float)random.NextDouble();
    void Start()
    {
        var shader=Resources.Load<Shader>("Shaders/BattleRain");
        if(!shader){Debug.LogError("Battle rain shader missing");enabled=false;return;}
        streakTexture=Texture(0);dropletTexture=Texture(1);rippleTexture=Texture(2);
        rainMaterial=new Material(shader){mainTexture=streakTexture};
        splashMaterial=new Material(shader){mainTexture=dropletTexture};
        rippleMaterial=new Material(shader){mainTexture=rippleTexture};
        rain=System("Rain volume",rainMaterial,Count,ParticleSystemRenderMode.Stretch);
        var rr=rain.GetComponent<ParticleSystemRenderer>();rr.velocityScale=.021f;rr.lengthScale=1.5f;rr.cameraVelocityScale=0;
        rain.Pause();drops=new ParticleSystem.Particle[Count];
        for(int i=0;i<Count;i++)Reset(i,true);
        rain.SetParticles(drops,Count);
        splashes=System("Rain ground droplets",splashMaterial,500,ParticleSystemRenderMode.Billboard);
        var sm=splashes.main;sm.startLifetime=new ParticleSystem.MinMaxCurve(.12f,.26f);sm.gravityModifier=1.2f;
        ripples=System("Rain ground ripples",rippleMaterial,160,ParticleSystemRenderMode.HorizontalBillboard);
        var rm=ripples.main;rm.startLifetime=.36f;
        var size=ripples.sizeOverLifetime;size.enabled=true;size.size=new ParticleSystem.MinMaxCurve(1,AnimationCurve.Linear(0,.2f,1,1.5f));
        Fade(splashes);Fade(ripples);
        SetWeatherVisible(WeatherVisible);
    }
    void Reset(int i,bool prewarm)
    {
        drops[i].position=new Vector3(Range(-17,17),prewarm?Range(.03f,19):Range(18,20),Range(-13,25));
        drops[i].velocity=new Vector3(-.8f,Range(-23,-16),.12f);
        drops[i].startSize=Range(.018f,.036f);
        drops[i].startColor=new Color(.56f,.64f,.73f,Range(.35f,.62f));
        drops[i].startLifetime=1000;drops[i].remainingLifetime=1000;
        drops[i].randomSeed=(uint)(i+1);
    }
    void Update()
    {
        if(drops==null || !WeatherVisible)return;
        float dt=Mathf.Min(Time.deltaTime,.05f);
        float wind=-.8f+Mathf.Sin(Time.time*.37f)*.30f;
        for(int i=0;i<Count;i++)
        {
            var velocity=drops[i].velocity;velocity.x=wind;drops[i].velocity=velocity;
            drops[i].position+=velocity*dt;
            if(drops[i].position.y>.025f)continue;
            var hit=drops[i].position;hit.y=.035f;
            if(random.NextDouble()<.16)
            {
                var ep=new ParticleSystem.EmitParams{position=hit,startSize=Range(.055f,.11f),startColor=new Color(.67f,.76f,.82f,.27f),velocity=Vector3.zero};
                ripples.Emit(ep,1);
                for(int j=0;j<3;j++)
                {
                    ep.startSize=Range(.012f,.023f);ep.startColor=new Color(.74f,.83f,.88f,.48f);
                    ep.velocity=new Vector3(Range(-.32f,.32f),Range(.3f,.75f),Range(-.32f,.32f));splashes.Emit(ep,1);
                }
            }
            Reset(i,false);
        }
        rain.SetParticles(drops,Count);
    }
    ParticleSystem System(string name,Material material,int cap,ParticleSystemRenderMode mode)
    {
        var go=new GameObject(name);go.transform.SetParent(transform,false);var ps=go.AddComponent<ParticleSystem>();ps.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
        var main=ps.main;main.maxParticles=cap;main.simulationSpace=ParticleSystemSimulationSpace.World;main.startSpeed=0;main.loop=true;main.playOnAwake=false;main.cullingMode=ParticleSystemCullingMode.AlwaysSimulate;
        var emission=ps.emission;emission.enabled=false;var shape=ps.shape;shape.enabled=false;
        var r=ps.GetComponent<ParticleSystemRenderer>();r.sharedMaterial=material;r.renderMode=mode;r.sortMode=ParticleSystemSortMode.Distance;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
        ps.Play();return ps;
    }
    static void Fade(ParticleSystem ps)
    {
        var c=ps.colorOverLifetime;c.enabled=true;var g=new Gradient();g.SetKeys(new[]{new GradientColorKey(Color.white,0),new GradientColorKey(Color.white,1)},new[]{new GradientAlphaKey(.7f,0),new GradientAlphaKey(0,1)});c.color=g;
    }
    static Texture2D Texture(int kind)
    {
        int n=32;var t=new Texture2D(n,n,TextureFormat.RGBA32,false);t.wrapMode=TextureWrapMode.Clamp;
        for(int y=0;y<n;y++)for(int x=0;x<n;x++)
        {
            float u=(x+.5f)/n*2-1,v=(y+.5f)/n*2-1,r=Mathf.Sqrt(u*u+v*v);
            float a=kind==0?Mathf.Exp(-u*u*8)*Mathf.Pow(Mathf.Max(0,1-v*v),1.5f):kind==1?Mathf.Exp(-r*r*8):Mathf.Exp(-Mathf.Pow((r-.70f)*18,2));
            t.SetPixel(x,y,new Color(1,1,1,a));
        }
        t.Apply();return t;
    }
    void OnDestroy()
    {
        if(rain)Destroy(rain.gameObject);if(splashes)Destroy(splashes.gameObject);if(ripples)Destroy(ripples.gameObject);
        Destroy(rainMaterial);Destroy(splashMaterial);Destroy(rippleMaterial);Destroy(streakTexture);Destroy(dropletTexture);Destroy(rippleTexture);
    }
}
