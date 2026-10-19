using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

/// <summary>
/// The World Map: each world is an island (World 1's, built and rendered in Blender by tools/blender/world_map.py,
/// Resources/Art/Map/world1.png). A carved stone marker on every level (positions from Resources/Data/worldmap.json):
/// open levels glow gold and show their name, finished ones carry a star, locked ones are dimmed with a lock.
/// Janani's portrait floats over the level she's up to. Tap a level to play it. Home (or Back) returns to the title.
/// </summary>
public class MapUI : MonoBehaviour
{
    [Serializable] class Spot { public string id, name; public float x, y; }
    [Serializable] class Spots { public Spot[] levels; }

    static readonly Color Gold = new(0.98f, 0.84f, 0.5f);
    static readonly Color Cream = new(1f, 0.95f, 0.86f);
    RectTransform root;
    Text toast;
    float toastTime;
    AudioSource click;

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
        map.Build();
        return map;
    }

    void Build()
    {
        // the sea all around, then the island picture covering the screen (its sea matches)
        var sea = Box(root, "Sea", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(5000, 3000));
        Picture(sea, null, new Color(0.07f, 0.22f, 0.32f));
        var island = Box(root, "Island", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(1280, 720));
        var pic = Picture(island, Resources.Load<Sprite>("Art/Map/world1"), Color.white);
        pic.preserveAspect = false;
        var fit = island.gameObject.AddComponent<AspectRatioFitter>();
        fit.aspectMode = AspectRatioFitter.AspectMode.EnvelopeParent;
        fit.aspectRatio = 16f / 9f;

        // the world's name
        Words(root, "World 1", new Vector2(0.5f, 1), new Vector2(0, -46), 54, Gold, 600);
        Words(root, "The Island of Lanterns", new Vector2(0.5f, 1), new Vector2(0, -96), 26, Cream, 600);

        // the levels
        var data = JsonUtility.FromJson<Spots>(Resources.Load<TextAsset>("Data/worldmap").text);
        int current = 0; // the first level not yet finished
        for (int i = 0; i < data.levels.Length; i++)
            if (Flow.Done(data.levels[i].id)) current = Mathf.Min(i + 1, data.levels.Length - 1);
        for (int i = 0; i < data.levels.Length; i++)
            Marker(island, data.levels[i], i, i == 0 || Flow.Done(data.levels[i - 1].id), i == current);

        // home, top left
        var home = Box(root, "Home", new Vector2(0, 1), new Vector2(62, -58), new Vector2(76, 76));
        var hb = home.gameObject.AddComponent<Button>();
        hb.targetGraphic = Picture(home, Pic("icon_home"), Color.white, true);
        hb.onClick.AddListener(() => { click.Play(); Flow.ToTitle(); });

        toast = Words(root, "", new Vector2(0.5f, 0), new Vector2(0, 70), 30, Cream, 900);
    }

    /// <summary>One level's marker: a stone with its number; gold and named when open, a lock when not.</summary>
    void Marker(RectTransform island, Spot spot, int index, bool open, bool here)
    {
        var at = new Vector2(spot.x, spot.y);
        var m = Box(island, spot.name, at, Vector2.zero, new Vector2(86, 86));
        if (open) // a soft gold glow under open levels
            Picture(Box(m, "Glow", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(170, 120)), Shapes.Glow(), new Color(1f, 0.8f, 0.4f, here ? 0.7f : 0.4f));
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
        if (here) // Janani's portrait, floating over the level she's up to
        {
            var face = Box(m, "Janani", new Vector2(0.5f, 1), new Vector2(0, 62), new Vector2(76, 76));
            Picture(face, Shapes.Disc(), new Color(0.05f, 0.03f, 0.1f, 0.8f));
            var inner = Box(face, "Face", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(66, 66));
            Picture(inner, Shapes.Disc(), Color.white);
            inner.gameObject.AddComponent<Mask>().showMaskGraphic = false;
            Picture(Box(inner, "Portrait", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(66, 66)), Art.Picture("Props/portrait_janani", new Vector2(0.5f, 0.5f)), Color.white);
            Picture(Box(face, "Ring", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(76, 76)), Shapes.Ring(), Gold);
            face.gameObject.AddComponent<Bob>();
        }
        string id = spot.id, name = spot.name;
        b.onClick.AddListener(() =>
        {
            click.Play();
            if (!open) Toast("Finish the level before it to open " + name);
            else if (Room.Find(id) == null) Toast(name + " is coming soon");
            else Flow.Play(id);
        });
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
        if (k != null && k.escapeKey.wasPressedThisFrame) // Back: to the title
            Flow.ToTitle();
    }
}
