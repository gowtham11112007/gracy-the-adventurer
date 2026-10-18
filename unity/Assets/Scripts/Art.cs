using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Pictures from Assets/Resources/Art, as sprites. One tile = 1 unit = 64 pixels.
/// Picture() gives a whole picture; Strip() cuts an animation strip (one row of frames) into frames.
/// </summary>
public static class Art
{
    public const float PixelsPerUnit = 64f;
    static readonly Dictionary<string, Sprite> cache = new();

    internal static void Fresh() => cache.Clear();

    /// <summary>A whole picture, its pivot as a fraction of its size (0,0 = bottom-left). Null if it's missing.</summary>
    public static Sprite Picture(string path, Vector2 pivot)
    {
        string key = path + pivot;
        if (cache.TryGetValue(key, out var sprite))
            return sprite;
        var tex = Resources.Load<Texture2D>("Art/" + path);
        if (tex == null)
        {
            Debug.LogWarning("Missing picture: Art/" + path);
            return null;
        }
        sprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), pivot, PixelsPerUnit);
        cache[key] = sprite;
        return sprite;
    }

    /// <summary>The frames of a strip of w x h frames, with the pivot (her feet) at (ax, 0) in each frame.</summary>
    public static Sprite[] Strip(string path, int frames, int w, int h, float ax)
    {
        var tex = Resources.Load<Texture2D>("Art/" + path);
        if (tex == null)
        {
            Debug.LogWarning("Missing strip: Art/" + path);
            return new Sprite[0];
        }
        var list = new Sprite[frames];
        for (int i = 0; i < frames; i++)
            list[i] = Sprite.Create(tex, new Rect(i * w, 0, w, h), new Vector2(ax / w, 0), PixelsPerUnit);
        return list;
    }
}
