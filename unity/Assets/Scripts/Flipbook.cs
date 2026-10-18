using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Frame-by-frame animations on a SpriteRenderer: Add() clips cut from strips, then Play("run").
/// A looping clip repeats; the others hold their last frame. Speed slows or pauses it (0 = paused).
/// </summary>
public class Flipbook : MonoBehaviour
{
    class Clip
    {
        public Sprite[] frames;
        public float fps;
        public bool loop;
    }

    public SpriteRenderer Renderer { get; private set; }
    public string Current { get; private set; } = "";
    public float Speed = 1f;

    readonly Dictionary<string, Clip> clips = new();
    Clip clip;
    float time;
    int frame;

    void Awake()
    {
        Renderer = GetComponent<SpriteRenderer>();
        if (Renderer == null)
            Renderer = gameObject.AddComponent<SpriteRenderer>();
    }

    public void Add(string name, Sprite[] frames, float fps, bool loop)
    {
        if (frames.Length > 0)
            clips[name] = new Clip { frames = frames, fps = fps, loop = loop };
    }

    public bool Has(string name) => clips.ContainsKey(name);

    /// <summary>How long a clip takes to play once, in seconds.</summary>
    public float Length(string name) => clips.TryGetValue(name, out var c) ? c.frames.Length / c.fps : 0f;

    public void Play(string name, bool restart = false)
    {
        if (!restart && name == Current)
            return;
        if (!clips.TryGetValue(name, out var c))
            return;
        clip = c;
        Current = name;
        time = 0;
        frame = 0;
        Renderer.sprite = c.frames[0];
    }

    void Update()
    {
        if (clip == null || clip.frames.Length < 2)
            return;
        time += Time.deltaTime * clip.fps * Speed;
        int f = (int)time;
        f = clip.loop ? f % clip.frames.Length : Mathf.Min(f, clip.frames.Length - 1);
        if (f != frame)
        {
            frame = f;
            Renderer.sprite = clip.frames[f];
        }
    }
}
