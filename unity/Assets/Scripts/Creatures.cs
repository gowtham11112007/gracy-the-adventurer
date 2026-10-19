using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// A creature of the forest (Asset Store FTTGR, Resources/Art/Creatures): a mushroom ('m' in a level) that walks
/// slowly, or a wolf ('W') that prowls fast. It patrols a few tiles each way, turning at obstacles, gaps and walls.
/// Touching it from the side hurts Janani; landing on its head defeats it (a bounce, its death, its cry).
/// </summary>
public class Creature : MonoBehaviour
{
    Room room;
    Flipbook look;
    int row;            // the grid row it walks along (it stands on the row below)
    float home, speed, dir = 1, range;
    bool dead;
    string kind;
    AudioSource voice;

    static Dictionary<string, Sprite> Sheet(string name)
    {
        var d = new Dictionary<string, Sprite>();
        foreach (var s in Resources.LoadAll<Sprite>("Art/Creatures/" + name))
            d[s.name] = s;
        return d;
    }

    static Sprite[] Frames(Dictionary<string, Sprite> sheet, string prefix, int count)
    {
        var list = new List<Sprite>();
        for (int i = 1; i <= count; i++)
            if (sheet.TryGetValue(prefix + i, out var s)) list.Add(s);
        return list.ToArray();
    }

    public static void Create(Room room, Transform parent, char ch, int col, int row)
    {
        bool wolf = ch == 'W';
        var go = new GameObject(wolf ? "Wolf" : "Mushroom");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = new Vector2(col + 0.5f, Room.TopY(row + 1));
        var c = go.AddComponent<Creature>();
        c.room = room;
        c.row = row;
        c.kind = wolf ? "Wolf" : "Mushroom";
        c.home = col + 0.5f;
        c.speed = wolf ? 2.4f : 0.9f;
        c.range = wolf ? 5f : 3f;
        var art = new GameObject("Look");
        art.transform.SetParent(go.transform, false);
        art.transform.localScale = Vector3.one * 0.5f; // (drawn at 8 pixels a unit: half size matches the village)
        c.look = art.AddComponent<Flipbook>();
        c.look.Renderer.sortingOrder = 8;
        var sheet = Sheet(c.kind);
        if (wolf)
        {
            c.look.Add("move", Frames(sheet, "WolfRun", 6), 12, true);
            c.look.Add("die", Frames(sheet, "WolfDeath", 5), 10, false);
        }
        else
        {
            c.look.Add("move", Frames(sheet, "MushroomWalk", 6), 8, true);
            c.look.Add("die", Frames(sheet, "MushroomDeath", 9), 12, false);
        }
        c.look.Play("move");
        // stand on the ground: lift the picture so its bottom is at the feet
        var first = c.look.Renderer.sprite;
        if (first != null)
            art.transform.localPosition = new Vector3(0, -first.bounds.min.y * 0.5f, 0);
        var box = go.AddComponent<BoxCollider2D>();
        box.isTrigger = true;
        box.size = wolf ? new Vector2(1.8f, 1.1f) : new Vector2(0.9f, 1.1f);
        box.offset = new Vector2(0, box.size.y / 2);
        var body = go.AddComponent<Rigidbody2D>();
        body.bodyType = RigidbodyType2D.Kinematic; // (moved by hand; still notices Janani)
        c.voice = go.AddComponent<AudioSource>();
        Flow.Sound(c.voice);
    }

    bool CanWalk(float x)
    {
        int c = Mathf.FloorToInt(x + dir * 0.6f);
        if (Mathf.Abs(x - home) > range) return false;
        char ahead = room.At(c, row), below = room.At(c, row + 1);
        return "CRO^L".IndexOf(ahead) < 0 && (below == '#' || below == '=') && c > 0 && c < room.Def.width - 1;
    }

    void Update()
    {
        if (dead) return;
        var p = transform.localPosition;
        if (!CanWalk(p.x)) dir = -dir;
        p.x += dir * speed * Time.deltaTime;
        transform.localPosition = p;
        look.Renderer.flipX = dir < 0; // (the pictures face right)
    }

    void OnTriggerStay2D(Collider2D other)
    {
        if (dead) return;
        var j = other.GetComponentInParent<Janani>();
        if (j == null) return;
        // from above, falling onto its head: defeated
        if (j.Falling && j.Feet.y > transform.position.y + 0.55f)
        {
            dead = true;
            j.Bounce();
            look.Play("die");
            voice.PlayOneShot(Resources.Load<AudioClip>("Audio/" + kind + "Death"));
            Sparkle.Burst(transform.position + Vector3.up * 0.6f, new Color(1f, 0.85f, 0.5f));
            StartCoroutine(Fade());
            return;
        }
        j.Hurt(transform.position.x, 20);
    }

    IEnumerator Fade()
    {
        yield return new WaitForSeconds(0.9f);
        var sr = look.Renderer;
        for (float t = 1; t > 0; t -= Time.deltaTime * 2)
        {
            sr.color = new Color(1, 1, 1, t);
            yield return null;
        }
        Destroy(gameObject);
    }
}

/// <summary>A small burst of glowing sparks (gems, defeated creatures).</summary>
public class Sparkle : MonoBehaviour
{
    Vector2 velocity;
    float life = 0.6f, age;
    SpriteRenderer sr;
    static Sprite dot;

    public static void Burst(Vector3 at, Color color, int count = 8)
    {
        if (dot == null)
            dot = Sprite.Create(Shapes.Glow().texture, new Rect(0, 0, 128, 64), new Vector2(0.5f, 0.5f), 256);
        for (int i = 0; i < count; i++)
        {
            var go = new GameObject("Spark");
            go.transform.position = at;
            var s = go.AddComponent<Sparkle>();
            s.sr = go.AddComponent<SpriteRenderer>();
            s.sr.sprite = dot;
            s.sr.color = color;
            s.sr.sortingOrder = 20;
            float a = i * Mathf.PI * 2 / count + UnityEngine.Random.value * 0.4f;
            s.velocity = new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * UnityEngine.Random.Range(1.5f, 3f);
        }
    }

    internal static void Fresh() => dot = null;

    void Update()
    {
        age += Time.deltaTime;
        transform.position += (Vector3)(velocity * Time.deltaTime);
        velocity *= 0.92f;
        float k = 1 - age / life;
        sr.color = new Color(sr.color.r, sr.color.g, sr.color.b, k);
        transform.localScale = Vector3.one * (0.6f + 0.6f * k);
        if (age >= life) Destroy(gameObject);
    }
}

/// <summary>A soft fade through night blue between screens (it stays across the scene reload).</summary>
public class Fader : MonoBehaviour
{
    static Fader instance;
    Image cover;

    static Fader Get()
    {
        if (instance != null) return instance;
        var go = new GameObject("Fader");
        DontDestroyOnLoad(go);
        var canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 999;
        var rt = new GameObject("Cover", typeof(RectTransform));
        rt.transform.SetParent(go.transform, false);
        var r = (RectTransform)rt.transform;
        r.anchorMin = Vector2.zero;
        r.anchorMax = Vector2.one;
        r.offsetMin = r.offsetMax = Vector2.zero;
        instance = go.AddComponent<Fader>();
        instance.cover = rt.AddComponent<Image>();
        instance.cover.color = new Color(0.03f, 0.04f, 0.09f, 0);
        instance.cover.raycastTarget = false;
        return instance;
    }

    /// <summary>Fade out, do `change` (load the next screen), fade back in.</summary>
    public static void Through(Action change)
    {
        var f = Get();
        f.StartCoroutine(f.Run(change));
    }

    IEnumerator Run(Action change)
    {
        cover.raycastTarget = true; // (no taps while it changes)
        for (float t = 0; t < 1; t += Time.unscaledDeltaTime / 0.3f)
        {
            cover.color = new Color(0.03f, 0.04f, 0.09f, t);
            yield return null;
        }
        cover.color = new Color(0.03f, 0.04f, 0.09f, 1);
        change();
        yield return null;
        yield return null;
        for (float t = 1; t > 0; t -= Time.unscaledDeltaTime / 0.45f)
        {
            cover.color = new Color(0.03f, 0.04f, 0.09f, t);
            yield return null;
        }
        cover.color = new Color(0.03f, 0.04f, 0.09f, 0);
        cover.raycastTarget = false;
    }

    internal static void Fresh() => instance = null;
}
