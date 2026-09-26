using UnityEngine;

/// <summary>Material adapter only for the two skill 06 costume snapshots.</summary>
public static class HeroHuntingEchoMaterial
{
    public static Material Create(Material source, int echoIndex)
    {
        Shader shader = Resources.Load<Shader>("Effects/Fool/HeroHuntingEcho");
        if (!source || !shader) return null;
        var result = new Material(shader) { name = source.name + " detailed hunting echo" };
        CopyTexture(source, result, source.HasProperty("_BaseMap") ? "_BaseMap" : "_MainTex", "_MainTex");
        Color original = source.HasProperty("_BaseColor") ? source.GetColor("_BaseColor")
            : source.HasProperty("_Color") ? source.GetColor("_Color") : Color.white;
        result.SetColor("_Color", original);
        result.SetColor("_RimColor", echoIndex == 0 ? new Color(.68f,.25f,1f) : new Color(.15f,.83f,1f));
        if (source.HasProperty("_BumpMap") && source.GetTexture("_BumpMap"))
        {
            CopyTexture(source, result, "_BumpMap", "_BumpMap");
            result.SetFloat("_HasNormal", 1);
            result.SetFloat("_BumpScale", source.HasProperty("_BumpScale") ? source.GetFloat("_BumpScale") : 1);
        }
        if (source.HasProperty("_Glossiness")) result.SetFloat("_Glossiness", source.GetFloat("_Glossiness"));
        return result;
    }

    static void CopyTexture(Material source, Material target, string from, string to)
    {
        if (!source.HasProperty(from)) return;
        target.SetTexture(to, source.GetTexture(from));
        target.SetTextureScale(to, source.GetTextureScale(from));
        target.SetTextureOffset(to, source.GetTextureOffset(from));
    }
}
