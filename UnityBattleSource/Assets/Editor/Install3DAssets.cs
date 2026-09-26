using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class Install3DAssets
{
    const string FoolRoot = "Assets/Models/Fool/";
    const string GuardRoot = "Assets/Models/ClockGuard/";
    const string CoreRoot = "Assets/Models/ClockCore/";
    const string HoundRoot = "Assets/Models/HellHound/Meshy_AI_Emberwolf_quadruped/";
    public const string GeneratedRoot = "Assets/Generated/";
    public const string FormationAssetPath = GeneratedRoot + "EnemyFormationProfile.asset";
    public const string GuardProfileAssetPath = GeneratedRoot + "ClockGuardVisualProfile.asset";
    public const string CoreProfileAssetPath = GeneratedRoot + "ClockCoreVisualProfile.asset";
    public const string HoundProfileAssetPath = GeneratedRoot + "HellHoundVisualProfile.asset";
    public const string GuardModelPrefabPath = GeneratedRoot + "ClockGuardModel.prefab";
    public const string CoreModelPrefabPath = GeneratedRoot + "ClockCoreModel.prefab";
    public const string HoundModelPrefabPath = GeneratedRoot + "HellHoundModel.prefab";

    [MenuItem("Mindstone/Install 3D Battle Assets")]
    public static void Install()
    {
        Directory.CreateDirectory(GeneratedRoot);
        AssetDatabase.Refresh();

        var scene = EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        DestroyInstalledEnemy("clock-guard", "ClockGuard_Imported");
        DestroyInstalledEnemy("clock-core", "ClockCore_Imported");
        DestroyInstalledEnemy("hell-hound", "HellHound_Imported");
        DestroyIfPresent("Fool_Imported");

        var foolController = BuildController(
            GeneratedRoot + "FoolBattle.controller",
            FindFile(FoolRoot, "Combat_Stance"),
            FindFile(FoolRoot, "mage_soell_cast_4"),
            FindFile(FoolRoot, "Two_Handed_Parry"),
            FindFile(FoolRoot, "Hit_Reaction"),
            FindFile(FoolRoot, "Running"),
            1f);

        var guardIdle = FindFile(GuardRoot, "Idle")
            ?? FindFile(GuardRoot, "Combat_Stance")
            ?? FindFile(GuardRoot, "Walking");
        var guardSource = guardIdle ?? FindFile(GuardRoot, "Walking");
        var guardController = BuildController(
            GeneratedRoot + "ClockGuardBattle.controller",
            guardIdle,
            // This authored take contains the guard's in-place turn and strike.
            // Keep it on the Animator unchanged; battle presentation pins the
            // actor to its formation slot instead of adding a run-in.
            FindFile(GuardRoot, "Axe_Spin_Attack"),
            FindFile(GuardRoot, "Sword_Parry_Backward_5"),
            null,
            FindFile(GuardRoot, "Running"),
            1f);

        var foolMaterial = BuildMaterial(
            GeneratedRoot + "FoolMaterial.mat",
            FoolRoot + "Meshy_AI_battle_magician_rig_biped_texture_0.png",
            FoolRoot + "Meshy_AI_battle_magician_rig_biped_texture_0_normal.png",
            FoolRoot + "Meshy_AI_battle_magician_rig_biped_texture_0_metallic.png");
        InstantiateCharacter(
            FindFile(FoolRoot, "Combat_Stance"), "Fool_Imported",
            new Vector3(0f, 0f, -4.8f), Quaternion.identity, 2.16f,
            foolController, foolMaterial);

        var guardMaterial = BuildMaterial(
            GeneratedRoot + "ClockGuardMaterial.mat",
            GuardRoot + "Meshy_AI_Shadow_Iron_Guardian__biped_texture_0.png",
            GuardRoot + "Meshy_AI_Shadow_Iron_Guardian__biped_texture_0_normal.png",
            GuardRoot + "Meshy_AI_Shadow_Iron_Guardian__biped_texture_0_metallic.png");
        var coreMaterial = BuildMaterial(
            GeneratedRoot + "ClockCoreMaterial.mat",
            CoreRoot + "Meshy_AI_Crimson_Eyed_Egg_0728100353_texture.png",
            CoreRoot + "Meshy_AI_Crimson_Eyed_Egg_0728100353_texture_normal.png",
            CoreRoot + "Meshy_AI_Crimson_Eyed_Egg_0728100353_texture_metallic.png",
            CoreRoot + "Meshy_AI_Crimson_Eyed_Egg_0728100353_texture_emit.png");
        var houndMaterial = BuildMaterial(
            GeneratedRoot + "HellHoundMaterial.mat",
            HoundRoot + "Meshy_AI_Emberwolf_quadruped_texture_0.png",
            HoundRoot + "Meshy_AI_Emberwolf_quadruped_texture_0_normal.png",
            HoundRoot + "Meshy_AI_Emberwolf_quadruped_texture_0_metallic.png");
        houndMaterial.SetFloat("_Metallic", 0.22f);
        houndMaterial.SetFloat("_Glossiness", 0.36f);
        houndMaterial.SetColor("_EmissionColor", Color.black);
        houndMaterial.DisableKeyword("_EMISSION");
        EditorUtility.SetDirty(houndMaterial);

        var houndSource = FindFile(HoundRoot, "Animation_Walking");
        var houndController = BuildGenericCombatController(
            GeneratedRoot + "HellHoundBattle.controller",
            houndSource,
            0.17f);

        var guardModelPrefab = BuildModelPrefab(
            guardSource,
            GuardModelPrefabPath,
            "ClockGuardModel",
            guardController,
            guardMaterial);
        var coreModelPrefab = BuildModelPrefab(
            FindFile(CoreRoot, "Crimson_Eyed_Egg_0728100353_texture"),
            CoreModelPrefabPath,
            "ClockCoreModel",
            null,
            coreMaterial);
        var houndModelPrefab = BuildModelPrefab(
            houndSource,
            HoundModelPrefabPath,
            "HellHoundModel",
            houndController,
            houndMaterial);

        var formation = LoadOrCreateAsset<EnemyFormationProfile>(FormationAssetPath);
        formation.Configure(2.88f, CreateDefaultFormationSlots());
        EditorUtility.SetDirty(formation);

        var guardProfile = LoadOrCreateAsset<EnemyVisualProfile>(GuardProfileAssetPath);
        guardProfile.Configure(
            "clock-guard",
            guardModelPrefab,
            guardController,
            new[] { new EnemyOrientationStep(EnemyOrientationAxis.Y, 180f) },
            1.02f,
            EnemyFormationSlotIds.FrontCenter,
            Vector3.zero,
            new EnemyHoverConfiguration(false, 0f, 4.2f),
            new EnemyAnchorConfiguration(
                new Vector3(0f, 1.42f, 0f),
                new Vector3(0f, 0.04f, 0f),
                new Vector3(0f, 3.08f, 0f),
                new Vector3(0f, 2.45f, 0f),
                new Vector3(0f, 1.42f, 0f)));
        EditorUtility.SetDirty(guardProfile);

        var coreProfile = LoadOrCreateAsset<EnemyVisualProfile>(CoreProfileAssetPath);
        coreProfile.Configure(
            "clock-core",
            coreModelPrefab,
            null,
            new[]
            {
                new EnemyOrientationStep(EnemyOrientationAxis.X, -15f),
                new EnemyOrientationStep(EnemyOrientationAxis.Y, 90f),
                new EnemyOrientationStep(EnemyOrientationAxis.Z, 90f),
                new EnemyOrientationStep(EnemyOrientationAxis.Y, 90f)
            },
            0.5865f,
            EnemyFormationSlotIds.AirRearLeft,
            Vector3.zero,
            new EnemyHoverConfiguration(true, 0.055f, 4.2f),
            new EnemyAnchorConfiguration(
                new Vector3(0f, 0.72f, 0f),
                Vector3.zero,
                new Vector3(0f, 1.66f, 0f),
                new Vector3(0f, 1.3f, 0f),
                new Vector3(0f, 0.72f, 0f)));
        EditorUtility.SetDirty(coreProfile);

        var houndProfile = LoadOrCreateAsset<EnemyVisualProfile>(HoundProfileAssetPath);
        houndProfile.Configure(
            "hell-hound",
            houndModelPrefab,
            houndController,
            new[] { new EnemyOrientationStep(EnemyOrientationAxis.Y, 180f) },
            1.04f,
            EnemyFormationSlotIds.FrontCenter,
            Vector3.zero,
            new EnemyHoverConfiguration(false, 0f, 4.2f),
            new EnemyAnchorConfiguration(
                new Vector3(0f, 0.92f, 0f),
                new Vector3(0f, 0.02f, 0f),
                new Vector3(0f, 2.42f, 0f),
                new Vector3(0f, 1.86f, 0f),
                new Vector3(0f, 0.78f, 0f)));
        EditorUtility.SetDirty(houndProfile);

        var guardHandle = EnemyPresenter.Present(new EnemyPresentationRequest
        {
            Profile = guardProfile,
            Formation = formation,
            SlotId = EnemyFormationSlotIds.FrontCenter,
            BattleEnemyId = EnemyBattleIds.ClockGuardPrimary,
            EnableMotion = false
        });
        guardHandle.EnemyRoot.name = "ClockGuard_Imported";
        AssignMaterial(guardHandle.Model.gameObject, guardMaterial);

        var coreHandle = EnemyPresenter.Present(new EnemyPresentationRequest
        {
            Profile = coreProfile,
            Formation = formation,
            SlotId = EnemyFormationSlotIds.AirRearLeft,
            BattleEnemyId = EnemyBattleIds.ClockCorePrimary,
            EnableMotion = true
        });
        coreHandle.EnemyRoot.name = "ClockCore_Imported";
        AssignMaterial(coreHandle.Model.gameObject, coreMaterial);
        coreHandle.EnemyRoot.gameObject.SetActive(false);

        var houndHandle = EnemyPresenter.Present(new EnemyPresentationRequest
        {
            Profile = houndProfile,
            Formation = formation,
            SlotId = EnemyFormationSlotIds.FrontCenter,
            BattleEnemyId = EnemyBattleIds.HellHoundPrimary,
            EnableMotion = false
        });
        houndHandle.EnemyRoot.name = "HellHound_Imported";
        AssignMaterial(houndHandle.Model.gameObject, houndMaterial);
        houndHandle.EnemyRoot.gameObject.SetActive(false);

        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
        AssetDatabase.SaveAssets();
        Selection.activeGameObject = guardHandle.EnemyRoot.gameObject;
        Debug.Log("Mindstone: installed profile-driven Clock Guard/Core/Hell Hound hierarchy and Meshy combat assets.");
    }

    static List<EnemyFormationSlot> CreateDefaultFormationSlots()
    {
        return EnemyFormationLayout.CreateClockPlazaSlots();
    }

    static T LoadOrCreateAsset<T>(string path) where T : ScriptableObject
    {
        var asset = AssetDatabase.LoadAssetAtPath<T>(path);
        if (asset != null) return asset;
        asset = ScriptableObject.CreateInstance<T>();
        AssetDatabase.CreateAsset(asset, path);
        return asset;
    }

    static GameObject BuildModelPrefab(
        string modelPath,
        string outputPath,
        string modelName,
        RuntimeAnimatorController controller,
        Material material)
    {
        var source = AssetDatabase.LoadAssetAtPath<GameObject>(modelPath);
        if (source == null) throw new FileNotFoundException("Could not load FBX", modelPath);

        var instance = (GameObject)PrefabUtility.InstantiatePrefab(source);
        instance.name = modelName;
        instance.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
        instance.transform.localScale = Vector3.one;
        AssignMaterial(instance, material);

        var animator = instance.GetComponentInChildren<Animator>(true);
        if (controller != null)
        {
            if (animator == null) animator = instance.AddComponent<Animator>();
            animator.runtimeAnimatorController = controller;
            animator.applyRootMotion = false;
            animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        }

        var prefab = PrefabUtility.SaveAsPrefabAsset(instance, outputPath);
        Object.DestroyImmediate(instance);
        if (prefab == null) throw new IOException($"Could not create model prefab at {outputPath}.");
        return prefab;
    }

    static void AssignMaterial(GameObject root, Material material)
    {
        var renderers = root.GetComponentsInChildren<Renderer>(true);
        for (var rendererIndex = 0; rendererIndex < renderers.Length; rendererIndex++)
        {
            var renderer = renderers[rendererIndex];
            var materials = new Material[renderer.sharedMaterials.Length];
            for (var materialIndex = 0; materialIndex < materials.Length; materialIndex++)
                materials[materialIndex] = material;
            renderer.sharedMaterials = materials;
            EditorUtility.SetDirty(renderer);
            if (PrefabUtility.IsPartOfPrefabInstance(renderer))
                PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
        }
    }

    static string FindFile(string folder, string contains)
    {
        var guid = AssetDatabase.FindAssets("t:Model", new[] { folder })
            .FirstOrDefault(id => AssetDatabase.GUIDToAssetPath(id).Contains(contains));
        return string.IsNullOrEmpty(guid) ? null : AssetDatabase.GUIDToAssetPath(guid);
    }

    static AnimatorController BuildController(
        string path,
        string idlePath,
        string attackPath,
        string blockPath,
        string hitPath,
        string runPath,
        float idleSpeed)
    {
        if (string.IsNullOrEmpty(idlePath) || string.IsNullOrEmpty(attackPath) || string.IsNullOrEmpty(blockPath))
            throw new FileNotFoundException($"Missing Meshy animation. Idle={idlePath}, Attack={attackPath}, Block={blockPath}");

        ConfigureClip(idlePath, true);
        ConfigureClip(attackPath, false);
        ConfigureClip(blockPath, false);
        ConfigureClip(hitPath, false);
        ConfigureClip(runPath, true);

        AssetDatabase.DeleteAsset(path);
        var controller = AnimatorController.CreateAnimatorControllerAtPath(path);
        controller.AddParameter("Attack", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Block", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Hit", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Running", AnimatorControllerParameterType.Bool);

        var machine = controller.layers[0].stateMachine;
        var idle = machine.AddState("Meshy · Idle");
        var attack = machine.AddState("Meshy · Attack");
        var block = machine.AddState("Meshy · Block");
        var hit = string.IsNullOrEmpty(hitPath) ? null : machine.AddState("Meshy · Hit Reaction");
        var run = string.IsNullOrEmpty(runPath) ? null : machine.AddState("Meshy · Run");
        idle.motion = FindClip(idlePath);
        attack.motion = FindClip(attackPath);
        block.motion = FindClip(blockPath);
        idle.speed = idleSpeed;
        idle.iKOnFeet = true;
        attack.iKOnFeet = true;
        block.iKOnFeet = true;
        if (hit != null) hit.motion = FindClip(hitPath);
        if (run != null) run.motion = FindClip(runPath);
        if (hit != null) hit.iKOnFeet = true;
        if (run != null) run.iKOnFeet = true;
        machine.defaultState = idle;

        AddTriggeredTransition(machine, attack, "Attack");
        AddTriggeredTransition(machine, block, "Block");
        if (hit != null) AddTriggeredTransition(machine, hit, "Hit");
        if (run != null)
        {
            var startRunning = idle.AddTransition(run);
            startRunning.hasExitTime = false;
            startRunning.duration = 0.08f;
            startRunning.AddCondition(AnimatorConditionMode.If, 0f, "Running");

            var stopRunning = run.AddTransition(idle);
            stopRunning.hasExitTime = false;
            stopRunning.duration = 0.1f;
            stopRunning.AddCondition(AnimatorConditionMode.IfNot, 0f, "Running");
        }
        AddReturnTransition(attack, idle);
        AddReturnTransition(block, idle);
        if (hit != null) AddReturnTransition(hit, idle);
        return controller;
    }

    // The Emberwolf is a quadruped. Its only supplied clip is a walk cycle, so
    // use a Generic controller rather than trying to retarget it as humanoid.
    // The familiar trigger surface is retained because BattlePrototype treats
    // all enemy controllers uniformly during hit and turn presentation.
    static AnimatorController BuildGenericCombatController(
        string path,
        string movementPath,
        float idleSpeed)
    {
        if (string.IsNullOrEmpty(movementPath))
            throw new FileNotFoundException("Missing quadruped movement animation.", movementPath);

        ConfigureGenericClip(movementPath, true);
        var movement = FindClip(movementPath);
        if (movement == null)
            throw new FileNotFoundException("Could not resolve quadruped animation clip.", movementPath);

        AssetDatabase.DeleteAsset(path);
        var controller = AnimatorController.CreateAnimatorControllerAtPath(path);
        controller.AddParameter("Attack", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Block", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Hit", AnimatorControllerParameterType.Trigger);
        controller.AddParameter("Running", AnimatorControllerParameterType.Bool);

        var machine = controller.layers[0].stateMachine;
        var idle = machine.AddState("Meshy · Idle");
        var attack = machine.AddState("Meshy · Attack");
        var block = machine.AddState("Meshy · Block");
        var hit = machine.AddState("Meshy · Hit Reaction");
        var run = machine.AddState("Meshy · Run");
        idle.motion = movement;
        attack.motion = movement;
        block.motion = movement;
        hit.motion = movement;
        run.motion = movement;
        idle.speed = path.EndsWith("HellHoundBattle.controller", System.StringComparison.Ordinal) ? .48f : idleSpeed;
        attack.speed = 0.34f;
        block.speed = 0.24f;
        hit.speed = 1f;
        run.speed = 0.42f;
        machine.defaultState = idle;

        AddTriggeredTransition(machine, attack, "Attack");
        AddTriggeredTransition(machine, block, "Block");
        AddTriggeredTransition(machine, hit, "Hit");
        var startRunning = idle.AddTransition(run);
        startRunning.hasExitTime = false;
        startRunning.duration = 0.08f;
        startRunning.AddCondition(AnimatorConditionMode.If, 0f, "Running");
        var stopRunning = run.AddTransition(idle);
        stopRunning.hasExitTime = false;
        stopRunning.duration = 0.10f;
        stopRunning.AddCondition(AnimatorConditionMode.IfNot, 0f, "Running");
        AddReturnTransition(attack, idle);
        AddReturnTransition(block, idle);
        // The quadruped fallback is a walking clip, not a dedicated recoil.
        // Brief reaction only; do not leave the stationary hound stepping for seconds.
        var recover = hit.AddTransition(idle);
        recover.hasExitTime = true;
        recover.exitTime = .35f / Mathf.Max(.01f, movement.length);
        recover.hasFixedDuration = true;
        recover.duration = .12f;
        return controller;
    }

    static AnimationClip FindClip(string path)
    {
        return AssetDatabase.LoadAllAssetsAtPath(path)
            .OfType<AnimationClip>()
            .FirstOrDefault(clip => !clip.name.StartsWith("__preview__"));
    }

    static void AddTriggeredTransition(AnimatorStateMachine machine, AnimatorState to, string trigger)
    {
        var transition = machine.AddAnyStateTransition(to);
        transition.hasExitTime = false;
        transition.duration = 0.04f;
        transition.canTransitionToSelf = false;
        transition.AddCondition(AnimatorConditionMode.If, 0f, trigger);
    }

    static void AddReturnTransition(AnimatorState from, AnimatorState idle)
    {
        var transition = from.AddTransition(idle);
        transition.hasExitTime = true;
        transition.exitTime = 0.95f;
        transition.duration = 0.12f;
    }

    static void ConfigureClip(string path, bool loop)
    {
        if (string.IsNullOrEmpty(path)) return;
        var importer = AssetImporter.GetAtPath(path) as ModelImporter;
        if (importer == null) return;

        importer.animationType = ModelImporterAnimationType.Human;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        var clips = importer.defaultClipAnimations;
        if (clips.Length == 0) return;
        foreach (var clip in clips)
        {
            clip.loopTime = loop;
            clip.loopPose = loop;
            clip.keepOriginalPositionY = false;
            clip.keepOriginalPositionXZ = false;
            clip.keepOriginalOrientation = false;
            clip.lockRootHeightY = true;
            clip.lockRootPositionXZ = true;
            clip.lockRootRotation = true;
            clip.heightFromFeet = true;
        }
        importer.clipAnimations = clips;
        importer.SaveAndReimport();
    }

    static void ConfigureGenericClip(string path, bool loop)
    {
        if (string.IsNullOrEmpty(path)) return;
        var importer = AssetImporter.GetAtPath(path) as ModelImporter;
        if (importer == null) return;

        importer.animationType = ModelImporterAnimationType.Generic;
        importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
        var clips = importer.defaultClipAnimations;
        if (clips.Length == 0) return;
        foreach (var clip in clips)
        {
            clip.loopTime = loop;
            clip.loopPose = loop;
            clip.keepOriginalPositionY = false;
            clip.keepOriginalPositionXZ = false;
            clip.keepOriginalOrientation = false;
            clip.lockRootHeightY = true;
            clip.lockRootPositionXZ = true;
            clip.lockRootRotation = true;
        }
        importer.clipAnimations = clips;
        importer.SaveAndReimport();
    }

    static Material BuildMaterial(string outputPath, string albedoPath, string normalPath, string metallicPath, string emissionPath = null)
    {
        AssetDatabase.DeleteAsset(outputPath);
        var shader = Shader.Find("Standard");
        var material = new Material(shader) { name = Path.GetFileNameWithoutExtension(outputPath) };
        material.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(albedoPath);
        material.SetFloat("_Metallic", 0.35f);
        material.SetFloat("_Glossiness", 0.5f);

        var normal = AssetDatabase.LoadAssetAtPath<Texture2D>(normalPath);
        if (normal)
        {
            material.SetTexture("_BumpMap", normal);
            material.EnableKeyword("_NORMALMAP");
        }

        var metallic = AssetDatabase.LoadAssetAtPath<Texture2D>(metallicPath);
        if (metallic)
        {
            material.SetTexture("_MetallicGlossMap", metallic);
            material.EnableKeyword("_METALLICGLOSSMAP");
        }

        var emission = string.IsNullOrEmpty(emissionPath) ? null : AssetDatabase.LoadAssetAtPath<Texture2D>(emissionPath);
        if (emission)
        {
            material.SetTexture("_EmissionMap", emission);
            material.SetColor("_EmissionColor", new Color(1f, 0.08f, 0.04f, 1f) * 1.8f);
            material.EnableKeyword("_EMISSION");
        }

        AssetDatabase.CreateAsset(material, outputPath);
        return material;
    }

    static GameObject InstantiateCharacter(
        string modelPath,
        string name,
        Vector3 groundPosition,
        Quaternion rotation,
        float targetHeight,
        RuntimeAnimatorController controller,
        Material material)
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(modelPath);
        if (!prefab) throw new FileNotFoundException("Could not load FBX", modelPath);

        var character = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        character.name = name;
        character.transform.SetPositionAndRotation(Vector3.zero, rotation);
        character.transform.localScale = Vector3.one;
        AssignMaterial(character, material);

        var bounds = CalculateBounds(character);
        if (bounds.size.y > 0.001f)
            character.transform.localScale = Vector3.one * (targetHeight / bounds.size.y);

        bounds = CalculateBounds(character);
        character.transform.position = groundPosition + Vector3.up * (groundPosition.y - bounds.min.y);

        var animator = character.GetComponentInChildren<Animator>(true);
        if (!animator) animator = character.AddComponent<Animator>();
        animator.runtimeAnimatorController = controller;
        animator.applyRootMotion = false;
        animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
        return character;
    }

    [MenuItem("Mindstone/Restore Original Fool")]
    public static void RestoreOriginalFool()
    {
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/BattlePrototype.unity");
        DestroyIfPresent("Fool_Imported");
        var controller = BuildController(GeneratedRoot + "FoolBattle.controller",
            FindFile(FoolRoot, "Combat_Stance"), FindFile(FoolRoot, "mage_soell_cast_4"),
            FindFile(FoolRoot, "Two_Handed_Parry"), FindFile(FoolRoot, "Hit_Reaction"),
            FindFile(FoolRoot, "Running"), 1f);
        InstantiateCharacter(FindFile(FoolRoot, "Combat_Stance"), "Fool_Imported",
            new Vector3(0, 0, -4.8f), Quaternion.identity, 2.16f, controller,
            AssetDatabase.LoadAssetAtPath<Material>(GeneratedRoot + "FoolMaterial.mat"));
        EditorSceneManager.SaveScene(scene);
        AssetDatabase.SaveAssets();
    }

    static Bounds CalculateBounds(GameObject root)
    {
        var renderers = root.GetComponentsInChildren<Renderer>(true);
        if (renderers.Length == 0) return new Bounds(root.transform.position, Vector3.one);
        var bounds = renderers[0].bounds;
        for (var i = 1; i < renderers.Length; i++) bounds.Encapsulate(renderers[i].bounds);
        return bounds;
    }

    static void DestroyInstalledEnemy(string profileEnemyId, string legacyName)
    {
        var handles = Object.FindObjectsByType<EnemyHandle>(FindObjectsInactive.Include, FindObjectsSortMode.None);
        for (var i = 0; i < handles.Length; i++)
        {
            if (handles[i].ProfileEnemyId == profileEnemyId)
                Object.DestroyImmediate(handles[i].EnemyRoot.gameObject);
        }
        DestroyIfPresent(legacyName);
    }

    static void DestroyIfPresent(string name)
    {
        var candidates = Resources.FindObjectsOfTypeAll<GameObject>();
        for (var i = 0; i < candidates.Length; i++)
        {
            var candidate = candidates[i];
            if (candidate.name != name || EditorUtility.IsPersistent(candidate)) continue;
            if (!candidate.scene.IsValid()) continue;
            Object.DestroyImmediate(candidate);
        }
    }
}
