using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

/// <summary>
/// The World Map: each world is an island (World 1's, built and rendered in Blender by tools/blender/world_map.py,
/// Resources/Art/Map/world1.png). A carved stone marker on every level (positions from Resources/Data/worldmap.json),
/// joined by a trail of glowing dots. Janani herself stands on the map: tap an open level and she runs along the
/// trail to it, then its card opens. After a level is finished, the trail to the next one lights up dot by dot, its
/// lock breaks, and she walks there. The map flies in from close up; crows circle Yuva's castle under a dark glow;
/// light glints on the sea; clouds drift over. Home (or Back) returns to the title.
/// </summary>
public class MapUI : MonoBehaviour
{
    [Serializable] class Spot { public string id, name; public float x, y; }
    [Serializable] class Spots { public Spot[] levels; }

    static readonly Color Gold = new(0.98f, 0.84f, 0.5f);
    static readonly Color Cream = new(1f, 0.95f, 0.86f);
    const int Dots = 11; // dots on the trail between two levels

    RectTransform root, world, island, hero;
    Text toast;
    float toastTime;
    AudioSource click, chime;
    Spot[] spots;
    readonly List<RectTransform> markers = new();
    readonly List<List<Image>> trail = new(); // trail[i]: the dots from level i to level i + 1
    int at;          // the level she's standing on
    int finished;    // how many levels are finished, in order
    bool busy;       // walking or revealing: taps wait
    UIFlip heroLook;
    Sprite[] idleFrames, runFrames;

    static Sprite Pic(string name) => Resources.Load<Sprite>("Art/Menu/" + name);

    static RectTransform Box(Transform parent, string name, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        var go = new GameObject(name, typeof(RectTransform));
        go.transform.SetParent(parent, false);
        var rt = (RectTransform)go.transform;
        rt.anchorMin = rt.anchorMax = anchor;
        rt.anchoredPosition = pos;
        rt.sizeDelta = size;
        return rt;
    }

    static Image Picture(RectTransform on, Sprite s, Color c, bool raycast = false)
    {
        var img = on.gameObject.AddComponent<Image>();
        img.sprite = s;
        img.color = c;
        img.preserveAspect = true;
        img.raycastTarget = raycast;
        return img;
    }

    static Text Words(Transform parent, string s, Vector2 anchor, Vector2 pos, int size, Color c, float wide = 400)
    {
        var rt = Box(parent, "Words", anchor, pos, new Vector2(wide, size * 1.7f));
        var t = rt.gameObject.AddComponent<Text>();
        t.text = s;
        t.font = MenuUI.Medieval;
        t.fontSize = size;
        t.color = c;
        t.alignment = TextAnchor.MiddleCenter;
        t.raycastTarget = false;
        var o = rt.gameObject.AddComponent<Outline>();
        o.effectColor = new Color(0.12f, 0.05f, 0.18f, 0.9f);
        o.effectDistance = new Vector2(2, -2);
        return t;
    }

    public static MapUI Show()
    {
        var go = new GameObject("World Map");
        var canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 70;
        var scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720);
        scaler.matchWidthOrHeight = 1;
        go.AddComponent<GraphicRaycaster>();
        if (FindAnyObjectByType<EventSystem>() == null)
            new GameObject("EventSystem", typeof(EventSystem), typeof(InputSystemUIInputModule));
        var map = go.AddComponent<MapUI>();
        map.root = (RectTransform)go.transform;
        map.click = go.AddComponent<AudioSource>();
        map.click.clip = Resources.Load<AudioClip>("Audio/Click Button SFX");
        Flow.Sound(map.click);
        map.chime = go.AddComponent<AudioSource>();
        map.chime.volume = 0.5f;
        Flow.Sound(map.chime);
        map.Build();
        return map;
    }

    void Build()
    {
        spots = JsonUtility.FromJson<Spots>(Resources.Load<TextAsset>("Data/worldmap").text).levels;
        finished = 0;
        while (finished < spots.Length && Flow.Done(spots[finished].id))
            finished++;
        int current = Mathf.Min(finished, spots.Length - 1); // the first level not yet finished
        int shown = Mathf.Min(PlayerPrefs.GetInt("map_shown", 0), finished); // finished levels the map has already celebrated
        bool reveal = finished > shown && shown < spots.Length - 1;

        // the sea all around, then the island (everything on it moves with it: the fly-in zooms this)
        var sea = Box(root, "Sea", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(5000, 3000));
        Picture(sea, null, new Color(0.07f, 0.22f, 0.32f));
        world = Box(root, "World", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(1280, 720));
        var fit = world.gameObject.AddComponent<AspectRatioFitter>();
        fit.aspectMode = AspectRatioFitter.AspectMode.EnvelopeParent;
        fit.aspectRatio = 16f / 9f;
        island = Box(world, "Island", new Vector2(0.5f, 0.5f), Vector2.zero, Vector2.zero);
        island.anchorMin = Vector2.zero;
        island.anchorMax = Vector2.one;
        var pic = Picture(island, Resources.Load<Sprite>("Art/Map/world1"), Color.white);
        pic.preserveAspect = false;
        SeaGlints();

        // the dark glow over Yuva's castle, and crows circling it
        var castle = spots[spots.Length - 1];
        var dark = Box(island, "Shadow", new Vector2(castle.x, castle.y), new Vector2(0, 20), new Vector2(330, 260));
        Picture(dark, Shapes.Glow(), new Color(0.35f, 0.08f, 0.45f, 0.55f));
        dark.gameObject.AddComponent<Breathe>().Setup(0.3f, 0.6f, 0.25f);
        Crows(new Vector2(castle.x, castle.y));

        // the trail between the levels, then the levels' markers
        for (int i = 0; i < spots.Length - 1; i++)
            trail.Add(Trail(i, i < shown ? 2 : (reveal && i == shown) ? 0 : 1));
        for (int i = 0; i < spots.Length; i++)
        {
            bool open = i == 0 || Flow.Done(spots[i - 1].id);
            bool waits = reveal && i == shown + 1; // opens in front of her, after the trail lights up
            markers.Add(Marker(spots[i], i, open && !waits, i == current && !reveal));
        }

        // Janani, standing on her level (or still on the one she just finished, until the trail lights up)
        at = reveal ? shown : Mathf.Clamp(PlayerPrefs.GetInt("map_at", current), 0, current);
        Hero();

        // the world's name, on a soft dark band across the top
        var band = Box(root, "Band", new Vector2(0.5f, 1), new Vector2(0, -70), new Vector2(3000, 170));
        Picture(band, Shapes.Glow(), new Color(0.03f, 0.02f, 0.08f, 0.55f)).preserveAspect = false;
        Words(root, "World 1", new Vector2(0.5f, 1), new Vector2(0, -46), 54, Gold, 600);
        Words(root, "The Island of Lanterns", new Vector2(0.5f, 1), new Vector2(0, -96), 26, Cream, 600);

        // home, top left; stars and gems, top right
        var home = Box(root, "Home", new Vector2(0, 1), new Vector2(62, -58), new Vector2(76, 76));
        var hb = home.gameObject.AddComponent<Button>();
        hb.targetGraphic = Picture(home, Pic("icon_home"), Color.white, true);
        home.gameObject.AddComponent<PressScale>();
        hb.onClick.AddListener(() => { click.Play(); Flow.ToTitle(); });
        Tally();

        toast = Words(root, "", new Vector2(0.5f, 0), new Vector2(0, 70), 30, Cream, 900);

        // soft clouds drifting over the sea and the island
        for (int i = 0; i < 4; i++)
        {
            var cloud = Box(root, "Cloud", new Vector2(0.5f, 0.5f), new Vector2(-600 + i * 380, 220 - i * 140), new Vector2(520, 160));
            cloud.SetSiblingIndex(2); // (above the island, under the words and markers)
            Picture(cloud, Shapes.Glow(), new Color(1f, 0.97f, 0.95f, 0.22f));
            cloud.gameObject.AddComponent<Drift>().speed = 10 + i * 4;
        }

        StartCoroutine(FlyIn(reveal ? shown : at, reveal));
    }

    // ---------------------------------------------------------------- the island's life

    /// <summary>Little glints of light twinkling on the sea around the island.</summary>
    void SeaGlints()
    {
        var rng = new System.Random(7);
        for (int i = 0; i < 26; i++)
        {
            // around the edge of the picture, where the sea is
            float a = (float)rng.NextDouble() * Mathf.PI * 2, r = 0.42f + (float)rng.NextDouble() * 0.12f;
            var p = new Vector2(0.5f + Mathf.Cos(a) * r, 0.5f + Mathf.Sin(a) * r * 1.05f);
            var g = Box(island, "Glint", p, Vector2.zero, new Vector2(26, 8));
            Picture(g, Shapes.Glow(), new Color(1f, 1f, 0.95f, 0.6f)).preserveAspect = false;
            g.gameObject.AddComponent<Breathe>().Setup(0f, 0.75f, 0.15f + (float)rng.NextDouble() * 0.35f);
        }
    }

    /// <summary>Three crows flying slow circles around the castle.</summary>
    void Crows(Vector2 centre)
    {
        var sheet = new Dictionary<string, Sprite>();
        foreach (var s in Resources.LoadAll<Sprite>("Art/Creatures/Crow"))
            sheet[s.name] = s;
        var fly = new List<Sprite>();
        for (int i = 1; i <= 9; i++)
            if (sheet.TryGetValue("CrowFly" + i, out var s)) fly.Add(s);
        if (fly.Count == 0)
            return;
        for (int i = 0; i < 3; i++)
        {
            var crow = Box(island, "Crow", centre, Vector2.zero, new Vector2(56, 56));
            Picture(crow, fly[0], new Color(0.12f, 0.08f, 0.16f));
            var flip = crow.gameObject.AddComponent<UIFlip>();
            flip.frames = fly.ToArray();
            flip.fps = 10 + i;
            var circle = crow.gameObject.AddComponent<Circle>();
            circle.radius = new Vector2(120 + i * 30, 50 + i * 12);
            circle.speed = 0.35f + i * 0.08f;
            circle.phase = i * 2.1f;
            circle.lift = 70;
        }
    }

    /// <summary>The trail of dots from level i to the next: 0 hidden (it lights up soon), 1 faint, 2 lit.</summary>
    List<Image> Trail(int i, int state)
    {
        var dots = new List<Image>();
        var a = new Vector2(spots[i].x, spots[i].y);
        var b = new Vector2(spots[i + 1].x, spots[i + 1].y);
        for (int d = 1; d < Dots; d++)
        {
            var dot = Box(island, "Dot", Bend(a, b, d / (float)Dots), Vector2.zero, new Vector2(15, 15));
            var img = Picture(dot, Shapes.Disc(), state == 2 ? Gold : new Color(1, 0.95f, 0.86f, 0.45f));
            var ring = Box(dot, "Ring", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(19, 19));
            Picture(ring, Shapes.Ring(), new Color(0.2f, 0.1f, 0.25f, 0.7f));
            if (state == 0)
                dot.localScale = Vector3.zero;
            dots.Add(img);
        }
        return dots;
    }

    /// <summary>A point along the trail from a to b (t 0..1), bending gently so it winds like a path.</summary>
    static Vector2 Bend(Vector2 a, Vector2 b, float t)
    {
        var side = new Vector2(-(b - a).y, (b - a).x) * 0.18f;
        return Vector2.Lerp(a, b, t) + side * Mathf.Sin(t * Mathf.PI);
    }

    /// <summary>Stars and gems collected, top right.</summary>
    void Tally()
    {
        int stars = 0, gems = 0;
        foreach (var s in spots)
        {
            if (Flow.Done(s.id)) stars++;
            gems += PlayerPrefs.GetInt("gems_" + s.id, 0);
        }
        var panel = Box(root, "Tally", new Vector2(1, 1), new Vector2(-150, -58), new Vector2(250, 70));
        Picture(Box(panel, "Shade", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(330, 120)), Shapes.Glow(), new Color(0.05f, 0.02f, 0.09f, 0.85f)).preserveAspect = false;
        Picture(Box(panel, "Star", new Vector2(0, 0.5f), new Vector2(36, 2), new Vector2(46, 46)), Pic("icon_fvt_star"), Color.white);
        Words(panel, $"{stars}/{spots.Length}", new Vector2(0, 0.5f), new Vector2(92, 0), 28, Cream, 80);
        var gemFrames = Art.Strip("Props/gem_pixel", 8, 32, 36, 16);
        if (gemFrames.Length > 0)
        {
            var g = Box(panel, "Gem", new Vector2(0, 0.5f), new Vector2(158, 0), new Vector2(36, 40));
            Picture(g, gemFrames[0], Color.white);
            g.gameObject.AddComponent<UIFlip>().frames = new[] { gemFrames[0], gemFrames[0], gemFrames[0], gemFrames[1], gemFrames[2], gemFrames[3], gemFrames[4], gemFrames[5], gemFrames[6], gemFrames[7] };
        }
        Words(panel, gems.ToString(), new Vector2(0, 0.5f), new Vector2(210, 0), 28, Cream, 70);
    }

    // ---------------------------------------------------------------- Janani on the map

    void Hero()
    {
        idleFrames = Art.Strip("Janani/beta7_idle", 10, 210, 210, 105);
        runFrames = Art.Strip("Janani/beta7_run", 16, 210, 210, 105);
        hero = Box(island, "Janani", Stand(at), Vector2.zero, new Vector2(150, 150));
        hero.pivot = new Vector2(0.5f, 0.12f); // (her feet)
        var shadow = Box(hero, "Shadow", new Vector2(0.5f, 0.12f), Vector2.zero, new Vector2(70, 18));
        Picture(shadow, Shapes.Disc(), new Color(0, 0, 0, 0.35f)).preserveAspect = false;
        var look = Box(hero, "Look", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(150, 150));
        Picture(look, idleFrames.Length > 0 ? idleFrames[0] : null, Color.white);
        heroLook = look.gameObject.AddComponent<UIFlip>();
        heroLook.frames = idleFrames;
        heroLook.fps = 6;
        hero.SetAsLastSibling();
    }

    Vector2 Stand(int i) => new Vector2(spots[i].x, spots[i].y) + new Vector2(0, 0.045f); // (on top of the marker stone)

    /// <summary>Janani runs along the trail from where she is to level `to`.</summary>
    IEnumerator Walk(int to)
    {
        if (to == at)
            yield break;
        heroLook.frames = runFrames;
        heroLook.fps = 18;
        int step = to > at ? 1 : -1;
        for (int i = at; i != to; i += step)
        {
            var a = new Vector2(spots[i].x, spots[i].y);
            var b = new Vector2(spots[i + step].x, spots[i + step].y);
            heroLook.transform.localScale = new Vector3(b.x < a.x ? -1 : 1, 1, 1);
            float length = (b - a).magnitude, time = length / 0.2f;
            for (float t = 0; t < 1; t += Time.unscaledDeltaTime / time)
            {
                var p = Bend(a, b, t) + new Vector2(0, Mathf.Lerp(i == at ? 0.045f : 0, i + step == to ? 0.045f : 0, t));
                hero.anchorMin = hero.anchorMax = p;
                yield return null;
            }
        }
        at = to;
        hero.anchorMin = hero.anchorMax = Stand(to);
        heroLook.frames = idleFrames;
        heroLook.fps = 6;
        PlayerPrefs.SetInt("map_at", at);
    }

    /// <summary>The map flies in from close up over her; after a finished level, the next trail lights up.</summary>
    IEnumerator FlyIn(int focus, bool reveal)
    {
        busy = true;
        var p = new Vector2(spots[focus].x - 0.5f, spots[focus].y - 0.5f);
        for (float t = 0; t < 1; t += Time.unscaledDeltaTime / 1.6f)
        {
            float e = 1 - Mathf.Pow(1 - t, 3);
            float zoom = Mathf.Lerp(1.45f, 1f, e);
            world.localScale = Vector3.one * zoom;
            world.anchoredPosition = -new Vector2(p.x * world.rect.width, p.y * world.rect.height) * zoom * (1 - e);
            yield return null;
        }
        world.localScale = Vector3.one;
        world.anchoredPosition = Vector2.zero;
        if (reveal)
            yield return Reveal(focus);
        busy = false;
    }

    /// <summary>The trail from level i lights up dot by dot, the next level's lock breaks, and she walks there.</summary>
    IEnumerator Reveal(int i)
    {
        var tick = Resources.Load<AudioClip>("Audio/GemChime");
        foreach (var dot in trail[i])
        {
            dot.color = Gold;
            for (float t = 0; t < 1; t += Time.unscaledDeltaTime / 0.12f)
            {
                float k = t < 0.7f ? t / 0.7f * 1.3f : 1.3f - (t - 0.7f) / 0.3f * 0.3f;
                dot.transform.localScale = Vector3.one * k;
                yield return null;
            }
            dot.transform.localScale = Vector3.one;
            if (tick != null) { chime.pitch = 1.6f + 0.05f * trail[i].IndexOf(dot); chime.PlayOneShot(tick, 0.25f); }
        }
        // the lock breaks: the marker opens with a burst of light
        int next = i + 1;
        var old = markers[next];
        var burst = Box(island, "Burst", new Vector2(spots[next].x, spots[next].y), Vector2.zero, new Vector2(60, 60));
        var bi = Picture(burst, Shapes.Glow(), new Color(1f, 0.9f, 0.55f, 1));
        chime.pitch = 1;
        var sparkle = Resources.Load<AudioClip>("Audio/ChestSparkle");
        if (sparkle != null) chime.PlayOneShot(sparkle, 0.5f);
        Destroy(old.gameObject);
        markers[next] = Marker(spots[next], next, true, true);
        markers[next].localScale = Vector3.zero;
        hero.SetAsLastSibling();
        for (float t = 0; t < 1; t += Time.unscaledDeltaTime / 0.5f)
        {
            burst.sizeDelta = Vector2.one * Mathf.Lerp(60, 340, t);
            bi.color = new Color(1f, 0.9f, 0.55f, 1 - t);
            float s = t < 0.6f ? t / 0.6f * 1.2f : 1.2f - (t - 0.6f) / 0.4f * 0.2f;
            markers[next].localScale = Vector3.one * s;
            yield return null;
        }
        markers[next].localScale = Vector3.one;
        Destroy(burst.gameObject);
        PlayerPrefs.SetInt("map_shown", finished);
        PlayerPrefs.Save();
        yield return new WaitForSecondsRealtime(0.25f);
        yield return Walk(next);
        Toast(spots[next].name + " is open!");
    }

    // ---------------------------------------------------------------- markers and the level card

    GameObject card;

    /// <summary>A level's card: its name, the most gems found there, and Play.</summary>
    void Card(string id, string name, int index)
    {
        if (card != null) Destroy(card);
        card = new GameObject("Card", typeof(RectTransform));
        card.transform.SetParent(root, false);
        var full = (RectTransform)card.transform;
        full.anchorMin = Vector2.zero;
        full.anchorMax = Vector2.one;
        full.offsetMin = full.offsetMax = Vector2.zero;
        card.AddComponent<Image>().color = new Color(0.04f, 0.02f, 0.08f, 0.55f);
        var sheet = Box(full, "Panel", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(440, 400));
        Picture(sheet, Pic("popup_bg"), Color.white);
        card.AddComponent<PopIn>();
        Words(sheet, $"Level {index + 1}", new Vector2(0.5f, 1), new Vector2(0, -66), 30, Cream, 380);
        Words(sheet, name, new Vector2(0.5f, 1), new Vector2(0, -118), 44, Gold, 400);
        int best = PlayerPrefs.GetInt("gems_" + id, 0);
        Words(sheet, Flow.Done(id) ? $"Finished   Gems {best}" : "Not finished yet", new Vector2(0.5f, 1), new Vector2(0, -180), 26, Cream, 380);
        var play = Box(sheet, "Play", new Vector2(0.5f, 0), new Vector2(0, 110), new Vector2(250, 92));
        var pb = play.gameObject.AddComponent<Button>();
        pb.targetGraphic = Picture(play, Pic("btn_play"), Color.white, true);
        play.gameObject.AddComponent<PressScale>();
        pb.onClick.AddListener(() => { click.Play(); PlayerPrefs.SetInt("map_at", index); Flow.Play(id); });
        var close = Box(sheet, "Close", new Vector2(1, 1), new Vector2(-40, -40), new Vector2(58, 58));
        var cb = close.gameObject.AddComponent<Button>();
        cb.targetGraphic = Picture(close, Pic("btn_close"), Color.white, true);
        cb.onClick.AddListener(() => { click.Play(); Destroy(card); });
    }

    /// <summary>One level's marker: a stone with its number; gold and named when open, a lock when not.</summary>
    RectTransform Marker(Spot spot, int index, bool open, bool here)
    {
        var where = new Vector2(spot.x, spot.y);
        var m = Box(island, spot.name, where, Vector2.zero, new Vector2(86, 86));
        if (open) // a soft gold glow under open levels (breathing under the one she's up to)
        {
            var glow = Box(m, "Glow", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(170, 120));
            Picture(glow, Shapes.Glow(), new Color(1f, 0.8f, 0.4f, here ? 0.7f : 0.4f));
            if (here) glow.gameObject.AddComponent<Breathe>().Setup(0.35f, 0.85f, 0.45f);
        }
        var stone = Box(m, "Stone", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(86, 86));
        var img = Picture(stone, Pic("btn_uncheck"), open ? Color.white : new Color(0.55f, 0.5f, 0.6f, 0.95f), true);
        var b = stone.gameObject.AddComponent<Button>();
        b.targetGraphic = img;
        stone.gameObject.AddComponent<PressScale>();
        if (open)
            Words(stone, (index + 1).ToString(), new Vector2(0.5f, 0.5f), new Vector2(0, 2), 40, Gold, 80);
        else
            Picture(Box(stone, "Lock", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(44, 44)), Pic("icon_lock"), Color.white);
        if (open)
            Words(m, spot.name, new Vector2(0.5f, 0), new Vector2(0, -18), 22, Cream, 300);
        if (Flow.Done(spot.id))
            Picture(Box(m, "Star", new Vector2(0.5f, 1), new Vector2(34, 6), new Vector2(40, 40)), Pic("icon_fvt_star"), Color.white);
        string id = spot.id, name = spot.name;
        b.onClick.AddListener(() =>
        {
            if (busy) return;
            click.Play();
            bool nowOpen = index == 0 || Flow.Done(spots[index - 1].id);
            if (!nowOpen) Toast("Finish the level before it to open " + name);
            else if (Room.Find(id) == null) StartCoroutine(GoThen(index, () => Toast(name + " is coming soon")));
            else StartCoroutine(GoThen(index, () => Card(id, name, index)));
        });
        if (hero != null)
            hero.SetAsLastSibling();
        return m;
    }

    /// <summary>She walks to level `index`, then `then` happens (its card opens).</summary>
    IEnumerator GoThen(int index, Action then)
    {
        busy = true;
        yield return Walk(index);
        busy = false;
        then();
    }

    void Toast(string words)
    {
        toast.text = words;
        toastTime = 2.5f;
    }

    void Update()
    {
        toastTime -= Time.unscaledDeltaTime;
        var c = toast.color;
        c.a = Mathf.Clamp01(toastTime);
        toast.color = c;
        var k = Keyboard.current;
        if (k != null && k.escapeKey.wasPressedThisFrame) // Back: closes the level card, or goes to the title
        {
            if (card != null) Destroy(card);
            else Flow.ToTitle();
        }
    }
}

/// <summary>Flies round and round an oval (the crows over the castle), facing the way it goes.</summary>
public class Circle : MonoBehaviour
{
    public Vector2 radius = new(100, 40);
    public float speed = 0.5f, phase, lift;

    void Update()
    {
        float a = Time.unscaledTime * speed + phase;
        var rt = (RectTransform)transform;
        rt.anchoredPosition = new Vector2(Mathf.Cos(a) * radius.x, lift + Mathf.Sin(a) * radius.y);
        rt.localScale = new Vector3(Mathf.Sin(a) > 0 ? -1 : 1, 1, 1); // (moving left on the top half, right on the bottom)
        rt.localEulerAngles = new Vector3(0, 0, Mathf.Sin(a * 2) * 6);
    }
}
