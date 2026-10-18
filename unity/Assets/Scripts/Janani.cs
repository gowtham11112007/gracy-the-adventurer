using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Janani: running, the low hop that clears one-tile obstacles, and climbing ladders between floors.
/// Same numbers as the Godot version (its pixels / 64 = units here), so she moves the way she does there.
/// Her body is a box from her feet up (the GameObject's position is her feet); her picture is a Flipbook of the
/// strips listed in Resources/Data/janani.json.
/// </summary>
public class Janani : MonoBehaviour
{
    const float Px = 1f / 64f;
    const float Gravity = 1800 * Px, RunSpeed = 300 * Px, HopSpeed = 540 * Px, HopCut = 240 * Px;
    const float MaxFall = 1100 * Px, FallPull = 1.25f, Coyote = 0.14f, JumpBuffer = 0.18f;
    const float ClimbSpeed = 200 * Px;

    public Room Room { get; private set; }
    public Flipbook Look { get; private set; }
    public bool Climbing { get; private set; }
    public bool Grounded { get; private set; }
    public bool FacingLeft => Look.Renderer.flipX;
    public Vector2 Feet => rb.position;
    public int Gems;
    public int Hits;    // times she was hurt (spikes...)

    Rigidbody2D rb;
    BoxCollider2D body;
    ContactFilter2D solid;
    readonly RaycastHit2D[] hits = new RaycastHit2D[8];
    float coyote, buffer, airTime, landTime, hurtTime, safeTime, fallSpeed;
    bool jumping, wasGrounded, noGrab;
    Ladder ladder;
    Vector2 lastSafe;

    [Serializable] class ClipData { public string name, file; public int frames, w, h; public float fps, ax; }
    [Serializable] class JananiData { public int cell; public ClipData[] clips; }

    /// <summary>Janani standing with her feet at `feet`, in the room.</summary>
    public static Janani Create(Room room, Vector2 feet)
    {
        var go = new GameObject("Janani");
        go.transform.position = feet;
        var j = go.AddComponent<Janani>();
        j.Setup(room);
        return j;
    }

    void Setup(Room room)
    {
        Room = room;
        lastSafe = transform.position;
        rb = gameObject.AddComponent<Rigidbody2D>();
        rb.gravityScale = 0; // (her own gravity, below: firmer when falling)
        rb.freezeRotation = true;
        rb.interpolation = RigidbodyInterpolation2D.Interpolate;
        rb.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
        rb.useFullKinematicContacts = true; // (on a ladder she is kinematic: gems must still notice her)
        body = gameObject.AddComponent<BoxCollider2D>();
        body.edgeRadius = 0.04f; // (rounded corners don't snag on tile edges)
        body.size = new Vector2(40 * Px - 0.08f, 112 * Px - 0.08f);
        body.offset = new Vector2(0, 56 * Px);
        body.sharedMaterial = new PhysicsMaterial2D("Janani") { friction = 0, bounciness = 0 };
        solid = new ContactFilter2D { useTriggers = false };

        var pic = new GameObject("Look");
        pic.transform.SetParent(transform, false);
        Look = pic.AddComponent<Flipbook>();
        Look.Renderer.sortingOrder = 10;
        LoadClips();
        Look.Play("idle");

        // a soft warm light around her (the Godot version's "light around Janani")
        var glow = new GameObject("Glow").AddComponent<Light2D>();
        glow.transform.SetParent(transform, false);
        glow.transform.localPosition = new Vector3(0, 1.3f, 0);
        glow.lightType = Light2D.LightType.Point;
        glow.pointLightOuterRadius = 4.5f;
        glow.pointLightInnerRadius = 0.5f;
        glow.intensity = 0.35f;
        glow.color = new Color(1f, 0.86f, 0.62f);
    }

    /// <summary>Her animations, cut the same way as the Godot version's detailed_frames().</summary>
    void LoadClips()
    {
        var data = JsonUtility.FromJson<JananiData>(Resources.Load<TextAsset>("Data/janani").text);
        var strips = new Dictionary<string, (Sprite[] frames, float fps)>();
        foreach (var c in data.clips)
            strips[c.name] = (Art.Strip("Janani/" + c.file, c.frames, c.w, c.h, c.ax), c.fps);
        // the frames between two points of a clip (0 = its start, 1 = its end)
        Sprite[] Part(Sprite[] all, float from, float to)
        {
            int a = (int)(all.Length * from);
            int b = Mathf.Min(all.Length, Mathf.Max(a + 1, (int)(all.Length * to)));
            return all[a..b];
        }
        var run = strips["run"].frames;
        float runFps = Mathf.Clamp(run.Length / 0.65f, 12, 26); // one stride takes about two thirds of a second
        var hurt = strips["hurt"].frames;
        var jump = strips["jump"].frames;
        Look.Add("run", run, runFps, true);
        if (strips.TryGetValue("walk", out var walk)) Look.Add("walk", walk.frames, walk.fps, true);
        else Look.Add("walk", run, runFps * 0.6f, true);
        if (strips.TryGetValue("idle", out var idle)) Look.Add("idle", idle.frames, idle.fps, true);
        else Look.Add("idle", Part(hurt, 0, 0.24f), 6, true);
        Look.Add("takeoff", Part(jump, 0.24f, 0.32f), 16, false);
        Look.Add("rise", Part(jump, 0.40f, 0.52f), 12, false);
        Look.Add("peak", Part(jump, 0.56f, 0.68f), 10, false);
        Look.Add("fall", Part(jump, 0.68f, 0.80f), 12, false);
        Look.Add("land", Part(jump, 0.80f, 0.92f), 16, false);
        Look.Add("hurt", Part(hurt, 0.32f, 0.52f), 24, false);
        if (strips.TryGetValue("climb", out var climb)) Look.Add("climb", climb.frames, climb.fps, true);
        else Look.Add("climb", run, runFps * 0.6f, true);
    }

    /// <summary>Put her somewhere at once (a respawn, the tests), standing still.</summary>
    public void Teleport(Vector2 feet)
    {
        if (Climbing)
            StopClimb();
        rb.position = feet;
        transform.position = feet;
        rb.linearVelocity = Vector2.zero;
        lastSafe = feet;
    }

    void Update()
    {
        // flashing for a moment after a hit
        Look.Renderer.enabled = safeTime <= 0 || (int)(safeTime / 0.09f) % 2 == 0;
    }

    void FixedUpdate()
    {
        if (rb == null)
            return;
        float dt = Time.fixedDeltaTime;
        hurtTime -= dt;
        safeTime -= dt;
        landTime -= dt;
        bool jumpPress = GameInput.TakePress(Act.Jump);

        if (Climbing)
        {
            ClimbStep(dt, jumpPress);
            return;
        }
        if (TryGrabLadder())
            return;

        Grounded = OnGround();
        var v = rb.linearVelocity;
        if (Grounded && !wasGrounded && fallSpeed > 420 * Px && Mathf.Abs(v.x) < 160 * Px)
            landTime = 0.09f; // a quick crouch after a big drop
        wasGrounded = Grounded;
        fallSpeed = -v.y;
        coyote = Grounded ? Coyote : coyote - dt;
        buffer = jumpPress ? JumpBuffer : buffer - dt;
        airTime = Grounded ? 0 : airTime + dt;

        // ease toward the target speed so turning feels smooth, a little looser in the air
        float dir = hurtTime > 0 ? 0 : GameInput.Axis;
        float grip = hurtTime > 0 ? 0 : (Grounded ? 14 : 7);
        v.x += (dir * RunSpeed - v.x) * Mathf.Min(1, grip * dt);
        if (buffer > 0 && coyote > 0)
        {
            v.y = HopSpeed;
            buffer = coyote = 0;
            jumping = true;
            airTime = 0;
            Grounded = false;
        }
        // a tap gives a short hop; holding gives the full hop that clears a one-tile obstacle
        if (jumping && !GameInput.Held(Act.Jump) && v.y > HopCut)
            v.y = HopCut;
        if (v.y <= 0)
            jumping = false;
        v.y = Mathf.Max(v.y - Gravity * (v.y < 0 ? FallPull : 1) * dt, -MaxFall);
        if (dir != 0)
            Look.Renderer.flipX = dir < 0;
        rb.linearVelocity = v;

        if (Grounded && Mathf.Abs(v.x) < 0.1f)
            lastSafe = rb.position;
        if (rb.position.y < -3) // fell into a gap: back to where she last stood
        {
            Hurt(rb.position.x);
            Teleport(lastSafe);
        }
        Animate();
    }

    bool OnGround()
    {
        if (rb.linearVelocity.y > 0.05f)
            return false;
        int n = rb.Cast(Vector2.down, solid, hits, 0.06f);
        for (int i = 0; i < n; i++)
            if (hits[i].normal.y > 0.6f)
                return true;
        return false;
    }

    // ---------------------------------------------------------------- ladders

    /// <summary>Up in front of a ladder grabs it; Down standing on its top climbs down.</summary>
    bool TryGrabLadder()
    {
        bool up = GameInput.Held(Act.Up), down = GameInput.Held(Act.Down);
        if (!up)
            noGrab = false;
        var feet = rb.position;
        foreach (var l in Room.Ladders)
        {
            float cx = l.col + 0.5f;
            if (Mathf.Abs(feet.x - cx) > 0.62f)
                continue;
            if (up && !noGrab && feet.y >= l.bottomY - 0.1f && feet.y < l.topY - 0.05f)
            {
                StartClimb(l);
                return true;
            }
            if (down && Grounded && Mathf.Abs(feet.y - l.topY) < 0.2f && Mathf.Abs(feet.x - cx) < 0.45f)
            {
                StartClimb(l);
                rb.position = new Vector2(cx, l.topY - 0.3f); // step down past the top
                return true;
            }
        }
        return false;
    }

    void StartClimb(Ladder l)
    {
        Climbing = true;
        ladder = l;
        jumping = false;
        rb.linearVelocity = Vector2.zero;
        rb.bodyType = RigidbodyType2D.Kinematic; // (passes through the floor above while climbing)
    }

    void StopClimb()
    {
        Climbing = false;
        rb.bodyType = RigidbodyType2D.Dynamic;
    }

    void ClimbStep(float dt, bool jumpPress)
    {
        bool up = GameInput.Held(Act.Up), down = GameInput.Held(Act.Down);
        float side = GameInput.Axis;
        // Jump hops off (not the keyboard's Up key, which is also a jump key: tapping Up keeps her climbing)
        if (jumpPress && !up)
        {
            StopClimb();
            rb.linearVelocity = new Vector2(side * 240 * Px, 380 * Px);
            return;
        }
        var p = rb.position;
        p.x = Mathf.Lerp(p.x, ladder.col + 0.5f, Mathf.Min(1, 18 * dt));
        float vy = up ? ClimbSpeed : down ? -ClimbSpeed : 0;
        p.y += vy * dt;
        if (p.y >= ladder.topY - 0.12f && (up || side != 0)) // the top: step onto the floor above
        {
            p.y = ladder.topY;
            StopClimb();
            rb.position = p;
            rb.linearVelocity = new Vector2(side * 160 * Px, 0);
            noGrab = true; // (holding Up must not grab the ladder again)
            return;
        }
        if (p.y <= ladder.bottomY && down) // the bottom: step onto the ground
        {
            p.y = ladder.bottomY;
            StopClimb();
            rb.position = p;
            return;
        }
        p.y = Mathf.Min(p.y, ladder.topY);
        rb.MovePosition(p);
        Look.Play("climb");
        Look.Speed = vy != 0 ? 1 : 0;
    }

    /// <summary>Hurt by something at x: knocked away from it, then a moment of flashing safety.</summary>
    public void Hurt(float fromX)
    {
        if (safeTime > 0)
            return;
        Hits++;
        hurtTime = 0.35f;
        safeTime = 2f;
        jumping = false;
        if (!Climbing)
            rb.linearVelocity = new Vector2(rb.position.x < fromX ? -260 * Px : 260 * Px, 420 * Px);
    }

    void Animate()
    {
        var v = rb.linearVelocity;
        float vx = Mathf.Abs(v.x);
        Look.Speed = 1;
        if (hurtTime > 0) Look.Play("hurt");
        else if (!Grounded)
        {
            if (jumping && airTime < 0.11f) Look.Play("takeoff");
            else if (v.y > 260 * Px) Look.Play("rise");
            else if (v.y > -260 * Px) Look.Play("peak");
            else Look.Play("fall");
        }
        else if (landTime > 0) Look.Play("land");
        else if (vx > 160 * Px)
        {
            Look.Play("run");
            Look.Speed = Mathf.Clamp(vx / (260 * Px), 0.8f, 1.3f); // legs keep pace with her speed
        }
        else if (vx > 25 * Px) Look.Play("walk");
        else Look.Play("idle");
    }
}
