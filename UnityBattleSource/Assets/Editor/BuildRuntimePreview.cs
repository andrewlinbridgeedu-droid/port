using System;
using UnityEditor;
using UnityEditor.Build.Reporting;

public static class BuildRuntimePreview
{
    [MenuItem("Mindstone/VFX V1/Build Frost Tornado Preview")]
    public static void BuildFrostTornadoPreview()
    {
        BuildMacPlayerAt(
            "/private/tmp/mindstone-vfx-v1-preview.app",
            "storm-frost-tornado-v1");
    }

    public static void BuildMacPlayer()
    {
        var output = ReadArgument("-previewPlayerOutput");
        var previewEffect = ReadArgument("-previewEffect");
        if (string.IsNullOrWhiteSpace(output))
            throw new ArgumentException("Missing -previewPlayerOutput.");

        BuildMacPlayerAt(output, previewEffect);
    }

    static void BuildMacPlayerAt(string output, string previewEffect)
    {

        var options = new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/BattlePrototype.unity" },
            locationPathName = output,
            target = BuildTarget.StandaloneOSX,
            options = BuildOptions.None
        };
        if (string.Equals(previewEffect, "wildwarden", StringComparison.OrdinalIgnoreCase))
            options.extraScriptingDefines = new[] { "MISTPORT_AUTO_VFX_BOARD_WILDWARDEN" };
        var group = BuildTargetGroup.Standalone;
        var previousBackend = PlayerSettings.GetScriptingBackend(group);
        var previousProductName = PlayerSettings.productName;
        try
        {
            // The preview is local-only; Mono is already installed while the
            // optional macOS IL2CPP module is not. iOS remains untouched.
            PlayerSettings.SetScriptingBackend(group, ScriptingImplementation.Mono2x);
            if (!string.IsNullOrWhiteSpace(previewEffect))
                PlayerSettings.productName = $"Mindstone VFX Preview - {previewEffect}";
            var report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
                throw new InvalidOperationException($"Preview player build failed: {report.summary.result}");
        }
        finally
        {
            PlayerSettings.productName = previousProductName;
            PlayerSettings.SetScriptingBackend(group, previousBackend);
        }
    }

    static string ReadArgument(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (var i = 0; i < args.Length - 1; i++)
            if (args[i] == name) return args[i + 1];
        return null;
    }
}
