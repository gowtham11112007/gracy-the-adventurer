using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// What the game is showing: the title screen, the world map, or a level (and which); the levels finished
/// (PlayerPrefs "done_level1"... 1 when finished, "gems_level1"... the most gems found there); and the player's
/// settings, music and sound on or off (PlayerPrefs "music" and "sound": 1 on, 0 off).
/// Moving between screens reloads the one scene with the right flag set.
/// </summary>
public static class Flow
{
    public enum Screen { Title, Map, Level }
    public static Screen Showing = Screen.Title;
    public static bool Playing => Showing == Screen.Level;
    public static string LevelId = "level1";

    public static bool Done(string id) => PlayerPrefs.GetInt("done_" + id, 0) == 1;

    /// <summary>A level finished: remembered, with the most gems found there.</summary>
    public static void Finish(string id, int gems)
    {
        PlayerPrefs.SetInt("done_" + id, 1);
        PlayerPrefs.SetInt("gems_" + id, Mathf.Max(gems, PlayerPrefs.GetInt("gems_" + id, 0)));
        PlayerPrefs.Save();
    }

    /// <summary>
    /// Every start begins fresh: the title screen, nothing held, no old pictures or menus remembered. (The Unity
    /// editor is set to keep the game's memory between Play presses, to start faster; a phone always starts fresh.)
    /// </summary>
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void FreshStart()
    {
        Showing = Screen.Title;
        music.Clear();
        sounds.Clear();
        GameInput.Fresh();
        Art.Fresh();
        Village.Fresh();
        Shapes.Fresh();
        Icons.Fresh();
        MenuUI.Fresh();
        LevelUI.Fresh();
    }

    static readonly List<AudioSource> music = new(), sounds = new();

    public static bool MusicOn
    {
        get => PlayerPrefs.GetInt("music", 1) == 1;
        set { PlayerPrefs.SetInt("music", value ? 1 : 0); PlayerPrefs.Save(); Apply(); }
    }

    public static bool SoundOn
    {
        get => PlayerPrefs.GetInt("sound", 1) == 1;
        set { PlayerPrefs.SetInt("sound", value ? 1 : 0); PlayerPrefs.Save(); Apply(); }
    }

    /// <summary>This source plays music (the Music switch turns it on and off).</summary>
    public static void Music(AudioSource a) { music.Add(a); Apply(); }

    /// <summary>This source plays sounds: birds, wind, footsteps, clicks (the Sound switch).</summary>
    public static void Sound(AudioSource a) { sounds.Add(a); Apply(); }

    static void Apply()
    {
        music.RemoveAll(a => a == null);
        sounds.RemoveAll(a => a == null);
        foreach (var a in music) a.mute = !MusicOn;
        foreach (var a in sounds) a.mute = !SoundOn;
    }

    public static void Play(string id)
    {
        LevelId = id;
        Showing = Screen.Level;
        Reload();
    }

    public static void ToMap()
    {
        Showing = Screen.Map;
        Reload();
    }

    public static void ToTitle()
    {
        Showing = Screen.Title;
        Reload();
    }

    public static void Restart() => Reload();

    static void Reload()
    {
        Time.timeScale = 1;
        GameInput.Clear();
        SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
    }
}
