using UnityEditor;
using UnityEditor.Build.Reporting;

public static class BuildDefeatPreview
{
    public static void Build()
    {
        var options = new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/BattlePrototype.unity" },
            locationPathName = "/private/tmp/MindstoneDefeatPreview.app",
            target = BuildTarget.StandaloneOSX,
            targetGroup = BuildTargetGroup.Standalone,
            options = BuildOptions.None
        };
        var report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded)
            throw new System.Exception($"Defeat preview build failed: {report.summary.result}");
    }
}
