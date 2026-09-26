using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

/// Source-preserving surface calibration. Install after authored actor setup
/// (particularly HeroBackArtRefinement / FogGhostActor.Configure). Never writes MPBs,
/// alpha, transforms, animation state or source assets. Death copies retain ExitOpacity.
[DisallowMultipleComponent]
public sealed class CharacterSurfaceRefinement20260916 : MonoBehaviour
{
    public enum Family { Guard, OldHound, Core, Ghost, Leech, Emerald, Archivist, ArmoredHound, Matriarch, Hero }
    sealed class Entry
    {
        public Renderer renderer;
        public Material live, before, after;
        public bool createdInstance;
        public Material originalShared;
        public int slot;
    }
    readonly List<Entry> entries = new List<Entry>();
    static readonly Dictionary<Material,Material> originalForRefined = new Dictionary<Material,Material>();
    static readonly HashSet<CharacterSurfaceRefinement20260916> installed = new HashSet<CharacterSurfaceRefinement20260916>();
    public static bool PolishEnabled { get; private set; } = true;
    public static void ShowAll(bool show) { PolishEnabled=show; foreach(var component in installed) if(component) component.ShowRefinement(show); }
    public static void InstallAllVisible(GameObject hero = null)
    {
        if(hero) Install(hero,Family.Hero);
        foreach(var enemy in UnityEngine.Object.FindObjectsByType<EnemyHandle>(FindObjectsSortMode.None))
            if(enemy.gameObject.activeInHierarchy) Install(enemy);
    }
    public Family CharacterFamily { get; private set; }
    public bool IsRefined { get; private set; }
    public int MaterialCount => entries.Count;
    public static CharacterSurfaceRefinement20260916 Install(GameObject actor, Family family)
    {
        if (!actor) return null;
        var component = actor.GetComponent<CharacterSurfaceRefinement20260916>();
        if (!component) component = actor.AddComponent<CharacterSurfaceRefinement20260916>();
        if (component.entries.Count != 0) return component;
        component.CharacterFamily = family; component.Configure(); installed.Add(component);
        CharacterContactShadow.Install(actor,family);
        if(!PolishEnabled)component.ShowRefinement(false); return component;
    }
    public static CharacterSurfaceRefinement20260916 Install(EnemyHandle enemy)
    {
        if (!enemy) return null;
        var presence=enemy.GetComponent<EarlyEnemyIdlePresence>();
        var actor=presence && presence.VisibleActor ? presence.VisibleActor : enemy.Model;
        if (!actor) return null;
        string id=(enemy.ProfileEnemyId+" "+actor.name).ToLowerInvariant();
        Family family=id.Contains("early-hell") || id.Contains("ember") ? Family.OldHound
            : id.Contains("emerald") || id.Contains("revenant") ? Family.Emerald
            : actor.GetComponent<FogGhostActor>() || id.Contains("ghost") ? Family.Ghost
            : id.Contains("leech") ? Family.Leech : id.Contains("core") ? Family.Core
            : id.Contains("archiv") ? Family.Archivist
            : id.Contains("matriarch") || id.Contains("thread") || id.Contains("veil") ? Family.Matriarch
            : id.Contains("hound") ? Family.ArmoredHound : Family.Guard;
        return Install(actor.gameObject,family);
    }
    void Configure()
    {
        var shader=Resources.Load<Shader>("Shaders/CharacterSurfaceRefinement20260916");
        if (!shader) { Debug.LogError("Character surface shader missing",this); return; }
        foreach(var renderer in GetComponentsInChildren<Renderer>(true))
        {
            if (renderer is ParticleSystemRenderer || renderer is LineRenderer || renderer is TrailRenderer) continue;
            var shared=renderer.sharedMaterials;
            var materials=(Material[])shared.Clone();
            for(int i=0;i<materials.Length;i++)
            {
                var live=materials[i]; if (!live || !live.shader) continue;
                string name=live.shader.name;
                // Instantiate can copy an already-polished template. Recover its
                // unrefined snapshot before making this clone its own materials.
                Material inheritedOriginal=null;
                if(name=="Mistport/Character Surface 20260916" && originalForRefined.TryGetValue(live,out inheritedOriginal) && inheritedOriginal) name=inheritedOriginal.shader.name;
                bool hero=name=="Mindstone/Hero Tailored PBR";
                bool leech=name=="Mindstone/Memory Leech GLTF" || name=="Mindstone/Memory Leech GLTF Fade";
                bool standard=name=="Standard";
                if (!hero && !leech && !standard) continue; // keep authored FX shaders
                string label=live.name.ToLowerInvariant();
                if((label.Contains("eyes") || label.Contains("lens") || label.Contains("thread") || label.Contains("chestcore"))
                    && (!live.HasProperty("_MainTex") || !live.GetTexture("_MainTex")))continue;
                bool storyRegion=label.StartsWith("scribe_") || label.StartsWith("rescue_");
                float authoredBump=live.HasProperty("_BumpScale") ? live.GetFloat("_BumpScale") : 1;
                bool retainLiveReference=CharacterFamily==Family.Ghost || hero;
                if(!retainLiveReference) {live=new Material(inheritedOriginal?inheritedOriginal:live);materials[i]=live;}
                var entry=new Entry {renderer=renderer,live=live,before=new Material(live),originalShared=shared[i],createdInstance=!retainLiveReference,slot=i};
                bool normal=live.HasProperty("_BumpMap") && live.GetTexture("_BumpMap");
                bool packed=live.HasProperty("_MetallicGlossMap") && live.GetTexture("_MetallicGlossMap");
                bool emission=live.IsKeywordEnabled("_EMISSION");
                bool cutout=live.IsKeywordEnabled("_ALPHATEST_ON");
                if (hero)
                {
                    // Existing hero shader already separates cloth/gold and keeps the
                    // authored roughness. Refine normal fidelity without losing embroidery.
                    live.SetFloat("_BumpScale",authoredBump);
                }
                else
                {
                    live.shader=shader;
                    live.SetFloat("_SurfaceFamily",(int)CharacterFamily);
                    live.SetFloat("_SurfaceArt",1);
                    live.SetFloat("_SurfaceNormal",normal?1:0);
                    live.SetFloat("_SurfaceMaps",leech?3:packed?1:0);
                    live.SetFloat("_SurfaceEmission",emission?1:0);
                    live.SetFloat("_SurfaceCutout",cutout?1:0);
                    live.SetFloat("_ExitOpacity",1);
                    live.SetFloat("_SurfaceCull",leech?0:2);
                    float cloth=.55f,metal=.23f,bias=.025f,bump=.9f;
                    switch(CharacterFamily)
                    {
                        case Family.Guard:cloth=.64f;metal=.24f;bump=.88f;break;
                        case Family.OldHound:cloth=.67f;metal=.31f;bump=.9f;break;
                        case Family.Core:cloth=.39f;metal=.3f;bump=.86f;break;
                        case Family.Ghost:cloth=.72f;metal=.55f;bump=.72f;break;
                        case Family.Leech:cloth=.36f;metal=.4f;bump=.88f;bias=0;break;
                        case Family.Emerald:cloth=.68f;metal=.33f;bump=.82f;break;
                        case Family.Archivist:cloth=.52f;metal=.22f;bump=.88f;break;
                        case Family.ArmoredHound:cloth=.65f;metal=.29f;bump=.92f;break;
                        case Family.Matriarch:cloth=.69f;metal=.30f;bump=.52f;break;
                    }
                    // Fresh story assets already have independently authored wax, cloth, leather, skin and metal regions.
                    // Keep their scalar roughness instead of imposing the legacy guard floor.
                    if(storyRegion) {
                        cloth=0;metal=0;bias=0;bump=authoredBump;
                        // Recover authored micro-roughness while keeping each approved material's
                        // cloth/wax/leather/metal baseline. Never turn skin into metallic source noise.
                        bool scribe=label.StartsWith("scribe_");
                        var orm=Resources.Load<Texture2D>("CharacterSurface20260916/Story/"+(scribe?"Scribe":"Rescue")+"_ORM");
                        if(orm) {
                            live.SetTexture("_MetallicRoughness",orm);
                            live.SetFloat("_SurfaceMaps",4);
                            live.SetFloat("_SurfaceRoughCenter",scribe?.8687f:.8823f);
                            live.SetFloat("_SurfaceRoughDetail",.65f);
                        }
                    }
                    live.SetFloat("_SurfaceClothFloor",cloth);live.SetFloat("_SurfaceMetalFloor",metal);
                    live.SetFloat("_SurfaceRoughBias",bias);live.SetFloat("_BumpScale",bump);
                    string maps=CharacterFamily==Family.Guard?"Guard":CharacterFamily==Family.OldHound?"OldHound":CharacterFamily==Family.Core?"Core":CharacterFamily==Family.Ghost?"Ghost":null;
                    // Only the authored body map receives the copied source maps, not
                    // separately painted gear or generated accessory materials.
                    if(maps!=null && HasMatchingBodyMap(live,maps))
                    {
                        var prefix="CharacterSurface20260916/"+maps+"/";
                        var n=Resources.Load<Texture2D>(prefix+"normal");
                        var orm=Resources.Load<Texture2D>(prefix+"surface_orm");
                        if(n && orm) {
                            live.SetTexture("_BumpMap",n);live.SetTexture("_MetallicRoughness",orm);
                            live.SetFloat("_SurfaceNormal",1);live.SetFloat("_SurfaceMaps",3);
                        }
                    }
                }
                entry.after=new Material(live);entries.Add(entry);originalForRefined[live]=entry.before;
            }
            renderer.sharedMaterials=materials;
        }
        IsRefined=true;
    }
    static bool HasMatchingBodyMap(Material material,string family)
    {
        if(!material.HasProperty("_MainTex") || !material.GetTexture("_MainTex"))return false;
        string texture=material.GetTexture("_MainTex").name.ToLowerInvariant();
        return family=="Guard"?texture.Contains("shadow_iron")
            :family=="OldHound"?texture.Contains("emberwolf")
            :family=="Core"?texture.Contains("crimson_eyed")
            :texture.Contains("ghost");
    }
    /// Same scene, light, camera and textures for comparisons. Call outside combat;
    /// live identity tint/emission is kept so red ghost variants never revert blue.
    public void ShowRefinement(bool show)
    {
        foreach(var entry in entries)
        {
            if (!entry.live) continue;
            bool color=entry.live.HasProperty("_Color"),emission=entry.live.HasProperty("_EmissionColor");
            Color tint=color?entry.live.GetColor("_Color"):Color.white;
            Color glow=emission?entry.live.GetColor("_EmissionColor"):Color.black;
            var source=show?entry.after:entry.before;
            entry.live.shader=source.shader;entry.live.CopyPropertiesFromMaterial(source);
            if(color && entry.live.HasProperty("_Color"))entry.live.SetColor("_Color",tint);
            if(emission && entry.live.HasProperty("_EmissionColor"))entry.live.SetColor("_EmissionColor",glow);
        }
        IsRefined=show;
    }
    [Serializable] public class MaterialAudit {public string actor,family;public bool refined;public List<MaterialRow> materials=new List<MaterialRow>();}
    [Serializable] public class MaterialRow {public string renderer,material,shader,albedo,normal,metal,rough;public float mode,normalStrength;public bool boundToRenderer;public string boundShader;}
    public string AuditJSON()
    {
        var audit=new MaterialAudit {actor=name,family=CharacterFamily.ToString(),refined=IsRefined};
        foreach(var entry in entries)
        {
            var m=entry.live;if(!m)continue;
            audit.materials.Add(new MaterialRow {renderer=entry.renderer.name,material=m.name,shader=m.shader.name,boundToRenderer=entry.renderer && entry.slot<entry.renderer.sharedMaterials.Length && entry.renderer.sharedMaterials[entry.slot]==m,boundShader=entry.renderer && entry.slot<entry.renderer.sharedMaterials.Length && entry.renderer.sharedMaterials[entry.slot] ? entry.renderer.sharedMaterials[entry.slot].shader.name : "missing",
                albedo=TextureName(m,"_MainTex"),normal=TextureName(m,"_BumpMap"),metal=ActiveSurfaceMap(m,false),rough=ActiveSurfaceMap(m,true),
                mode=m.HasProperty("_SurfaceMaps")?m.GetFloat("_SurfaceMaps"):-1,normalStrength=m.HasProperty("_BumpScale")?m.GetFloat("_BumpScale"):1});
        }
        return JsonUtility.ToJson(audit,true);
    }
    static string ActiveSurfaceMap(Material m,bool rough) {
        if(!m.HasProperty("_SurfaceMaps"))return TextureName(m,rough?"_RoughMap":"_MetalMap");
        float mode=m.GetFloat("_SurfaceMaps");
        if(mode>3.5f)return rough?TextureName(m,"_MetallicRoughness"):"scalar region";
        if(mode>2.5f)return TextureName(m,"_MetallicRoughness");
        if(mode>1.5f)return TextureName(m,rough?"_SurfaceRoughMap":"_SurfaceMetalMap");
        return mode>.5f?TextureName(m,"_MetallicGlossMap"):"scalar";
    }
    static string FirstTextureName(Material material,params string[] properties) {foreach(var property in properties) {var value=TextureName(material,property);if(!string.IsNullOrEmpty(value))return value;}return "";}
    static string TextureName(Material material,string property) => material.HasProperty(property) && material.GetTexture(property) ? material.GetTexture(property).name : "";
    public void SaveAudit(string absolutePath) {Directory.CreateDirectory(Path.GetDirectoryName(absolutePath));File.WriteAllText(absolutePath,AuditJSON());}
    void OnDestroy()
    {
        installed.Remove(this);
        ShowRefinement(false);
        foreach(var entry in entries)
        {
            if(entry.live)originalForRefined.Remove(entry.live);
            if(entry.before)Destroy(entry.before);if(entry.after)Destroy(entry.after);
            if(entry.createdInstance && entry.live)
            {
                if(entry.renderer) {var current=entry.renderer.sharedMaterials; if(entry.slot<current.Length && current[entry.slot]==entry.live) {current[entry.slot]=entry.originalShared;entry.renderer.sharedMaterials=current;}}
                Destroy(entry.live);
            }
        }
        entries.Clear();
    }
}
