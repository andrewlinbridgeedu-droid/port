using UnityEngine;

public sealed partial class EnemySignatureSpellVFX
{
    // Presentation only: thick folded cloth and opaque metal share the owner's
    // frame meshes and disappear through its normal cancellation lifecycle.
    static Shader crimsonSurfaceShader;
    CrimsonStageProjection crimsonProjection;
    private void CrimsonSpectacle(int variant, int phase, float p, Vector3 s, Vector3 t)
    {
        if(!crimsonProjection || crimsonProjection.transform.parent!=root.transform)
        {
            var go=new GameObject("Crimson stage spell projection");go.transform.SetParent(root.transform,false);
            crimsonProjection=go.AddComponent<CrimsonStageProjection>();
        }
        crimsonProjection.Sample(variant,phase,p,s,t);
        if (!crimsonSurfaceShader) crimsonSurfaceShader = Resources.Load<Shader>("EnemySignature/SignatureSprite");
        if(crimsonSurfaceShader && ink.material.shader!=crimsonSurfaceShader)
        {ink.material.shader=crimsonSurfaceShader;ink.material.SetFloat("_Shape",4);ink.material.SetFloat("_DstBlend",(float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);}
        float alpha=phase==0?Mathf.SmoothStep(0,1,p):phase==1?1:1-p;
        if(variant%2!=0)
        {
            // Real metal cores remain in world space, with the projected needle
            // storm supplying the enveloping red energy and impact fragmentation.
            for(int i=0;i<9;i++)
            {
                float lane=(i/8f*2-1),delay=Noise(i+88)*.18f;
                Vector3 top=s+cameraRight*lane*1.8f+cameraUp*(.65f+Noise(i+41));
                Vector3 landing=t+cameraRight*lane*.55f-cameraUp*.35f;
                float fall=phase==0?0:phase==1?Mathf.Pow(Mathf.Clamp01((p-delay)/(1-delay)),2.3f):1;
                Vector3 c=Vector3.Lerp(top,landing,fall);
                CrimsonShuttle(c,(landing-top).normalized,1.15f+Noise(i)*.35f,alpha);
            }
        }
        else if(phase==2)
        {
            // A few actual torn lengths peel through depth after the red tidal
            // wall ruptures; these no longer form two rectangular cloth panels.
            for(int i=0;i<5;i++)
            {
                float side=i%2==0?-1:1;
                Vector3 a=t+cameraRight*side*(.35f+p*1.3f)+cameraUp*(Noise(i)-.5f);
                Vector3 b=a+cameraRight*side*.7f+cameraUp*(.3f+p*.5f)+forward*(Noise(i+4)-.5f);
                CrimsonCloth(a,b,i,p*3,.35f,.14f*(1-p),alpha*.55f);
            }
        }
    }

    void CrimsonStageSheet(Vector3 inner, Vector3 outer, float height, int seed, float time, float alpha)
    {
        // Vertical velvet folds: illumination varies across the hanging cloth,
        // NOT in horizontal bands. Dense geometry resolves curved ridges/valleys.
        const int columns = 56, rows = 16;
        for (int x = 0; x < columns; x++)
        for (int y = 0; y < rows; y++)
        {
            float u0=x/(float)columns,u1=(x+1)/(float)columns;
            float v0=y/(float)rows,v1=(y+1)/(float)rows;
            float u=(u0+u1)*.5f,v=(v0+v1)*.5f;
            float phase=u*39f + Mathf.Sin(u*8+seed)*.65f + v*.55f-time*.55f+seed;
            float ridge=.5f+.5f*Mathf.Cos(phase);
            float velvet=Mathf.Pow(ridge,2.3f);
            float falloff=.84f+.16f*Mathf.Sin(v*2.7f+.5f);
            // Deep wine valleys; narrow muted silk sheen, no luminous stripes.
            Color color=new Color((.075f+velvet*.25f)*falloff,
                (.009f+velvet*.033f)*falloff,(.025f+velvet*.068f)*falloff,alpha*.97f);
            ink.Quad(CrimsonSheetPoint(inner,outer,u0,v0,height,seed,time),
                CrimsonSheetPoint(inner,outer,u1,v0,height,seed,time),
                CrimsonSheetPoint(inner,outer,u1,v1,height,seed,time),
                CrimsonSheetPoint(inner,outer,u0,v1,height,seed,time),color);
        }
    }
    Vector3 CrimsonSheetPoint(Vector3 inner,Vector3 outer,float u,float v,float height,int seed,float time)
    {
        float phase=u*39f+Mathf.Sin(u*8+seed)*.65f+v*.55f-time*.55f+seed;
        float scallop=.09f*Mathf.Sin(u*18+seed)+.055f*Mathf.Sin(u*43+seed*.7f);
        float upper=.64f*height+scallop;
        float lower=-1.34f*height+.13f*Mathf.Sin(u*11+seed)+scallop*.5f;
        float sag=Mathf.Sin(u*Mathf.PI)*.19f;
        return Vector3.Lerp(inner,outer,u)
            +cameraUp*(Mathf.Lerp(lower,upper,v)-sag)
            +view*(Mathf.Sin(phase)*(.13f+.075f*(1-v))+.035f*Mathf.Sin(phase*2))
            +cameraRight*Mathf.Sin(v*2.7f+time*1.5f+seed)*.065f*(1-v);
    }

    void CrimsonCloth(Vector3 start, Vector3 end, int seed, float time, float bow, float halfWidth, float alpha)
    {
        if (halfWidth < .002f || alpha < .002f) return;
        Vector3 previousA = Vector3.zero, previousB = Vector3.zero, previousFold = Vector3.zero;
        for (int j = 0; j <= 22; j++)
        {
            float u = j / 22f;
            float envelope = Mathf.Sin(u * Mathf.PI);
            Vector3 center = Vector3.Lerp(start, end, u)
                + cameraRight * Mathf.Sin(u * 2.5f + seed * .91f + time * 2.3f) * bow * envelope
                + cameraUp * Mathf.Sin(u * 3.3f + seed * 1.7f - time * 3) * halfWidth * 1.6f * envelope
                + forward * Mathf.Sin(u * 7 + seed + time * 2) * .20f * envelope;
            float twist = Mathf.Sin(u * 3.7f + seed * 2 + time * 2.5f);
            Vector3 cross = (cameraUp * (.6f + twist * .22f) + cameraRight * twist * .5f + forward * .30f).normalized;
            float width = halfWidth * (.32f + .68f * Mathf.Pow(Mathf.Max(0, envelope), .35f))
                * (.85f + Mathf.Sin(u * 23 + seed) * .15f);
            Vector3 a = center - cross * width;
            Vector3 b = center + cross * width;
            Vector3 fold = center + cameraUp * width * .17f - view * width * (.24f + twist * .2f);
            if (j > 0)
            {
                float sheen = .5f + .5f * Mathf.Sin(u * 12 - time * 3 + seed);
                ink.Quad(previousA, a, fold, previousFold,
                    new Color(.25f + sheen * .22f, .012f + sheen * .018f, .045f + sheen * .032f, alpha * .92f));
                ink.Quad(previousFold, fold, b, previousB,
                    new Color(.57f + sheen * .20f, .035f + sheen * .035f, .095f + sheen * .06f, alpha * .94f));
            }
            previousA = a; previousB = b; previousFold = fold;
        }
    }

    void CrimsonShuttle(Vector3 tip, Vector3 direction, float size, float alpha)
    {
        // Rounded steel sewing spindle, with continuous curved shading rather
        // than three large triangular faces that read as floating diamonds.
        Vector3 axis=(direction-cameraUp*.55f).normalized;
        Vector3 side=Vector3.Cross(axis,view).normalized;
        if(side.sqrMagnitude<.01f)side=cameraRight;
        Vector3 depth=Vector3.Cross(axis,side).normalized;
        for(int j=0;j<18;j++) for(int k=0;k<12;k++) {
            float u0=j/18f,u1=(j+1)/18f,a0=k/12f*Mathf.PI*2,a1=(k+1)/12f*Mathf.PI*2;
            float r0=Mathf.Pow(Mathf.Sin(u0*Mathf.PI),.7f)*size*.026f;
            float r1=Mathf.Pow(Mathf.Sin(u1*Mathf.PI),.7f)*size*.026f;
            Vector3 c0=tip-axis*size*u0,c1=tip-axis*size*u1;
            Vector3 x0=side*Mathf.Cos(a0)+depth*Mathf.Sin(a0),x1=side*Mathf.Cos(a1)+depth*Mathf.Sin(a1);
            float shine=.28f+.65f*Mathf.Pow(Mathf.Max(0,Mathf.Cos((a0+a1)*.5f-.6f)),5);
            ink.Quad(c0+x0*r0,c1+x0*r1,c1+x1*r1,c0+x1*r0,new Color(shine*.88f,shine*.75f,shine*.72f,alpha));
        }
    }
}
