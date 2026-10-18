using UnityEngine;

/// <summary>
/// One layer of the painted background: it moves with the camera, `scroll` of the way behind it (0.1 = far away),
/// repeating sideways so it never runs out, and always fills the screen from top to bottom.
/// </summary>
[DefaultExecutionOrder(100)] // (after the camera has moved)
public class Parallax : MonoBehaviour
{
    float scroll;
    float width;
    Transform[] copies;

    public static Parallax Create(Transform parent, Sprite picture, float scroll, int order)
    {
        var go = new GameObject("Background " + order);
        go.transform.SetParent(parent, false);
        var layer = go.AddComponent<Parallax>();
        layer.scroll = scroll;
        layer.width = picture.bounds.size.x;
        layer.copies = new Transform[3];
        for (int i = 0; i < 3; i++)
        {
            var copy = new GameObject("Copy " + i);
            copy.transform.SetParent(go.transform, false);
            var sr = copy.AddComponent<SpriteRenderer>();
            sr.sprite = picture;
            sr.sortingOrder = order;
            layer.copies[i] = copy.transform;
        }
        return layer;
    }

    void LateUpdate()
    {
        var cam = Camera.main;
        if (cam == null)
            return;
        var c = cam.transform.position;
        float x0 = c.x * (1 - scroll);              // the layer lags behind the camera
        float k = Mathf.Floor((c.x - x0) / width);  // which copy the camera is over
        for (int i = 0; i < 3; i++)
            copies[i].localPosition = new Vector3((k - 1 + i) * width, 0, 0);
        float bottom = c.y - cam.orthographicSize;
        float stretch = cam.orthographicSize * 2 / copies[0].GetComponent<SpriteRenderer>().sprite.bounds.size.y;
        transform.position = new Vector3(x0, bottom, 0);
        transform.localScale = new Vector3(1, Mathf.Max(1, stretch), 1);
    }
}
