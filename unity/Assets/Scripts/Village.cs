using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Level 1's look, from the Asset Store packs: Cainos "Pixel Art Platformer - Village Props" (ground tiles and the
/// village's props, Resources/Art/Village) and "2D Pixel Art Platformer Biome - American Forest" (the drifting sky
/// and hills, Resources/Art/Forest). Room asks it for each piece when a level's mood is "village".
/// The pieces are pixel art at 32 pixels a tile (the forest at 16), drawn crisp.
/// </summary>
public static class Village
{
    static Dictionary<string, Sprite> ground, props, forest;
    static readonly Dictionary<Sprite, Sprite> standing = new();

    static Dictionary<string, Sprite> Load(string path)
    {
        var d = new Dictionary<string, Sprite>();
        foreach (var s in Resources.LoadAll<Sprite>(path))
            d[s.name] = s;
        return d;
    }

    /// <summary>A ground tile: 0-2 grass top (left, middle, right), 3-5 earth below.</summary>
    public static Sprite Ground(int piece) =>
        (ground ??= Load("Art/Village/TX Tileset Ground")).TryGetValue("TX Tileset Ground_" + piece, out var s) ? s : null;

    public static Sprite Prop(string name) =>
        (props ??= Load("Art/Village/TX Village Props")).TryGetValue("TX Village Props - " + name, out var s) ? s : null;

    public static Sprite Forest(string name) =>
        (forest ??= Load("Art/Forest/Sprites")).TryGetValue(name, out var s) ? s : null;

    /// <summary>
    /// A picture placed so that a chosen point of it (0,0 = its bottom-left corner, 0.5,0 = the middle of its bottom
    /// edge, where it stands) is at `at`. (The pictures keep their own pivots: in a build they can be packed
    /// together, so we move them rather than re-cut them.)
    /// </summary>
    public static SpriteRenderer Place(Transform parent, Sprite sprite, Vector2 at, int order, string name, Vector2 point)
    {
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = sprite;
        sr.sortingOrder = order;
        var offset = Vector2.zero;
        if (sprite != null)
        {
            var b = sprite.bounds; // (around the picture's own pivot)
            offset = new Vector2(Mathf.Lerp(b.min.x, b.max.x, point.x), Mathf.Lerp(b.min.y, b.max.y, point.y));
        }
        go.transform.localPosition = at - offset;
        return sr;
    }

    static readonly Vector2 Feet = new(0.5f, 0);

    /// <summary>A picture standing with the middle of its bottom edge at `foot`.</summary>
    public static SpriteRenderer Stand(Transform parent, string prop, Vector2 foot, int order, string name) =>
        Place(parent, Prop(prop), foot, order, name, Feet);

    static Light2D Glow(Transform parent, Vector2 at, Color color, float radius, float intensity, bool flicker)
    {
        var go = new GameObject("Light");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = at;
        var l = go.AddComponent<Light2D>();
        l.lightType = Light2D.LightType.Point;
        l.color = color;
        l.pointLightOuterRadius = radius;
        l.pointLightInnerRadius = radius * 0.15f;
        l.intensity = intensity;
        l.falloffIntensity = 0.7f;
        if (flicker)
            go.AddComponent<Flicker>();
        return l;
    }

    /// <summary>Scenery standing on the ground at `foot` (no collision). False if `ch` isn't scenery.</summary>
    public static bool Scenery(char ch, Transform parent, Vector2 foot, int col)
    {
        const int Behind = -3, Trees = -6, Front = 12;
        var warm = new Color(1f, 0.72f, 0.4f);
        switch (ch)
        {
            case 'w': Stand(parent, "Well", foot, Behind, "Well"); return true;
            case 'k': Stand(parent, "Scarecrow", foot, Behind, "Scarecrow"); return true;
            case 's': Stand(parent, "Sign 01", foot, Behind, "Sign"); return true;
            case 'h': Stand(parent, "Hay Pile", foot, Behind, "Hay"); return true;
            case 'x': Stand(parent, "Wheelbarrow", foot, Behind, "Wheelbarrow"); return true;
            case 'b': Stand(parent, $"Bush 0{1 + col % 3}", foot, Behind, "Bush"); return true;
            case 't': Stand(parent, col % 2 == 0 ? "Tree 01" : "Tree 02", foot, Trees, "Tree"); return true;
            case 'g': Stand(parent, $"Grass 0{1 + (col * 7) % 9}", foot, Front, "Grass"); return true;
            case 'u':
                for (int i = 0; i < 3; i++)
                    Stand(parent, $"Sunflower 0{1 + i}", foot + new Vector2(-0.45f + i * 0.45f, 0), Behind, "Sunflower");
                return true;
            case 'f':
                Stand(parent, "Fence 01 Pillar 01", foot + new Vector2(-0.5f, 0), Behind, "Fence");
                Stand(parent, "Fence 01 Rail 01", foot + new Vector2(0, 0.55f), Behind, "Fence");
                return true;
            case 'p': // a road lamp, lit
            {
                var pillar = Stand(parent, "Road Lamp Pillar", foot, Behind, "Lamp");
                float top = pillar.sprite.bounds.size.y;
                Place(parent, Prop("Road Lamp Light On"), foot + new Vector2(0, top - 0.05f), Behind, "Lamp Light", new Vector2(0.5f, 1));
                Glow(parent, foot + new Vector2(0, top - 0.35f), warm, 5f, 1.1f, false);
                return true;
            }
            case 'c': // a campfire, flickering
                Stand(parent, "Campfire", foot, Behind, "Campfire");
                Glow(parent, foot + new Vector2(0, 0.4f), new Color(1f, 0.55f, 0.25f), 6f, 1.3f, true);
                return true;
            case 'E': // the Stone of Recall: the end of the level
            {
                var stone = Stand(parent, "Stone of Recall", foot, Behind, "Stone of Recall");
                Place(parent, Prop("Stone of Recall - Glow"), foot + new Vector2(0, stone.sprite.bounds.size.y * 0.55f), Behind + 1, "Glow", new Vector2(0.5f, 0.5f));
                Glow(parent, foot + new Vector2(0, 0.8f), new Color(0.45f, 0.85f, 1f), 4.5f, 1.4f, true);
                Goal.Create(parent, foot + new Vector2(0, 1f));
                return true;
            }
        }
        return false;
    }

    /// <summary>The forest behind the village: sky, clouds, hills and two rows of pines, each drifting at its own pace.</summary>
    public static void Background(Transform parent)
    {
        string[] far = { "Background5", "Background4", "Background3", "Background2", "Background1" };
        for (int i = 0; i < far.Length; i++)
        {
            var s = Forest(far[i]);
            if (s != null)
                Parallax.Create(parent, s, 0.04f + i * 0.08f, -100 + i);
        }
    }
}

/// <summary>A light that flickers like a flame.</summary>
public class Flicker : MonoBehaviour
{
    Light2D l;
    float baseIntensity, seed;

    void Start()
    {
        l = GetComponent<Light2D>();
        baseIntensity = l.intensity;
        seed = Random.value * 10;
    }

    void Update() => l.intensity = baseIntensity * (0.85f + 0.15f * Mathf.PerlinNoise(seed, Time.time * 3f));
}

/// <summary>The end of a level: touching it finishes the level.</summary>
public class Goal : MonoBehaviour
{
    bool reached;

    public static void Create(Transform parent, Vector2 at)
    {
        var go = new GameObject("Goal");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = at;
        var box = go.AddComponent<BoxCollider2D>();
        box.isTrigger = true;
        box.size = new Vector2(1.2f, 2f);
        go.AddComponent<Goal>();
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        if (reached || other.GetComponentInParent<Janani>() == null)
            return;
        reached = true;
        if (LevelUI.Instance != null)
            LevelUI.Instance.Finished();
    }
}
