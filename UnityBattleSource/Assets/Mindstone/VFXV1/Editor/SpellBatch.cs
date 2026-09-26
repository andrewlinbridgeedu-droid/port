#if UNITY_EDITOR

using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Mindstone.VFXV1
{
    public static class SpellBatch
    {
        [Serializable]
        sealed class ValidationReport
        {
            public int schema = 1;
            public bool ok;
            public string spell;
            public int registryCount;
            public string[] errors;
            public string unityVersion;
            public bool runtimeSelfTest;
        }

        public static void Validate()
        {
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            SpellRegistry.Reload();
            var spell = ReadArgument("-vfxSpell");
            var output = ReadArgument("-vfxReport");
            var errors = new List<string>(SpellRegistry.Validate(spell));
            var runtimeSelfTest = RunRuntimeSelfTest(errors);
            var report = new ValidationReport
            {
                ok = errors.Count == 0,
                spell = string.IsNullOrWhiteSpace(spell) ? "all" : spell,
                registryCount = SpellRegistry.All.Count,
                errors = errors.ToArray(),
                unityVersion = Application.unityVersion,
                runtimeSelfTest = runtimeSelfTest
            };
            if (!string.IsNullOrWhiteSpace(output))
            {
                var directory = Path.GetDirectoryName(output);
                if (!string.IsNullOrWhiteSpace(directory))
                    Directory.CreateDirectory(directory);
                File.WriteAllText(output, JsonUtility.ToJson(report, true) + Environment.NewLine);
            }
            if (errors.Count > 0)
                throw new InvalidOperationException("VFX V1 validation failed:\n" + string.Join("\n", errors));
            Debug.Log($"[VFX V1] Validated {report.registryCount} registered spell(s); runtime self-test passed.");
        }

        static bool RunRuntimeSelfTest(List<string> errors)
        {
            if (!SpellRegistry.TryGet("v1-system-projectile", out var systemSpec))
            {
                errors.Add("Missing VFX V1 system fixture: v1-system-projectile");
                return false;
            }
            if (systemSpec.capture?.times == null || systemSpec.capture.times.Length != 5)
            {
                errors.Add("VFX V1 system fixture must expose exactly five capture times");
                return false;
            }

            var host = new GameObject("VFX V1 Batch Self-Test");
            try
            {
                var runtime = host.AddComponent<SpellRuntime>();
                runtime.AutoAdvance = false;
                var context = new SpellContext
                {
                    source = () => Vector3.zero,
                    target = () => Vector3.forward * 2f,
                    impact = () => Vector3.forward * 2f,
                    ground = () => Vector3.forward * 2f,
                    seed = 42
                };
                var handle = runtime.Play(systemSpec.id, context);
                if (!handle.IsValid || runtime.ActiveCount != 1)
                {
                    errors.Add("VFX V1 runtime could not start the system fixture");
                    return false;
                }
                runtime.Interrupt(handle);
                if (runtime.ActiveCount != 0)
                {
                    errors.Add("VFX V1 runtime left an active spell after interrupt");
                    return false;
                }
                if (host.transform.childCount != 0)
                {
                    errors.Add("VFX V1 runtime left a root object after interrupt");
                    return false;
                }
                return true;
            }
            catch (Exception exception)
            {
                errors.Add("VFX V1 runtime self-test failed: " + exception.Message);
                return false;
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(host);
            }
        }

        static string ReadArgument(string name)
        {
            var arguments = Environment.GetCommandLineArgs();
            for (var index = 0; index < arguments.Length - 1; index++)
                if (arguments[index] == name)
                    return arguments[index + 1];
            return null;
        }
    }
}

#endif
