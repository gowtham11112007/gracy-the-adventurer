using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Janani's health along the top left (instead of hearts): her portrait in a gold-ringed medallion, and the red bar
/// of the Bloodlines pack (Asset Store, Alebardium) in its dark carved frame. After a hit a pale "trail" shows what
/// was lost, then drains away; healing fills smoothly; when health is low the bar pulses. Gems are counted below.
/// On a 720-high canvas like the buttons.
/// </summary>
public class HealthBar : MonoBehaviour
{
    const float BarWide = 360, BarHigh = 50; // (the Bloodlines bar is 793 x 109)
    static readonly Color Gold = new(0.91f, 0.78f, 0.49f);
    static readonly Color Glass = new(0.03f, 0.05f, 0.09f, 0.72f);

    Janani janani;
    Image fill, trailBar, glow;
    Text gems;
    float shown = 1, trail = 1, trailWait;

    public static HealthBar Create(Janani j)
    {
        var go = new GameObject("Health Bar");
        var canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 40;
        var scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720);
        scaler.matchWidthOrHeight = 1;
        var bar = go.AddComponent<HealthBar>();
        bar.janani = j;
        bar.Build();
        return bar;
    }

    static RectTransform Box(Transform parent, string name, Vector2 pos, Vector2 size)
    {
        var go = new GameObject(name, typeof(RectTransform));
        go.transform.SetParent(parent, false);
        var rt = (RectTransform)go.transform;
        rt.anchorMin = rt.anchorMax = new Vector2(0, 1); // measured from the top left
        rt.pivot = new Vector2(0, 1);
        rt.anchoredPosition = pos;
        rt.sizeDelta = size;
        return rt;
    }

    static Image Picture(RectTransform on, Sprite sprite, Color color, bool sliced = false)
    {
        var img = on.gameObject.AddComponent<Image>();
        img.sprite = sprite;
        img.color = color;
        img.raycastTarget = false;
        if (sliced) img.type = Image.Type.Sliced;
        return img;
    }

    /// <summary>A rect filling its parent (less `inset` on every side), for layers inside a box.</summary>
    static RectTransform Fill(Transform parent, string name, float inset = 0)
    {
        var go = new GameObject(name, typeof(RectTransform));
        go.transform.SetParent(parent, false);
        var rt = (RectTransform)go.transform;
        rt.anchorMin = Vector2.zero;
        rt.anchorMax = Vector2.one;
        rt.offsetMin = Vector2.one * inset;
        rt.offsetMax = -Vector2.one * inset;
        return rt;
    }

    void Build()
    {
        // the bar: the empty carved frame, the pale trail, then the red health filling it from the left
        var frame = Box(transform, "Bar", new Vector2(98, -32), new Vector2(BarWide, BarHigh));
        var glowRt = Box(transform, "Glow", new Vector2(70, -10), new Vector2(BarWide + 60, BarHigh + 44));
        glow = Picture(glowRt, Shapes.Glow(), new Color(1f, 0.35f, 0.4f, 0.16f));
        Picture(frame, Resources.Load<Sprite>("Art/UI/Progress_Bar_Rectangle_empty_v5"), Color.white);
        trailBar = Picture(Fill(frame, "Trail"), Resources.Load<Sprite>("Art/UI/Progress_Bar_Rectangle_full_v5"), new Color(1f, 0.9f, 0.8f, 0.75f));
        fill = Picture(Fill(frame, "Health"), Resources.Load<Sprite>("Art/UI/Progress_Bar_Rectangle_full_v5"), Color.white);
        foreach (var bar in new[] { trailBar, fill })
        {
            bar.type = Image.Type.Filled;
            bar.fillMethod = Image.FillMethod.Horizontal;
            bar.fillOrigin = (int)Image.OriginHorizontal.Left;
        }

        // the medallion: her portrait in a circle with a gold ring
        var medal = Box(transform, "Medallion", new Vector2(22, -14), new Vector2(92, 92));
        Picture(medal, Shapes.Disc(), Glass);
        var face = Fill(medal, "Portrait", 5);
        Picture(face, Shapes.Disc(), Color.white);
        face.gameObject.AddComponent<Mask>().showMaskGraphic = false;
        Picture(Fill(face, "Face"), Art.Picture("Props/portrait_janani", new Vector2(0.5f, 0.5f)), Color.white);
        Picture(Fill(medal, "Ring"), Shapes.Ring(), Gold);

        // gems under the bar
        var gemArt = Art.Strip("Props/gem", 3, 32, 42, 16);
        if (gemArt.Length > 0)
            Picture(Box(transform, "Gem", new Vector2(124, -88), new Vector2(18, 24)), gemArt[0], Color.white);
        var label = Box(transform, "Gems", new Vector2(150, -86), new Vector2(120, 28));
        gems = label.gameObject.AddComponent<Text>();
        gems.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        gems.fontSize = 22;
        gems.fontStyle = FontStyle.Bold;
        gems.color = new Color(1f, 0.96f, 0.88f);
        gems.raycastTarget = false;
    }

    void Update()
    {
        if (janani == null)
            return;
        float target = Mathf.Clamp01(janani.Health / Janani.MaxHealth);
        // the health itself moves quickly; the pale trail waits a moment after a hit, then drains to meet it
        if (target < shown)
            trailWait = 0.45f;
        shown = Mathf.MoveTowards(shown, target, Time.deltaTime * (target > shown ? 0.8f : 3f));
        trailWait -= Time.deltaTime;
        if (trail < shown) trail = shown;
        else if (trailWait <= 0) trail = Mathf.MoveTowards(trail, shown, Time.deltaTime * 0.6f);
        fill.fillAmount = shown;
        trailBar.fillAmount = trail;
        // low health: the bar breathes brighter and the glow reddens
        float low = shown < 0.3f ? 0.5f + 0.5f * Mathf.Sin(Time.time * 6f) : 0;
        fill.color = Color.Lerp(Color.white, new Color(1f, 0.6f, 0.6f), low);
        glow.color = new Color(1f, 0.35f, 0.4f, 0.16f + 0.3f * low);
        gems.text = janani.Gems.ToString();
    }
}

/// <summary>The health bar's shapes, drawn once in code.</summary>
static class Shapes
{
    static Sprite rounded, solid, gradient, glow, disc, ring;

    static Texture2D Paint(int w, int h, System.Func<float, float, Color> paint)
    {
        var tex = new Texture2D(w, h, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
        var px = new Color[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                px[y * w + x] = paint(x + 0.5f, y + 0.5f);
        tex.SetPixels(px);
        tex.Apply();
        return tex;
    }

    static Sprite Whole(Texture2D tex, Vector4 border = default) =>
        Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f), 100, 0, SpriteMeshType.FullRect, border);

    /// <summary>A rounded box: `fill` inside, a thin `edge` line around it (9-sliced: any size keeps its corners).</summary>
    public static Sprite Rounded(Color fill, Color edge) => rounded ??= Whole(Paint(64, 64, (x, y) =>
    {
        const float r = 14, n = 64;
        float dx = Mathf.Max(r - x, x - (n - r), 0), dy = Mathf.Max(r - y, y - (n - r), 0);
        float outside = Mathf.Sqrt(dx * dx + dy * dy) - r; // > 0 outside the rounded box
        if (outside > 0.5f) return Color.clear;
        var c = outside > -2f ? edge : fill;                // a 2-pixel edge
        c.a *= Mathf.Clamp01(0.5f - outside);
        return c;
    }), new Vector4(18, 18, 18, 18));

    public static Sprite Solid() => solid ??= Whole(Paint(4, 4, (x, y) => Color.white));

    /// <summary>Deep rose to coral to warm gold, lighter along the top like light catching glass.</summary>
    public static Sprite HealthGradient() => gradient ??= Whole(Paint(256, 32, (x, y) =>
    {
        float t = x / 256f;
        var c = t < 0.55f
            ? Color.Lerp(new Color(0.55f, 0.06f, 0.2f), new Color(0.96f, 0.36f, 0.42f), t / 0.55f)
            : Color.Lerp(new Color(0.96f, 0.36f, 0.42f), new Color(1f, 0.8f, 0.5f), (t - 0.55f) / 0.45f);
        float v = y / 32f;
        c = Color.Lerp(c * 0.78f, c, Mathf.SmoothStep(0, 1, v * 1.4f)); // darker at the bottom
        if (v > 0.62f && v < 0.8f) c = Color.Lerp(c, Color.white, 0.35f); // the highlight line
        c.a = 1;
        return c;
    }));

    public static Sprite Glow() => glow ??= Whole(Paint(128, 64, (x, y) =>
    {
        float dx = (x - 64) / 64f, dy = (y - 32) / 32f;
        float a = Mathf.Clamp01(1 - (dx * dx + dy * dy));
        return new Color(1, 1, 1, a * a);
    }));

    public static Sprite Disc() => disc ??= Whole(Paint(128, 128, (x, y) =>
        new Color(1, 1, 1, Mathf.Clamp01(63.5f - Vector2.Distance(new Vector2(x, y), new Vector2(64, 64))))));

    public static Sprite Ring() => ring ??= Whole(Paint(128, 128, (x, y) =>
    {
        float d = Vector2.Distance(new Vector2(x, y), new Vector2(64, 64));
        return new Color(1, 1, 1, Mathf.Clamp01(Mathf.Min(63.5f - d, d - 58.5f)));
    }));
}
