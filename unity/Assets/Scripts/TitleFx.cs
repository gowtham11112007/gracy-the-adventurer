using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// The title screen's life, layered like a film's opening: slow light rays and drifting fog over the cloud
/// mountains, glowing motes rising, Janani standing on a stone ledge looking out over it all (her idle animation),
/// a darker frame at the edges, the gold logo floating gently, and the buttons sliding in one after another.
/// Built by MenuUI.Title() on the menu canvas (720 high).
/// </summary>
public static class TitleFx
{
    static Sprite ray, vignette;

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

    static Image Picture(RectTransform on, Sprite sprite, Color color)
    {
        var img = on.gameObject.AddComponent<Image>();
        img.sprite = sprite;
        img.color = color;
        img.raycastTarget = false;
        return img;
    }

    static Sprite Paint(int w, int h, System.Func<float, float, float> alpha)
    {
        var tex = new Texture2D(w, h, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
        var px = new Color[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                px[y * w + x] = new Color(1, 1, 1, alpha((x + 0.5f) / w, (y + 0.5f) / h));
        tex.SetPixels(px);
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, w, h), new Vector2(0.5f, 0.5f), 100);
    }

    /// <summary>A beam of light: soft at its sides, fading out toward its end.</summary>
    static Sprite Ray() => ray ??= Paint(32, 256, (x, y) => Mathf.Pow(Mathf.Sin(x * Mathf.PI), 2) * y * y);

    /// <summary>Clear in the middle, dark at the edges.</summary>
    static Sprite Vignette() => vignette ??= Paint(128, 72, (x, y) =>
    {
        float dx = (x - 0.5f) * 2, dy = (y - 0.5f) * 2;
        return Mathf.Clamp01((dx * dx * 0.6f + dy * dy * 0.9f) - 0.35f) * 0.85f;
    });

    /// <summary>The layers between the mountains and the menu.</summary>
    public static void Scenery(RectTransform root)
    {
        // light falling from the upper left, breathing slowly
        for (int i = 0; i < 3; i++)
        {
            var beam = Box(root, "Light Ray", new Vector2(0, 1), new Vector2(180 + i * 230, -120), new Vector2(150 + i * 40, 1500));
            beam.localEulerAngles = new Vector3(0, 0, -28);
            Picture(beam, Ray(), new Color(1f, 0.93f, 0.8f, 0.1f));
            beam.gameObject.AddComponent<Breathe>().Setup(0.06f, 0.14f, 0.25f + i * 0.07f);
        }
        // fog drifting across the mountains
        for (int i = 0; i < 3; i++)
        {
            var fog = Box(root, "Fog", new Vector2(0.5f, 0), new Vector2(0, 120 + i * 120), new Vector2(2600, 220));
            Picture(fog, Shapes.Glow(), new Color(0.85f, 0.85f, 0.95f, 0.16f));
            fog.gameObject.AddComponent<Drift>().speed = 14 + i * 9;
        }
        // glowing motes rising
        var rnd = new System.Random(7);
        for (int i = 0; i < 30; i++)
        {
            float s = 6 + (float)rnd.NextDouble() * 10;
            var mote = Box(root, "Mote", new Vector2(0, 0), Vector2.zero, new Vector2(s, s));
            Picture(mote, Shapes.Glow(), new Color(1f, 0.85f, 0.5f, 0.7f));
            mote.gameObject.AddComponent<Mote>().Setup((float)rnd.NextDouble(), (float)rnd.NextDouble());
        }
        // Janani on a stone ledge at the lower left, looking out at the mountains
        var ledge = Box(root, "Ledge", new Vector2(0, 0), Vector2.zero, Vector2.zero);
        int[] top = { 0, 1, 1, 1, 1, 2 }, below = { 3, 4, 4, 4, 4, 5 };
        for (int c = 0; c < top.Length; c++)
        {
            var t = Box(ledge, "Ground", new Vector2(0, 0), new Vector2(40 + c * 64, 96), new Vector2(64, 64));
            Picture(t, Village.Ground(top[c]), Color.white);
            var b = Box(ledge, "Ground", new Vector2(0, 0), new Vector2(40 + c * 64, 32), new Vector2(64, 64));
            Picture(b, Village.Ground(below[c]), Color.white);
        }
        var her = Box(root, "Janani", new Vector2(0, 0), new Vector2(200, 128 + 168), new Vector2(336, 336));
        her.pivot = new Vector2(0.5f, 0);
        her.anchoredPosition = new Vector2(205, 126);
        var look = Picture(her, null, Color.white);
        look.preserveAspect = true;
        var flip = her.gameObject.AddComponent<UIFlip>();
        flip.frames = Art.Strip("Janani/beta7_idle", 10, 210, 210, 105); // (her idle strip: 10 frames of 210 px)
        flip.fps = 6;
        // the darker frame around it all
        var edge = Box(root, "Vignette", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(3000, 1700));
        Picture(edge, Vignette(), new Color(0.04f, 0.02f, 0.08f, 1f));
    }

    /// <summary>The logo: GRACY in gold with a soft glow behind it, "The Adventurer" between two fine lines.</summary>
    public static RectTransform Logo(RectTransform root, Font font, Vector2 pos)
    {
        var logo = Box(root, "Logo", new Vector2(0.5f, 1), pos, new Vector2(700, 260));
        Picture(Box(logo, "Glow", new Vector2(0.5f, 0.5f), new Vector2(0, 10), new Vector2(760, 300)), Shapes.Glow(), new Color(1f, 0.8f, 0.45f, 0.28f));
        Text Words(string s, Vector2 at, int size, Color color, int outline)
        {
            var rt = Box(logo, "Words", new Vector2(0.5f, 0.5f), at, new Vector2(800, size * 1.6f));
            var t = rt.gameObject.AddComponent<Text>();
            t.text = s;
            t.font = font;
            t.fontSize = size;
            t.color = color;
            t.alignment = TextAnchor.MiddleCenter;
            t.raycastTarget = false;
            var o = rt.gameObject.AddComponent<Outline>();
            o.effectColor = new Color(0.16f, 0.07f, 0.22f, 0.95f);
            o.effectDistance = new Vector2(outline, -outline);
            var sh = rt.gameObject.AddComponent<Shadow>();
            sh.effectColor = new Color(0, 0, 0, 0.6f);
            sh.effectDistance = new Vector2(3, -6);
            return t;
        }
        Words("GRACY", new Vector2(0, 30), 150, new Color(1f, 0.85f, 0.45f), 4);
        Words("The Adventurer", new Vector2(0, -78), 40, new Color(1f, 0.95f, 0.86f), 2);
        foreach (int side in new[] { -1, 1 })
        {
            var line = Box(logo, "Line", new Vector2(0.5f, 0.5f), new Vector2(side * 225, -78), new Vector2(120, 3));
            Picture(line, Shapes.Glow(), new Color(1f, 0.85f, 0.5f, 0.9f));
        }
        logo.gameObject.AddComponent<Bob>();
        return logo;
    }
}

/// <summary>A UI picture playing frames (Janani on the title screen).</summary>
public class UIFlip : MonoBehaviour
{
    public Sprite[] frames;
    public float fps = 6;
    Image img;

    void Update()
    {
        if (frames == null || frames.Length == 0) return;
        img ??= GetComponent<Image>();
        img.sprite = frames[(int)(Time.unscaledTime * fps) % frames.Length];
    }
}

/// <summary>Brightens and dims slowly (the light rays).</summary>
public class Breathe : MonoBehaviour
{
    float low, high, speed;
    Image img;

    public void Setup(float low, float high, float speed) { this.low = low; this.high = high; this.speed = speed; }

    void Update()
    {
        img ??= GetComponent<Image>();
        var c = img.color;
        c.a = Mathf.Lerp(low, high, 0.5f + 0.5f * Mathf.Sin(Time.unscaledTime * speed * Mathf.PI * 2 + speed * 10));
        img.color = c;
    }
}

/// <summary>Moves slowly sideways and comes round again (the fog).</summary>
public class Drift : MonoBehaviour
{
    public float speed = 15;

    void Update()
    {
        var rt = (RectTransform)transform;
        float x = rt.anchoredPosition.x + speed * Time.unscaledDeltaTime;
        if (x > 700) x -= 1400;
        rt.anchoredPosition = new Vector2(x, rt.anchoredPosition.y);
    }
}

/// <summary>A glowing mote rising slowly, swaying, fading near the top, then starting again at the bottom.</summary>
public class Mote : MonoBehaviour
{
    float x, phase, speed;
    Image img;

    public void Setup(float across, float start)
    {
        x = across;
        phase = start;
        speed = 0.03f + across * 0.03f;
    }

    void Update()
    {
        img ??= GetComponent<Image>();
        var canvas = (RectTransform)transform.parent;
        phase = (phase + speed * Time.unscaledDeltaTime) % 1f;
        float w = canvas.rect.width, h = canvas.rect.height;
        ((RectTransform)transform).anchoredPosition = new Vector2(x * w + Mathf.Sin(phase * 12 + x * 20) * 18, phase * h);
        var c = img.color;
        c.a = 0.75f * Mathf.Sin(phase * Mathf.PI);
        img.color = c;
    }
}

/// <summary>Floats gently up and down (the logo).</summary>
public class Bob : MonoBehaviour
{
    Vector2 home;
    bool set;

    void Update()
    {
        var rt = (RectTransform)transform;
        if (!set) { home = rt.anchoredPosition; set = true; }
        rt.anchoredPosition = home + new Vector2(0, Mathf.Sin(Time.unscaledTime * 1.1f) * 7);
    }
}

/// <summary>Slides up into place and fades in after a delay (the title's buttons, one after another).</summary>
public class Reveal : MonoBehaviour
{
    public float delay;
    Vector2 home;
    float t;
    CanvasGroup group;

    void Start()
    {
        home = ((RectTransform)transform).anchoredPosition;
        group = gameObject.AddComponent<CanvasGroup>();
        group.alpha = 0;
    }

    void Update()
    {
        t += Time.unscaledDeltaTime;
        float k = Mathf.Clamp01((t - delay) / 0.45f);
        float e = 1 - (1 - k) * (1 - k) * (1 - k);
        group.alpha = e;
        ((RectTransform)transform).anchoredPosition = home + new Vector2(0, -40 * (1 - e));
        if (k >= 1) enabled = false;
    }
}
