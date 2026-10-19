using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

/// <summary>
/// The menus, in the Asset Store "Adventure UI Kit" (soft purple stone panels and buttons, Resources/Art/Menu):
/// the title screen (Play, Options, Quit) over a quiet view of Level 1; the Options pop-up (music and sound on/off);
/// in a level the pause button (Resume, Restart, Options, Exit to the title); and "Level Complete" with its three
/// stars (play again, or back to the title). Back (Esc, the phone's Back button) closes the newest pop-up, pauses a
/// level, or on the title leaves the game. Words are in the Bloodlines pack's MedievalSharp font (OFL).
/// </summary>
public class MenuUI : MonoBehaviour
{
    public static MenuUI Instance { get; private set; }
    internal static void Fresh() => Instance = null;

    static readonly Color Gold = new(0.98f, 0.84f, 0.5f);
    static readonly Color Cream = new(1f, 0.95f, 0.86f);
    RectTransform root;
    GameObject popup;   // the open pop-up (pause, options, complete)
    GameObject pauseButton;
    bool title, paused;
    AudioSource click;

    static Sprite Pic(string name) => Resources.Load<Sprite>("Art/Menu/" + name);

    public static Font Medieval
    {
        get
        {
            var f = Resources.Load<Font>("Fonts/MedievalSharp-Regular");
            return f != null ? f : Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        }
    }

    static MenuUI Create()
    {
        var go = new GameObject("Menus");
        var canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 80;
        var scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720);
        scaler.matchWidthOrHeight = 1;
        go.AddComponent<GraphicRaycaster>();
        if (FindAnyObjectByType<EventSystem>() == null) // (buttons need one to be pressed)
            new GameObject("EventSystem", typeof(EventSystem), typeof(InputSystemUIInputModule));
        var ui = go.AddComponent<MenuUI>();
        ui.root = (RectTransform)go.transform;
        ui.click = go.AddComponent<AudioSource>();
        ui.click.clip = Resources.Load<AudioClip>("Audio/Click Button SFX");
        ui.click.playOnAwake = false;
        Flow.Sound(ui.click);
        Instance = ui;
        return ui;
    }

    // ------------------------------------------------------------------ pieces

    static RectTransform Rect(Transform parent, string name, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        var go = new GameObject(name, typeof(RectTransform));
        go.transform.SetParent(parent, false);
        var rt = (RectTransform)go.transform;
        rt.anchorMin = rt.anchorMax = anchor;
        rt.pivot = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = pos;
        rt.sizeDelta = size;
        return rt;
    }

    static Image Picture(RectTransform on, Sprite sprite, bool raycast = false)
    {
        var img = on.gameObject.AddComponent<Image>();
        img.sprite = sprite;
        img.preserveAspect = true;
        img.raycastTarget = raycast;
        return img;
    }

    static Text Words(Transform parent, string text, Vector2 anchor, Vector2 pos, int size, Color color, float wide = 900)
    {
        var rt = Rect(parent, "Words", anchor, pos, new Vector2(wide, size * 1.7f));
        var t = rt.gameObject.AddComponent<Text>();
        t.text = text;
        t.font = Medieval;
        t.fontSize = size;
        t.color = color;
        t.alignment = TextAnchor.MiddleCenter;
        t.raycastTarget = false;
        var shadow = rt.gameObject.AddComponent<Shadow>();
        shadow.effectColor = new Color(0.1f, 0.05f, 0.15f, 0.75f);
        shadow.effectDistance = new Vector2(2, -3);
        return t;
    }

    /// <summary>A button from one of the kit's pictures; it grows a little under the finger and clicks.</summary>
    Button Press(Transform parent, string picture, Vector2 anchor, Vector2 pos, float high, Action action)
    {
        var sprite = Pic(picture);
        float wide = sprite != null ? high * sprite.rect.width / sprite.rect.height : high;
        var rt = Rect(parent, picture, anchor, pos, new Vector2(wide, high));
        var img = Picture(rt, sprite, true);
        var b = rt.gameObject.AddComponent<Button>();
        b.targetGraphic = img;
        var colors = b.colors;
        colors.highlightedColor = new Color(1f, 0.95f, 1f);
        colors.pressedColor = new Color(0.85f, 0.8f, 0.95f);
        b.colors = colors;
        rt.gameObject.AddComponent<PressScale>();
        b.onClick.AddListener(() =>
        {
            click.Play();
            action();
        });
        return b;
    }

    /// <summary>A pop-up: the screen dims (and can't be pressed through) and a panel appears in the middle.</summary>
    RectTransform Popup(string panel, Vector2 size)
    {
        Close();
        popup = new GameObject("Popup", typeof(RectTransform));
        popup.transform.SetParent(root, false);
        var full = (RectTransform)popup.transform;
        full.anchorMin = Vector2.zero;
        full.anchorMax = Vector2.one;
        full.offsetMin = full.offsetMax = Vector2.zero;
        var dim = popup.AddComponent<Image>();
        dim.color = new Color(0.05f, 0.03f, 0.1f, 0.6f);
        var sheet = Rect(full, "Panel", new Vector2(0.5f, 0.5f), Vector2.zero, size);
        Picture(sheet, Pic(panel));
        popup.AddComponent<PopIn>();
        return sheet;
    }

    void Close()
    {
        if (popup != null)
            Destroy(popup);
        popup = null;
    }

    // ------------------------------------------------------------- the screens

    /// <summary>The title screen: the game's name and Play / Options / Quit, over a quiet view of Level 1.</summary>
    public static void Title()
    {
        var ui = Create();
        ui.title = true;
        // the picture behind it all: mountain peaks rising through clouds, drifting very slowly
        var back = Rect(ui.root, "Mountains", new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(1280, 720));
        var bg = Picture(back, Pic("MainBackground2"));
        bg.preserveAspect = false;
        back.gameObject.AddComponent<SlowDrift>();
        // light rays, fog, rising motes, Janani on her ledge, and a darker frame (TitleFx)
        TitleFx.Scenery(ui.root);
        // the logo and the buttons, a little right of the middle (Janani stands on the left)
        TitleFx.Logo(ui.root, Medieval, new Vector2(150, -175));
        var play = ui.Press(ui.root, "btn_play", new Vector2(0.5f, 0), new Vector2(150, 285), 96, Flow.Play);
        var options = ui.Press(ui.root, "btn_options", new Vector2(0.5f, 0), new Vector2(150, 180), 70, ui.Options);
        var quit = ui.Press(ui.root, "btn_quit", new Vector2(0.5f, 0), new Vector2(150, 98), 70, Application.Quit);
        float delay = 0.5f;
        foreach (var b in new[] { play, options, quit })
        {
            b.gameObject.AddComponent<Reveal>().delay = delay;
            delay += 0.18f;
        }
    }

    /// <summary>In a level: the pause button at the top right.</summary>
    public static void InGame()
    {
        var ui = Create();
        ui.pauseButton = ui.Press(ui.root, "icon_pause", new Vector2(1, 1), new Vector2(-62, -58), 76, ui.Pause).gameObject;
    }

    void Options()
    {
        bool back = paused; // (opened from the pause menu: closing it goes back there)
        var sheet = Popup("popup_bg", new Vector2(460, 440));
        Words(sheet, "Options", new Vector2(0.5f, 1), new Vector2(0, -70), 46, Gold, 400);
        Switch(sheet, "Music", -170, () => Flow.MusicOn, v => Flow.MusicOn = v);
        Switch(sheet, "Sound", -265, () => Flow.SoundOn, v => Flow.SoundOn = v);
        Press(sheet, "btn_close", new Vector2(1, 1), new Vector2(-40, -40), 58, () =>
        {
            if (back) Pause(); else Close();
        });
    }

    void Switch(RectTransform sheet, string name, float y, Func<bool> get, Action<bool> set)
    {
        Words(sheet, name, new Vector2(0.5f, 1), new Vector2(-80, y), 36, Cream, 200);
        Button b = null;
        b = Press(sheet, get() ? "btn_toggle_on" : "btn_toggle_off", new Vector2(0.5f, 1), new Vector2(105, y), 62, () =>
        {
            set(!get());
            ((Image)b.targetGraphic).sprite = Pic(get() ? "btn_toggle_on" : "btn_toggle_off");
        });
    }

    public void Pause()
    {
        paused = true;
        Time.timeScale = 0;
        var sheet = Popup("popup_bg", new Vector2(460, 470));
        Words(sheet, "Paused", new Vector2(0.5f, 1), new Vector2(0, -68), 46, Gold, 400);
        Press(sheet, "btn_resume", new Vector2(0.5f, 1), new Vector2(0, -150), 66, Resume);
        Press(sheet, "btn_restart", new Vector2(0.5f, 1), new Vector2(0, -230), 66, Flow.Restart);
        Press(sheet, "btn_options", new Vector2(0.5f, 1), new Vector2(0, -310), 66, Options);
        Press(sheet, "btn_exit", new Vector2(0.5f, 1), new Vector2(0, -390), 66, Flow.ToTitle);
    }

    void Resume()
    {
        paused = false;
        Time.timeScale = 1;
        Close();
    }

    /// <summary>The end of the level: three stars, the gems found, play again or back to the title.</summary>
    public void Complete(int gems)
    {
        if (pauseButton != null)
            pauseButton.SetActive(false);
        var sheet = Popup("bg_mission_compelete", new Vector2(400, 456));
        Words(sheet, "Level Complete", new Vector2(0.5f, 0.5f), new Vector2(0, 40), 40, Gold, 380);
        Words(sheet, $"Gems  {gems}", new Vector2(0.5f, 0.5f), new Vector2(0, -20), 30, Cream, 380);
        Press(sheet, "icon_replay", new Vector2(0.5f, 0), new Vector2(-60, 60), 74, Flow.Restart);
        Press(sheet, "icon_home", new Vector2(0.5f, 0), new Vector2(60, 60), 74, Flow.ToTitle);
    }

    void Update()
    {
        // Back: Esc on a computer, the Back button on a phone
        var k = Keyboard.current;
        if (k == null || !k.escapeKey.wasPressedThisFrame)
            return;
        if (title)
        {
            if (popup != null) Close(); else Application.Quit();
        }
        else if (paused) Resume();
        else if (popup == null) Pause();
    }
}

/// <summary>The title picture: always covers the whole screen, and drifts and breathes very slowly.</summary>
public class SlowDrift : MonoBehaviour
{
    void Update()
    {
        var rt = (RectTransform)transform;
        var canvas = (RectTransform)rt.parent;
        float cover = Mathf.Max(canvas.rect.width / 1280f, canvas.rect.height / 720f) * 1.12f;
        float t = Time.unscaledTime;
        rt.sizeDelta = new Vector2(1280, 720) * cover * (1 + 0.03f * Mathf.Sin(t * 0.12f));
        rt.anchoredPosition = new Vector2(Mathf.Sin(t * 0.07f) * 40, Mathf.Cos(t * 0.05f) * 12);
    }
}

/// <summary>A button grows a little while it's held down.</summary>
public class PressScale : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IPointerExitHandler
{
    public void OnPointerDown(PointerEventData e) => transform.localScale = Vector3.one * 1.06f;
    public void OnPointerUp(PointerEventData e) => transform.localScale = Vector3.one;
    public void OnPointerExit(PointerEventData e) => transform.localScale = Vector3.one;
}

/// <summary>A pop-up rises in softly (it works while the game is paused).</summary>
public class PopIn : MonoBehaviour
{
    float t;

    void Update()
    {
        t = Mathf.Min(1, t + Time.unscaledDeltaTime / 0.25f);
        float e = 1 - (1 - t) * (1 - t) * (1 - t);
        var group = GetComponent<CanvasGroup>();
        if (group == null)
            group = gameObject.AddComponent<CanvasGroup>();
        group.alpha = e;
        if (transform.childCount > 0)
            transform.GetChild(0).localScale = Vector3.one * (0.9f + 0.1f * e);
    }
}
