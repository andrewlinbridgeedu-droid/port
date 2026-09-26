using UnityEngine;

public sealed partial class EnemySignatureSpellVFX
{
    // Presentation only: thick folded cloth and opaque metal share the owner's
    // frame meshes and disappear through its normal cancellation lifecycle.
    static Shader crimsonSurfaceShader;
    private void CrimsonSpectacle(int variant, int phase, float p, Vector3 s, Vector3 t)
    {
        // The filament shader softened every filled cloth face into a rubber
        // tube. Use the existing batch material with the solid sprite surface.
        if (!crimsonSurfaceShader) crimsonSurfaceShader = Resources.Load<Shader>("EnemySignature/SignatureSprite");
        if (crimsonSurfaceShader && ink.material.shader != crimsonSurfaceShader)
        {
            ink.material.shader = crimsonSurfaceShader;
            ink.material.SetFloat("_Shape", 4);
            ink.material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        }
        float alpha = phase == 0 ? Mathf.SmoothStep(0, 1, p * 1.5f) : phase == 1 ? 1 : 1 - p;
        float span = Mathf.Clamp(airWidth * .96f, 2.5f, 4.0f);
        bool rain = variant % 2 != 0;
        float travel = phase == 0 ? .16f : phase == 1 ? Mathf.Lerp(.16f, .89f, p) : .89f;
        Vector3 stage = Vector3.Lerp(s, t, travel) - cameraUp * .17f;
        if (!rain)
        {
            // Two theatrical lengths of cloth unfurl OUTWARDS, leaving an open
            // lane at the actor's face. They sweep through the corridor as sheets.
            for (int panel = 0; panel < 2; panel++)
            {
                float side = panel % 2 == 0 ? -1 : 1;
                float depth = panel / 2;
                Vector3 inner = stage + cameraRight * side * (.39f + (phase == 2 ? p * .65f : 0))
                    + cameraUp * (depth * .28f - .16f) + forward * depth * .42f;
                Vector3 outer = stage + cameraRight * side * span * (phase == 0 ? .45f + p * .55f : 1 + (phase == 2 ? p * .18f : 0))
                    + cameraUp * (.15f + depth * .55f) + forward * (.20f + depth * .42f);
                CrimsonStageSheet(inner, outer, 1.0f + depth * .22f, panel, p + phase, alpha * (depth == 0 ? 1 : .75f));
            }
            if (phase == 2)
                for (int k = 0; k < 8; k++)
                {
                    float side = k % 2 == 0 ? -1 : 1;
                    Vector3 end = t + cameraRight * side * (.65f + Noise(k + 56) * 1.7f + p * .8f)
                        - cameraUp * (.15f + p * (.25f + Noise(k))) + forward * (Noise(k + 34) - .5f);
                    CrimsonCloth(end - cameraUp * (.65f + p * .2f), end, k + 7, p * 2,
                        .20f, .20f * (1 - p), alpha);
                }
        }
        else
        {
            // A single diagonal bolt of velvet is cut into broad billowing
            // sections by substantial sewing shuttles, rather than thin needles.
            Vector3 loom = Vector3.Lerp(s, t, phase == 0 ? .28f : phase == 1 ? .28f + p * .54f : .82f)
                + cameraUp * (phase == 0 ? .64f : .64f * (1 - p));
            for (int panel = 0; panel < 2; panel++)
            {
                float side = panel % 2 == 0 ? -1 : 1;
                Vector3 inner = loom + cameraRight * side * .52f + cameraUp * (panel - 1) * .22f;
                Vector3 outer = loom + cameraRight * side * span * (.88f + panel * .06f)
                    + cameraUp * (.25f + panel * .30f) + forward * panel * .28f;
                CrimsonStageSheet(inner, outer, .84f, panel + 6, p * 1.4f + phase, alpha * .88f);
            }
            for (int i = 0; i < 7; i++)
            {
                float lane = (i / 6f * 2 - 1) * .85f + (Noise(i + 67) - .5f) * .16f;
                Vector3 top = Vector3.Lerp(s, t, .30f + Noise(i + 30) * .18f)
                    + cameraRight * lane * span + cameraUp * (.70f + Noise(i + 41) * 1.05f);
                Vector3 landing = t - cameraUp * .40f + cameraRight * lane * .85f
                    + forward * (Noise(i + 23) - .5f) * .65f;
                float delay = Noise(i + 88) * .20f;
                float fall = phase == 0 ? 0 : phase == 1 ? Mathf.Clamp01((p - delay) / (1 - delay)) : 1;
                Vector3 c = Vector3.Lerp(top, landing, fall);
                Vector3 direction = (landing - top).normalized;
                float visible = alpha * (phase == 0 ? Mathf.Clamp01(p * 2 - Noise(i + 2) * .65f) : 1);
                float size = .88f + Noise(i + 17) * .34f;
                CrimsonShuttle(c, direction, size, visible);
                if (phase < 2)
                {
                    for (int wake=0;wake<6;wake++) {
                        Vector3 mistPoint=c-direction*(size*.5f+wake*.14f);
                        Billboard(smoke,mistPoint,.52f,.7f,i+p,new Color(.24f,.018f,.055f,visible*(1-wake/6f)*.23f),wake%4);
                    }
                }
            }
        }
        for(int burst=0;burst<(rain?16:10);burst++)
        {
            float side=burst%2==0?-1:1;
            float launch=phase==0?p*.25f:phase==1?p:1;
            Vector3 c=Vector3.Lerp(s,t,launch)+cameraRight*side*(.48f+Noise(burst+71)*1.3f)
                +cameraUp*(Noise(burst+18)-.5f)*1.5f;
            FlameTongue(c,.40f+Noise(burst+2)*.42f,new Color(1f,.035f,.11f,.9f),alpha*.48f,burst,p+phase);
        }
        // A wine-dark backing sits below/behind the wide cloth, not a white
        // bloom and not a smoke blob substituted for the cloth's actual surface.
        for (int i = 0; i < 26; i++)
        {
            float side = i % 2 == 0 ? -1 : 1;
            Vector3 c = stage + cameraRight * side * (.65f + Noise(i + 55) * span * .73f)
                + cameraUp * (Noise(i + 16) - .65f) * .94f
                + forward * (.30f + Noise(i + 7) * .48f);
            Billboard(smoke, c, 1.0f + Noise(i) * .75f, .85f + Noise(i + 8) * .55f,
                i * 1.81f + p * .35f, new Color(.23f, .018f, .05f, .24f * alpha), i % 4);
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
            float r0=Mathf.Pow(Mathf.Sin(u0*Mathf.PI),.7f)*size*.065f;
            float r1=Mathf.Pow(Mathf.Sin(u1*Mathf.PI),.7f)*size*.065f;
            Vector3 c0=tip-axis*size*u0,c1=tip-axis*size*u1;
            Vector3 x0=side*Mathf.Cos(a0)+depth*Mathf.Sin(a0),x1=side*Mathf.Cos(a1)+depth*Mathf.Sin(a1);
            float shine=.28f+.65f*Mathf.Pow(Mathf.Max(0,Mathf.Cos((a0+a1)*.5f-.6f)),5);
            ink.Quad(c0+x0*r0,c1+x0*r1,c1+x1*r1,c0+x1*r0,new Color(shine*.88f,shine*.75f,shine*.72f,alpha));
        }
    }
}
