using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

/// <summary>
/// Project settings for the phone game, and a phone build, runnable from the command line:
///   Unity -batchmode -quit -projectPath unity -executeMethod ProjectSetup.Apply
///   Unity -batchmode -quit -projectPath unity -executeMethod ProjectSetup.BuildAndroid   (-> Builds/Gracy-Unity.apk)
/// </summary>
public static class ProjectSetup
{
    const string AppId = "com.jananijanika.gracy.unity"; // (the Godot app is ...gracy.godot: both fit on one phone)

    /// <summary>Name, app id, landscape only, 64-bit phones, and Android as the build target.</summary>
    public static void Apply()
    {
        PlayerSettings.companyName = "Janani & Janika";
        PlayerSettings.productName = "Gracy";
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, AppId);
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Standalone, AppId);

        // landscape only, either way round
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
        PlayerSettings.allowedAutorotateToPortrait = false;
        PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
        PlayerSettings.allowedAutorotateToLandscapeLeft = true;
        PlayerSettings.allowedAutorotateToLandscapeRight = true;

        // today's phones: 64-bit, IL2CPP
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;

        if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android)
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
        AssetDatabase.SaveAssets();
        Debug.Log("ProjectSetup: settings applied (" + AppId + ", landscape, ARM64, Android)");
    }

    /// <summary>Builds the scenes in the build list into Builds/Gracy-Unity.apk. Exits with 1 if it fails.</summary>
    public static void BuildAndroid()
    {
        Apply();
        var scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
        if (scenes.Length == 0)
            scenes = new[] { "Assets/Scenes/SampleScene.unity" };
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = scenes,
            locationPathName = "Builds/Gracy-Unity.apk",
            target = BuildTarget.Android,
            options = BuildOptions.None,
        });
        var summary = report.summary;
        Debug.Log($"ProjectSetup: build {summary.result}, {summary.totalSize / 1_000_000f:0.0} MB, {summary.totalTime}");
        if (summary.result != BuildResult.Succeeded)
            EditorApplication.Exit(1);
    }
}
