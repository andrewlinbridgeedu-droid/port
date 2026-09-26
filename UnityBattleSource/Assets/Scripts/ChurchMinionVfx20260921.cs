using System;
using System.Collections.Generic;
using UnityEngine;

// Five independently shaped attacks. All meshes/materials are owned by the
// action; this visual clock never pauses combat or dispatches damage.
public sealed class ChurchMinionVfx20260921 : MonoBehaviour
{
    sealed class Sheet { public Mesh mesh; public Material mat; public MeshRenderer renderer; public Vector3[] vertices; }
    readonly List<Sheet> sheets = new List<Sheet>();
    readonly List<LineRenderer> sparks = new List<LineRenderer>();
    Material sparkMaterial;
    EnemyHandle actor; Func<Vector3> target; string species; bool second, held;
    float contact, elapsed; Color hue; Vector3 origin;
    const int Length = 48, Width = 10;
    public static bool Handles(string s) => s == "copperback" || s == "crimson-brute" || s == "veil-oracle" || s == "golden-throat" || s == "moonfang";
    public static ChurchMinionVfx20260921 Create(EnemyHandle a, string s, string intent, Func<Vector3> end, float time, Transform owner)
    {
        var root = new GameObject("Minion authored spell " + s + " " + intent); root.transform.SetParent(owner, false);
        var v = root.AddComponent<ChurchMinionVfx20260921>(); v.actor=a;v.species=s;v.target=end;v.contact=time;
        v.second=intent.EndsWith("second")||intent.EndsWith("charge2");v.held=intent.Contains("charge");
        v.hue=s=="copperback"?new Color(1,.51f,.16f):s=="crimson-brute"?new Color(1,.15f,.065f):s=="veil-oracle"?new Color(.88f,.12f,.42f):s=="golden-throat"?new Color(1,.82f,.19f):new Color(.45f,.7f,1);
        v.origin=a.EffectAnchor.position;
        for(int i=0;i<18;i++)v.AddSheet(i);
        v.sparkMaterial=new Material(Shader.Find("Sprites/Default"));
        v.sparkMaterial.mainTexture=Resources.Load<Texture2D>("Effects/Mistport/Official/Slashing/Line01");
        int splinters=s=="copperback"?35:s=="crimson-brute"?42:s=="golden-throat"?29:s=="veil-oracle"?33:26;
        for(int i=0;i<splinters;i++){
            var go=new GameObject("Contact splinter "+i);go.transform.SetParent(root.transform,false);
            var line=go.AddComponent<LineRenderer>();line.sharedMaterial=v.sparkMaterial;line.positionCount=3;line.useWorldSpace=true;
            line.numCapVertices=2;line.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;line.receiveShadows=false;line.enabled=false;
            v.sparks.Add(line);
        }
        return v;
    }
    void AddSheet(int index){
        var go=new GameObject("Sculpted spell surface "+index);go.transform.SetParent(transform,false);
        var mesh=new Mesh();mesh.name=species+" curved surface";mesh.MarkDynamic();
        var uv=new Vector2[(Length+1)*(Width+1)];var tri=new int[Length*Width*6];
        for(int x=0;x<=Length;x++)for(int y=0;y<=Width;y++){
            int n=x*(Width+1)+y;uv[n]=new Vector2(x/(float)Length,y/(float)Width);
            if(x<Length&&y<Width){int k=(x*Width+y)*6;tri[k]=n;tri[k+1]=n+Width+1;tri[k+2]=n+1;tri[k+3]=n+1;tri[k+4]=n+Width+1;tri[k+5]=n+Width+2;}
        }
        mesh.vertices=new Vector3[uv.Length];mesh.uv=uv;mesh.triangles=tri;
        go.AddComponent<MeshFilter>().sharedMesh=mesh;var r=go.AddComponent<MeshRenderer>();
        var mat=new Material(Resources.Load<Shader>(species=="veil-oracle"&&second?"SpellImpact20260925/CrimsonCurtain":"Shaders/MinionSurface20260921"));
        mat.mainTexture=Resources.Load<Texture2D>("ChurchSpellArt/"+((species=="copperback"||species=="crimson-brute")?"earth":species=="golden-throat"?"mend":species=="veil-oracle"?"sickle":"claw"));
        if(species=="golden-throat")mat.SetVector("_Crop",new Vector4(.38f,.55f,.27f,.25f));
        if(species=="crimson-brute"){
            mat.mainTexture=Resources.Load<Texture2D>("Effects/HellHound/Texture/Fire_Single");
            mat.SetVector("_Crop",new Vector4(.14f,.02f,.73f,.96f));mat.SetFloat("_Flame",1);
        }
        // The former claw-atlas crop nearly erased the moonfang's swept face.
        if(species=="moonfang")mat.SetFloat("_Claw",1);
        if(species=="veil-oracle")mat.SetVector("_Crop",new Vector4(.10f,.35f,.25f,.30f));
        if(species=="veil-oracle"&&second)mat.mainTexture=Resources.Load<Texture2D>("ChurchSpellArt/BountyEffekseer/Texture/CrimsonSilk");
        mat.SetFloat("_Seed",index*1.731f+(species=="golden-throat"?3.7f:species=="veil-oracle"?7.1f:1));
        // The lower surfaces carry the painted mass. Six independent inner
        // surfaces provide a readable hot seam without replacing that mass by
        // a shared white flash or adding a closed impact ring.
        mat.SetFloat("_Lucent",index>=6&&index<12?1.52f:
            species=="moonfang"?1.46f:species=="copperback"?1.43f:
            species=="golden-throat"?1.32f:1.13f);
        r.sharedMaterial=mat;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
        sheets.Add(new Sheet{mesh=mesh,mat=mat,renderer=r,vertices=new Vector3[uv.Length]});
    }
    void Surface(int i,Func<float,float,Vector3> shape,float alpha,float clock,Color? color=null){
        var s=sheets[i];s.renderer.enabled=alpha>.002f;if(!s.renderer.enabled)return;
        var vertices=s.vertices;
        for(int x=0;x<=Length;x++)for(int y=0;y<=Width;y++)vertices[x*(Width+1)+y]=shape(x/(float)Length,y/(float)Width);
        #if UNITY_EDITOR
        foreach(var point in vertices)if(float.IsNaN(point.sqrMagnitude)||float.IsInfinity(point.sqrMagnitude))throw new InvalidOperationException("Non-finite minion VFX vertex: "+species+" surface "+i);
        #endif
        s.mesh.vertices=vertices;s.mesh.RecalculateNormals();s.mesh.RecalculateBounds();
        var c=color??hue;c.a=alpha;s.mat.SetColor("_Color",c);s.mat.SetFloat("_Clock",clock);
        s.mat.SetFloat("_Flare",!held&&clock>=contact?Mathf.Clamp01(1-(clock-contact)/.18f):0);
    }
    void Update(){if(held){elapsed+=Time.deltaTime;Tick(elapsed);}}
    public void Tick(float raw){
        if(!actor||target==null)return;
        foreach(var s in sheets)s.renderer.enabled=false;foreach(var l in sparks)l.enabled=false;
        var start=held?actor.EffectAnchor.position:origin;var end=target();
        Vector3 forward=end-start;forward.y=0;if(forward.sqrMagnitude<.01f)forward=actor.transform.forward;forward.Normalize();
        Vector3 right=Vector3.Cross(Vector3.up,forward).normalized;
        if(held){Charge(start,forward,right,raw);return;}
        float age=TowerImpactTiming20260921.Sample(raw,contact,.10f),post=age-contact;
        float launch=second?.23f:.18f;
        if(age<launch){Charge(start,forward,right,raw);return;}
        float travel=Mathf.SmoothStep(0,1,Mathf.Clamp01((age-launch)/(contact-launch)));
        float amplitude=species=="moonfang"?3.1f:species=="golden-throat"?2.7f:3.45f;
        float grow=post<0?1:1+amplitude*Mathf.Sin(Mathf.Clamp01(post/.045f)*Mathf.PI*.5f)*Mathf.Exp(-Mathf.Max(0,post-.045f)*11);
        float fade=post<0?1:Mathf.Clamp01(1-post/.48f);var center=Vector3.Lerp(start,end,travel);
        if(species=="copperback")Copper(center,end,forward,right,travel,post,grow,fade,age);
        else if(species=="crimson-brute")Brute(center,end,forward,right,travel,post,grow,fade,age);
        else if(species=="golden-throat")Throat(center,forward,right,post,grow,fade,age);
        else if(species=="veil-oracle")Veil(center,forward,right,travel,post,grow,fade,age);
        else Mouse(center,forward,right,travel,post,grow,fade,age);
        Accent(center,end,forward,right,post,grow,fade,age);
        if(post>=0)Burst(end,right,forward,post,fade);
    }
    void Charge(Vector3 c,Vector3 f,Vector3 r,float t){
        // Energy hugs each physical organ instead of a common floor ring.
        string[] names=species=="golden-throat"?new[]{"Sac.L","Sac.R","Throat"}:species=="veil-oracle"?new[]{"Hand.L","Hand.R"}:species=="moonfang"?new[]{"Head","TailTip"}:species=="copperback"?new[]{"Chest","Pelvis"}:new[]{"Hand.L","Hand.R"};
        int i=0;foreach(string name in names){var bone=FindBone(name);if(!bone)continue;Vector3 p=bone.position;
            int index=i++;float seed=index*1.83f;
            Surface(index,(u,v)=>{
                float a=(u-.5f)*2.35f+seed*.17f,edge=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.7f);
                float w=edge*(.12f+.10f*v)*(1+.20f*Mathf.Sin(u*7+t*3+seed));
                return p+r*(Mathf.Sin(a)*w)+Vector3.up*(u*.36f+.05f*Mathf.Sin(v*3+u*8+t*4+seed))+f*(Mathf.Cos(a)*w);
            },.64f+.13f*Mathf.Sin(t*5+seed),t);
        }
    }
    Transform FindBone(string name){foreach(var t in actor.VisualRoot.GetComponentsInChildren<Transform>(true))if(t.name==name)return t;return null;}
    void Copper(Vector3 c,Vector3 end,Vector3 f,Vector3 r,float travel,float post,float grow,float fade,float age){
        c.y=.07f;int count=second?5:4;
        for(int i=0;i<count;i++){int k=i;float side=(i-(count-1)*.5f)+Mathf.Sin(i*3.1f)*.28f;
            Surface(i,(u,v)=> {
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.75f),rag=1+.19f*Mathf.Sin(u*8+k*1.7f)+.09f*Mathf.Sin(u*17+k);
                if(second){float a=(u-.5f)*(2.15f+.14f*k)+k*.15f;return c+r*(Mathf.Sin(a)*(.32f+v*taper*.26f)*grow+side*.10f)+f*(side*.24f+Mathf.Cos(a)*.23f+v*.12f)+Vector3.up*(.04f+taper*(.25f+v*(.25f+.12f*Mathf.Sin(k*2.1f)))*rag*grow);}
                return c+r*(side*.24f*grow+(v-.5f)*taper*.52f*rag*grow+Mathf.Sin(u*3+k)*.09f)+f*((u-.5f)*(1.05f+.11f*k)*grow+k*.11f)+Vector3.up*(.035f+taper*(.22f+.14f*Mathf.Sin(k*2.1f))*grow+(v-.5f)*.16f*taper*grow);
            },fade,age,Color.Lerp(hue,new Color(.37f,.15f,.045f),i%3*.15f));
        }
        // First strike splits the floor in staggered copper seams; the second
        // exposes glowing undersides as the unequal armor plates turn upward.
        for(int i=0;i<(second?4:3);i++){int k=i;float side=i-(second?1.45f:1.0f);
            Surface(6+i,(u,v)=>{
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.72f),edge=(v-.5f)*taper;
                if(second){float arc=(u-.5f)*(2.0f+.12f*k)+k*.26f;
                    return c+r*(Mathf.Sin(arc)*(.28f+.20f*v)*grow+side*.12f)+f*(side*.22f+Mathf.Cos(arc)*.18f+v*.11f)
                        +Vector3.up*(.075f+taper*(.32f+v*.20f)*grow+.07f*Mathf.Sin(u*8+k));}
                return c+r*(side*.32f*grow+edge*.29f*grow+.045f*Mathf.Sin(u*11+k*2.1f))
                    +f*((u-.5f)*(1.38f+.16f*k)*grow+k*.13f)+Vector3.up*(.085f+taper*(.13f+.045f*k)*grow+edge*.10f*grow);
            },fade*(i==0?.94f:.76f),age,i==0?new Color(1,.93f,.68f):new Color(1,.72f,.32f));
        }
    }
    void Brute(Vector3 c,Vector3 end,Vector3 f,Vector3 r,float travel,float post,float grow,float fade,float age){
        if(second)c=Vector3.Lerp(end+Vector3.up*2.3f,end,travel*travel);
        // Interlocking flame lobes, not four identical rigid finger capsules.
        for(int i=0;i<(second?6:4);i++){int k=i;float side=second?(i<3?-.19f:.17f):0,phase=(i%3)*1.61f+.22f;
            Surface(i,(u,v)=>{
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.68f);
                float a=phase+(v-.5f)*2.4f+u*.8f+.14f*Mathf.Sin(age*8+u*6+k);
                float radius=taper*(.21f+.08f*v+.03f*Mathf.Sin(u*10+k))*grow;
                var axis=second?Vector3.up:f;var normal=second?f:Vector3.up;
                return c+r*(side*grow+Mathf.Cos(a)*radius)+normal*(Mathf.Sin(a)*radius)+axis*((u-.56f)*(.74f+.09f*Mathf.Sin(k))*grow);
            },fade,age,Color.Lerp(hue,new Color(1,.84f,.33f),i%3*.26f));
        }
        // A pale furnace seam follows the punch on A and falls from above on
        // B; their axes and recovery stay different even at the bright peak.
        for(int i=0;i<3;i++){int k=i;float axisSide=second?(i-1)*.24f:(i-1)*.16f;
            Surface(6+i,(u,v)=>{
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.59f);
                float heat=Mathf.Sin(u*(7.6f+k)+age*8.2f+k*2.3f)*.085f*taper;
                Vector3 axis=second?Vector3.up:f,normal=second?f:Vector3.up;
                return c+r*(axisSide*grow+(v-.5f)*(.15f+.025f*k)*taper*grow+heat)
                    +normal*(heat*.75f+taper*(.06f+.04f*k)*grow)
                    +axis*((u-.52f)*(1.0f+.13f*k)*grow);
            },fade*(.90f-i*.13f),age,i==0?new Color(1,.98f,.79f):new Color(1,.78f,.34f));
        }
    }
    void Throat(Vector3 c,Vector3 f,Vector3 r,float post,float grow,float fade,float age){
        for(int i=0;i<(second?4:3);i++){int k=i;float phase=i*1.87f+.28f;
            Surface(i,(u,v)=>{
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.8f);
                if(second){float sweep=(u-.5f)*(1.07f+.13f*Mathf.Sin(k*2))*grow;
                    // Four offset pressure crests occupy real depth. Narrower
                    // scalloped membranes and gaps replace the merged flat
                    // yellow plate seen in the first engine recording.
                    return c+r*(sweep+(k-1.5f)*.17f*grow)
                        +Vector3.up*((v-.5f)*(.16f+.028f*k)*taper*grow+Mathf.Sin(u*(3.5f+k*.32f)+k*1.7f)*(.17f+.028f*k)*grow+(k-1.5f)*.11f*grow)
                        +f*(taper*(.13f+.065f*k)*grow+k*.22f*grow+(v-.5f)*.20f*taper*grow+.065f*Mathf.Sin(u*8+age*7+k));}
                float angle=phase+(u-.5f)*(2.1f+.15f*k)+age*.75f;
                float radius=(.31f+(v-.5f)*.29f*taper)*grow*(1+.16f*Mathf.Sin(u*8+k));
                return c+f*((u-.5f)*.62f*grow+k*.12f)+r*(Mathf.Sin(angle)*radius)+Vector3.up*(Mathf.Cos(angle)*radius*.77f+(v-.5f)*.17f*taper*grow);
            },fade*.88f,age,Color.Lerp(hue,new Color(.32f,1,.79f),i*.12f));
        }
        // Gold throat membranes are open calligraphic crests, never a circular
        // pulse or evenly spaced acoustic bars. B spreads laterally; A curls.
        for(int i=0;i<3;i++){int k=i;float phase=i*1.41f+.2f;
            Surface(6+i,(u,v)=>{
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.74f),edge=(v-.5f)*taper;
                if(second)return c+r*((u-.5f)*(1.25f+.20f*k)*grow+(k-1)*.17f*grow+edge*.16f*grow)
                    +Vector3.up*(Mathf.Sin(u*(3.4f+k*.5f)+phase)*(.17f+.04f*k)*grow+edge*.12f*grow+(k-1)*.11f*grow)
                    +f*(taper*(.13f+.075f*k)*grow+k*.22f*grow+edge*.13f*grow+Mathf.Sin(u*8+age*6+k)*.045f);
                float arc=phase+(u-.5f)*(1.70f+.18f*k)+age*.48f;
                return c+f*((u-.5f)*(.78f+.08f*k)*grow)+r*(Mathf.Sin(arc)*(.28f+edge*.19f)*grow)
                    +Vector3.up*(Mathf.Cos(arc)*(.24f+edge*.14f)*grow);
            },fade*(.87f-i*.15f),age,i==0?new Color(1,.98f,.76f):new Color(.59f,1,.84f));
        }
    }

    void Veil(Vector3 c,Vector3 f,Vector3 r,float travel,float post,float grow,float fade,float age){
        if(second){
            float closure=post<0?travel:1-Mathf.Clamp01(post/.48f);
            for(int i=0;i<4;i++){int k=i;float sign=i%2==0?-1:1;
                Surface(i,(u,v)=>{
                    float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.68f);
                    float pull=(1-closure)*(.48f+.17f*k), curl=u*5.1f+age*2+k*1.3f;
                    float breadth=(.86f+.18f*Mathf.Sin(u*7.3f+k))*taper;
                    return c+r*(sign*(.17f+pull)+Mathf.Sin(curl)*.18f*grow+(v-.5f)*breadth*grow)
                        +Vector3.up*((u-.5f)*(1.43f-.13f*k)*grow+(v-.5f)*.29f*taper*grow)
                        +f*(k*.18f+Mathf.Cos(curl)*.28f*grow+Mathf.Sin(v*3.2f+u*4+k)*.33f*taper*grow+(v-.5f)*.30f*taper*grow);
                },fade,age,Color.Lerp(hue,new Color(.28f,.07f,.38f),k*.15f));
                Surface(6+i,(u,v)=>{
                    float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.73f),curl=u*5.1f+age*2+k*1.3f;
                    return c+r*(sign*(.17f+(1-closure)*(.48f+.17f*k))+Mathf.Sin(curl)*.18f*grow+(v-.5f)*.085f*taper*grow)
                        +Vector3.up*((u-.5f)*(1.47f-.13f*k)*grow)
                        +f*(k*.18f+Mathf.Cos(curl)*.28f*grow+.015f);
                },fade*.76f,age,new Color(1,.74f,.88f));
            }
            return;
        }
        for(int i=0;i<(second?4:3);i++){int k=i;float angle=second?(i%2==0?.72f:-1.02f)+i*.09f:i*.29f-.29f;var along=r*Mathf.Cos(angle)+Vector3.up*Mathf.Sin(angle);
            Surface(i,(u,v)=>{float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.75f),length=1.08f+.19f*Mathf.Sin(k*1.7f);
                return c+along*((u-.5f)*length*grow)+Vector3.up*((v-.5f)*(.32f+.07f*Mathf.Sin(u*8+k))*grow*taper+Mathf.Sin(u*5+k*2.1f)*.15f*grow+k*.065f)+f*(Mathf.Sin(u*Mathf.PI*1.6f+age*4+k)*.32f*grow+(v-.5f)*.24f*taper*grow+k*.10f);
            },fade,age,Color.Lerp(hue,new Color(.64f,.30f,.88f),i*.13f));
        }
        // Pale thread remains stitched into the moving cloth. A is one
        // slanted draw; B crosses two separate folds at unequal depth.
        for(int i=0;i<(second?4:3);i++){int k=i;float angle=second?(i%2==0?.72f:-1.02f)+i*.09f:i*.29f-.29f;var along=r*Mathf.Cos(angle)+Vector3.up*Mathf.Sin(angle);
            Surface(6+i,(u,v)=>{float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.72f),edge=(v-.5f)*taper;
                return c+along*((u-.5f)*(1.18f+.13f*Mathf.Sin(k*1.7f))*grow)
                    +Vector3.up*(edge*.16f*grow+Mathf.Sin(u*6+k*2.1f)*.08f*grow+k*.055f)
                    +f*(Mathf.Sin(u*Mathf.PI*1.6f+age*4+k)*(.23f+.03f*k)*grow+edge*.13f*grow+k*.10f+.045f);
            },fade*(.88f-i*.10f),age,i==0?new Color(1,.82f,.90f):new Color(1,.39f,.61f));
        }
    }
    void Mouse(Vector3 c,Vector3 f,Vector3 r,float travel,float post,float grow,float fade,float age){
        const int count=2;
        for(int i=0;i<count;i++){int k=i;
            Surface(i,(u,v)=>{float taper=Mathf.Max(0,Mathf.Sin(u*Mathf.PI));
                if(!second){float sign=k==0?1:-1;return c+r*((u-.5f)*(.94f+k*.14f)*grow)+Vector3.up*((sign*(.08f+.21f*taper)+(v-.5f)*.55f*taper)*grow)+f*((u-.5f)*.37f*grow+k*.13f+(v-.5f)*.23f*taper*grow);}
                float a=(u-.5f)*(2.45f+k*.18f)+travel*1.65f+k*.36f;float radius=(.36f+.19f*v*taper)*grow*(1+.08f*Mathf.Sin(u*9+k));
                return c+r*(Mathf.Sin(a)*radius)+Vector3.up*(.42f*Mathf.Cos(a)*radius+(v-.5f)*.50f*taper*grow+k*.08f)+f*(.20f*Mathf.Cos(a)*grow+(v-.5f)*.35f*taper*grow+k*.11f);},fade,age,Color.Lerp(hue,Color.white,.3f));
        }
        if(second)Surface(2,(u,v)=>{float taper=Mathf.Max(0,Mathf.Sin(u*Mathf.PI));return c+r*((u-.5f)*1.80f*grow)+f*(Mathf.Sin(u*4+age*10)*.22f+(v-.5f)*.20f*taper*grow)+Vector3.up*((v-.5f)*.36f*taper*grow+.12f*Mathf.Sin(u*4+age*5));},fade*.63f,age);
        for(int i=0;i<2;i++){int k=i;
            Surface(6+i,(u,v)=>{float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.68f),edge=(v-.5f)*taper;
                if(!second)return c+r*((u-.5f)*(.94f+k*.15f)*grow)+Vector3.up*((k==0?1:-1)*(.07f+.16f*taper)*grow+edge*.24f*grow)
                    +f*((u-.5f)*.38f*grow+k*.12f+edge*.14f*grow);
                float arc=(u-.5f)*(2.5f+k*.17f)+travel*1.65f+k*.36f;
                return c+r*(Mathf.Sin(arc)*(.38f+edge*.18f)*grow)+Vector3.up*(Mathf.Cos(arc)*(.19f+edge*.16f)*grow+k*.08f)
                    +f*(Mathf.Cos(arc)*.17f*grow+edge*.17f*grow+k*.11f);
            },fade*(.92f-i*.17f),age,i==0?new Color(.88f,.98f,1):new Color(.38f,.89f,1));
        }
    }
    void Accent(Vector3 center,Vector3 end,Vector3 f,Vector3 r,float post,float grow,float fade,float age){
        if(post<0)return;
        // Torn, curved hot seams leave the principal silhouette in its own
        // direction. No shared circular shockwave, card face, or screen plate.
        float opening=Mathf.Clamp01(post/.07f),life=Mathf.Clamp01(1-post/.25f);
        for(int i=0;i<6;i++){int k=i;float side=i%2==0?-1:1,seed=i*1.73f;
            Surface(12+i,(u,v)=>{
                float taper=Mathf.Pow(Mathf.Max(0,Mathf.Sin(u*Mathf.PI)),.8f);
                float w=(v-.5f)*taper*(.065f+.027f*Mathf.Sin(seed))*grow;
                float reach=(.23f+.09f*Mathf.Sin(seed+1))*grow;
                if(species=="copperback")return new Vector3(end.x,.055f,end.z)+r*(side*(.05f+u*reach)+w)+f*((u-.3f)*reach*.7f+k*.04f)+Vector3.up*(taper*(.12f+.065f*k)*grow+opening*u*.12f);
                if(species=="crimson-brute")return end+r*(side*(.035f+u*reach*.7f)+w*Mathf.Cos(u*5+seed))+f*(Mathf.Sin(u*5+seed)*reach*.23f+w)+Vector3.up*(u*(.22f+.09f*k)*grow+Mathf.Sin(u*4+seed)*.05f);
                if(species=="golden-throat"){float a=seed*.42f+u*(1.15f+.06f*k);return end+r*(Mathf.Sin(a)*reach+w)+Vector3.up*(Mathf.Cos(a)*reach*.6f+w)+f*(u*reach*.9f+k*.035f);}
                if(species=="veil-oracle")return end+r*(side*(u-.20f)*reach+w)+Vector3.up*(side*(u-.48f)*reach*.72f+w*.8f)+f*(Mathf.Sin(u*4+seed)*reach*.38f+k*.025f);
                return end+r*(side*(u-.25f)*reach+w)+Vector3.up*(Mathf.Sin(u*3.5f+seed*.28f)*reach*.4f+w)+f*(u*u*reach*.53f+k*.035f);
            },life*fade*(.70f+.18f*Mathf.Sin(seed)),age,Color.Lerp(hue,Color.white,species=="copperback"?.55f:.70f));
        }
    }
    void Burst(Vector3 end,Vector3 r,Vector3 f,float t,float fade){
        for(int i=0;i<sparks.Count;i++){
            float a=i*2.399963f+.16f*Mathf.Sin(i*3.7f),delay=(i%6)*.008f,life=Mathf.Max(0,t-delay);
            float up=species=="crimson-brute"?.65f+Mathf.Abs(Mathf.Sin(a))*.8f:species=="copperback"?.25f+Mathf.Abs(Mathf.Sin(a))*.48f:Mathf.Sin(a)*.6f;
            float along=species=="golden-throat"?.9f:species=="moonfang"?.65f:.35f;
            Vector3 direction=(r*Mathf.Cos(a)+Vector3.up*up+f*Mathf.Sin(i*1.7f)*along).normalized;
            float speed=3.8f+(i%7)*.57f,gravity=species=="copperback"?4.8f:species=="crimson-brute"?2.2f:1.1f;
            Vector3 anchor=species=="copperback"?new Vector3(end.x,.08f,end.z):end;
            Vector3 p=anchor+direction*(.07f+life*speed)+Vector3.down*life*life*gravity;
            var l=sparks[i];l.enabled=t>=delay&&fade>.02f;l.startWidth=(i%5==0?.036f:.018f)*(1-life);l.endWidth=.001f;
            var color=Color.Lerp(hue,Color.white,i%3==0?.83f:.25f);color.a=fade*Mathf.Clamp01(1-life/.42f);l.startColor=color;l.endColor=new Color(hue.r,hue.g,hue.b,0);
            float trail=.08f+life*.27f;l.SetPosition(0,p-direction*trail+Vector3.up*life*.06f);l.SetPosition(1,p);l.SetPosition(2,p+direction*.025f);
        }
    }
    void OnDestroy(){foreach(var s in sheets){if(s.mesh)Destroy(s.mesh);if(s.mat)Destroy(s.mat);}if(sparkMaterial)Destroy(sparkMaterial);}
}
