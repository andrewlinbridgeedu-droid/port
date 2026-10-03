using System.Linq;
using UnityEngine;

// One shared skeleton and Animator; selected outfit meshes never change the arena or clocks.
public sealed class RefinedHeroAppearance : MonoBehaviour
{
    public string Outfit { get; private set; } = "mistport-night";
    // Created on first use: Unity rejects MaterialPropertyBlock in a field initializer.
    MaterialPropertyBlock block;
    public bool Apply(string id)
    {
        if (id != "mistport-night" && id != "starlight-magician" && id != "midnight-carnival") return false;
        Outfit = id;
        string costume = id == "starlight-magician" ? "starlight" : id == "midnight-carnival" ? "carnival" : "night";
        bool separateCostumes = GetComponentsInChildren<Renderer>(true).Any(r => r.name.StartsWith("Outfit-"));
        if (separateCostumes) {
            foreach (var r in GetComponentsInChildren<Renderer>(true))
                if (r.name.StartsWith("Outfit-")) r.enabled = r.name.StartsWith("Outfit-" + costume + "-");
            return true;
        }
        var coat = id == "starlight-magician" ? new Color(.62f,.58f,.47f) : id == "midnight-carnival" ? new Color(.055f,.016f,.024f) : new Color(.016f,.011f,.025f);
        var silk = id == "starlight-magician" ? new Color(.035f,.055f,.19f) : id == "midnight-carnival" ? new Color(.35f,.018f,.032f) : new Color(.072f,.018f,.15f);
        var sash = id == "midnight-carnival" ? new Color(.36f,.035f,.028f) : new Color(.018f,.22f,.25f);
        block ??= new MaterialPropertyBlock();
        foreach (var r in GetComponentsInChildren<Renderer>(true)) {
            if (r.name == "Hero Starlight Motifs") { r.enabled = id == "starlight-magician"; continue; }
            if (r.name == "Hero Carnival Motifs") { r.enabled = id == "midnight-carnival"; continue; }
            var materials = r.sharedMaterials;
            for (int i = 0; i < materials.Length; i++) {
                var m = materials[i]; if (!m) continue;
                Color c;
                if (m.name.Contains("Coat Charcoal")) c = coat;
                else if (m.name.Contains("Violet Silk")) c = silk;
                else if (m.name.Contains("Teal Sash")) c = sash;
                else continue;
                r.GetPropertyBlock(block, i); block.SetColor("_Color", c); r.SetPropertyBlock(block, i); block.Clear();
            }
        }
        return true;
    }
}
