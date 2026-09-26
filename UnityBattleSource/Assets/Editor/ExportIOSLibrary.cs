using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class ExportIOSLibrary
{
    const string ExportManifestName = ".mistport-unity-export-manifest";
    const string ExportVersionName = ".mistport-unity-export-version";
    const string ExportVersion = "3";
    const string ScenePath = "Assets/Scenes/BattlePrototype.unity";
    const string EffekseerSimulatorLibrary =
        "BuildSupport/Effekseer/iOSSimulatorARM64/libEffekseerUnity.a";
    const string ExportedEffekseerLibrary =
        "Libraries/Effekseer/Plugins/iOS/libEffekseerUnity.a";
    const string DefaultOutput =
        "/Users/andrewlin/Downloads/DEV_Projects/mindstone-game/mistport-ios/UnityBuild";

    [MenuItem("Mindstone/Export iOS Library")]
    public static void Export()
    {
        var output = Environment.GetEnvironmentVariable("MISTPORT_UNITY_IOS_OUTPUT");
        if (string.IsNullOrWhiteSpace(output))
            output = DefaultOutput;

        // Build into an isolated directory. Reusing UnityBuild can leave a
        // new global-metadata.dat next to an older GameAssembly export when
        // Unity's incremental iOS pipeline skips one generated artifact.
        // That combination passes a source freshness check but crashes on a
        // real device inside MetadataCache.cpp. Replace the complete export
        // only after every generated artifact and the manifest are complete.
        var stagingOutput = output + ".exporting";
        if (Directory.Exists(stagingOutput))
            Directory.Delete(stagingOutput, true);
        Directory.CreateDirectory(stagingOutput);

        EditorUserBuildSettings.SwitchActiveBuildTarget(
            BuildTargetGroup.iOS,
            BuildTarget.iOS);

        PlayerSettings.SetApplicationIdentifier(
            NamedBuildTarget.iOS,
            "com.mistport.unitybattle");
        PlayerSettings.iOS.targetDevice = iOSTargetDevice.iPhoneAndiPad;
        var simulator = string.Equals(
            Environment.GetEnvironmentVariable("MISTPORT_UNITY_IOS_SIMULATOR"),
            "1",
            StringComparison.Ordinal);
        PlayerSettings.iOS.sdkVersion = simulator
            ? iOSSdkVersion.SimulatorSDK
            : iOSSdkVersion.DeviceSDK;
        if (simulator)
        {
            // Apple Silicon simulators require an arm64 player. Effekseer's
            // bundled fat archive cannot contain both its arm64 device slice
            // and an arm64 Simulator slice, so the matching archive is
            // installed into the isolated export after Unity finishes.
            PlayerSettings.iOS.simulatorSdkArchitecture =
                AppleMobileArchitectureSimulator.ARM64;
        }
        else
        {
            PlayerSettings.SetArchitecture(NamedBuildTarget.iOS, 1);
        }

        var options = new BuildPlayerOptions
        {
            scenes = new[] { ScenePath },
            locationPathName = stagingOutput,
            target = BuildTarget.iOS,
            targetGroup = BuildTargetGroup.iOS,
            options = BuildOptions.None
        };

        BuildReport report;
        try
        {
            report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
                throw new BuildFailedException(
                    $"Mindstone iOS export failed: {report.summary.result}");

            if (simulator)
                InstallSimulatorNativePlugins(stagingOutput);

            WriteExportManifest(stagingOutput);
            File.WriteAllText(
                Path.Combine(stagingOutput, ExportVersionName),
                ExportVersion + Environment.NewLine);
            ReplaceExportDirectory(stagingOutput, output);
        }
        catch
        {
            if (Directory.Exists(stagingOutput))
                Directory.Delete(stagingOutput, true);
            throw;
        }

        Debug.Log(
            $"Mindstone: exported UnityFramework project to {output} " +
            $"({report.summary.totalSize} bytes).");
    }

    static void InstallSimulatorNativePlugins(string output)
    {
        var projectRoot = Directory.GetParent(Application.dataPath).FullName;
        var source = Path.Combine(projectRoot, EffekseerSimulatorLibrary);
        var destination = Path.Combine(output, ExportedEffekseerLibrary);
        if (!File.Exists(source))
            throw new BuildFailedException(
                $"Missing ARM64 Simulator Effekseer library: {source}");
        if (!File.Exists(destination))
            throw new BuildFailedException(
                $"Unity export did not contain the expected Effekseer library: {destination}");

        File.Copy(source, destination, true);
    }

    static void ReplaceExportDirectory(string stagingOutput, string output)
    {
        var backupOutput = output + ".previous";
        if (Directory.Exists(backupOutput))
            Directory.Delete(backupOutput, true);

        var hadPreviousOutput = Directory.Exists(output);
        try
        {
            if (hadPreviousOutput)
                Directory.Move(output, backupOutput);

            Directory.Move(stagingOutput, output);

            if (hadPreviousOutput && Directory.Exists(backupOutput))
                Directory.Delete(backupOutput, true);
        }
        catch
        {
            if (!Directory.Exists(output)
                && hadPreviousOutput
                && Directory.Exists(backupOutput))
            {
                Directory.Move(backupOutput, output);
            }

            throw;
        }
    }

    static void WriteExportManifest(string output)
    {
        var projectRoot = Directory.GetParent(Application.dataPath).FullName;
        var roots = new[]
        {
            Path.Combine(projectRoot, "Assets", "Scripts"),
            Path.Combine(projectRoot, "Assets", "Mindstone"),
            Path.Combine(projectRoot, "Assets", "Resources"),
            Path.Combine(projectRoot, "Assets", "Scenes"),
            Path.Combine(projectRoot, "BuildSupport")
        };

        using var sha256 = SHA256.Create();
        var entries = new List<string>();
        foreach (var root in roots.Where(Directory.Exists))
        foreach (var file in Directory.GetFiles(root, "*", SearchOption.AllDirectories)
                     .Where(path => !path.EndsWith(".meta", StringComparison.OrdinalIgnoreCase))
                     .OrderBy(path => path, StringComparer.Ordinal))
        {
            var bytes = File.ReadAllBytes(file);
            var hash = BitConverter.ToString(sha256.ComputeHash(bytes))
                .Replace("-", string.Empty)
                .ToLowerInvariant();
            var relative = Path.GetRelativePath(projectRoot, file).Replace('\\', '/');
            entries.Add($"{hash}  {relative}");
        }

        File.WriteAllLines(
            Path.Combine(output, ExportManifestName),
            entries);
    }
}
