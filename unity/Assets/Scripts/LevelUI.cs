using System.Collections;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// The level's words on screen, like a film title: "LEVEL 1" and its name fade in when it starts and fade away;
/// at the end (the Stone of Recall) "Level Complete" stays. In the Bloodlines pack's MedievalSharp font (OFL).
/// </summary>
public class LevelUI : MonoBehaviour
{
    public static LevelUI Instance { get; private set; }
    public bool Done { get; private set; }

    static readonly Color Gold = new(0.95f, 0.82f, 0.52f);
    static readonly Color Mist = new(0.92f, 0.9f, 0.86f, 0.9f);
    CanvasGroup group;
    Text over, title;
    string levelName;

    public static LevelUI Create(string level, string name)
    {
        var go = new GameObject("Level Words");
        var canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 60;
        var scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720);
        scaler.matchWidthOrHeight = 1;
        var ui = go.AddComponent<LevelUI>();
        Instance = ui;
        ui.Build();
        ui.levelName = name;
        ui.StartCoroutine(ui.Show(level.ToUpper(), name, 2.6f));
        return ui;
    }

    Text Line(string name, float y, int size, Color color)
    {
        var go = new GameObject(name, typeof(RectTransform));
        go.transform.SetParent(group.transform, false);
        var rt = (RectTransform)go.transform;
        rt.anchorMin = new Vector2(0, 0.5f);
        rt.anchorMax = new Vector2(1, 0.5f);
        rt.anchoredPosition = new Vector2(0, y);
        rt.sizeDelta = new Vector2(0, size * 1.6f);
        var t = go.AddComponent<Text>();
        var font = Resources.Load<Font>("Fonts/MedievalSharp-Regular");
        t.font = font != null ? font : Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
        t.fontSize = size;
        t.alignment = TextAnchor.MiddleCenter;
        t.color = color;
        t.raycastTarget = false;
        var shadow = go.AddComponent<Shadow>();
        shadow.effectColor = new Color(0, 0, 0, 0.65f);
        shadow.effectDistance = new Vector2(2, -3);
        return t;
    }

    void Build()
    {
        var g = new GameObject("Words", typeof(RectTransform));
        g.transform.SetParent(transform, false);
        var rt = (RectTransform)g.transform;
        rt.anchorMin = Vector2.zero;
        rt.anchorMax = Vector2.one;
        rt.offsetMin = rt.offsetMax = Vector2.zero;
        group = g.AddComponent<CanvasGroup>();
        group.alpha = 0;
        group.blocksRaycasts = false;
        over = Line("Over", 150, 26, Mist);
        title = Line("Title", 96, 64, Gold);
    }

    IEnumerator Show(string top, string big, float hold)
    {
        over.text = top;
        title.text = big;
        for (float t = 0; t < 1; t += Time.deltaTime / 0.9f)
        {
            group.alpha = t;
            yield return null;
        }
        group.alpha = 1;
        if (hold <= 0)
            yield break; // (stays)
        yield return new WaitForSeconds(hold);
        for (float t = 1; t > 0; t -= Time.deltaTime / 0.9f)
        {
            group.alpha = t;
            yield return null;
        }
        group.alpha = 0;
    }

    /// <summary>After a moment, the "Level Complete" panel with its stars (and the words above make way).</summary>
    IEnumerator ShowStars()
    {
        yield return new WaitForSeconds(1.6f);
        group.alpha = 0;
        var room = FindAnyObjectByType<Room>();
        if (MenuUI.Instance != null)
            MenuUI.Instance.Complete(room != null && room.Player != null ? room.Player.Gems : 0);
    }

    /// <summary>She reached the end of the level.</summary>
    public void Finished()
    {
        if (Done)
            return;
        Done = true;
        GameInput.Blocked = true; // (she stops at the stone)
        StopAllCoroutines();
        StartCoroutine(Show(levelName.ToUpper(), "Level Complete", 0));
        StartCoroutine(ShowStars());
    }
}
