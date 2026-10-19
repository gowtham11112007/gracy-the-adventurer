using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;

[Serializable] public class RoomExit { public string side, to, arrive, gate; public int col, row; }
[Serializable] public class RoomDef
{
    public string id, name, area_name, area, mood;
    public int width, start;
    public RoomExit[] exits;
    public int[] benches;
    public string[] grid;
}
[Serializable] class RoomList { public RoomDef[] rooms; }

/// <summary>One ladder: its column, where the floor above is (top) and the ground it stands on (bottom), in units.</summary>
public struct Ladder
{
    public int col;
    public float topY, bottomY;
}

/// <summary>
/// One room of the world, built from its tile grid (Resources/Data/rooms.json, made from the Godot project by
/// tools/export_unity_data.py) the way the Godot version builds it: ground from the area's art pack, a ladder up
/// to the second floor, obstacles to hop (crate C, boulder R, barrel O, spikes ^), gems (o), the background, light,
/// Janani, the camera and the phone's buttons. Grid rows go down from row 0 to the ground (rows 10 and 11); in
/// Unity y goes up, so a tile in row r spans y = 11 - r to 12 - r. One tile is one unit.
/// Test it from the command line with  -room w6  (any room id) and  -entry left|right|up|down|bench.
/// </summary>
public class Room : MonoBehaviour
{
    public const int Rows = 12;
    public string roomId = "level1";
    public string entry = "left";

    public RoomDef Def { get; private set; }
    public Janani Player { get; private set; }
    public readonly List<Ladder> Ladders = new();
    public string Skin { get; private set; }

    static readonly Dictionary<string, string> SkinForMood = new()
    {
        { "day", "meadow" }, { "windy", "meadow" }, { "sky", "sky" }, { "golden", "desert" }, { "dusk", "graveyard" },
        { "village", "village" }, // (Level 1: the Asset Store packs, see Village)
    };
    static readonly Dictionary<string, RoomDef> all = new();
    Transform art;

    /// <summary>A room's data by its id (null if there's none).</summary>
    public static RoomDef Find(string id)
    {
        if (all.Count == 0)
            foreach (var file in new[] { "Data/rooms", "Data/levels" }) // the world's rooms, and the hand-made levels
            {
                var text = Resources.Load<TextAsset>(file);
                if (text != null)
                    foreach (var r in JsonUtility.FromJson<RoomList>(text.text).rooms)
                        all[r.id] = r;
            }
        return all.TryGetValue(id, out var def) ? def : null;
    }

    /// <summary>The top edge of a grid row, in units: where feet stand on that row.</summary>
    public static float TopY(int row) => Rows - row;

    /// <summary>The tile at a column and row (' ' outside the room).</summary>
    public char At(int c, int r) => r >= 0 && r < Rows && c >= 0 && c < Def.width ? Def.grid[r][c] : ' ';

    void Start()
    {
        Time.fixedDeltaTime = 1f / 60f; // (as in Godot: the hop is tuned to 60 steps a second)
        var args = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(args, "-room");
        if (i >= 0 && i + 1 < args.Length) roomId = args[i + 1];
        i = Array.IndexOf(args, "-entry");
        if (i >= 0 && i + 1 < args.Length) entry = args[i + 1];

        if (Array.IndexOf(args, "-room") >= 0 || Array.IndexOf(args, "-autorun") >= 0)
            Flow.Showing = Flow.Screen.Level; // (test runs go straight into the level)
        else if (Array.IndexOf(args, "-map") >= 0)
            Flow.Showing = Flow.Screen.Map; // (test runs: the world map)
        else if (Flow.Playing)
            roomId = Flow.LevelId; // (the level chosen on the world map)
        Def = Find(roomId) ?? Find("level1") ?? Find("m1");
        Skin = SkinForMood.TryGetValue(Def.mood, out var s) ? s : "meadow";
        if (FindAnyObjectByType<GameInput>() == null)
            new GameObject("Input").AddComponent<GameInput>();
        GameInput.Clear();
        if (!Flow.Playing) // the title screen (mountains in the clouds) or the world map: music, wind, the menu
        {
            GameInput.Blocked = true;
            Ambience(title: true);
            if (Flow.Showing == Flow.Screen.Map) MapUI.Show();
            else MenuUI.Title();
            return;
        }
        art = new GameObject("Art").transform;
        art.SetParent(transform, false);

        BuildGround();
        BuildThings();
        BuildBackground();
        BuildLight();
        if (Village)
            Fireflies.Create(art, Def.width, Def.width / 3);
        Entrance = StartFeet();
        Player = Janani.Create(this, Entrance);
        var cam = Camera.main;
        CameraFollow follow = null;
        if (cam != null)
        {
            follow = cam.GetComponent<CameraFollow>();
            if (follow == null)
                follow = cam.gameObject.AddComponent<CameraFollow>();
            follow.Follow(Player, Def.width);
        }
        if (Village)
            Ambience();
        GameInput.Blocked = false;
        HealthBar.Create(Player);
        if (TouchPad.Wanted())
            TouchPad.Create();
        LevelUI.Create(Def.area_name, Def.name);
        MenuUI.InGame();
    }

    bool Village => Skin == "village";

    /// <summary>The village's sound: birdsong and a light wind, soft music under them (the title: wind and music).</summary>
    void Ambience(bool title = false)
    {
        void Loop(string clip, float volume, bool isMusic)
        {
            var a = gameObject.AddComponent<AudioSource>();
            a.clip = Resources.Load<AudioClip>("Audio/" + clip);
            a.loop = true;
            a.volume = volume;
            a.Play();
            if (isMusic) Flow.Music(a); else Flow.Sound(a);
        }
        if (!title)
            Loop("BirdLoop", 0.45f, false);
        Loop("WindWeakLoop", 0.25f, false);
        Loop("SummerTension", 0.3f, true);
    }

    /// <summary>Where she came in (where she starts again if she runs out of health).</summary>
    public Vector2 Entrance { get; private set; }

    /// <summary>Where she appears: beside the door she came in by, in a doorway, at the bench, or the start.</summary>
    Vector2 StartFeet()
    {
        int col = Def.start, row = 10;
        if (entry == "left") col = 2;
        else if (entry == "right") col = Def.width - 3;
        else if (entry == "bench" && Def.benches is { Length: > 0 }) col = Def.benches[0];
        else
            foreach (var ex in Def.exits ?? new RoomExit[0])
                if (ex.side == entry)
                {
                    col = ex.col;
                    row = ex.row;
                }
        return new Vector2(col + 0.5f, TopY(row));
    }

    SpriteRenderer Picture(Sprite sprite, Vector2 at, int order, string name)
    {
        var go = new GameObject(name);
        go.transform.SetParent(art, false);
        go.transform.localPosition = at;
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = sprite;
        sr.sortingOrder = order;
        return sr;
    }

    /// <summary>
    /// Ground and floors (one merged collision shape, so she never snags on tile edges), the ladders with a
    /// step at their top, the solid obstacles and the walls at both ends.
    /// </summary>
    void BuildGround()
    {
        var ground = new GameObject("Ground");
        ground.transform.SetParent(transform, false);
        ground.AddComponent<Rigidbody2D>().bodyType = RigidbodyType2D.Static;
        var shape = ground.AddComponent<CompositeCollider2D>();
        shape.geometryType = CompositeCollider2D.GeometryType.Polygons;
        shape.sharedMaterial = new PhysicsMaterial2D("Ground") { friction = 0 };
        void Box(Vector2 center, Vector2 size)
        {
            var b = ground.AddComponent<BoxCollider2D>();
            b.offset = center;
            b.size = size;
            b.compositeOperation = Collider2D.CompositeOperation.Merge;
        }

        int[] floatPieces = { 13, 14, 15 };
        for (int r = 0; r < Rows; r++)
        {
            int run = -1;
            for (int c = 0; c <= Def.width; c++)
            {
                char ch = At(c, r);
                if (c < Def.width && ch == '#' && Village)
                    global::Village.Place(art, global::Village.Ground(GroundPiece(c, r) - 1), new Vector2(c, TopY(r) - 1), 0, "Ground", Vector2.zero);
                else if (c < Def.width && ch == '#')
                    Picture(Art.Picture($"Skins/{Skin}/tile_{GroundPiece(c, r)}", Vector2.zero), new Vector2(c, TopY(r) - 1), 0, "Ground");
                else if (c < Def.width && ch == '=' && Village)
                {
                    bool left = At(c - 1, r) == '=', right = At(c + 1, r) == '=';
                    string piece = right && !left ? "Platform L 01" : left && !right ? "Platform R 01" : "Platform M 01";
                    global::Village.Place(art, global::Village.Prop(piece), new Vector2(c, TopY(r)), 0, "Floor", new Vector2(0, 1));
                }
                else if (c < Def.width && ch == '=')
                {
                    bool left = At(c - 1, r) == '=', right = At(c + 1, r) == '=';
                    int n = right && !left ? floatPieces[0] : left && !right ? floatPieces[2] : floatPieces[1];
                    Picture(Art.Picture($"Skins/{Skin}/tile_{n}", new Vector2(0, 1)), new Vector2(c, TopY(r)), 0, "Floor");
                }
                bool solid = c < Def.width && (ch == '#' || ch == '=');
                if (solid && run < 0)
                    run = c;
                else if (!solid && run >= 0)
                {
                    // (the village's wooden platforms are thinner than a tile)
                    float high = Village && At(run, r) == '=' ? 0.8f : 1f;
                    Box(new Vector2((run + c) / 2f, TopY(r) - high / 2), new Vector2(c - run, high));
                    run = -1;
                }
            }
        }

        // ladders: rungs behind her, and a thin step at the top that fills the gap in the floor above
        var ladderSprite = Art.Picture("Props/ladder", Vector2.zero);
        for (int c = 0; c < Def.width; c++)
        {
            int top = -1, bottom = -1;
            for (int r = 0; r < Rows; r++)
                if (At(c, r) == 'L')
                {
                    if (top < 0) top = r;
                    bottom = r;
                    if (Village)
                        global::Village.Place(art, global::Village.Prop(r == top ? "Ladder 01 T" : At(c, r + 1) == 'L' ? "Ladder 01 M" : "Ladder 01 B"), new Vector2(c, TopY(r) - 1), -5, "Ladder", Vector2.zero);
                    else
                        Picture(ladderSprite, new Vector2(c, TopY(r) - 1), -5, "Ladder");
                }
            if (top < 0)
                continue;
            Ladders.Add(new Ladder { col = c, topY = TopY(top), bottomY = TopY(bottom + 1) });
            Box(new Vector2(c + 0.5f, TopY(top) - 0.075f), new Vector2(1, 0.15f));
        }

        // solid obstacles to hop over
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Def.width; c++)
            {
                char ch = At(c, r);
                if ("CRO^".IndexOf(ch) < 0)
                    continue;
                var foot = new Vector2(c + 0.5f, TopY(r) - 1);
                if (Village) // the village's own crate, barrel, stump and spikes, each as solid as it looks
                {
                    string name = ch switch { 'C' => "Crate Small", 'O' => "Barrel", 'R' => "Stump", _ => "Spike Plate" };
                    var pic = global::Village.Stand(art, name, foot, 1, name);
                    var size = pic.sprite.bounds.size;
                    Box(foot + new Vector2(0, size.y / 2), new Vector2(Mathf.Min(1, size.x), size.y));
                    if (ch == '^')
                        Hazard.Create(art, foot + new Vector2(0, 0.35f), new Vector2(0.8f, 0.7f));
                    continue;
                }
                Box(new Vector2(c + 0.5f, TopY(r) - 0.5f), Vector2.one);
                switch (ch)
                {
                    case 'C': Picture(Art.Picture($"Skins/{Skin}/block", new Vector2(0.5f, 0)), foot, 1, "Crate"); break;
                    case 'R': Picture(Art.Picture("Props/boulder", new Vector2(0.5f, 0)), foot, 1, "Boulder"); break;
                    case 'O': Picture(Art.Picture("Props/barrel", new Vector2(0.5f, 0)), foot, 1, "Barrel"); break;
                    case '^':
                        Picture(Art.Picture("Props/tile_spikes", new Vector2(0.5f, 0)), foot, 1, "Spikes");
                        Hazard.Create(art, new Vector2(c + 0.5f, TopY(r) - 0.45f), new Vector2(0.8f, 1.1f));
                        break;
                }
            }

        // the room's two ends are walls for now (doors to the next rooms come next)
        Box(new Vector2(-0.5f, Rows), new Vector2(1, Rows * 3));
        Box(new Vector2(Def.width + 0.5f, Rows), new Vector2(1, Rows * 3));
    }

    /// <summary>Which numbered ground piece a tile needs: grass on top where it's open above (1-3), earth below
    /// (4-6), rounded at a side that's open (the Godot version's _ground_piece).</summary>
    int GroundPiece(int c, int r)
    {
        bool Ground(int cc, int rr) => cc < 0 || cc >= Def.width || (rr >= 0 && rr < Rows && Def.grid[rr][cc] == '#');
        bool openLeft = !Ground(c - 1, r), openRight = !Ground(c + 1, r);
        int side = openLeft == openRight ? 0 : (openLeft ? -1 : 1);
        int middle = Ground(c, r - 1) ? 5 : 2;
        return middle + side;
    }

    /// <summary>Gems to collect. (Animals, crystals and candles come next.)</summary>
    void BuildThings()
    {
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Def.width; c++)
                if (At(c, r) == 'o')
                    Gem.Create(art, new Vector2(c + 0.5f, TopY(r) - 0.85f));
                else if (Village && (At(c, r) == 'm' || At(c, r) == 'W'))
                    Creature.Create(this, art, At(c, r), c, r);
                else if (At(c, r) == 'T')
                    Chest.Create(art, new Vector2(c + 0.5f, TopY(r) - 1));
                else if (Village)
                    global::Village.Scenery(At(c, r), art, new Vector2(c + 0.5f, TopY(r) - 1), c);
    }

    /// <summary>The area's painted background, in layers that drift slower the further away they are.</summary>
    void BuildBackground()
    {
        if (Village)
        {
            global::Village.Background(transform);
            return;
        }
        for (int i = 0; i < 4; i++)
        {
            if (Resources.Load<Texture2D>($"Art/Skins/{Skin}/bg_{i}") == null)
                break;
            Parallax.Create(transform, Art.Picture($"Skins/{Skin}/bg_{i}", Vector2.zero), 0.1f + i * 0.15f, -100 + i);
        }
    }

    /// <summary>The room's light: one soft light over everything, tinted by the area's mood.</summary>
    void BuildLight()
    {
        var light = new GameObject("Light").AddComponent<Light2D>();
        light.transform.SetParent(transform, false);
        light.lightType = Light2D.LightType.Global;
        light.intensity = Def.mood == "dusk" ? 0.75f : Def.mood == "village" ? 0.8f : 1f; // (the village: evening, so its lamps glow)
        light.color = Def.mood switch
        {
            "day" => new Color(1f, 0.97f, 0.9f),
            "windy" => new Color(0.92f, 0.96f, 1f),
            "golden" => new Color(1f, 0.9f, 0.75f),
            "dusk" => new Color(0.75f, 0.8f, 1f),
            "village" => new Color(1f, 0.88f, 0.74f),
            _ => Color.white,
        };
    }
}

/// <summary>
/// A gem: a sparkling pixel crystal (tools/make_pixel_gem.py) that bobs in a soft glow and chimes when she touches
/// it. Gems from a chest pop out, fall, and then fly to her.
/// </summary>
public class Gem : MonoBehaviour
{
    Vector2 velocity, home;
    float age, seed;
    bool popped, taken;
    Transform look;

    public static Gem Create(Transform parent, Vector2 at)
    {
        var go = new GameObject("Gem");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = at;
        var g = go.AddComponent<Gem>();
        g.home = at;
        g.seed = at.x * 0.7f;
        var glow = new GameObject("Glow").AddComponent<SpriteRenderer>();
        glow.transform.SetParent(go.transform, false);
        glow.transform.localPosition = new Vector3(0, 0.3f, 0);
        glow.transform.localScale = new Vector3(0.9f, 1.4f, 1);
        glow.sprite = Art.Glow;
        glow.color = new Color(0.55f, 0.85f, 1f, 0.45f);
        glow.sortingOrder = 1;
        var pic = new GameObject("Look");
        pic.transform.SetParent(go.transform, false);
        g.look = pic.transform;
        var book = pic.AddComponent<Flipbook>();
        var f = Art.Strip("Props/gem_pixel", 8, 32, 36, 16);
        // (the glint sweeps across, then it rests a moment)
        if (f.Length == 8)
            book.Add("shine", new[] { f[0], f[0], f[0], f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7] }, 10, true);
        book.Play("shine");
        book.Renderer.sortingOrder = 2;
        var touch = go.AddComponent<CircleCollider2D>();
        touch.isTrigger = true;
        touch.radius = 0.35f;
        touch.offset = new Vector2(0, 0.3f);
        return g;
    }

    /// <summary>A gem thrown out of an opened chest.</summary>
    public static void Pop(Transform parent, Vector2 from, Vector2 velocity)
    {
        var g = Create(parent, from);
        g.popped = true;
        g.velocity = velocity;
    }

    void Update()
    {
        age += Time.deltaTime;
        if (!popped)
        {
            look.localPosition = new Vector3(0, Mathf.Sin(Time.time * 2.4f + seed) * 0.07f, 0);
            return;
        }
        // out of the chest: up, down, then off to her
        var p = (Vector2)transform.localPosition;
        var j = FindAnyObjectByType<Janani>();
        if (age > 0.55f && j != null)
        {
            var target = j.Feet + Vector2.up * 0.9f;
            p = Vector2.MoveTowards(p, target, (4 + age * 10) * Time.deltaTime);
        }
        else
        {
            velocity.y -= 18 * Time.deltaTime;
            p += velocity * Time.deltaTime;
        }
        transform.localPosition = p;
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        var j = other.GetComponentInParent<Janani>();
        if (j == null || taken || (popped && age < 0.4f))
            return;
        taken = true;
        j.Gems++;
        j.PlaySound(Resources.Load<AudioClip>("Audio/GemChime"), 0.45f);
        Sparkle.Burst(transform.position + Vector3.up * 0.35f, new Color(0.7f, 0.92f, 1f), 7);
        Destroy(gameObject);
    }
}

/// <summary>A golden treasure chest ('T'): touching it opens it, and five gems spill out.</summary>
public class Chest : MonoBehaviour
{
    Flipbook look;
    bool open;

    public static void Create(Transform parent, Vector2 foot)
    {
        var go = new GameObject("Chest");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = foot;
        var c = go.AddComponent<Chest>();
        var frames = new Sprite[7];
        var sheet = new System.Collections.Generic.Dictionary<string, Sprite>();
        foreach (var s in Resources.LoadAll<Sprite>("Art/Village/TX Chest Animation"))
            sheet[s.name] = s;
        for (int i = 0; i < 7; i++)
            sheet.TryGetValue("TX Chest Animation Golden " + i, out frames[i]);
        var pic = new GameObject("Look");
        pic.transform.SetParent(go.transform, false);
        c.look = pic.AddComponent<Flipbook>();
        c.look.Add("shut", new[] { frames[0] }, 1, true);
        c.look.Add("open", frames, 14, false);
        c.look.Play("shut");
        c.look.Renderer.sortingOrder = 1;
        if (frames[0] != null) // (stand it on the floor)
            pic.transform.localPosition = new Vector3(-frames[0].bounds.center.x, -frames[0].bounds.min.y, 0);
        var glow = new GameObject("Glow").AddComponent<UnityEngine.Rendering.Universal.Light2D>();
        glow.transform.SetParent(go.transform, false);
        glow.transform.localPosition = new Vector3(0, 0.5f, 0);
        glow.lightType = UnityEngine.Rendering.Universal.Light2D.LightType.Point;
        glow.pointLightOuterRadius = 2.2f;
        glow.intensity = 0.8f;
        glow.color = new Color(1f, 0.8f, 0.4f);
        glow.gameObject.AddComponent<Flicker>();
        var box = go.AddComponent<BoxCollider2D>();
        box.isTrigger = true;
        box.size = new Vector2(1.2f, 1.2f);
        box.offset = new Vector2(0, 0.6f);
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        var j = other.GetComponentInParent<Janani>();
        if (j == null || open)
            return;
        open = true;
        look.Play("open");
        j.PlaySound(Resources.Load<AudioClip>("Audio/HeroOpenBag"), 0.8f);
        j.PlaySound(Resources.Load<AudioClip>("Audio/ChestSparkle"), 0.4f);
        Sparkle.Burst(transform.position + Vector3.up * 0.8f, new Color(1f, 0.85f, 0.45f), 12);
        for (int i = 0; i < 5; i++)
            Gem.Pop(transform.parent, (Vector2)transform.localPosition + Vector2.up * 0.8f, new Vector2(-2f + i, 6f + (i % 2) * 1.5f));
    }
}

/// <summary>A little puff of dust (her jumps and landings).</summary>
public class Puff : MonoBehaviour
{
    Vector2 velocity;
    float age, life = 0.45f;
    SpriteRenderer sr;

    public static void At(Vector2 feet, int count)
    {
        for (int i = 0; i < count; i++)
        {
            var go = new GameObject("Puff");
            go.transform.position = feet + new Vector2(UnityEngine.Random.Range(-0.2f, 0.2f), 0.05f);
            var p = go.AddComponent<Puff>();
            p.sr = go.AddComponent<SpriteRenderer>();
            p.sr.sprite = Art.Glow;
            p.sr.sortingOrder = 11;
            p.sr.color = new Color(0.95f, 0.85f, 0.72f, 0.7f);
            float side = i % 2 == 0 ? -1 : 1;
            p.velocity = new Vector2(side * UnityEngine.Random.Range(0.6f, 1.6f), UnityEngine.Random.Range(0.2f, 0.6f));
        }
    }

    void Update()
    {
        age += Time.deltaTime;
        transform.position += (Vector3)(velocity * Time.deltaTime);
        velocity *= 0.9f;
        float k = age / life;
        transform.localScale = Vector3.one * (0.25f + k * 0.35f);
        sr.color = new Color(sr.color.r, sr.color.g, sr.color.b, 0.7f * (1 - k));
        if (age >= life)
            Destroy(gameObject);
    }
}

/// <summary>Fireflies drifting over the whole level, glowing on and off.</summary>
public class Fireflies : MonoBehaviour
{
    class Fly { public Transform t; public SpriteRenderer sr; public Vector2 home; public float seed; }
    readonly System.Collections.Generic.List<Fly> flies = new();

    public static void Create(Transform parent, float width, int count)
    {
        var go = new GameObject("Fireflies");
        go.transform.SetParent(parent, false);
        var f = go.AddComponent<Fireflies>();
        for (int i = 0; i < count; i++)
        {
            var dot = new GameObject("Firefly").AddComponent<SpriteRenderer>();
            dot.transform.SetParent(go.transform, false);
            dot.sprite = Art.Glow;
            dot.sortingOrder = 9;
            dot.transform.localScale = Vector3.one * UnityEngine.Random.Range(0.12f, 0.22f);
            f.flies.Add(new Fly { t = dot.transform, sr = dot, home = new Vector2(UnityEngine.Random.Range(1f, width - 1), UnityEngine.Random.Range(2.6f, 8.5f)), seed = UnityEngine.Random.value * 50 });
        }
    }

    void Update()
    {
        float t = Time.time;
        foreach (var f in flies)
        {
            f.t.localPosition = f.home + new Vector2(Mathf.Sin(t * 0.4f + f.seed) * 1.2f, Mathf.Sin(t * 0.7f + f.seed * 1.3f) * 0.5f);
            float glow = Mathf.Clamp01(Mathf.Sin(t * 1.6f + f.seed) * 0.8f + 0.4f);
            f.sr.color = new Color(1f, 0.92f, 0.5f, glow * 0.9f);
        }
    }
}

/// <summary>A looping sound (the campfire's crackle) that grows louder as she comes near.</summary>
public class NearSound : MonoBehaviour
{
    AudioSource src;
    float range;

    public static void Create(Transform parent, Vector2 at, string clip, float range)
    {
        var go = new GameObject("Sound " + clip);
        go.transform.SetParent(parent, false);
        go.transform.localPosition = at;
        var n = go.AddComponent<NearSound>();
        n.range = range;
        n.src = go.AddComponent<AudioSource>();
        n.src.clip = Resources.Load<AudioClip>("Audio/" + clip);
        n.src.loop = true;
        n.src.volume = 0;
        Flow.Sound(n.src);
        n.src.Play();
    }

    void Update()
    {
        var j = FindAnyObjectByType<Janani>();
        if (j == null)
            return;
        float d = Vector2.Distance(j.Feet, transform.position);
        src.volume = Mathf.Clamp01(1 - d / range) * 0.6f;
    }
}

/// <summary>Spikes: touching them hurts.</summary>
public class Hazard : MonoBehaviour
{
    public static void Create(Transform parent, Vector2 center, Vector2 size)
    {
        var go = new GameObject("Hurts");
        go.transform.SetParent(parent, false);
        go.transform.localPosition = center;
        var box = go.AddComponent<BoxCollider2D>();
        box.isTrigger = true;
        box.size = size;
        go.AddComponent<Hazard>();
    }

    void OnTriggerStay2D(Collider2D other)
    {
        var j = other.GetComponentInParent<Janani>();
        if (j != null)
            j.Hurt(transform.position.x);
    }
}
