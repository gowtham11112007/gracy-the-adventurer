using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// What the game is doing: the title screen (over a quiet view of Level 1) or playing; and the player's settings,
/// music and sound on or off (kept between games in PlayerPrefs "music" and "sound": 1 on, 0 off).
/// Starting, restarting and going back to the title reload the one scene with the right flag set.
/// </summary>
public static class Flow
{
    public static bool Playing;

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

    public static void Play()
    {
        Playing = true;
        Reload();
    }

    public static void ToTitle()
    {
        Playing = false;
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
