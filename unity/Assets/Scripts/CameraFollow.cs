using UnityEngine;

/// <summary>
/// The camera follows Janani smoothly, looking a little ahead of where she faces and a little above her feet,
/// and never shows past the room's edges. The view is 720 game pixels high (11.25 tiles), as in Godot.
/// </summary>
public class CameraFollow : MonoBehaviour
{
    const float Lean = 150f / 64f, Above = 150f / 64f;
    Janani target;
    float width;
    float lean = Lean;
    Vector3 velocity;
    Camera cam;
    /// <summary>The title screen: the camera drifts slowly along the level instead of following her.</summary>
    public bool Drift;

    public void Follow(Janani j, float roomWidth)
    {
        target = j;
        width = roomWidth;
        cam = GetComponent<Camera>();
        cam.orthographic = true;
        cam.orthographicSize = 720f / 64f / 2f;
        transform.position = Wanted(); // (start there: no swoop on the first frame)
    }

    Vector3 Wanted()
    {
        float half = cam.orthographicSize, halfWide = half * cam.aspect;
        var p = target.transform.position;
        float x = Mathf.Clamp(p.x + lean, halfWide, Mathf.Max(halfWide, width - halfWide));
        float y = Mathf.Clamp(p.y + Above, half, Mathf.Max(half, Room.Rows - half));
        return new Vector3(x, y, -10);
    }

    void LateUpdate()
    {
        if (target == null)
            return;
        if (Drift)
        {
            float half = cam.orthographicSize, halfWide = half * cam.aspect;
            float span = Mathf.Max(0, width - 2 * halfWide);
            transform.position = new Vector3(halfWide + Mathf.PingPong(Time.time * 0.8f, span), half + 0.4f, -10);
            return;
        }
        lean = Mathf.MoveTowards(lean, target.FacingLeft ? -Lean : Lean, 3f * Time.deltaTime);
        transform.position = Vector3.SmoothDamp(transform.position, Wanted(), ref velocity, 0.12f);
    }
}
