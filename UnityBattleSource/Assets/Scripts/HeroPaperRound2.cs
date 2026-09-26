using System.Collections.Generic;
using UnityEngine;

/// Painted, curled paper with chipped, unequal edges and a physical side wall.
/// The silhouette is geometry, not a rectangular quad covered in noisy glow.
public static class HeroPaperRound2
{
    public static Mesh Create(Rect art, float aspect=.58f, float depth=.018f,
        float curl=.10f, int seed=0, bool seal=false)
    {
        const int columns=16, rows=24;
        int faceCount=(columns+1)*(rows+1);
        var vertices=new List<Vector3>(faceCount*2+320);
        var uv=new List<Vector2>(faceCount*2+320);
        var colors=new List<Color>(faceCount*2+320);
        var faces=new List<int>(columns*rows*12);
        var sides=new List<int>(320*6);
        for(int face=0;face<2;face++)
        for(int row=0;row<=rows;row++)
        for(int col=0;col<=columns;col++)
        {
            float u=col/(float)columns,v=row/(float)rows;
            float left=.045f*Mathf.Sin(v*15.3f+seed)+.023f*Mathf.Sin(v*38.7f+1.2f);
            float right=.042f*Mathf.Sin(v*12.7f+seed+1.7f)+.018f*Mathf.Sin(v*31.2f+2.8f);
            float rounded=.075f*Mathf.Pow(Mathf.Abs(v*2-1),12);
            float outline=seal ? .22f+.76f*Mathf.Pow(Mathf.Max(0,Mathf.Sin(v*Mathf.PI)),.55f)
                *(1+.13f*Mathf.Sin(v*19+seed)) : 1;
            float x=Mathf.Lerp(-.5f+left+rounded,.5f+right-rounded,u)*aspect*outline;
            float y=v-.5f+Mathf.Lerp(.028f*Mathf.Sin(u*12+seed)+.017f*Mathf.Sin(u*34+3),
                .026f*Mathf.Sin(u*15+seed+2)+.016f*Mathf.Sin(u*29.7f+1),v);
            float z=Mathf.Sin(u*Mathf.PI)*curl+Mathf.Sin(v*3.7f+seed)*curl*.22f
                +Mathf.Sin(u*3.8f+v*2.5f)*curl*.17f+(face==0?-depth:depth);
            vertices.Add(new Vector3(x,y,z));
            uv.Add(new Vector2(Mathf.Lerp(art.xMin,art.xMax,u),Mathf.Lerp(art.yMin,art.yMax,v)));
            float shade=.78f+.22f*Mathf.Sin(u*Mathf.PI);
            colors.Add(new Color(shade,shade*.98f,shade*.96f,1));
            if(row<rows&&col<columns)
            {
                int a=face*faceCount+row*(columns+1)+col,b=a+1,c=a+columns+2,d=a+columns+1;
                if(face==0)faces.AddRange(new[]{a,c,b,a,d,c});
                else faces.AddRange(new[]{a,b,c,a,c,d});
            }
        }
        var perimeter=new List<int>();
        for(int x=0;x<=columns;x++)perimeter.Add(x);
        for(int y=1;y<=rows;y++)perimeter.Add(y*(columns+1)+columns);
        for(int x=columns-1;x>=0;x--)perimeter.Add(rows*(columns+1)+x);
        for(int y=rows-1;y>0;y--)perimeter.Add(y*(columns+1));
        for(int edge=0;edge<perimeter.Count;edge++)
        {
            int a=perimeter[edge],b=perimeter[(edge+1)%perimeter.Count],n=vertices.Count;
            vertices.AddRange(new[]{vertices[a],vertices[b],vertices[b+faceCount],vertices[a+faceCount]});
            uv.AddRange(new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up});
            Color tint=edge%7<3?new Color(.96f,.65f,.25f):new Color(.41f,.23f,.12f);
            for(int k=0;k<4;k++)colors.Add(tint);
            sides.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});
        }
        var mesh=new Mesh{name=seal?"Irregular embossed evidence seal":"Curled illustrated tarot with torn edges"};
        mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetColors(colors);mesh.subMeshCount=2;
        mesh.SetTriangles(faces,0);mesh.SetTriangles(sides,1);mesh.RecalculateNormals();mesh.RecalculateBounds();
        return mesh;
    }
}
