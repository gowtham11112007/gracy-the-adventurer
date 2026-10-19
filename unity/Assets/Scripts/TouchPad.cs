using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

/// <summary>
/// The phone's on-screen buttons (the owner's layout): left and right under the left thumb; under the right thumb
/// up, jump and down in a column. Every finger is tracked, so she can run
/// and jump at once; each finger presses only the button it is nearest to, with a generous reach because thumbs
/// aren't precise. The buttons press the same actions as the keyboard (GameInput.Touch).
/// Laid out on a 720-high canvas measured from the bottom corners, so wider phones just spread them further apart.
/// Shown on phones, or on a computer when started with  -touch.
/// </summary>
[DefaultExecutionOrder(-200)] // (before GameInput reads the actions)
public class TouchPad : MonoBehaviour
{
    const float Reach = 1.45f; // a finger this many radii from a button's middle still presses it

    class Button
    {
        public Act act;
        public bool rightSide;
        public Vector2 offset;
        public float radius;
        public Image disc, icon;
    }

    readonly List<Button> buttons = new();
    Canvas canvas;

    public static bool Wanted() =>
        Application.isMobilePlatform || Touchscreen.current != null || Environment.GetCommandLineArgs().Contains("-touch");

    public static TouchPad Create()
    {
        var go = new GameObject("Touch Pad");
        var c = go.AddComponent<Canvas>();
        c.renderMode = RenderMode.ScreenSpaceOverlay;
        c.sortingOrder = 50;
        var scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720);
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
        scaler.matchWidthOrHeight = 1; // always 720 high, like the Godot version
        var pad = go.AddComponent<TouchPad>();
        pad.canvas = c;
        pad.Build();
        return pad;
    }

    void Build()
    {
        // carved stone buttons from the Adventure UI Kit (the same stone as the pause button and the menus)
        var arrow = Resources.Load<Sprite>("Art/Menu/Next");
        var plain = Resources.Load<Sprite>("Art/Menu/btn_uncheck");
        Add(Act.Left, false, new Vector2(118, 128), 72, arrow, 180, null);
        Add(Act.Right, false, new Vector2(300, 128), 72, arrow, 0, null);
        var column = new Vector2(-150, 230); // jump in the middle, up above it, down below
        Add(Act.Jump, true, column, 68, plain, 0, Icons.Jump());
        Add(Act.Up, true, column + new Vector2(0, 118), 52, arrow, 90, null);
        Add(Act.Down, true, column + new Vector2(0, -118), 52, arrow, 270, null);
        // (the magic button comes back when there's magic to throw)
    }

    /// <summary>A button: a stone face (turned for the arrows), with an icon on it if it has one.</summary>
    void Add(Act act, bool rightSide, Vector2 offset, float radius, Sprite face, float turn, Sprite icon)
    {
        var b = new Button { act = act, rightSide = rightSide, offset = offset, radius = radius };
        var go = new GameObject(act.ToString(), typeof(RectTransform));
        go.transform.SetParent(transform, false);
        var rt = (RectTransform)go.transform;
        rt.anchorMin = rt.anchorMax = rightSide ? new Vector2(1, 0) : Vector2.zero;
        rt.anchoredPosition = offset;
        rt.sizeDelta = Vector2.one * radius * 2;
        var stone = new GameObject("Stone", typeof(RectTransform));
        stone.transform.SetParent(go.transform, false);
        var srt = (RectTransform)stone.transform;
        srt.sizeDelta = Vector2.one * radius * 1.7f;
        srt.localEulerAngles = new Vector3(0, 0, turn);
        b.disc = stone.AddComponent<Image>();
        b.disc.sprite = face != null ? face : Icons.Disc();
        b.disc.preserveAspect = true;
        b.disc.raycastTarget = false;
        if (icon == null)
        {
            buttons.Add(b);
            return;
        }
        var pic = new GameObject("Icon", typeof(RectTransform));
        pic.transform.SetParent(go.transform, false);
        var prt = (RectTransform)pic.transform;
        prt.sizeDelta = Vector2.one * radius * (act == Act.Shoot ? 1.0f : 0.9f);
        b.icon = pic.AddComponent<Image>();
        b.icon.sprite = icon;
        b.icon.preserveAspect = true;
        b.icon.raycastTarget = false;
        buttons.Add(b);
    }

    /// <summary>The button a point on the canvas presses: the nearest one in reach (null for none).</summary>
    public Act? ButtonAt(Vector2 point)
    {
        float canvasWide = Screen.width / canvas.scaleFactor;
        Act? best = null;
        float bestDistance = float.MaxValue;
        foreach (var b in buttons)
        {
            var center = b.rightSide ? new Vector2(canvasWide + b.offset.x, b.offset.y) : b.offset;
            float d = Vector2.Distance(point, center) / b.radius;
            if (d < Reach && d < bestDistance)
            {
                best = b.act;
                bestDistance = d;
            }
        }
        return best;
    }

    void Update()
    {
        canvas.enabled = !GameInput.Blocked && Time.timeScale > 0; // (hidden under the pause menu and at the end)
        GameInput.Touch.Clear();
        var points = new List<Vector2>();
        if (Touchscreen.current != null)
            foreach (var t in Touchscreen.current.touches)
                if (t.press.isPressed)
                    points.Add(t.position.ReadValue());
        if (points.Count == 0 && Mouse.current != null && Mouse.current.leftButton.isPressed)
            points.Add(Mouse.current.position.ReadValue()); // (trying it with a mouse on a computer)
        foreach (var p in points)
            if (ButtonAt(p / canvas.scaleFactor) is Act act)
                GameInput.Touch.Add(act);
        foreach (var b in buttons)
        {
            bool on = GameInput.Touch.Contains(b.act) || GameInput.Held(b.act);
            // a held button sinks a little and lights up
            b.disc.color = on ? new Color(1f, 0.95f, 1f, 1f) : new Color(1, 1, 1, 0.82f);
            b.disc.transform.localScale = Vector3.one * (on ? 0.92f : 1f);
            if (b.icon != null)
                b.icon.color = on ? new Color(1f, 0.85f, 0.45f) : new Color(1f, 0.82f, 0.4f, 0.9f);
        }
    }
}

/// <summary>The touch buttons' pictures, drawn once in code: a dark glass disc with a light ring, and white icons.</summary>
static class Icons
{
    static Sprite disc, arrow, jump;

    internal static void Fresh() => disc = arrow = jump = null;

    static Sprite Draw(int size, Func<float, float, Color> paint)
    {
        var tex = new Texture2D(size, size, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp };
        var px = new Color[size * size];
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                // four samples per pixel: smooth edges
                Color sum = Color.clear;
                for (int s = 0; s < 4; s++)
                    sum += paint((x + 0.25f + 0.5f * (s % 2)) / size, (y + 0.25f + 0.5f * (s / 2)) / size);
                px[y * size + x] = sum / 4;
            }
        tex.SetPixels(px);
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100);
    }

    static float Segment(float x, float y, Vector2 a, Vector2 b)
    {
        var p = new Vector2(x, y);
        var ab = b - a;
        float t = Mathf.Clamp01(Vector2.Dot(p - a, ab) / ab.sqrMagnitude);
        return Vector2.Distance(p, a + ab * t);
    }

    static bool InTriangle(float x, float y, Vector2 a, Vector2 b, Vector2 c)
    {
        float Side(Vector2 p1, Vector2 p2) => (x - p2.x) * (p1.y - p2.y) - (p1.x - p2.x) * (y - p2.y);
        float d1 = Side(a, b), d2 = Side(b, c), d3 = Side(c, a);
        bool neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
        return !(neg && pos);
    }

    public static Sprite Disc() => disc ??= Draw(160, (x, y) =>
    {
        float d = Vector2.Distance(new Vector2(x, y), new Vector2(0.5f, 0.5f));
        if (d > 0.5f) return Color.clear;
        if (d > 0.475f) return new Color(1, 1, 1, 0.45f);      // the light ring
        return new Color(0.02f, 0.03f, 0.06f, 0.3f);            // dark glass
    });

    public static Sprite Arrow() => arrow ??= Draw(96, (x, y) =>
        InTriangle(x, y, new Vector2(0.78f, 0.5f), new Vector2(0.3f, 0.2f), new Vector2(0.3f, 0.8f)) ? Color.white : Color.clear);

    // an arrow springing off a line (not the same as Up)
    public static Sprite Jump() => jump ??= Draw(96, (x, y) =>
        InTriangle(x, y, new Vector2(0.5f, 0.86f), new Vector2(0.2f, 0.42f), new Vector2(0.8f, 0.42f)) ||
        (y > 0.2f && y < 0.28f && x > 0.2f && x < 0.8f) ? Color.white : Color.clear);
}
